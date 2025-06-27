import pandas as pd
import os
import joblib
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split

# Load CSV
df = pd.read_csv('data/sales_data.csv')
df['date'] = pd.to_datetime(df['date'])
df['days_from_start'] = (df['date'] - df['date'].min()).dt.days

# Group by product_id if needed
for product_id in df['product_id'].unique():
    product_data = df[df['product_id'] == product_id]
    
    X = product_data[['days_from_start']]
    y = product_data['sales_quantity']

    model = LinearRegression()
    model.fit(X, y)

    # Save model per product
    os.makedirs('model', exist_ok=True)
    joblib.dump(model, f'model/restock_model_product_{product_id}.pkl')
    print(f'Model saved for product {product_id}')
