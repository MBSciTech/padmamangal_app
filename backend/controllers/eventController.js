const { ObjectId } = require("mongodb");

function createEventController(db) {
    const events = db.collection("events");
    const users = db.collection("users");

    async function getEvents(req, res) {
        try {
            const list = await events
                .find({})
                .sort({ dateTime: 1 })
                .limit(100)
                .toArray();

            return res.json(list);
        } catch (err) {
            console.error("Get events error:", err);
            return res.status(500).json({
                message: "Server error fetching events."
            });
        }
    }

    async function createEvent(req, res) {
        try {
            const {
                title,
                description,
                dateTime,
                category,
                isRecurringYearly
            } = req.body;

            if (!title || !title.trim()) {
                return res.status(400).json({
                    message: "Title is required."
                });
            }

            if (!dateTime) {
                return res.status(400).json({
                    message: "Date/time is required."
                });
            }

            if (!req.userId) {
                return res.status(401).json({
                    message: "User not authenticated."
                });
            }

            const validCategories = [
                "birthday",
                "anniversary",
                "festival",
                "meeting",
                "reminder",
                "other"
            ];

            const user = await users.findOne({
                _id: new ObjectId(req.userId)
            });

            const createdByName = user
                ? user.fullName
                : "Unknown";

            const doc = {
                title: title.trim(),
                description: (description || "").trim(),
                dateTime: new Date(dateTime),
                category: validCategories.includes(category)
                    ? category
                    : "other",
                isRecurringYearly: !!isRecurringYearly,
                createdById: req.userId,
                createdByName,
                createdAt: new Date()
            };

            const result = await events.insertOne(doc);

            return res.status(201).json({
                ...doc,
                _id: result.insertedId
            });

        } catch (err) {
            console.error("Create event error:", err);

            return res.status(500).json({
                message: "Server error creating event."
            });
        }
    }

    async function deleteEvent(req, res) {
        try {
            const { id } = req.params;

            if (!ObjectId.isValid(id)) {
                return res.status(400).json({
                    message: "Invalid event ID."
                });
            }

            await events.deleteOne({
                _id: new ObjectId(id)
            });

            return res.json({
                message: "Event deleted."
            });

        } catch (err) {
            console.error("Delete event error:", err);

            return res.status(500).json({
                message: "Server error deleting event."
            });
        }
    }

    return {
        getEvents,
        createEvent,
        deleteEvent
    };
}

module.exports = {
    createEventController
};