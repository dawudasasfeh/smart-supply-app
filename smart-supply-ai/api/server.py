from flask import Flask, request, jsonify
import pandas as pd
import joblib

app = Flask(__name__)
model_dict = joblib.load('model/restock_model.pkl')  # your saved dict of models

@app.route('/predict', methods=['POST'])
def predict_restock():
    data = request.get_json()
    product_id = data.get('product_id')
    days_ahead = data.get('days_ahead')

    if product_id is None or days_ahead is None:
        return jsonify({'error': 'Missing product_id or days_ahead'}), 400

    model = model_dict.get(product_id)
    if model is None:
        return jsonify({'restock_quantity': 0})

    features = pd.DataFrame([{'days_since': days_ahead}])
    prediction = model.predict(features)[0]
    return jsonify({'restock_quantity': int(round(prediction))})

if __name__ == '__main__':
    app.run(debug=True, port=5001)
