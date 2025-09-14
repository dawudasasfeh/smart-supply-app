const { RatingCriteria } = require('../models/rating.model');

const seedRatingCriteria = async () => {
  try {
    // Supplier Rating Criteria (Supermarket rates Distributor)
    const supplierCriteria = [
      {
        rating_type: 'supplier_rating',
        criteria_name: 'Product Quality',
        criteria_description: 'Quality and freshness of products supplied',
        weight: 1.2
      },
      {
        rating_type: 'supplier_rating',
        criteria_name: 'Delivery Timeliness',
        criteria_description: 'Punctuality in delivering orders',
        weight: 1.1
      },
      {
        rating_type: 'supplier_rating',
        criteria_name: 'Order Accuracy',
        criteria_description: 'Accuracy of delivered items vs ordered items',
        weight: 1.0
      },
      {
        rating_type: 'supplier_rating',
        criteria_name: 'Pricing Competitiveness',
        criteria_description: 'Competitive pricing and value for money',
        weight: 0.9
      },
      {
        rating_type: 'supplier_rating',
        criteria_name: 'Communication',
        criteria_description: 'Responsiveness and clarity in communication',
        weight: 0.8
      },
      {
        rating_type: 'supplier_rating',
        criteria_name: 'Reliability',
        criteria_description: 'Consistency in service and availability',
        weight: 1.0
      }
    ];

    // Delivery Rating Criteria (Supermarket rates Delivery)
    const deliveryCriteria = [
      {
        rating_type: 'delivery_rating',
        criteria_name: 'Delivery Speed',
        criteria_description: 'Time taken to complete delivery',
        weight: 1.2
      },
      {
        rating_type: 'delivery_rating',
        criteria_name: 'Package Condition',
        criteria_description: 'Condition of products upon delivery',
        weight: 1.1
      },
      {
        rating_type: 'delivery_rating',
        criteria_name: 'Professionalism',
        criteria_description: 'Professional behavior and appearance',
        weight: 1.0
      },
      {
        rating_type: 'delivery_rating',
        criteria_name: 'Communication',
        criteria_description: 'Updates and communication during delivery',
        weight: 0.9
      },
      {
        rating_type: 'delivery_rating',
        criteria_name: 'Punctuality',
        criteria_description: 'Adherence to scheduled delivery times',
        weight: 1.1
      },
      {
        rating_type: 'delivery_rating',
        criteria_name: 'Customer Service',
        criteria_description: 'Helpfulness and courtesy',
        weight: 0.8
      }
    ];

    // Retailer Rating Criteria (Distributor/Delivery rates Supermarket)
    const retailerCriteria = [
      {
        rating_type: 'retailer_rating',
        criteria_name: 'Payment Timeliness',
        criteria_description: 'Promptness in making payments',
        weight: 1.3
      },
      {
        rating_type: 'retailer_rating',
        criteria_name: 'Order Consistency',
        criteria_description: 'Regularity and predictability of orders',
        weight: 1.0
      },
      {
        rating_type: 'retailer_rating',
        criteria_name: 'Communication',
        criteria_description: 'Clear communication of requirements',
        weight: 0.9
      },
      {
        rating_type: 'retailer_rating',
        criteria_name: 'Business Relationship',
        criteria_description: 'Professional relationship and cooperation',
        weight: 1.0
      },
      {
        rating_type: 'retailer_rating',
        criteria_name: 'Order Volume',
        criteria_description: 'Consistency in order volumes',
        weight: 0.8
      },
      {
        rating_type: 'retailer_rating',
        criteria_name: 'Flexibility',
        criteria_description: 'Adaptability to changes and special requests',
        weight: 0.7
      }
    ];

    const allCriteria = [...supplierCriteria, ...deliveryCriteria, ...retailerCriteria];

    // Insert criteria
    await RatingCriteria.bulkCreate(allCriteria, {
      ignoreDuplicates: true
    });

    console.log('Rating criteria seeded successfully');
  } catch (error) {
    console.error('Error seeding rating criteria:', error);
  }
};

module.exports = { seedRatingCriteria };
