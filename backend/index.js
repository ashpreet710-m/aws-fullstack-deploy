const express = require('express');
const app = express();
const port = process.env.PORT || 5000;

app.get('/api/hello', (req, res) => {
  res.json({ message: 'Hello from backend!', instance: process.env.INSTANCE_ID || 'unknown' });
});

app.get('/health', (req, res) => res.status(200).send('OK'));

app.listen(port, () => {
  console.log(`Backend listening on ${port}`);
});
