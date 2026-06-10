const ethers = require('ethers');

/**
 * Simple event decoder service.
 * Receives ABI, Log Data, and Topics.
 * Returns decoded JSON.
 */
async function decodeEvent(abi, log) {
    try {
        const iface = new ethers.Interface(abi);
        const parsedLog = iface.parseLog(log);
        return {
            eventName: parsedLog.name,
            args: parsedLog.args,
            success: true
        };
    } catch (e) {
        return { error: e.message, success: false };
    }
}

// Simple HTTP wrapper for the decoder
const http = require('http');
const server = http.createServer(async (req, res) => {
    if (req.method === 'POST' && req.url === '/decode') {
        let body = '';
        req.on('data', chunk => body += chunk.toString());
        req.on('end', async () => {
            try {
                const { abi, log } = JSON.parse(body);
                const result = await decodeEvent(abi, log);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(result));
            } catch (e) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Invalid request body' }));
            }
        });
    } else {
        res.writeHead(404);
        res.end();
    }
});

server.listen(3000, () => {
    console.log('Event Decoder Service running on port 3000');
});
