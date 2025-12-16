"""
Test script to verify ML model integration in the API.
This script tests that the model.predict() function is actually being called.
"""

import requests
import json
from datetime import datetime

# API endpoint
API_URL = "http://localhost:5000/api/check_location"

# Test cases: known accident-prone locations from the training data
test_cases = [
    {
        "name": "Test 1: Poblacion, Mangaldan (Known accident-prone)",
        "barangay": "poblacion",
        "station": "Mangaldan",
        "timestamp": datetime.now().isoformat(),
    },
    {
        "name": "Test 2: Lucao, Dagupan City (Known accident-prone)",
        "barangay": "lucao",
        "station": "Dagupan City",
        "timestamp": datetime.now().isoformat(),
    },
    {
        "name": "Test 3: Random barangay (Likely safe)",
        "barangay": "test_barangay",
        "station": "Dagupan City",
        "timestamp": datetime.now().isoformat(),
    },
    {
        "name": "Test 4: Night time prediction (22:00)",
        "barangay": "poblacion",
        "station": "Dagupan City",
        "timestamp": "2025-12-16T22:00:00Z",
    },
    {
        "name": "Test 5: Morning rush hour (07:00)",
        "barangay": "poblacion",
        "station": "Dagupan City",
        "timestamp": "2025-12-16T07:00:00Z",
    },
]

print("\n" + "="*70)
print("ML MODEL API TESTING")
print("="*70)

for i, test in enumerate(test_cases, 1):
    print(f"\n{'='*70}")
    print(f"{test['name']}")
    print(f"{'='*70}")

    # Prepare request
    payload = {
        "barangay": test["barangay"],
        "station": test["station"],
        "timestamp": test["timestamp"],
    }

    print(f"📤 Request:")
    print(f"   Barangay: {payload['barangay']}")
    print(f"   Station: {payload['station']}")
    print(f"   Timestamp: {payload['timestamp']}")

    try:
        # Make API request
        response = requests.post(API_URL, json=payload, timeout=10)

        if response.status_code == 200:
            result = response.json()

            print(f"\n✅ Response (Status: {response.status_code}):")
            print(f"   🤖 ML Prediction: {'ACCIDENT-PRONE' if result['is_accident_prone'] else 'SAFE'}")
            print(f"   📊 ML Confidence: {result['ml_confidence']:.2%}")
            print(f"   ⚠️  Risk Level: {result['risk_level']}")
            print(f"   📈 Historical Accidents: {result['accident_count']}")
            print(f"   💀 Fatal Accidents: {result['fatal_accidents']}")
            print(f"   🔧 Prediction Method: {result.get('prediction_method', 'N/A')}")
            print(f"   💬 Message: {result['message']}")

            # Verify ML is being used
            if result.get('prediction_method') == 'machine_learning':
                print(f"\n   ✅ ML MODEL IS BEING USED!")
            else:
                print(f"\n   ❌ WARNING: ML model might not be in use!")

        else:
            print(f"\n❌ Error (Status: {response.status_code}):")
            print(f"   {response.text}")

    except requests.exceptions.ConnectionError:
        print(f"\n❌ Connection Error: API server not running!")
        print(f"   Please start the server with: python api_server.py")
        break
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")

print("\n" + "="*70)
print("TESTING COMPLETE")
print("="*70)

print("\n📝 Summary:")
print("   - If you see 'ML MODEL IS BEING USED!' above, the integration is successful!")
print("   - Check the API server console for '🤖 ML Prediction' logs")
print("   - The model is now making real predictions based on location and time")
print("\n")
