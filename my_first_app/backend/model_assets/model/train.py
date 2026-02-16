import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, StackingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.base import BaseEstimator, ClassifierMixin, clone
from sklearn.model_selection import GridSearchCV
from imblearn.over_sampling import SMOTE, SMOTENC
from imblearn.pipeline import Pipeline as ImbPipeline
from imblearn.ensemble import EasyEnsembleClassifier
try:
    from imblearn.ensemble import BalancedRandomForestClassifier
    BALANCED_RF_AVAILABLE = True
except Exception:
    BALANCED_RF_AVAILABLE = False

from sklearn.model_selection import cross_validate, StratifiedKFold
try:
    import lightgbm as lgb
    LGB_AVAILABLE = True
except Exception:
    LGB_AVAILABLE = False

from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, 
    f1_score, confusion_matrix, classification_report, roc_auc_score, balanced_accuracy_score
)
import matplotlib.pyplot as plt
import seaborn as sns
import joblib
import os
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

try:
    import shap
    SHAP_AVAILABLE = True
except ImportError:
    SHAP_AVAILABLE = False
    print("Warning: SHAP not installed. Install with: pip install shap")

# Configuration
EXCEL_FILE = 'ECD Data sets (4).xlsx'  # Replace with your Excel file path
TEST_SIZE = 0.2
RANDOM_STATE = 42
MODELS_DIR = 'trained_models'
# Toggle comparison experiments (SMOTE-in-CV, LightGBM, EasyEnsemble)
RUN_COMPARISONS = False
COMPARE_CV_FOLDS = 5

def load_data():
    """
    Load data from multiple Excel sheets
    """
    print("Loading data from sheets...")
    
    # Load each sheet
    registration = pd.read_excel(EXCEL_FILE, sheet_name='Registration')
    developmental_risk = pd.read_excel(EXCEL_FILE, sheet_name='Developmental_Risk')
    neuro_behavioral = pd.read_excel(EXCEL_FILE, sheet_name='Neuro_Behavioral')
    nutrition = pd.read_excel(EXCEL_FILE, sheet_name='Nutrition')
    environment_caregiving = pd.read_excel(EXCEL_FILE, sheet_name='Environment_Caregiving')
    baseline_risk = pd.read_excel(EXCEL_FILE, sheet_name='Baseline_Risk_Output')
    
    print(f"Registration shape: {registration.shape}")
    print(f"Developmental_Risk shape: {developmental_risk.shape}")
    print(f"Neuro_Behavioral shape: {neuro_behavioral.shape}")
    print(f"Nutrition shape: {nutrition.shape}")
    print(f"Environment_Caregiving shape: {environment_caregiving.shape}")
    print(f"Baseline_Risk_Output shape: {baseline_risk.shape}")
    
    return {
        'registration': registration,
        'developmental_risk': developmental_risk,
        'neuro_behavioral': neuro_behavioral,
        'nutrition': nutrition,
        'environment_caregiving': environment_caregiving,
        'baseline_risk': baseline_risk
    }

def merge_data(data_dict):
    """
    Merge all feature sheets with target label
    Uses 'child_id' as the common key across all sheets
    """
    print("\nMerging data from all sheets...")
    
    # Start with baseline_risk which contains the target
    merged_data = data_dict['baseline_risk'].copy()
    
    # Keep only relevant columns from baseline_risk
    merged_data = merged_data[['child_id', 'baseline_category']].copy()
    
    # Merge each feature sheet
    sheets_to_merge = [
        'registration',
        'developmental_risk',
        'neuro_behavioral',
        'nutrition',
        'environment_caregiving'
    ]
    
    for sheet_name in sheets_to_merge:
        try:
            # Merge on child_id
            merged_data = pd.merge(
                merged_data,
                data_dict[sheet_name],
                on='child_id',
                how='inner'
            )
            print(f"  ✓ Merged {sheet_name} | Shape: {merged_data.shape}")
        except Exception as e:
            print(f"  ⚠ Warning merging {sheet_name}: {e}")
    
    print(f"\nFinal merged data shape: {merged_data.shape}")
    print(f"Total features: {merged_data.shape[1] - 2}")  # -2 for child_id and target
    return merged_data

def preprocess_data(data):
    """
    Preprocess the merged data
    """
    print("\nPreprocessing data...")
    
    # Separate features and target
    target_column = 'baseline_category'
    
    if target_column not in data.columns:
        print(f"Error: Target column '{target_column}' not found.")
        print(f"Available columns: {data.columns.tolist()}")
        raise ValueError(f"Target column '{target_column}' not found in data")
    
    # Drop non-feature columns (ID, target, and non-predictive columns)
    cols_to_drop = ['child_id', target_column, 'dob', 'awc_code']
    
    X = data.drop(columns=[col for col in cols_to_drop if col in data.columns])
    y = data[target_column]
    
    print(f"Features shape: {X.shape}")
    print(f"Target shape: {y.shape}")
    print(f"Target distributions:\n{y.value_counts()}")
    
    # Handle missing values
    print("\nHandling missing values...")
    missing_before = X.isnull().sum().sum()
    print(f"Missing values before: {missing_before}")
    
    # Fill missing values with median for numeric columns, mode for categorical
    for col in X.columns:
        if X[col].isnull().sum() > 0:
            if X[col].dtype in ['float64', 'int64']:
                X[col].fillna(X[col].median(), inplace=True)
            else:
                X[col].fillna(X[col].mode()[0] if len(X[col].mode()) > 0 else 'Unknown', inplace=True)
    
    print(f"Missing values after: {X.isnull().sum().sum()}")
    
    # Encode categorical variables
    print("\nEncoding categorical variables...")
    label_encoders = {}
    categorical_cols = X.select_dtypes(include=['object']).columns.tolist()
    
    for col in categorical_cols:
        le = LabelEncoder()
        X[col] = le.fit_transform(X[col].astype(str))
        label_encoders[col] = le
        print(f"  ✓ Encoded {col} ({len(le.classes_)} classes)")
    
    # Convert all columns to numeric to avoid dtype issues
    print("\nConverting to numeric types...")
    for col in X.columns:
        X[col] = pd.to_numeric(X[col], errors='coerce')
    
    # Fill any NaN created by conversion
    X = X.fillna(X.mean(numeric_only=True))
    
    # Encode target if categorical
    if y.dtype == 'object':
        le_target = LabelEncoder()
        y = le_target.fit_transform(y)
        label_encoders['target'] = le_target
        print(f"  ✓ Encoded target variable ({len(le_target.classes_)} classes): {le_target.classes_}")
    
    print(f"\nFinal feature types:\n{X.dtypes.value_counts()}")
    
    return X, y, label_encoders, categorical_cols

def scale_numeric_features(X_train, X_test, numeric_cols):
    """
    Scale numeric columns only; keep categorical columns unchanged.
    Returns scaled DataFrames and the fitted scaler (or None if no numeric cols).
    """
    if not numeric_cols:
        return X_train.copy(), X_test.copy(), None
    scaler = StandardScaler()
    X_train_scaled = X_train.copy()
    X_test_scaled = X_test.copy()
    X_train_scaled[numeric_cols] = scaler.fit_transform(X_train[numeric_cols])
    X_test_scaled[numeric_cols] = scaler.transform(X_test[numeric_cols])
    return X_train_scaled, X_test_scaled, scaler

def make_sampling_strategy(y_train, target_ratio=0.7):
    """
    Build a conservative multi-class sampling strategy dictionary.
    Each minority class is upsampled to target_ratio * majority_count.
    """
    from collections import Counter
    class_counts = Counter(y_train)
    majority_count = max(class_counts.values())
    target_count = max(2, int(majority_count * target_ratio))
    sampling_strategy_dict = {}
    for cls, count in class_counts.items():
        sampling_strategy_dict[cls] = target_count if count < majority_count else majority_count
    return sampling_strategy_dict, min(class_counts.values())

class CascadingClassifier(BaseEstimator, ClassifierMixin):
    """
    Cascading classifier: train a base model, then a meta model using
    original features plus base model outputs.
    """
    def __init__(self, base_model=None, meta_model=None, use_proba=True):
        self.base_model = base_model
        self.meta_model = meta_model
        self.use_proba = use_proba

    def _augment_features(self, X):
        if self.use_proba and hasattr(self.base_model_, "predict_proba"):
            base_output = self.base_model_.predict_proba(X)
        else:
            base_output = self.base_model_.predict(X).reshape(-1, 1)
        return np.hstack([X, base_output])

    def fit(self, X, y):
        self.base_model_ = clone(self.base_model)
        self.meta_model_ = clone(self.meta_model)
        self.base_model_.fit(X, y)
        X_aug = self._augment_features(X)
        self.meta_model_.fit(X_aug, y)
        self.classes_ = getattr(self.meta_model_, "classes_", np.unique(y))
        return self

    def predict(self, X):
        X_aug = self._augment_features(X)
        return self.meta_model_.predict(X_aug)

    def predict_proba(self, X):
        X_aug = self._augment_features(X)
        if hasattr(self.meta_model_, "predict_proba"):
            return self.meta_model_.predict_proba(X_aug)
        preds = self.meta_model_.predict(X_aug)
        proba = np.zeros((len(preds), len(self.classes_)))
        for i, cls in enumerate(self.classes_):
            proba[:, i] = (preds == cls).astype(float)
        return proba

def train_model(X_train, y_train):
    """
    Train Random Forest with hyperparameter tuning to prevent overfitting
    """
    
    print("  ⏳ Performing hyperparameter tuning with GridSearchCV...")
    
    # Define hyperparameter grid for tuning
    param_grid = {
        'n_estimators': [40, 50, 60],
        'max_depth': [5, 6, 7],
        'min_samples_split': [50, 60, 70],
        'min_samples_leaf': [30, 35, 40]
    }
    
    # Base model
    base_model = RandomForestClassifier(
        max_features='sqrt',
        random_state=RANDOM_STATE,
        n_jobs=-1,
        class_weight='balanced',
        bootstrap=True,
        oob_score=True
    )
    
    # Grid search with 5-fold cross-validation
    grid_search = GridSearchCV(
        base_model,
        param_grid,
        cv=5,
        scoring='accuracy',
        n_jobs=-1,
        verbose=0
    )
    
    grid_search.fit(X_train, y_train)
    model = grid_search.best_estimator_
    
    print(f"  ✓ Model training complete")
    print(f"  ✓ Best parameters: {grid_search.best_params_}")
    print(f"  ✓ Best CV Accuracy: {grid_search.best_score_:.4f}")
    print(f"  ✓ Trees trained: {model.n_estimators}")
    print(f"  ✓ Max depth: {model.max_depth}")
    print(f"  ✓ Min samples split: {model.min_samples_split}")
    print(f"  ✓ Min samples leaf: {model.min_samples_leaf}")
    print(f"  ✓ Out-of-Bag Score: {model.oob_score_:.4f}")
    
    return model

def train_stacking_model(X_train, y_train):
    """
    Train a stacking classifier using diverse base models.
    """
    print("  Starting StackingClassifier training...")

    base_estimators = [
        ('rf', RandomForestClassifier(
            n_estimators=120,
            max_depth=8,
            min_samples_split=40,
            min_samples_leaf=20,
            max_features='sqrt',
            random_state=RANDOM_STATE,
            n_jobs=-1,
            class_weight='balanced',
            bootstrap=True
        )),
        ('gb', GradientBoostingClassifier(
            n_estimators=150,
            learning_rate=0.05,
            max_depth=3,
            random_state=RANDOM_STATE
        )),
        ('lr', LogisticRegression(
            max_iter=1000,
            solver='saga',
            n_jobs=-1,
            class_weight='balanced'
        ))
    ]

    final_estimator = LogisticRegression(
        max_iter=1000,
        solver='saga',
        n_jobs=-1,
        class_weight='balanced'
    )

    model = StackingClassifier(
        estimators=base_estimators,
        final_estimator=final_estimator,
        cv=5,
        n_jobs=-1,
        passthrough=True
    )

    model.fit(X_train, y_train)
    print("  StackingClassifier training complete")
    return model

def train_cascading_model(X_train, y_train):
    """
    Train a cascading classifier: base model -> meta model using augmented features.
    """
    print("  Starting CascadingClassifier training...")

    base_model = RandomForestClassifier(
        n_estimators=120,
        max_depth=8,
        min_samples_split=40,
        min_samples_leaf=20,
        max_features='sqrt',
        random_state=RANDOM_STATE,
        n_jobs=-1,
        class_weight='balanced',
        bootstrap=True
    )

    meta_model = GradientBoostingClassifier(
        n_estimators=150,
        learning_rate=0.05,
        max_depth=3,
        random_state=RANDOM_STATE
    )

    model = CascadingClassifier(base_model=base_model, meta_model=meta_model, use_proba=True)
    model.fit(X_train, y_train)
    print("  CascadingClassifier training complete")
    return model

def plot_learning_curve(model, X_train, X_test, y_train, y_test):
    """
    Plot learning curves to visualize overfitting
    """
    from sklearn.model_selection import learning_curve
    
    print("\n" + "-"*70)
    print("GENERATING LEARNING CURVE:")
    print("-"*70)
    
    train_sizes, train_scores, val_scores = learning_curve(
        model, X_train, y_train, cv=5, 
        train_sizes=np.linspace(0.1, 1.0, 10),
        scoring='accuracy', n_jobs=-1
    )
    
    train_mean = np.mean(train_scores, axis=1)
    train_std = np.std(train_scores, axis=1)
    val_mean = np.mean(val_scores, axis=1)
    val_std = np.std(val_scores, axis=1)
    
    plt.figure(figsize=(12, 6))
    plt.plot(train_sizes, train_mean, 'o-', color='blue', label='Training score')
    plt.fill_between(train_sizes, train_mean - train_std, train_mean + train_std, alpha=0.1, color='blue')
    plt.plot(train_sizes, val_mean, 'o-', color='red', label='Validation score')
    plt.fill_between(train_sizes, val_mean - val_std, val_mean + val_std, alpha=0.1, color='red')
    plt.xlabel('Training Set Size')
    plt.ylabel('Accuracy Score')
    plt.title('Learning Curve - Detecting Overfitting')
    plt.legend(loc='best')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    lc_path = f'learning_curve_{timestamp}.png'
    plt.savefig(lc_path, dpi=150, bbox_inches='tight')
    print(f"✓ Learning curve saved: {lc_path}")
    plt.close()
    
    print(f"  Gap at end: {train_mean[-1] - val_mean[-1]:.4f}")
    if train_mean[-1] - val_mean[-1] < 0.05:
        print("  ✓ Good! Low overfitting")
    else:
        print("  ⚠ Model still overfitting - consider these solutions:")
        print("    1. Increase min_samples_leaf further")
        print("    2. Reduce max_depth more")
        print("    3. Add more regularization")
        print("    4. Collect more training data")

def compare_classifiers(X_train, X_test, y_train, y_test, categorical_cols=None, cv=COMPARE_CV_FOLDS):
    """Run optional comparison experiments (SMOTENC-in-CV, LightGBM class-weight, EasyEnsemble, BalancedRF).

    This function runs cross-validated evaluations (no data leakage) and saves a CSV summary to
    `trained_models/compare_results_<timestamp>.csv`.
    Returns (results_df, best_estimator_name_or_None).
    """
    if not RUN_COMPARISONS:
        print("Skipping comparison experiments (RUN_COMPARISONS=False). Set RUN_COMPARISONS=True to enable.")
        return {}, None

    print("\nRunning comparison experiments with Stratified CV (no leakage)...")
    # Determine categorical indices for SMOTENC (if provided)
    cat_indices = []
    if categorical_cols:
        cat_indices = [X_train.columns.get_loc(c) for c in categorical_cols if c in X_train.columns]

    skf = StratifiedKFold(n_splits=cv, shuffle=True, random_state=RANDOM_STATE)
    scoring = {
        'f1_macro': 'f1_macro',
        'precision_macro': 'precision_macro',
        'recall_macro': 'recall_macro',
        'balanced_accuracy': 'balanced_accuracy'
    }

    estimators = []

    # 1) RandomForest (no resample)
    estimators.append((
        'rf_no_resample',
        RandomForestClassifier(
            n_estimators=200, max_depth=8, min_samples_split=40, min_samples_leaf=20,
            max_features='sqrt', random_state=RANDOM_STATE, n_jobs=-1, class_weight='balanced', bootstrap=True
        )
    ))

    # 2) RandomForest + SMOTENC (inside CV via pipeline)
    if len(cat_indices) > 0:
        smote_for_cv = SMOTENC(categorical_features=cat_indices, random_state=RANDOM_STATE)
    else:
        smote_for_cv = SMOTE(random_state=RANDOM_STATE)
    estimators.append(('rf_smotenc_cv', ImbPipeline([('smote', smote_for_cv), ('clf', RandomForestClassifier(
        n_estimators=200, max_depth=8, min_samples_split=40, min_samples_leaf=20,
        max_features='sqrt', random_state=RANDOM_STATE, n_jobs=-1, class_weight='balanced', bootstrap=True
    ))])))

    # 3) LightGBM (class-weight) - optional
    if LGB_AVAILABLE:
        estimators.append(('lightgbm_weighted', lgb.LGBMClassifier(n_estimators=300, class_weight='balanced', random_state=RANDOM_STATE)))
    else:
        print("  ⚠ LightGBM not installed — skipping LightGBM comparison.")

    # 4) EasyEnsemble (resampling ensemble)
    estimators.append(('easy_ensemble', EasyEnsembleClassifier(n_estimators=10, n_jobs=-1, random_state=RANDOM_STATE)))

    # 5) BalancedRandomForest (if available)
    if BALANCED_RF_AVAILABLE:
        estimators.append(('balanced_rf', BalancedRandomForestClassifier(n_estimators=120, random_state=RANDOM_STATE, n_jobs=-1)))
    else:
        print("  ⚠ BalancedRandomForest not available in imbalanced-learn — skipping.")

    # 6) Stacking classifier (tree + gbm + lr)
    stacking_clf = StackingClassifier(
        estimators=[
            ('rf', RandomForestClassifier(n_estimators=120, max_depth=8, min_samples_split=40, min_samples_leaf=20,
                                         max_features='sqrt', random_state=RANDOM_STATE, n_jobs=-1, class_weight='balanced')),
            ('gb', GradientBoostingClassifier(n_estimators=150, learning_rate=0.05, max_depth=3, random_state=RANDOM_STATE)),
            ('lr', LogisticRegression(max_iter=1000, solver='saga', n_jobs=-1, class_weight='balanced'))
        ],
        final_estimator=LogisticRegression(max_iter=1000, solver='saga', n_jobs=-1, class_weight='balanced'),
        cv=3,
        n_jobs=-1,
        passthrough=True
    )
    estimators.append(('stacking', stacking_clf))

    # 6b) Stacking + SMOTENC (inside CV via pipeline)
    try:
        estimators.append(('stacking_smotenc_cv', ImbPipeline([('smote', smote_for_cv), ('clf', stacking_clf)])))
    except Exception:
        pass

    # 7) Cascading classifier (RF -> GBM)
    cascading_clf = CascadingClassifier(
        base_model=RandomForestClassifier(n_estimators=120, max_depth=8, min_samples_split=40, min_samples_leaf=20,
                                         max_features='sqrt', random_state=RANDOM_STATE, n_jobs=-1, class_weight='balanced'),
        meta_model=GradientBoostingClassifier(n_estimators=150, learning_rate=0.05, max_depth=3, random_state=RANDOM_STATE),
        use_proba=True
    )
    estimators.append(('cascading', cascading_clf))

    # 7b) Cascading + SMOTENC (inside CV via pipeline)
    try:
        estimators.append(('cascading_smotenc_cv', ImbPipeline([('smote', smote_for_cv), ('clf', cascading_clf)])))
    except Exception:
        pass

    results = []
    for name, est in estimators:
        try:
            print(f"  · Evaluating: {name}")
            cv_res = cross_validate(est, X_train, y_train, cv=skf, scoring=scoring, n_jobs=-1, return_train_score=False)
            row = {
                'estimator': name,
                'f1_macro_mean': np.mean(cv_res['test_f1_macro']),
                'f1_macro_std': np.std(cv_res['test_f1_macro']),
                'precision_macro_mean': np.mean(cv_res['test_precision_macro']),
                'recall_macro_mean': np.mean(cv_res['test_recall_macro']),
                'balanced_acc_mean': np.mean(cv_res['test_balanced_accuracy'])
            }
            results.append(row)
        except Exception as e:
            print(f"    ⚠ Skipping {name} due to error: {e}")

    if not results:
        print("No comparison results produced.")
        return {}, None

    res_df = pd.DataFrame(results).sort_values('f1_macro_mean', ascending=False)

    # Save results CSV
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if not os.path.exists(MODELS_DIR):
        os.makedirs(MODELS_DIR)
    csv_path = os.path.join(MODELS_DIR, f'compare_results_{timestamp}.csv')
    res_df.to_csv(csv_path, index=False)
    print(f"\n✓ Comparison results saved: {csv_path}")

    print("\nTop results:")
    print(res_df[['estimator','f1_macro_mean','precision_macro_mean','recall_macro_mean','balanced_acc_mean']].head(5).to_string(index=False))

    best_name = res_df.iloc[0]['estimator']
    return res_df, best_name

def save_model(model, scaler, encoders, results, model_name):
    """
    Save trained model, scaler, and encoders to disk
    """
    # Create models directory if it doesn't exist
    if not os.path.exists(MODELS_DIR):
        os.makedirs(MODELS_DIR)
    
    # Create timestamp for versioning
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    safe_name = model_name.lower().replace(" ", "_").replace("-", "_")

    # Save model
    model_path = os.path.join(MODELS_DIR, f'baseline_risk_{safe_name}_{timestamp}.pkl')
    joblib.dump(model, model_path)
    
    # Save scaler
    scaler_path = os.path.join(MODELS_DIR, f'scaler_{timestamp}.pkl')
    joblib.dump(scaler, scaler_path)
    
    # Save encoders
    encoders_path = os.path.join(MODELS_DIR, f'encoders_{timestamp}.pkl')
    joblib.dump(encoders, encoders_path)
    
    # Save results/metrics
    results_path = os.path.join(MODELS_DIR, f'metrics_{safe_name}_{timestamp}.txt')
    with open(results_path, 'w') as f:
        f.write(f"BASELINE RISK MODEL - PERFORMANCE METRICS ({model_name})\n")
        f.write("="*60 + "\n")
        f.write(f"Accuracy:  {results['accuracy']:.4f}\n")
        f.write(f"Precision: {results['precision']:.4f}\n")
        f.write(f"Recall:    {results['recall']:.4f}\n")
        f.write(f"F1-Score:  {results['f1']:.4f}\n")
        if 'f1_macro' in results:
            f.write(f"Macro F1:  {results['f1_macro']:.4f}\n")
        if 'balanced_accuracy' in results:
            f.write(f"Balanced Acc: {results['balanced_accuracy']:.4f}\n")
        if results.get('feature_importance') is not None:
            f.write("\nTop 15 Important Features:\n")
            f.write(results['feature_importance'].head(15).to_string())
        else:
            f.write("\nFeature importance not available for this model.\n")
    
    print("\n" + "="*70)
    print("MODEL SAVED SUCCESSFULLY!")
    print("="*70)
    print(f"Model saved:    {model_path}")
    print(f"Scaler saved:   {scaler_path}")
    print(f"Encoders saved: {encoders_path}")
    print(f"Metrics saved:  {results_path}")
    print("="*70)
    
    return {
        'model_path': model_path,
        'scaler_path': scaler_path,
        'encoders_path': encoders_path,
        'results_path': results_path
    }

def load_model(model_path, scaler_path, encoders_path):
    """
    Load saved model, scaler, and encoders from disk
    """
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model not found: {model_path}")
    if not os.path.exists(scaler_path):
        raise FileNotFoundError(f"Scaler not found: {scaler_path}")
    if not os.path.exists(encoders_path):
        raise FileNotFoundError(f"Encoders not found: {encoders_path}")
    
    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)
    encoders = joblib.load(encoders_path)
    
    print(f"Model loaded from: {model_path}")
    print(f"Scaler loaded from: {scaler_path}")
    print(f"Encoders loaded from: {encoders_path}")
    
    return model, scaler, encoders

def plot_confusion_matrix(y_test, y_test_pred, label_encoder, model_name="Random Forest"):
    """
    Plot and save confusion matrix
    """
    print("\n" + "-"*70)
    print("CONFUSION MATRIX:")
    print("-"*70)
    
    cm = confusion_matrix(y_test, y_test_pred)
    
    # Create labels
    if hasattr(label_encoder, 'classes_'):
        labels = label_encoder.classes_
    else:
        labels = [f'Class_{i}' for i in range(len(cm))]
    
    # Plot confusion matrix
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                xticklabels=labels, yticklabels=labels, cbar_kws={'label': 'Count'})
    plt.title(f'Confusion Matrix - {model_name}')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.tight_layout()
    
    # Save figure
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    cm_path = f'confusion_matrix_{timestamp}.png'
    plt.savefig(cm_path, dpi=150, bbox_inches='tight')
    print(f"\n✓ Confusion matrix saved: {cm_path}")
    plt.close()
    
    # Print confusion matrix values
    print(f"\nConfusion Matrix:\n{cm}")
    return cm

def plot_shap_explainability(model, X_test, feature_names, max_display=15):
    """
    Generate SHAP explainability plots
    """
    if not SHAP_AVAILABLE:
        print("\n⚠ SHAP not available. Install with: pip install shap")
        return
    
    print("\n" + "-"*70)
    print("GENERATING SHAP EXPLAINABILITY PLOTS:")
    print("-"*70)
    
    try:
        # Create SHAP explainer
        print("  ✓ Creating SHAP explainer...")
        explainer = shap.TreeExplainer(model)
        
        # Calculate SHAP values
        print("  ✓ Calculating SHAP values (this may take a moment)...")
        shap_values = explainer.shap_values(X_test)
        
        # Handle different output types
        if isinstance(shap_values, list):
            shap_values = shap_values[1]  # For binary/multiclass, use class 1 or majority class
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Summary plot
        print("  ✓ Creating summary plot...")
        plt.figure(figsize=(12, 8))
        shap.summary_plot(shap_values, X_test, feature_names=feature_names, 
                         max_display=max_display, show=False)
        summary_path = f'shap_summary_{timestamp}.png'
        plt.savefig(summary_path, dpi=150, bbox_inches='tight')
        print(f"    ✓ Saved: {summary_path}")
        plt.close()
        
        # Bar plot
        print("  ✓ Creating feature importance bar plot...")
        plt.figure(figsize=(12, 8))
        shap.summary_plot(shap_values, X_test, feature_names=feature_names,
                         plot_type="bar", max_display=max_display, show=False)
        bar_path = f'shap_bar_{timestamp}.png'
        plt.savefig(bar_path, dpi=150, bbox_inches='tight')
        print(f"    ✓ Saved: {bar_path}")
        plt.close()
        
        print(f"\n✓ SHAP analysis complete! Check generated PNG files.")
        
    except Exception as e:
        print(f"⚠ Error generating SHAP plots: {e}")

def evaluate_model(model, X_train, X_test, y_train, y_test, label_encoders, model_name):
    """
    Evaluate model performance with confusion matrix and SHAP
    X_train and X_test are DataFrames/arrays used for predictions
    """
    print("\n" + "="*70)
    print(f"MODEL EVALUATION - {model_name}")
    print("="*70)
    
    # Get column names from original X
    feature_names = X_test.columns if hasattr(X_test, 'columns') else None
    
    # Predictions
    y_train_pred = model.predict(X_train)
    y_test_pred = model.predict(X_test)
    
    # Training Metrics
    print("\n" + "-"*70)
    print("TRAINING SET METRICS:")
    print("-"*70)
    train_accuracy = accuracy_score(y_train, y_train_pred)
    train_precision = precision_score(y_train, y_train_pred, average='weighted', zero_division=0)
    train_recall = recall_score(y_train, y_train_pred, average='weighted', zero_division=0)
    train_f1 = f1_score(y_train, y_train_pred, average='weighted', zero_division=0)
    train_f1_macro = f1_score(y_train, y_train_pred, average='macro', zero_division=0)
    
    print(f"  Accuracy:  {train_accuracy:.4f}")
    print(f"  Precision: {train_precision:.4f}")
    print(f"  Recall:    {train_recall:.4f}")
    print(f"  F1-Score:  {train_f1:.4f}")
    print(f"  Macro F1:  {train_f1_macro:.4f}")
    
    # Test Metrics
    print("\n" + "-"*70)
    print("TEST SET METRICS:")
    print("-"*70)
    test_accuracy = accuracy_score(y_test, y_test_pred)
    test_precision = precision_score(y_test, y_test_pred, average='weighted', zero_division=0)
    test_recall = recall_score(y_test, y_test_pred, average='weighted', zero_division=0)
    test_f1 = f1_score(y_test, y_test_pred, average='weighted', zero_division=0)
    test_f1_macro = f1_score(y_test, y_test_pred, average='macro', zero_division=0)
    test_balanced_acc = balanced_accuracy_score(y_test, y_test_pred)
    
    print(f"  Accuracy:  {test_accuracy:.4f}")
    print(f"  Precision: {test_precision:.4f}")
    print(f"  Recall:    {test_recall:.4f}")
    print(f"  F1-Score:  {test_f1:.4f}")
    print(f"  Macro F1:  {test_f1_macro:.4f}")
    print(f"  Balanced Acc: {test_balanced_acc:.4f}")
    
    # Overfitting Gap
    overfit_gap = train_accuracy - test_accuracy
    print(f"\n  Overfitting Gap: {overfit_gap:.4f} {'(Good!)' if overfit_gap < 0.05 else '(⚠ High overfitting)'}")
    
    # Classification Report
    print("\n" + "-"*70)
    print("DETAILED CLASSIFICATION REPORT (Test Set):")
    print("-"*70)
    print(classification_report(y_test, y_test_pred, zero_division=0))
    
    # Per-class recall
    print("-"*70)
    print("PER-CLASS RECALL (Test Set):")
    print("-"*70)
    target_encoder = label_encoders.get('target')
    labels = sorted(np.unique(y_test))
    if hasattr(target_encoder, 'classes_'):
        class_labels = [target_encoder.classes_[i] for i in labels]
    else:
        class_labels = [f'Class_{i}' for i in labels]
    recalls = recall_score(
        y_test,
        y_test_pred,
        average=None,
        labels=labels,
        zero_division=0
    )
    for cls, recall_val in zip(class_labels, recalls):
        print(f"  {cls:30s} : {recall_val:.4f}")
    
    # Feature importance
    print("-"*70)
    print("TOP 15 IMPORTANT FEATURES:")
    print("-"*70)
    feature_importance = None
    if hasattr(model, "feature_importances_"):
        importances = model.feature_importances_
        if feature_names is not None and len(importances) == len(feature_names):
            feature_importance = pd.DataFrame({
                'feature': feature_names,
                'importance': importances
            }).sort_values('importance', ascending=False)
        else:
            feature_importance = pd.DataFrame({
                'feature': [f'Feature_{i}' for i in range(len(importances))],
                'importance': importances
            }).sort_values('importance', ascending=False)

        for idx, row in feature_importance.head(15).iterrows():
            print(f"  {row['feature']:40s} : {row['importance']:.4f}")
    else:
        print("  Feature importance not available for this model.")
    
    # Confusion Matrix
    target_encoder = label_encoders.get('target')
    cm = plot_confusion_matrix(y_test, y_test_pred, target_encoder, model_name)
    
    # SHAP Explainability
    print("\n" + "="*70)
    if SHAP_AVAILABLE and hasattr(model, "feature_importances_"):
        plot_shap_explainability(
            model,
            X_test,
            feature_names if feature_names is not None else
            [f'Feature_{i}' for i in range(X_test.shape[1])],
            max_display=15
        )
    else:
        print("SHAP explainability skipped for this model.")
    print("="*70)
    
    return {
        'accuracy': test_accuracy,
        'precision': test_precision,
        'recall': test_recall,
        'f1': test_f1,
        'f1_macro': test_f1_macro,
        'balanced_accuracy': test_balanced_acc,
        'feature_importance': feature_importance,
        'confusion_matrix': cm
    }

def main():
    """
    Main pipeline: Load -> Merge -> Preprocess -> Train -> Evaluate
    """
    print("\n" + "="*70)
    print("ECD BASELINE RISK CLASSIFICATION MODEL")
    print("="*70)
    print(f"Excel File: {EXCEL_FILE}")
    print(f"Test Size: {TEST_SIZE * 100}%")
    print("="*70)
    
    try:
        # Load data
        print("\n[Step 1/6] Loading data...")
        data_dict = load_data()
        
        # Merge data
        print("\n[Step 2/6] Merging sheets...")
        merged_data = merge_data(data_dict)
        
        # Preprocess
        print("\n[Step 3/6] Preprocessing data...")
        X, y, encoders, categorical_cols = preprocess_data(merged_data)
        
        # Split data
        print(f"\n[Step 4/6] Splitting data (test size: {TEST_SIZE})...")
        X_train, X_test, y_train, y_test = train_test_split(
            X, y,
            test_size=TEST_SIZE,
            random_state=RANDOM_STATE,
            stratify=y
        )
        print(f"  Training set: {X_train.shape[0]} samples")
        print(f"  Test set: {X_test.shape[0]} samples")
        
        # Scale numeric features only
        print("\n[Step 5/6] Scaling numeric features...")
        numeric_cols = [c for c in X.columns if c not in categorical_cols]
        X_train_scaled, X_test_scaled, scaler = scale_numeric_features(X_train, X_test, numeric_cols)
        print(f"  ??? Scaling complete (numeric cols: {len(numeric_cols)})")

        # Optional comparison experiments (SMOTE-in-CV, LightGBM, EasyEnsemble)
        compare_results, _ = compare_classifiers(X_train_scaled, X_test_scaled, y_train, y_test, categorical_cols)

        # SMOTE ablation: no SMOTE vs SMOTENC
        print("\n[Step 6/6] SMOTE Ablation (No SMOTE vs SMOTENC)...")
        base_model = RandomForestClassifier(
            n_estimators=200,
            max_depth=8,
            min_samples_split=40,
            min_samples_leaf=20,
            max_features='sqrt',
            random_state=RANDOM_STATE,
            n_jobs=-1,
            class_weight='balanced',
            bootstrap=True
        )

        # No SMOTE
        print("\nTraining model without SMOTE...")
        no_smote_model = clone(base_model)
        no_smote_model.fit(X_train_scaled, y_train)
        no_smote_results = evaluate_model(
            no_smote_model, X_train_scaled, X_test_scaled, y_train, y_test, encoders,
            "RandomForest (no SMOTE)"
        )

        # SMOTENC
        print("\nTraining model with SMOTENC...")
        sampling_strategy_dict, min_class_count = make_sampling_strategy(y_train, target_ratio=0.7)
        if min_class_count < 2:
            print("  ??? Not enough samples in a class for SMOTENC. Skipping resampling.")
            X_train_smote, y_train_smote = X_train_scaled, y_train
        else:
            k_neighbors = max(1, min(5, min_class_count - 1))
            if categorical_cols:
                cat_indices = [X_train_scaled.columns.get_loc(c) for c in categorical_cols]
                smote = SMOTENC(
                    categorical_features=cat_indices,
                    random_state=RANDOM_STATE,
                    k_neighbors=k_neighbors,
                    sampling_strategy=sampling_strategy_dict
                )
            else:
                print("  ??? No categorical columns found. Falling back to standard SMOTE.")
                smote = SMOTE(
                    random_state=RANDOM_STATE,
                    k_neighbors=k_neighbors,
                    sampling_strategy=sampling_strategy_dict
                )
            try:
                X_train_smote, y_train_smote = smote.fit_resample(X_train_scaled, y_train)
                print(f"  ??? SMOTE applied (k_neighbors={k_neighbors})")
                print(f"  Original training set: {X_train_scaled.shape[0]} samples")
                print(f"  After SMOTE: {X_train_smote.shape[0]} samples")
                print(f"  Class distribution after SMOTE:\n{pd.Series(y_train_smote).value_counts()}")
            except Exception as e:
                print(f"  ??? SMOTE failed: {e}. Using original data.")
                X_train_smote, y_train_smote = X_train_scaled, y_train

        smotenc_model = clone(base_model)
        smotenc_model.fit(X_train_smote, y_train_smote)
        smotenc_results = evaluate_model(
            smotenc_model, X_train_scaled, X_test_scaled, y_train, y_test, encoders,
            "RandomForest + SMOTENC"
        )

        # Train stacking and cascading models (with and without SMOTE where applicable)
        print("\nTraining stacking and cascading models (no SMOTE)...")
        stacking_model = train_stacking_model(X_train_scaled, y_train)
        stacking_results = evaluate_model(
            stacking_model, X_train_scaled, X_test_scaled, y_train, y_test, encoders,
            "StackingClassifier (no SMOTE)"
        )

        print("\nTraining cascading model (no SMOTE)...")
        cascading_model = train_cascading_model(X_train_scaled, y_train)
        cascading_results = evaluate_model(
            cascading_model, X_train_scaled, X_test_scaled, y_train, y_test, encoders,
            "CascadingClassifier (no SMOTE)"
        )

        # If SMOTE was applied successfully, also train stacking/cascading on resampled data
        stacking_smote_results = None
        cascading_smote_results = None
        stacking_model_smote = None
        cascading_model_smote = None
        if (X_train_smote is not None) and (len(X_train_smote) > len(X_train_scaled)):
            try:
                print("\nTraining stacking and cascading models (with SMOTE)...")
                stacking_model_smote = train_stacking_model(X_train_smote, y_train_smote)
                stacking_smote_results = evaluate_model(
                    stacking_model_smote, X_train_scaled, X_test_scaled, y_train, y_test, encoders,
                    "StackingClassifier + SMOTENC"
                )

                cascading_model_smote = train_cascading_model(X_train_smote, y_train_smote)
                cascading_smote_results = evaluate_model(
                    cascading_model_smote, X_train_scaled, X_test_scaled, y_train, y_test, encoders,
                    "CascadingClassifier + SMOTENC"
                )
            except Exception as e:
                print(f"  ⚠ Could not train SMOTE variants of stacking/cascading: {e}")

        # Select best model across all candidates by macro-F1
        candidates = [
            ("RandomForest (no SMOTE)", no_smote_model, no_smote_results),
            ("RandomForest + SMOTENC", smotenc_model, smotenc_results),
            ("Stacking (no SMOTE)", stacking_model, stacking_results),
            ("Cascading (no SMOTE)", cascading_model, cascading_results)
        ]
        if stacking_smote_results is not None:
            candidates.append(("Stacking + SMOTENC", stacking_model_smote, stacking_smote_results))
        if cascading_smote_results is not None:
            candidates.append(("Cascading + SMOTENC", cascading_model_smote, cascading_smote_results))

        best_name, best_model, best_results = max(candidates, key=lambda t: t[2].get('f1_macro', 0))
        print(f"\nBest model by Macro F1: {best_name}")

        # Learning Curve Analysis (best model only)
        print("\nAnalyzing overfitting with learning curve (best model)...")
        try:
            plot_learning_curve(best_model, X_train_scaled, X_test_scaled, y_train, y_test)
        except Exception as e:
            print(f"  Learning curve skipped: {e}")

        # Save all trained models (including stacking/cascading)
        print("\nSaving models...")
        save_model(no_smote_model, scaler, encoders, no_smote_results, "rf_no_smote")
        save_model(smotenc_model, scaler, encoders, smotenc_results, "rf_smotenc")
        save_model(stacking_model, scaler, encoders, stacking_results, "stacking_no_smote")
        save_model(cascading_model, scaler, encoders, cascading_results, "cascading_no_smote")
        if stacking_model_smote is not None:
            save_model(stacking_model_smote, scaler, encoders, stacking_smote_results, "stacking_smotenc")
        if cascading_model_smote is not None:
            save_model(cascading_model_smote, scaler, encoders, cascading_smote_results, "cascading_smotenc")
        
        print("\n" + "="*70)
        print("SUCCESS: Model training completed!")
        print("="*70)
        
        return best_model, scaler, encoders, best_results
        
    except FileNotFoundError:
        print(f"\nError: Could not find '{EXCEL_FILE}'")
        print(f"Please ensure the Excel file exists in the current directory.")
        print(f"Expected sheets:")
        print(f"  - Registration")
        print(f"  - Developmental_Risk")
        print(f"  - Neuro_Behavioral")
        print(f"  - Nutrition")
        print(f"  - Environment_Caregiving")
        print(f"  - Baseline_Risk_Output")
        return None, None, None, None
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        return None, None, None, None

if __name__ == "__main__":
    model, scaler, encoders, results = main()
    
    # EXAMPLE: How to load and use the saved model for predictions:
    # -----------------------------------------------------------------
    # Step 1: Load the saved model (replace timestamps with actual ones)
    # model, scaler, encoders = load_model(
    #     'trained_models/baseline_risk_rf_no_smote_20260212_150000.pkl',
    #     'trained_models/scaler_20260212_150000.pkl',
    #     'trained_models/encoders_20260212_150000.pkl'
    # )
    # 
    # Step 2: Prepare new data (preprocess same way as training data)
    # new_data = pd.read_csv('new_data.csv')  # Your new data
    # new_data_scaled = scaler.transform(new_data)
    #
    # Step 3: Make predictions
    # predictions = model.predict(new_data_scaled)
    # probabilities = model.predict_proba(new_data_scaled)
    # -----------------------------------------------------------------
