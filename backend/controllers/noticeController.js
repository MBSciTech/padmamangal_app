const { ObjectId } = require("mongodb");

function createNoticeController(db) {
    const notices = db.collection("notices");
    const users   = db.collection("users");

    async function getNotices(req, res) {
        try {
            const list = await notices
                .find({})
                .sort({ createdAt: -1 })
                .limit(50)
                .toArray();
            return res.json(list);
        } catch (err) {
            console.error("Get notices error:", err);
            return res.status(500).json({ message: "Server error fetching notices." });
        }
    }

    async function createNotice(req, res) {
        try {
            const { title, body, priority } = req.body;
            if (!title || !title.trim()) {
                return res.status(400).json({ message: "Title is required." });
            }

            const user = await users.findOne({ _id: new ObjectId(req.userId) });
            const postedByName = user ? user.username : "Unknown";

            const doc = {
                title:       title.trim(),
                body:        (body || "").trim(),
                priority:    ["low", "medium", "high"].includes(priority) ? priority : "low",
                postedById:  req.userId,
                postedByName,
                createdAt:   new Date(),
            };

            const result = await notices.insertOne(doc);
            return res.status(201).json({ ...doc, _id: result.insertedId });
        } catch (err) {
            console.error("Create notice error:", err);
            return res.status(500).json({ message: "Server error creating notice." });
        }
    }

    async function deleteNotice(req, res) {
        try {
            const { id } = req.params;
            if (!ObjectId.isValid(id)) {
                return res.status(400).json({ message: "Invalid notice ID." });
            }
            await notices.deleteOne({ _id: new ObjectId(id) });
            return res.json({ message: "Notice deleted." });
        } catch (err) {
            console.error("Delete notice error:", err);
            return res.status(500).json({ message: "Server error deleting notice." });
        }
    }

    return { getNotices, createNotice, deleteNotice };
}

module.exports = { createNoticeController };
