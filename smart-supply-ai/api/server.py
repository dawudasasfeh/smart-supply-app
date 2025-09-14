from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import logging
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
import joblib
import os

app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO)

class EnhancedSupplyAI:
    def __init__(self):
        self.models = {}
        self.scalers = {}
        self.product_baselines = {}
        self.seasonal_patterns = {}
        self.initialize_models()
        
    def initialize_models(self):
        """Initialize AI models with improved algorithms"""
        # Define seasonal patterns
        self.seasonal_patterns = {
            'spring': {'multiplier': 1.1, 'months': [3, 4, 5]},
            'summer': {'multiplier': 1.3, 'months': [6, 7, 8]},
            'fall': {'multiplier': 0.9, 'months': [9, 10, 11]},
            'winter': {'multiplier': 0.8, 'months': [12, 1, 2]}
        }
        
        # Initialize models for different product categories
        self.create_predictive_models()
        
    def create_predictive_models(self):
        """Create and train predictive models"""
        # Create models for different product types
        model_configs = {
            'food': {'base_demand': 25, 'volatility': 0.3, 'seasonal_sensitivity': 1.2},
            'beverages': {'base_demand': 35, 'volatility': 0.4, 'seasonal_sensitivity': 1.5},
            'household': {'base_demand': 15, 'volatility': 0.2, 'seasonal_sensitivity': 0.8},
            'default': {'base_demand': 20, 'volatility': 0.25, 'seasonal_sensitivity': 1.0}
        }
        
        for category, config in model_configs.items():
            # Create Random Forest model for each category
            model = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42
            )
            
            # Generate synthetic training data
            X_train, y_train = self.generate_training_data(config)
            
            # Train model
            scaler = StandardScaler()
            X_scaled = scaler.fit_transform(X_train)
            model.fit(X_scaled, y_train)
            
            self.models[category] = model
            self.scalers[category] = scaler
            
        logging.info(f"Initialized {len(self.models)} AI models")
    
    def generate_training_data(self, config, n_samples=1000):
        """Generate synthetic training data based on business logic"""
        np.random.seed(42)
        
        # Features: [current_stock, previous_orders, active_offers, days_since_last_order, season_factor]
        current_stock = np.random.uniform(0, 100, n_samples)
        previous_orders = np.random.poisson(10, n_samples)
        active_offers = np.random.poisson(1, n_samples)
        days_since_last_order = np.random.uniform(0, 30, n_samples)
        season_factor = np.random.uniform(0.8, 1.4, n_samples)
        
        X = np.column_stack([
            current_stock, previous_orders, active_offers, 
            days_since_last_order, season_factor
        ])
        
        # Target: demand based on business logic
        base_demand = config['base_demand']
        volatility = config['volatility']
        seasonal_sensitivity = config['seasonal_sensitivity']
        
        # Calculate demand with realistic factors
        stock_effect = np.where(current_stock < 20, 1.3, 1.0)  # Higher demand when stock is low
        order_effect = 1 + (previous_orders / 50)  # Previous orders influence
        offer_effect = 1 + (active_offers * 0.2)  # Offers boost demand
        time_decay = np.exp(-days_since_last_order / 10)  # Recent orders matter more
        seasonal_effect = season_factor * seasonal_sensitivity
        
        y = (base_demand * stock_effect * order_effect * offer_effect * 
             time_decay * seasonal_effect * 
             np.random.normal(1, volatility, n_samples))
        
        y = np.maximum(0, y)  # Ensure non-negative demand
        
        return X, y
    
    def get_product_category(self, product_name):
        """Determine product category from name"""
        if not product_name:
            return 'default'
            
        name_lower = product_name.lower()
        
        if any(word in name_lower for word in ['rice', 'bread', 'milk', 'egg', 'meat', 'fish', 'fruit', 'vegetable']):
            return 'food'
        elif any(word in name_lower for word in ['water', 'juice', 'soda', 'coffee', 'tea', 'beer', 'wine']):
            return 'beverages'
        elif any(word in name_lower for word in ['soap', 'detergent', 'tissue', 'paper', 'cleaning']):
            return 'household'
        else:
            return 'default'
    
    def get_seasonal_factor(self, date=None):
        """Calculate seasonal factor based on current date"""
        if date is None:
            date = datetime.now()
            
        month = date.month
        
        for season, info in self.seasonal_patterns.items():
            if month in info['months']:
                return info['multiplier']
        
        return 1.0
    
    def predict_demand(self, product_data):
        """Predict demand for a single product"""
        try:
            product_name = product_data.get('product_name', '')
            current_stock = float(product_data.get('current_stock', 0))
            previous_orders = int(product_data.get('previous_orders', 0))
            active_offers = int(product_data.get('active_offers', 0))
            
            # Get product category and corresponding model
            category = self.get_product_category(product_name)
            model = self.models.get(category, self.models['default'])
            scaler = self.scalers.get(category, self.scalers['default'])
            
            # Calculate features
            days_since_last_order = 7  # Default assumption
            season_factor = self.get_seasonal_factor()
            
            features = np.array([[
                current_stock, previous_orders, active_offers,
                days_since_last_order, season_factor
            ]])
            
            # Scale features and predict
            features_scaled = scaler.transform(features)
            predicted_demand = model.predict(features_scaled)[0]
            
            # Apply business rules and convert to integer
            predicted_demand = max(1, int(round(predicted_demand)))
            
            # Add confidence calculation
            confidence = self.calculate_confidence(current_stock, previous_orders)
            
            return {
                'predicted_demand': int(predicted_demand),
                'confidence': round(confidence, 2),
                'category': category,
                'seasonal_factor': round(season_factor, 2)
            }
            
        except Exception as e:
            logging.error(f"Prediction error: {e}")
            return {
                'predicted_demand': 20,
                'confidence': 0.5,
                'category': 'default',
                'seasonal_factor': 1.0
            }
    
    def calculate_confidence(self, current_stock, previous_orders):
        """Calculate prediction confidence based on data quality"""
        # Base confidence
        confidence = 0.6
        
        # Increase confidence with more historical data
        if previous_orders > 10:
            confidence += 0.2
        elif previous_orders > 5:
            confidence += 0.1
            
        # Adjust based on stock levels (extreme values are less reliable)
        if 10 <= current_stock <= 80:
            confidence += 0.1
            
        return min(0.95, confidence)
    
    def generate_restock_suggestions(self, products_data):
        """Generate intelligent restock suggestions"""
        suggestions = []
        
        for product in products_data:
            try:
                # Get prediction
                prediction = self.predict_demand(product)
                predicted_demand = prediction['predicted_demand']
                confidence = prediction['confidence']
                
                current_stock = float(product.get('current_stock', 0))
                product_id = product.get('product_id')
                product_name = product.get('product_name', f'Product {product_id}')
                
                # Calculate restock needs - more aggressive thresholds
                safety_stock = predicted_demand * 0.5  # 50% safety margin
                reorder_point = predicted_demand + safety_stock
                
                # Always suggest restock if stock is below 2x predicted demand
                if current_stock < (predicted_demand * 2):
                    # Use exact same formula as prediction endpoint
                    suggested_quantity = max(10, int(predicted_demand * 1.5 - current_stock))
                    
                    # Determine priority
                    stock_ratio = current_stock / max(1, predicted_demand)
                    if stock_ratio < 0.2:
                        priority = 'high'
                        urgency = 'critical'
                    elif stock_ratio < 1.0:
                        priority = 'medium'
                        urgency = 'moderate'
                    else:
                        priority = 'low'
                        urgency = 'low'
                    
                    # Generate reason
                    reason = self.generate_suggestion_reason(stock_ratio, predicted_demand, prediction['seasonal_factor'])
                    
                    suggestions.append({
                        'product_id': product_id,
                        'product_name': product_name,
                        'current_stock': current_stock,
                        'predicted_demand': predicted_demand,
                        'suggested_quantity': suggested_quantity,
                        'priority': priority,
                        'urgency': urgency,
                        'confidence': confidence,
                        'reason': reason,
                        'category': prediction['category'],
                        'reorder_point': round(reorder_point, 1)
                    })
                    
            except Exception as e:
                logging.error(f"Error processing product {product.get('product_id')}: {e}")
        
        # Sort by priority and urgency
        priority_order = {'high': 3, 'medium': 2, 'low': 1}
        suggestions.sort(key=lambda x: (priority_order[x['priority']], x['confidence']), reverse=True)
        
        return suggestions
    
    def generate_suggestion_reason(self, stock_ratio, predicted_demand, seasonal_factor):
        """Generate human-readable reason for restock suggestion"""
        if stock_ratio < 0.2:
            return "Critical stock shortage - immediate restock needed"
        elif stock_ratio < 0.5:
            return "Low stock level - restock recommended soon"
        elif stock_ratio < 1.0:
            return "Stock below demand forecast - prepare for restock"
        elif predicted_demand > 30:
            return "High demand predicted - maintain adequate stock"
        elif seasonal_factor > 1.1:
            return "Seasonal demand increase - stock up now"
        else:
            return "Proactive restocking to maintain optimal levels"
    
    def generate_analytics(self, products_data):
        """Generate comprehensive analytics"""
        if not products_data:
            return {}
            
        total_products = len(products_data)
        low_stock_count = 0
        high_demand_products = []
        total_predicted_demand = 0
        categories = {}
        
        for product in products_data:
            prediction = self.predict_demand(product)
            predicted_demand = prediction['predicted_demand']
            current_stock = float(product.get('current_stock', 0))
            category = prediction['category']
            
            total_predicted_demand += predicted_demand
            
            # Count low stock items
            if current_stock < predicted_demand * 0.5:
                low_stock_count += 1
            
            # Identify high demand products
            if predicted_demand > 35:
                high_demand_products.append({
                    'product_id': product.get('product_id'),
                    'product_name': product.get('product_name', 'Unknown'),
                    'predicted_demand': round(predicted_demand, 1),
                    'current_stock': current_stock
                })
            
            # Category analysis
            if category not in categories:
                categories[category] = {'count': 0, 'avg_demand': 0, 'total_demand': 0}
            categories[category]['count'] += 1
            categories[category]['total_demand'] += predicted_demand
        
        # Calculate category averages
        for category in categories:
            categories[category]['avg_demand'] = round(
                categories[category]['total_demand'] / categories[category]['count'], 1
            )
        
        # Generate insights
        insights = []
        if low_stock_count > total_products * 0.3:
            insights.append("High number of low-stock items detected - review inventory management")
        if len(high_demand_products) > 0:
            insights.append(f"{len(high_demand_products)} products showing high demand - consider bulk ordering")
        if total_predicted_demand > 0:
            avg_demand = total_predicted_demand / total_products
            if avg_demand > 30:
                insights.append("Overall high demand period - ensure adequate supply chain capacity")
        
        return {
            'total_products': total_products,
            'low_stock_products': low_stock_count,
            'high_demand_products': high_demand_products[:5],  # Top 5
            'total_predicted_demand': round(total_predicted_demand, 1),
            'average_demand_per_product': round(total_predicted_demand / total_products, 1) if total_products > 0 else 0,
            'stock_health_score': round((total_products - low_stock_count) / total_products * 100, 1) if total_products > 0 else 0,
            'category_breakdown': categories,
            'insights': insights,
            'seasonal_factor': self.get_seasonal_factor()
        }

# Initialize AI system
ai_system = EnhancedSupplyAI()

@app.route('/predict', methods=['POST'])
def predict():
    """Single product demand prediction"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"success": False, "error": "No data provided"}), 400
        
        prediction = ai_system.predict_demand(data)
        current_stock = float(data.get('current_stock', 0))
        
        # Calculate additional metrics using exact same formula as suggestions
        predicted_demand = prediction['predicted_demand']
        stock_ratio = current_stock / max(1, predicted_demand)
        urgency_level = "high" if stock_ratio < 0.3 else "medium" if stock_ratio < 0.6 else "low"
        
        # Use identical calculation as in generate_restock_suggestions
        if current_stock < (predicted_demand * 2):
            suggested_quantity = max(10, int(predicted_demand * 1.5 - current_stock))
        else:
            suggested_quantity = 0
        
        return jsonify({
            "success": True,
            "product_id": data.get('product_id'),
            "predicted_demand": prediction['predicted_demand'],
            "current_stock": current_stock,
            "stock_ratio": round(stock_ratio, 2),
            "urgency_level": urgency_level,
            "suggested_quantity": suggested_quantity,
            "suggested_restock": suggested_quantity,  # Keep both for compatibility
            "confidence": prediction['confidence'],
            "category": prediction['category'],
            "seasonal_factor": prediction['seasonal_factor']
        })
        
    except Exception as e:
        logging.error(f"Prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/suggestions', methods=['POST'])
def suggestions():
    """Generate restock suggestions"""
    try:
        data = request.get_json()
        products_data = data.get('products', [])
        
        if not products_data:
            return jsonify({"success": False, "error": "No products provided"}), 400
        
        suggestions = ai_system.generate_restock_suggestions(products_data)
        
        return jsonify({
            "success": True,
            "suggestions": suggestions,
            "total_suggestions": len(suggestions),
            "high_priority_count": len([s for s in suggestions if s['priority'] == 'high']),
            "medium_priority_count": len([s for s in suggestions if s['priority'] == 'medium']),
            "generated_at": datetime.now().isoformat()
        })
        
    except Exception as e:
        logging.error(f"Suggestions error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/analytics', methods=['POST'])
def analytics():
    """Generate comprehensive analytics"""
    try:
        data = request.get_json()
        products_data = data.get('products', [])
        
        if not products_data:
            return jsonify({"success": False, "error": "No products provided"}), 400
        
        analytics_data = ai_system.generate_analytics(products_data)
        
        return jsonify({
            "success": True,
            "analytics": analytics_data,
            "generated_at": datetime.now().isoformat()
        })
        
    except Exception as e:
        logging.error(f"Analytics error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "models_loaded": len(ai_system.models),
        "categories": list(ai_system.models.keys()),
        "timestamp": datetime.now().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, port=5001, host='0.0.0.0')
