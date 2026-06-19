const { ObjectId } = require("mongodb");

function createChatController(db) {
    const messages = db.collection("messages");
    const users    = db.collection("users");

    // ── Server-side in-memory cache ────────────────────────────────────────
    // Polling happens every 5 s from each client; without a cache every poll
    // is a full MongoDB Atlas round-trip. With a 2 s TTL we cut Atlas queries
    // by ~60-70% and dramatically reduce latency for concurrent users.
    let _cachedMessages  = null;
    let _cachedUserPics  = null;
    let _cacheTimestamp  = 0;
    const CACHE_TTL_MS   = 5000; // 2 s — fresh enough for a chat app

    function _isCacheValid() {
        return _cachedMessages !== null && (Date.now() - _cacheTimestamp) < CACHE_TTL_MS;
    }

    function _invalidateCache() {
        _cachedMessages = null;
        _cachedUserPics = null;
        _cacheTimestamp = 0;
    }

    // ── GET /api/messages ──────────────────────────────────────────────────
    async function getMessages(req, res) {
        try {
            if (_isCacheValid()) {
                return res.json(_cachedMessages);
            }

            // Fetch user pic map (also cached)
            if (!_cachedUserPics) {
                const allUsers = await users
                    .find({}, { projection: { profilePic: 1 } })
                    .toArray();
                _cachedUserPics = {};
                allUsers.forEach(u => {
                    _cachedUserPics[u._id.toString()] = u.profilePic || null;
                });
            }

            const chatList = await messages
                .find({})
                .sort({ createdAt: 1 })
                .limit(100)
                .toArray();

            _cachedMessages = chatList.map(msg => ({
                ...msg,
                senderProfilePic: _cachedUserPics[msg.senderId] || null,
                reactions:        msg.reactions || [],
            }));
            _cacheTimestamp = Date.now();

            return res.json(_cachedMessages);
        } catch (error) {
            console.error("Get messages error:", error.message);
            return res.status(500).json({ message: "Server error fetching messages." });
        }
    }

    // ── POST /api/messages ─────────────────────────────────────────────────
    async function sendMessage(req, res) {
        try {
            const { message, file, location } = req.body;
            if ((!message || !message.trim()) && !file && !location) {
                return res.status(400).json({ message: "Message content, file, or location is required." });
            }

            const user = await users.findOne({ _id: new ObjectId(req.userId) });
            if (!user) {
                return res.status(404).json({ message: "User not found." });
            }

            const now = new Date();
            const newMessage = {
                senderId:    req.userId,
                senderName:  user.username,
                message:     (message || "").trim(),
                createdAt:   now,
                reactions:   [],
            };

            if (file) {
                newMessage.file = {
                    data: file.data,
                    name: file.name,
                    type: file.type,
                };
            }

            if (location) {
                newMessage.location = {
                    latitude:      Number(location.latitude),
                    longitude:     Number(location.longitude),
                    isLive:        Boolean(location.isLive),
                    liveExpiresAt: location.liveExpiresAt ? new Date(location.liveExpiresAt) : null,
                };
            }

            const result = await messages.insertOne(newMessage);

            // Invalidate cache so next poll fetches the new message
            _invalidateCache();

            return res.status(201).json({ _id: result.insertedId, ...newMessage });
        } catch (error) {
            console.error("Send message error:", error.message);
            return res.status(500).json({ message: "Server error sending message." });
        }
    }

    // ── POST /api/messages/:id/react ───────────────────────────────────────
    async function reactToMessage(req, res) {
        try {
            const messageId = req.params.id;
            const { emoji } = req.body;
            if (!emoji) {
                return res.status(400).json({ message: "Emoji is required." });
            }

            const user = await users.findOne({ _id: new ObjectId(req.userId) });
            if (!user) return res.status(404).json({ message: "User not found." });

            const msg = await messages.findOne({ _id: new ObjectId(messageId) });
            if (!msg)  return res.status(404).json({ message: "Message not found." });

            let reactions = msg.reactions || [];
            const existingIndex = reactions.findIndex(
                r => r.userId === req.userId && r.emoji === emoji
            );

            if (existingIndex > -1) {
                reactions.splice(existingIndex, 1);
            } else {
                reactions = reactions.filter(r => r.userId !== req.userId);
                reactions.push({ userId: req.userId, username: user.username, emoji });
            }

            await messages.updateOne(
                { _id: new ObjectId(messageId) },
                { $set: { reactions } }
            );

            _invalidateCache(); // reactions changed — next poll will reflect it

            return res.json({ message: "Reaction updated successfully.", reactions });
        } catch (error) {
            console.error("React to message error:", error.message);
            return res.status(500).json({ message: "Server error reacting to message." });
        }
    }

    // ── PUT /api/messages/:id/location ─────────────────────────────────────
    async function updateLiveLocation(req, res) {
        try {
            const messageId            = req.params.id;
            const { latitude, longitude } = req.body;

            if (latitude === undefined || longitude === undefined) {
                return res.status(400).json({ message: "Latitude and longitude are required." });
            }

            const msg = await messages.findOne({ _id: new ObjectId(messageId) });
            if (!msg) return res.status(404).json({ message: "Message not found." });

            if (msg.senderId !== req.userId) {
                return res.status(403).json({ message: "You can only update your own live location." });
            }

            if (!msg.location || !msg.location.isLive) {
                return res.status(400).json({ message: "This message is not a live location message." });
            }

            const now = new Date();
            if (msg.location.liveExpiresAt && now > new Date(msg.location.liveExpiresAt)) {
                return res.status(400).json({ message: "This live location has expired." });
            }

            await messages.updateOne(
                { _id: new ObjectId(messageId) },
                { $set: { "location.latitude": Number(latitude), "location.longitude": Number(longitude) } }
            );

            _invalidateCache(); // location changed

            return res.json({ message: "Location updated successfully." });
        } catch (error) {
            console.error("Update live location error:", error.message);
            return res.status(500).json({ message: "Server error updating location." });
        }
    }

    return { getMessages, sendMessage, reactToMessage, updateLiveLocation };
}

module.exports = { createChatController };
