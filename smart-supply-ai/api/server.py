from flask import Flask, request, jsonify
import pandas as pd
import pickle
from sqlalchemy import create_engine, Column, Integer, Float, Date
from sqlalchemy.orm import sessionmaker, declarative_base
from datetime import datetime

app = Flask(__name__)

# === DB Config ===
engine = create_engine('postgresql://postgres:dawud@localhost:5432/GP')
Session = sessionmaker(bind=engine)
session = Session()

Base = declarative_base()

class ProductSale(Base):
    __tablename__ = 'product_sales'  # Assuming this is the features table/view
    id = Column(Integer, primary_key=True)
    product_id = Column(Integer, nullable=False)
    distributor_id = Column(Integer, nullable=False)
    stock_level = Column(Integer, nullable=False)
    previous_orders = Column(Integer, nullable=False)
    active_offers = Column(Integer, nullable=False)
    sale_date = Column(Date, nullable=False)
    quantity = Column(Float)  # target column (optional here)

# Load models
MODEL_PATH = 'model/restock_model.pkl'
with open(MODEL_PATH, 'rb') as f:
    best_models = pickle.load(f)

def get_earliest_sale_dates():
    results = session.query(
        ProductSale.product_id,
        ProductSale.sale_date
    ).order_by(ProductSale.product_id, ProductSale.sale_date).all()

    earliest_dates = {}
    for product_id, sale_date in results:
        if product_id not in earliest_dates:
            earliest_dates[product_id] = sale_date
    return earliest_dates

earliest_sale_dates = get_earliest_sale_dates()

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json(force=True)
        print("Received request data:", data)

        product_id = int(data.get("product_id"))
        distributor_id = int(data.get("distributor_id"))
        stock_level = float(data.get("stock_level"))
        previous_orders = int(data.get("previous_orders"))
        active_offers = int(data.get("active_offers"))
        input_date_str = data.get("date")
        print(f"Parsed inputs: product_id={product_id}, distributor_id={distributor_id}, stock_level={stock_level}, previous_orders={previous_orders}, active_offers={active_offers}, date={input_date_str}")

        input_date = pd.to_datetime(input_date_str)
        if product_id not in earliest_sale_dates:
            error_msg = f"Unknown product_id {product_id} or no sales data"
            print(error_msg)
            return jsonify({"error": error_msg}), 404

        earliest_date = earliest_sale_dates[product_id]
        days_since = (input_date.date() - earliest_date).days
        if days_since < 0:
            days_since = 0

        features = [[distributor_id, stock_level, previous_orders, active_offers, days_since]]
        print("Features for prediction:", features)

        model = best_models.get(product_id)
        if not model:
            error_msg = f"Model not found for product_id {product_id}"
            print(error_msg)
            return jsonify({"error": error_msg}), 404

        predicted_quantity = model.predict(features)[0]
        print(f"Predicted quantity: {predicted_quantity}")

        return jsonify({
            "product_id": product_id,
            "predicted_demand": round(float(predicted_quantity), 2),
            "low_stock_alert": bool(predicted_quantity > stock_level)
        })

    except Exception as e:
        print("Exception during prediction:", e)
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5001)
