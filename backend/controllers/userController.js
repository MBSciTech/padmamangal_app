const { ObjectId } = require("mongodb");
const bcrypt = require("bcryptjs");

function createUserController(db) {
    const users = db.collection("users");

    async function getProfile(req, res) {
        try {
            const user = await users.findOne(
                { _id: new ObjectId(req.userId) },
                { projection: { password: 0 } }
            );
            if (!user) {
                return res.status(404).json({ message: "User not found." });
            }
            return res.json({
                id: user._id.toString(),
                username: user.username,
                phoneNumber: user.phoneNumber || null,
                email: user.email || null,
                profilePic: user.profilePic || null,
            });
        } catch (error) {
            console.error("Get profile error:", error);
            return res.status(500).json({ message: "Server error fetching profile." });
        }
    }

    async function updateProfile(req, res) {
        try {
            const { username, phoneNumber, email, profilePic, password } = req.body;
            const userId = new ObjectId(req.userId);

            const currentUser = await users.findOne({ _id: userId });
            if (!currentUser) {
                return res.status(404).json({ message: "User not found." });
            }

            const updateFields = {};

            if (username !== undefined) {
                const trimmedUsername = username.trim().toLowerCase();
                if (!trimmedUsername) {
                    return res.status(400).json({ message: "Username cannot be empty." });
                }
                if (trimmedUsername.length < 3) {
                    return res.status(400).json({ message: "Username must be at least 3 characters." });
                }
                if (!/^[a-zA-Z0-9_]+$/.test(trimmedUsername)) {
                    return res.status(400).json({ message: "Username can only contain letters, numbers, and underscores." });
                }

                // Check uniqueness against other users
                const exists = await users.findOne({
                    username: trimmedUsername,
                    _id: { $ne: userId }
                });
                if (exists) {
                    return res.status(409).json({ message: "Username is already taken." });
                }
                updateFields.username = trimmedUsername;
            }

            if (phoneNumber !== undefined) {
                const digitsPhone = phoneNumber.replace(/\D/g, "");
                if (!digitsPhone) {
                    return res.status(400).json({ message: "Phone number cannot be empty." });
                }
                if (digitsPhone.length < 10 || digitsPhone.length > 15) {
                    return res.status(400).json({ message: "Enter a valid phone number (10–15 digits)." });
                }

                // Check uniqueness against other users
                const exists = await users.findOne({
                    phoneNumber: digitsPhone,
                    _id: { $ne: userId }
                });
                if (exists) {
                    return res.status(409).json({ message: "Phone number is already registered." });
                }
                updateFields.phoneNumber = digitsPhone;
            }

            if (email !== undefined) {
                const trimmedEmail = email ? email.trim().toLowerCase() : "";
                if (trimmedEmail !== "") {
                    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
                        return res.status(400).json({ message: "Enter a valid email address." });
                    }

                    // Check email uniqueness against other users
                    const exists = await users.findOne({
                        email: trimmedEmail,
                        _id: { $ne: userId }
                    });
                    if (exists) {
                        return res.status(409).json({ message: "Email is already registered." });
                    }
                    updateFields.email = trimmedEmail;
                } else {
                    updateFields.email = null;
                }
            }

            if (profilePic !== undefined) {
                updateFields.profilePic = profilePic ? profilePic.trim() : null;
            }

            if (password !== undefined && password.trim() !== "") {
                if (password.length < 6) {
                    return res.status(400).json({ message: "Password must be at least 6 characters." });
                }
                const hashedPassword = await bcrypt.hash(password, 10);
                updateFields.password = hashedPassword;
            }

            if (Object.keys(updateFields).length === 0) {
                return res.status(400).json({ message: "No updates provided." });
            }

            updateFields.updatedAt = new Date();

            await users.updateOne(
                { _id: userId },
                { $set: updateFields }
            );

            const updatedUser = await users.findOne({ _id: userId });

            return res.json({
                message: "Profile updated successfully.",
                user: {
                    id: updatedUser._id.toString(),
                    username: updatedUser.username,
                    phoneNumber: updatedUser.phoneNumber || null,
                    email: updatedUser.email || null,
                    profilePic: updatedUser.profilePic || null,
                }
            });

        } catch (error) {
            console.error("Update profile error:", error);
            return res.status(500).json({ message: "Server error updating profile." });
        }
    }

    return { getProfile, updateProfile };
}

module.exports = { createUserController };
