const pool = require('../db');

// Simple model exports for raw SQL queries
const Rating = {
  tableName: 'ratings',
  fields: ['id', 'rater_id', 'rated_id', 'rater_role', 'rated_role', 'rating_type', 'overall_rating', 'comment', 'order_id', 'is_anonymous', 'created_at', 'updated_at']
};

const RatingCriteria = {
  tableName: 'rating_criteria', 
  fields: ['id', 'criteria_name', 'rating_type', 'description', 'weight', 'created_at', 'updated_at']
};

const RatingCriteriaScore = {
  tableName: 'rating_criteria_scores',
  fields: ['id', 'rating_id', 'criteria_id', 'score', 'created_at']
};

const RatingSummary = {
  tableName: 'rating_summaries',
  fields: ['id', 'user_id', 'user_role', 'rating_type', 'total_ratings', 'average_rating', 'total_score', 'last_rating_date', 'created_at', 'updated_at']
};

module.exports = {
  Rating,
  RatingCriteria,
  RatingCriteriaScore,
  RatingSummary
};
