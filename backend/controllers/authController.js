const { ObjectId } = require("mongodb");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const JWT_SECRET = process.env.JWT_SECRET || "dev-secret-change-in-production";

function createAuthController(db) {
    const users = db.collection("users");

    async function ensureIndexes() {
        await users.createIndex({ username: 1 }, { unique: true });
        await users.createIndex({ phoneNumber: 1 }, { unique: true });
    }

    async function signup(req, res) {
        try {
            const { username, phoneNumber, password } = req.body;

            if (!username || !phoneNumber || !password) {
                return res.status(400).json({ message: "Username, phone number and password are required" });
            }

            const existingUser = await users.findOne({ 
                $or: [{ username }, { phoneNumber }] 
            });

            if (existingUser) {
                return res.status(400).json({
                    message: "User already exists with this username or phone number"
                });
            }

            const hashedPassword = await bcrypt.hash(password, 10);

            const newUser = {
                username,
                phoneNumber,
                password: hashedPassword,
                createdAt: new Date(),
                updatedAt: new Date()
            };

            const result = await users.insertOne(newUser);
            const userId = result.insertedId.toString();

            const token = jwt.sign({ userId }, JWT_SECRET, { expiresIn: "30d" });

            res.status(201).json({
                message: "User created successfully",
                token,
                user: {
                    id: userId,
                    username: newUser.username,
                    phoneNumber: newUser.phoneNumber
                }
            });

        } catch (error) {
            console.error("Signup error:", error);
            res.status(500).json({ message: "Server error during signup" });
        }
    }

    async function login(req, res) {
        try {
            const { username, password } = req.body;

            if (!username || !password) {
                return res.status(400).json({ message: "Username and password are required" });
            }

            const user = await users.findOne({ username });

            if (!user) {
                return res.status(404).json({
                    message: "User not found"
                });
            }

            const isMatch = await bcrypt.compare(password, user.password);

            if (!isMatch) {
                return res.status(401).json({
                    message: "Invalid password"
                });
            }

            const token = jwt.sign({ userId: user._id.toString() }, JWT_SECRET, { expiresIn: "30d" });

            res.status(200).json({
                message: "Login successful",
                token,
                user: {
                    id: user._id.toString(),
                    username: user.username,
                    phoneNumber: user.phoneNumber
                }
            });

        } catch (error) {
            console.error("Login error:", error);
            res.status(500).json({ message: "Server error during login" });
        }
    }

    return { signup, login, ensureIndexes };
}

module.exports = { createAuthController };