const { ObjectId } = require("mongodb");

function createChatController(db, io) {
    const messages = db.collection("messages");
    const users    = db.collection("users");

    // ── GET /api/messages ──────────────────────────────────────────────────
    async function getMessages(req, res) {
        try {
            const allUsers = await users
                .find({}, { projection: { profilePic: 1 } })
                .toArray();
            const userPics = {};
            allUsers.forEach(u => {
                userPics[u._id.toString()] = u.profilePic || null;
            });

            const chatList = await messages
                .find({})
                .sort({ createdAt: 1 })
                .limit(100)
                .toArray();

            const populatedMessages = chatList.map(msg => ({
                ...msg,
                senderProfilePic: userPics[msg.senderId] || null,
                reactions:        msg.reactions || [],
            }));

            return res.json(populatedMessages);
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

            const insertedMessage = { _id: result.insertedId, ...newMessage, senderProfilePic: user.profilePic || null };
            io.emit("new_message", insertedMessage);

            return res.status(201).json(insertedMessage);
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

            io.emit("reaction_updated", { messageId, reactions });

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

            io.emit("location_updated", { 
                messageId, 
                location: { 
                    latitude: Number(latitude), 
                    longitude: Number(longitude), 
                    isLive: true,
                    liveExpiresAt: msg.location.liveExpiresAt
                } 
            });

            return res.json({ message: "Location updated successfully." });
        } catch (error) {
            console.error("Update live location error:", error.message);
            return res.status(500).json({ message: "Server error updating location." });
        }
    }

    return { getMessages, sendMessage, reactToMessage, updateLiveLocation };
}

module.exports = { createChatController };
