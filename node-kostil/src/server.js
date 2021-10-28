'use strict';
import { SignMessage, Deploy, CallMethod } from './crypto.js';


import express from 'express';

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

// App setUp
const app = express();
app.use(express.json());


app.post('/sign', async (request, response) => {
  // Pass ipfs & user_address
  console.log('get', request.body);
  try {
    const link = await SignMessage(request.body)
    console.log('Response with link', link);
    response.json({link: link, status: "OK"});
  } catch (error) {
    console.error(error);
    response.json({error: error, status: "ERROR"});
    return;
  }
});

app.post('/deploy', async (request, response) => {
  // Pass ipfs & user_address
  console.log('get', request.body);
  try {
    const link = await Deploy(request.body)
    console.log('Response with link', link);
    response.json({link: link, status: "OK"});
  } catch (error) {
    console.error(error);
    response.json({error: error, status: "ERROR"});
    return;
  }
});

app.post('/call', async (request, response) => {
  // Pass ipfs & user_address
  console.log('get', request.body);
  try {
    const link = await CallMethod(request.body)
    console.log('Response with link', link);
    response.json({link: link, status: "OK"});
  } catch (error) {
    console.error(error);
    response.json({error: error, status: "ERROR"});
    return;
  }
});

app.get('/healthcheck', async (request, response) => {
  response.json({status: 'ok'});
});

app.listen(PORT, HOST);
console.log(`Express Kostil Server is running on http://${HOST}:${PORT}`);
