const Inventory = require('../models/inventory.model');

const getLowStock = async (req, res) => {
  try {
    const supermarket_id = req.user.id;
    const items = await Inventory.getLowStockInventory(supermarket_id);
    res.json(items);
  } catch (err) {
    console.error('Error fetching low stock inventory:', err);
    res.status(500).json({ error: 'Failed to fetch low stock inventory' });
  }
};

const getSupermarketInventory = async (req, res) => {
  try {
    // Get authenticated user's ID
    const supermarket_id = req.user.id;
    const items = await Inventory.getAllInventory(supermarket_id);
    res.json(items);
  } catch (err) {
    console.error('Error fetching supermarket inventory:', err);
    res.status(500).json({ error: 'Failed to fetch supermarket inventory' });
  }
};

const restock = async (req, res) => {
  try {
    const supermarket_id = req.user.id;
    const { product_id, distributor_id, quantity } = req.body;

    const updated = await Inventory.restockProduct({
      supermarket_id,
      product_id,
      distributor_id,
      quantity,
    });

    res.json({ success: true, updated });
  } catch (err) {
    console.error('Error during restock:', err);
    res.status(500).json({ error: 'Failed to restock product' });
  }
};

const getSupermarketStats = async (req, res) => {
  try {
    const supermarket_id = req.user.id;
    const stats = await Inventory.getSupermarketStats(supermarket_id);
    res.json(stats);
  } catch (err) {
    console.error('Error fetching supermarket stats:', err);
    res.status(500).json({ error: 'Failed to fetch supermarket stats' });
  }
};

module.exports = {
  getLowStock,
  restock,
  getSupermarketInventory,
  getSupermarketStats,
};