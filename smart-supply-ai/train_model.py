# train_model.py
from sqlalchemy import create_engine
import pandas as pd
import xgboost as xgb
import pickle
from datetime import datetime

# Connect to PostgreSQL
engine = create_engine("postgresql://postgres:dawud@localhost:5432/GP")

# Load sales data
df = pd.read_sql("SELECT * FROM product_sales", engine)

# Preprocess: convert sale_date to days since start
df['sale_date'] = pd.to_datetime(df['sale_date'])
df['days_since'] = (df['sale_date'] - df['sale_date'].min()).dt.days

# Train a model per product
models = {}
for product_id, group in df.groupby('product_id'):
    X = group[['days_since']]
    y = group['quantity']
    model = xgb.XGBRegressor(objective='reg:squarederror', n_estimators=100)
    model.fit(X, y)
    models[product_id] = model

# Save all models as a dictionary
with open('model/restock_model.pkl', 'wb') as f:
    pickle.dump(models, f)

print("✅ All product models trained and saved.")
