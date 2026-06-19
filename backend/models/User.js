const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
    {
        fullName: {
            type: String,
            required: true,
            trim: true
        },

        email: {
            type: String,
            unique: true,
            lowercase: true,
            trim: true
        },

        phone: {
            type: String,
            required: true,
            default: null
        },

        password: {
            type: String,
            required: true
        },

        profilePic: {
            type: String,
            default: null
        },

        role: {
            type: String,
            enum: ["admin", "member"],
            default: "member"
        }
    },
    {
        timestamps: true
    }
);

module.exports = mongoose.model("User", userSchema);