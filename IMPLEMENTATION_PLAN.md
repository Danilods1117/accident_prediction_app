# ML Model Integration Plan

## Problem Statement
The teacher correctly identified that the ML model is **NOT being used** for predictions. Currently, the API (`api_server.py:42`) only performs a dictionary lookup to check if a location exists in a pre-computed list of accident-prone areas. The trained Logistic Regression model is loaded but never used.

## Current State Analysis

### What the Flutter App Collects:
- ✅ GPS coordinates (latitude, longitude)
- ✅ Barangay name (via geocoding)
- ✅ Municipality/Station name
- ✅ Timestamp (automatic)

### What the ML Model Requires (2894 features):
1. **Temporal features** (automatic):
   - `month` (1-12)
   - `day_of_week` (0-6)
   - `hour` (0-23)

2. **Location features** (one-hot encoded):
   - `location_key` (composite: "barangay, station")
   - 49 `Station_*` columns (one-hot encoded municipalities)
   - ~700 `Place_of_Accident_*` columns (one-hot encoded barangays)

3. **Contextual features** (one-hot encoded, ~2100 columns):
   - `Offense_*` (types of traffic violations)
   - `Vehicles_involved_*` (car, motorcycle, truck, etc.)
   - `Driver_s_Behavior_*` (normal, drunk, drugs, etc.)
   - `Severity_of_Accident_*` (fatal, injured, etc.)
   - `Weather_Condition_*` (clear, rain, fog, etc.)
   - `Frequent_Location_of_Accident_*`

### The Gap:
The app cannot realistically collect Offense, Severity, or Driver Behavior **before** an accident happens. These are historical features, not predictive inputs.

## Proposed Solutions

### **Option 1: Practical Real-Time Prediction (RECOMMENDED)**

**Approach**: Use the ML model with available features and sensible defaults.

**Implementation**:
1. **Automatic features** (from app):
   - Extract `month`, `day_of_week`, `hour` from current timestamp
   - Use `barangay` and `station` from GPS/user input
   - Create `location_key` = "barangay, station"

2. **Optional user inputs** (add to Flutter app settings):
   - Vehicle type (dropdown: Car/Motorcycle/Tricycle/Truck)
   - Weather condition (auto-fetch from weather API OR manual input)

3. **Default values for unavailable features**:
   - All `Offense_*` columns → 0 (not applicable for prediction)
   - All `Severity_*` columns → 0 (not applicable for prediction)
   - `Driver_s_Behavior_*` → default to "Normal" (all 0s = dropped first category)
   - If no vehicle type selected → default to "Car"
   - If no weather data → default to "Clear" (most common)

4. **API changes**:
   - Modify `/api/check_location` to accept: `barangay`, `station`, `timestamp`, `vehicle_type` (optional), `weather` (optional)
   - Build feature vector matching training format (2894 features)
   - Call `model.predict_proba()` to get risk probability
   - Return: `is_accident_prone` (from model), `confidence` (probability), `risk_level`

**Pros**:
- ✅ Actually uses the ML model
- ✅ Provides real-time predictions
- ✅ Practical for a mobile app
- ✅ Model confidence can guide risk levels
- ✅ Can be enhanced later (weather API integration)

**Cons**:
- ⚠️ Some features defaulted, may reduce accuracy slightly
- ⚠️ Requires significant API refactoring

---

### **Option 2: Simplified Model (Requires Retraining)**

**Approach**: Retrain the model using only features the app can collect.

**Features to use**:
- Temporal: month, day_of_week, hour
- Location: Station, Place of Accident
- Optional: Weather (from API), Vehicle type (from settings)

**Steps**:
1. Modify `train_model.py` to exclude unavailable features
2. Retrain model (accuracy may drop but will be more honest)
3. Update API to use new simplified model
4. Update Flutter app to collect necessary inputs

**Pros**:
- ✅ Most academically sound approach
- ✅ All features are meaningful and available
- ✅ Clear relationship between inputs and predictions

**Cons**:
- ⚠️ Requires retraining (may reduce accuracy)
- ⚠️ More work upfront
- ⚠️ Needs new dataset analysis

---

### **Option 3: Hybrid Approach**

**Approach**: Keep current dictionary lookup but ALSO show ML predictions.

**Implementation**:
1. Keep existing `/api/check_location` as-is (dictionary lookup)
2. Add NEW endpoint `/api/predict_risk` that uses ML model
3. Flutter app calls both endpoints
4. Show both results to user:
   - "Historical risk: HIGH (12 accidents recorded)"
   - "Current predicted risk: 75% (based on time and conditions)"

**Pros**:
- ✅ Demonstrates ML model usage
- ✅ Provides richer information
- ✅ Less breaking changes

**Cons**:
- ⚠️ More complex UI
- ⚠️ May confuse users with two risk scores

---

## Recommended Implementation: Option 1

### Implementation Steps:

#### Step 1: Modify API Server (`api_server.py`)

1. Create new function `prepare_features()` to build feature vector
2. Update `/api/check_location` endpoint to:
   - Accept: barangay, station, timestamp, vehicle_type, weather
   - Extract temporal features from timestamp
   - Build 2894-feature vector with defaults
   - Call `model.predict_proba()`
   - Return ML-based prediction

#### Step 2: Update Flutter Models

1. Update `PredictionResult` to include:
   - `mlPrediction` (bool) - from model
   - `mlConfidence` (double) - probability from model
   - Keep existing fields for backward compatibility

#### Step 3: Enhance Flutter App (Optional)

1. Add settings screen options:
   - Vehicle type preference
   - Weather data source (manual/auto)
2. Pass these to API when checking location

#### Step 4: Testing

1. Test with known accident-prone locations
2. Test with different times of day
3. Verify model predictions are reasonable
4. Compare ML predictions vs dictionary lookup

---

## Files to Modify

1. `api_server.py` - Add ML prediction logic
2. `lib/models/prediction_result.dart` - Add ML fields
3. `lib/services/api_service.dart` - Send additional parameters
4. `lib/screens/settings_screen.dart` - Add vehicle/weather preferences (optional)

---

## Expected Outcome

After implementation:
- ✅ ML model will be actively used for predictions
- ✅ `model.predict()` or `model.predict_proba()` will be called on every location check
- ✅ Real-time risk assessment based on time, location, and conditions
- ✅ Teacher can verify model usage in code
- ✅ More intelligent predictions than simple dictionary lookup

---

## Timeline Estimate

- **Option 1**: 2-3 hours of coding
- **Option 2**: 4-6 hours (including retraining)
- **Option 3**: 2-3 hours of coding
