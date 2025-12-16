from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import json
from datetime import datetime
import os
import numpy as np

app = Flask(__name__)
CORS(app)

# Load model and metadata
print("Loading model and metadata...")
model = joblib.load('accident_prediction_model.pkl')
with open('accident_prone_places.json', 'r') as f:
    accident_prone_data = json.load(f)
with open('feature_names.json', 'r') as f:
    feature_names = json.load(f)
with open('model_metadata.json', 'r') as f:
    model_metadata = json.load(f)

print(f"ML Model loaded - {len(feature_names)} features ready")
print(f"Historical data: {accident_prone_data['total_places']} locations")

def prepare_features(barangay, station, timestamp_str=None, vehicle_type=None, weather=None):
    
    # Parse timestamp or use current time
    if timestamp_str:
        try:
            dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        except:
            dt = datetime.now()
    else:
        dt = datetime.now()

    # Extract temporal features
    month = dt.month
    day_of_week = dt.weekday()
    hour = dt.hour

    # Normalize location inputs for feature matching
    barangay_normalized = barangay.lower().strip().replace(' ', '_')
    station_normalized = station.strip().replace(' ', '_')

    # Create feature dictionary (all features start at 0)
    features = {name: 0 for name in feature_names}

    # Set temporal features
    features['month'] = month
    features['day_of_week'] = day_of_week
    features['hour'] = hour
    features['location_key'] = 0  # Composite key, typically encoded

    # Set station (municipality) one-hot encoding
    station_feature = f"Station_{station_normalized}"
    if station_feature in features:
        features[station_feature] = 1

    # Set place of accident (barangay) one-hot encoding
    place_feature = f"Place_of_Accident_{barangay_normalized}"
    if place_feature in features:
        features[place_feature] = 1

    # Set vehicle type if provided
    if vehicle_type:
        vehicle_normalized = vehicle_type.lower().replace(' ', '_')
        vehicle_feature = f"Vehicles_involved_{vehicle_normalized}"
        if vehicle_feature in features:
            features[vehicle_feature] = 1

    # Set weather if provided
    if weather:
        weather_normalized = weather.lower().replace(' ', '_')
        weather_feature = f"Weather_Condition_{weather_normalized}"
        if weather_feature in features:
            features[weather_feature] = 1

    # All other features remain 0 (defaults for Offense, Severity, Driver Behavior, etc.)
    # This represents "unknown" or "normal" conditions - typical for predictive scenarios

    # Convert to numpy array in correct order
    feature_vector = np.array([features[name] for name in feature_names]).reshape(1, -1)

    return feature_vector

@app.route('/api/check_location', methods=['POST'])
def check_location():
    
    try:
        data = request.json
        barangay = data.get('barangay', '').lower().strip()
        station = data.get('station', 'unknown').lower().strip()
        timestamp_str = data.get('timestamp')
        vehicle_type = data.get('vehicle_type')
        weather = data.get('weather')

        if not barangay:
            return jsonify({'error': 'Barangay name is required'}), 400

        # ML MODEL PREDICTION
        feature_vector = prepare_features(
            barangay=barangay,
            station=station,
            timestamp_str=timestamp_str,
            vehicle_type=vehicle_type,
            weather=weather
        )

        ml_prediction = model.predict(feature_vector)[0]
        ml_prediction_proba = model.predict_proba(feature_vector)[0]

        ml_confidence = float(ml_prediction_proba[1])
        is_accident_prone_ml = bool(ml_prediction == 1)

        print(f"ML Prediction for {barangay}, {station}: {ml_confidence:.2%}")

        # Get historical data for context
        location_key = f"{barangay}, {station}"
        stats = accident_prone_data.get('statistics', {}).get(location_key, {})
        accident_count = stats.get('total_accidents', 0)
        fatal_count = stats.get('fatal_accidents', 0)
        common_offense = stats.get('most_common_offense', 'Unknown')

        # Calculate risk level
        if ml_confidence >= 0.85:
            risk_level = 'CRITICAL'
        elif ml_confidence >= 0.70:
            risk_level = 'HIGH'
        elif ml_confidence >= 0.50:
            risk_level = 'MEDIUM'
        else:
            risk_level = 'LOW'

        # Create message

        if is_accident_prone_ml:
            message = f"ML MODEL ALERT: {barangay.upper()} has {ml_confidence:.0%} predicted accident risk!"
            if accident_count > 0:
                message += f" Historical data shows {accident_count} recorded incidents"
                if fatal_count > 0:
                    message += f" ({fatal_count} fatal)"
                message += "."
        else:
            message = f"{barangay.upper()} appears safe - {ml_confidence:.0%} confidence in low risk."
            if accident_count > 0:
                message += f" (Note: {accident_count} historical incidents recorded)"

        response = {
            'barangay': barangay.title(),
            'station': station.title(),
            'is_accident_prone': is_accident_prone_ml,
            'ml_confidence': ml_confidence,
            'accident_count': accident_count,
            'fatal_accidents': fatal_count,
            'risk_level': risk_level,
            'confidence': ml_confidence,
            'common_offense': common_offense,
            'message': message,
            'timestamp': datetime.now().isoformat(),
            'prediction_method': 'machine_learning'
        }

        return jsonify(response), 200

    except Exception as e:
        print(f"Error in check_location: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500



@app.route('/api/barangay_list', methods=['GET'])
def get_barangay_list():
    """Get list of all barangays and their risk status"""
    is_accident_prone_only = request.args.get('accident_prone_only', 'false').lower() == 'true'

    barangay_list = []
    for location_key, stats in accident_prone_data.get('statistics', {}).items():
        if is_accident_prone_only and not stats.get('is_accident_prone', False):
            continue

        barangay_list.append({
            'name': stats.get('barangay', location_key).title(),
            'station': stats.get('station', 'Unknown').title(),
            'is_accident_prone': stats.get('is_accident_prone', False),
            'total_accidents': stats.get('total_accidents', 0),
            'fatal_accidents': stats.get('fatal_accidents', 0)
        })

    # Sort by accident count
    barangay_list.sort(key=lambda x: x['total_accidents'], reverse=True)

    return jsonify({
        'barangays': barangay_list,
        'total_count': len(barangay_list)
    }), 200

@app.route('/api/municipalities', methods=['GET'])
def get_municipalities():
    """Get list of unique municipalities from loaded data"""
    try:
        # Extract unique municipalities/stations from accident data
        municipalities = set()

        # Get municipalities from statistics data
        for stats in accident_prone_data.get('statistics', {}).values():
            station = stats.get('station', '').strip()
            if station:
                municipalities.add(station.title())

        return jsonify({
            'municipalities': sorted(list(municipalities)),
            'total_count': len(municipalities)
        }), 200

    except Exception as e:
        return jsonify({
            'error': str(e),
            'municipalities': [],
            'total_count': 0
        }), 500

@app.route('/api/barangays', methods=['GET'])
def get_barangays_by_municipality():
    """Get list of barangays for a specific municipality"""
    try:
        municipality = request.args.get('municipality', '').lower().strip()

        if not municipality:
            return jsonify({'error': 'Municipality parameter is required'}), 400

        barangays = set()  # Use set to avoid duplicates

        # Get barangays for the specified municipality from statistics
        for location_key, stats in accident_prone_data.get('statistics', {}).items():
            station = stats.get('station', '').lower().strip()
            if station == municipality:
                barangay = stats.get('barangay', '')
                if barangay:
                    barangays.add(barangay.title())

        # Convert to sorted list (alphabetically)
        barangays_list = sorted(list(barangays))

        return jsonify({
            'municipality': municipality.title(),
            'barangays': barangays_list,
            'total_count': len(barangays_list)
        }), 200

    except Exception as e:
        return jsonify({'error': str(e), 'barangays': []}), 500


@app.route('/', methods=['GET'])
def home():
    """API information"""
    return jsonify({
        'service': 'Accident Prone Area Prediction API (ML-Powered)',
        'version': '2.0.0',
        'model': {
            'type': model_metadata['model_type'],
            'accuracy': model_metadata['accuracy'],
            'features': len(feature_names)
        },
        'endpoints': {
            'POST /api/check_location': 'ML prediction for accident risk',
            'GET /api/barangay_list': 'Get list of all barangays',
            'GET /api/municipalities': 'Get list of municipalities',
            'GET /api/barangays': 'Get barangays by municipality',
        }
    }), 200

if __name__ == '__main__':
    print("\n" + "="*60)
    print("ACCIDENT PREDICTION API (ML-POWERED)")
    print("="*60)
    print(f"\nML Model:")
    print(f"   Type: {model_metadata['model_type']}")
    print(f"   Accuracy: {model_metadata['accuracy']:.2%}")
    print(f"   Features: {len(feature_names)}")
    print(f"   Training samples: {model_metadata['training_samples']}")
    print(f"\nData:")
    print(f"   Total locations: {accident_prone_data['total_places']}")
    print(f"\nEndpoints:")
    print("   - POST /api/check_location (ML prediction)")
    print("   - GET  /api/barangay_list")
    print("   - GET  /api/municipalities")
    print("   - GET  /api/barangays")

    port = int(os.environ.get('PORT', 5000))
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

    print(f"\nServer: http://0.0.0.0:{port}")
    print(f"Debug: {debug_mode}")
    print("="*60 + "\n")

    app.run(host='0.0.0.0', port=port, debug=debug_mode)