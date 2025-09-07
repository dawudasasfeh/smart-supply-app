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

module.exports = {
  getLowStock,
  restock,
};