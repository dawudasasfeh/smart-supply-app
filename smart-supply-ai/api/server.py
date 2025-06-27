from flask import Flask, request, jsonify
import joblib
import os
import datetime

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict_restock():
    data = request.get_json()

    product_id = data.get('product_id')
    days_ahead = data.get('days_ahead', 7)  # default 7 days from now

    if not product_id:
        return jsonify({'error': 'Missing product_id'}), 400

    model_path = f'../model/restock_model_product_{product_id}.pkl'
    if not os.path.exists(model_path):
        return jsonify({'error': f'Model for product {product_id} not found'}), 404

    model = joblib.load(model_path)

    # Predict using days from the start of the dataset
    today = datetime.datetime.today()
    start_date = today - datetime.timedelta(days=days_ahead)
    days_from_start = (today - start_date).days + days_ahead

    prediction = model.predict([[days_from_start]])
    predicted_qty = max(int(prediction[0]), 0)

    return jsonify({
        'product_id': product_id,
        'recommended_restock': predicted_qty,
        'days_ahead': days_ahead
    })


@app.route('/', methods=['GET'])
def health_check():
    return jsonify({'message': 'AI Server is running'})


if __name__ == '__main__':
    app.run(debug=True, port=5001)
