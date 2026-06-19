require("dotenv").config();

const express = require("express");
const { MongoClient } = require("mongodb");
const { createAuthController }   = require("./controllers/authController");
const { createAuthRoutes }       = require("./routes/authRoutes");
const { createChatController }   = require("./controllers/chatController");
const { createChatRoutes }       = require("./routes/chatRoutes");
const { createUserController }   = require("./controllers/userController");
const { createUserRoutes }       = require("./routes/userRoutes");
const { createNoticeController } = require("./controllers/noticeController");
const { createNoticeRoutes }     = require("./routes/noticeRoutes");
const { createEventController }  = require("./controllers/eventController");
const { createEventRoutes }      = require("./routes/eventRoutes");

const app  = express();
const PORT = 3000;

const client = new MongoClient(process.env.MONGO_DB_URI, {
    // ── Connection pool ───────────────────────────────────────────────────
    maxPoolSize:          10,   // max simultaneous connections
    minPoolSize:           2,   // keep at least 2 alive at all times
    maxIdleTimeMS:     60000,   // close pool connections idle > 60 s
    maxConnecting:         2,   // max concurrent connection attempts

    // ── Timeouts ──────────────────────────────────────────────────────────
    connectTimeoutMS:  10000,   // initial connect timeout
    socketTimeoutMS:   45000,   // per-operation socket timeout
    serverSelectionTimeoutMS: 15000, // how long to wait for a usable server

    // ── Heartbeat / topology ──────────────────────────────────────────────
    heartbeatFrequencyMS:  10000, // ping each server every 10 s

    // ── Retry ─────────────────────────────────────────────────────────────
    retryWrites:  true,
    retryReads:   true,

    // ── TLS / socket keep-alive ───────────────────────────────────────────
    // Prevents OS from silently dropping idle TCP connections (fixes ECONNRESET)
    family:       4,            // force IPv4 (avoids IPv6 resolution delays)
});

app.use(express.json({ limit: "50mb" }));

app.use((req, res, next) => {
    res.header("Access-Control-Allow-Origin",  "*");
    res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    if (req.method === "OPTIONS") return res.sendStatus(200);
    next();
});

async function startServer() {
    try {
        await client.connect();
        console.log("✅ Connected to MongoDB");

        const db = client.db("family_app");

        const authController   = createAuthController(db);
        await authController.ensureIndexes();
        const chatController   = createChatController(db);
        const userController   = createUserController(db);
        const noticeController = createNoticeController(db);
        const eventController  = createEventController(db);

        app.get("/", (req, res) => res.send("Backend is running!"));

        app.use("/api/auth",    createAuthRoutes(authController));
        app.use("/api/messages", createChatRoutes(chatController));
        app.use("/api/users",   createUserRoutes(userController));
        app.use("/api/notices", createNoticeRoutes(noticeController));
        app.use("/api/events",  createEventRoutes(eventController));

        app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
    } catch (error) {
        console.error("❌ Error:", error);
    }
}

startServer();
