## Nutrition Risk Model

Train a `Low / Medium / High` nutrition risk model from exported nutrition form data.

### Expected CSV
- One row per completed nutrition assessment.
- Must include target column: `nutrition_risk` (values: `Low`, `Medium`, `High`).
- Remaining columns are used as features (except known ID/timestamp columns).

### Train
```powershell
cd c:\FlutterProjects\my_first_app\backend
python .\model_assets\nutrition\train_nutrition_model.py --csv .\model_assets\nutrition\nutrition_training_data.csv
```

### Output
Artifacts are saved to:
- `backend/model_assets/nutrition/trained_models/nutrition_risk_model_<timestamp>.pkl`
- `backend/model_assets/nutrition/trained_models/nutrition_risk_metrics_<timestamp>.txt`

### Runtime env (optional)
- `ECD_NUTRITION_MODEL_DIR` to override model directory
- `ECD_NUTRITION_MODEL_FILE` to force a specific model file

