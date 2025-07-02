import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.tree import DecisionTreeRegressor
from sklearn.neural_network import MLPRegressor
import xgboost as xgb
from sklearn.metrics import mean_squared_error
import pickle
from sqlalchemy import create_engine

# === DB Config ===

engine = create_engine('postgresql://postgres:dawud@localhost:5432/GP')

# Load data - assume a prepared view/table with all needed features:
query = """
SELECT
    product_id,
    distributor_id,
    stock_level,
    previous_orders,
    active_offers,
    sale_date,
    quantity_sold as quantity
FROM product_sales
ORDER BY product_id, sale_date
"""

df = pd.read_sql(query, engine)

if df.empty:
    raise Exception("No data found in product_sales")

# Create days_since from sale_date (per product)
df['sale_date'] = pd.to_datetime(df['sale_date'])
df['days_since'] = df.groupby('product_id')['sale_date'].transform(lambda x: (x - x.min()).dt.days)

# Select features and target
feature_cols = ['distributor_id', 'stock_level', 'previous_orders', 'active_offers', 'days_since']
target_col = 'quantity'

# Ensure model dir exists
os.makedirs('model', exist_ok=True)

model_types = {
    "LinearRegression": LinearRegression(),
    "RandomForest": RandomForestRegressor(n_estimators=100, random_state=42),
    "DecisionTree": DecisionTreeRegressor(random_state=42),
    "XGBoost": xgb.XGBRegressor(objective='reg:squarederror', n_estimators=100),
    "NeuralNetwork": MLPRegressor(hidden_layer_sizes=(50, 30), max_iter=1000, random_state=42)
}

performance = {name: [] for name in model_types}
best_models = {}

for product_id, group in df.groupby('product_id'):
    X = group[feature_cols].values
    y = group[target_col].values

    best_rmse = float('inf')
    best_model = None
    best_model_name = None

    for name, model in model_types.items():
        try:
            model.fit(X, y)
            preds = model.predict(X)
            rmse = np.sqrt(mean_squared_error(y, preds))
            performance[name].append(rmse)
            if rmse < best_rmse:
                best_rmse = rmse
                best_model = model
                best_model_name = name
        except Exception as e:
            print(f"Model {name} failed on product {product_id}: {e}")

    best_models[product_id] = (best_model_name, best_model)
    print(f"Best model for product {product_id}: {best_model_name} with RMSE={best_rmse:.3f}")

wrapped_models = {pid: model for pid, (name, model) in best_models.items()}

with open('model/restock_model.pkl', 'wb') as f:
    pickle.dump(wrapped_models, f)

avg_rmse = {name: np.mean(vals) for name, vals in performance.items() if vals}
fig, ax = plt.subplots(figsize=(10, 5))
ax.bar(avg_rmse.keys(), avg_rmse.values(), color='skyblue')
ax.set_title("Average RMSE per Model Type")
ax.set_ylabel("RMSE")
ax.set_xlabel("Model Type")
plt.xticks(rotation=30)
plt.tight_layout()

plt_path = "model/model_comparison_real_data.png"
plt.savefig(plt_path)

print(f"Model comparison chart saved to: {plt_path}")
