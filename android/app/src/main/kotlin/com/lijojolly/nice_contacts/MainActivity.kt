package com.lijojolly.nice_contacts

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import co.quis.flutter_contacts.FlutterContacts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lijojolly.nice_contacts/direct_call"
    private val RINGTONE_CHANNEL = "com.lijojolly.nice_contacts/ringtone"
    private val CONTACT_CHANNEL = "com.lijojolly.nice_contacts/contact_ops"
    private val CALL_PHONE_PERMISSION_CODE = 100
    private var pendingNumber: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Direct-call channel ──────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "directCall") {
                val number = call.argument<String>("number")
                if (number != null) {
                    makeDirectCall(number)
                    result.success(true)
                } else {
                    result.error("INVALID", "Phone number is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // ── Per-contact ringtone channel ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setContactRingtone" -> {
                    val contactId = call.argument<String>("contactId")
                    val filePath  = call.argument<String>("filePath")
                    if (contactId == null || filePath == null) {
                        result.error("INVALID", "contactId or filePath is null", null)
                    } else {
                        try {
                            val ringtoneUri = addFileToMediaStore(filePath)
                            if (ringtoneUri != null) {
                                applyRingtoneToContact(contactId, ringtoneUri)
                                result.success(null)
                            } else {
                                result.error("FAILED", "Could not register file in MediaStore", null)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                "clearContactRingtone" -> {
                    val contactId = call.argument<String>("contactId")
                    if (contactId == null) {
                        result.error("INVALID", "contactId is null", null)
                    } else {
                        try {
                            applyRingtoneToContact(contactId, null)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Contact insert channel ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "insertContactSafely" -> {
                    val contactMap = call.argument<Map<String, Any?>>("contact")
                    if (contactMap == null) {
                        result.error("INVALID", "contact is null", null)
                    } else {
                        try {
                            val prepared = contactMap.toMutableMap()
                            chooseWritableContactAccount()?.let { account ->
                                prepared["accounts"] = listOf(
                                    mapOf(
                                        "rawId" to "",
                                        "type" to account.first,
                                        "name" to account.second,
                                        "mimetypes" to emptyList<String>(),
                                    )
                                )
                            }
                            val inserted = FlutterContacts.insert(contentResolver, prepared)
                            if (inserted != null) {
                                result.success(inserted)
                            } else {
                                result.error("FAILED", "Contact insertion returned null", null)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Inserts [filePath] into the Android MediaStore Audio collection as a
     * ringtone and returns the resulting content URI string, or null on failure.
     * Deduplicates: if the file is already in the MediaStore the existing URI
     * is returned without re-inserting.
     */
    private fun addFileToMediaStore(filePath: String): String? {
        val file = File(filePath)
        if (!file.exists()) return null

        val mimeType = when (file.extension.lowercase()) {
            "mp3"  -> "audio/mpeg"
            "wav"  -> "audio/wav"
            "aac"  -> "audio/aac"
            "m4a"  -> "audio/mp4"
            "ogg"  -> "audio/ogg"
            "flac" -> "audio/flac"
            else   -> "audio/*"
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: copy file content into shared Ringtones/ folder
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, file.name)
                put(MediaStore.Audio.Media.TITLE, file.nameWithoutExtension)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                put(MediaStore.Audio.Media.RELATIVE_PATH, "Ringtones/")
                put(MediaStore.Audio.Media.IS_RINGTONE, 1)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 0)
                put(MediaStore.Audio.Media.IS_ALARM, 0)
                put(MediaStore.Audio.Media.IS_MUSIC, 0)
            }
            val uri = contentResolver.insert(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values
            ) ?: return null
            contentResolver.openOutputStream(uri)?.use { os ->
                FileInputStream(file).use { it.copyTo(os) }
            }
            uri.toString()
        } else {
            // Android 9 and below: use legacy DATA field
            // Check for existing entry to avoid duplicates
            val projection = arrayOf(MediaStore.Audio.Media._ID)
            val selection  = "${MediaStore.Audio.Media.DATA} = ?"
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection, selection, arrayOf(filePath), null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(
                        cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                    )
                    return ContentUris.withAppendedId(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id
                    ).toString()
                }
            }
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DATA, filePath)
                put(MediaStore.Audio.Media.TITLE, file.nameWithoutExtension)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                put(MediaStore.Audio.Media.IS_RINGTONE, 1)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 0)
                put(MediaStore.Audio.Media.IS_ALARM, 0)
                put(MediaStore.Audio.Media.IS_MUSIC, 0)
            }
            contentResolver.insert(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values
            )?.toString()
        }
    }

    /** Writes [ringtoneUri] (or null to restore default) into the contact record. */
    private fun applyRingtoneToContact(contactId: String, ringtoneUri: String?) {
        val id = contactId.toLongOrNull() ?: return
        val contactUri = ContentUris.withAppendedId(
            ContactsContract.Contacts.CONTENT_URI, id
        )
        val values = ContentValues()
        if (ringtoneUri != null) {
            values.put(ContactsContract.Contacts.CUSTOM_RINGTONE, ringtoneUri)
        } else {
            values.putNull(ContactsContract.Contacts.CUSTOM_RINGTONE)
        }
        contentResolver.update(contactUri, values, null, null)
    }

    private fun chooseWritableContactAccount(): Pair<String, String>? {
        val preferredSettings = contentResolver.query(
            ContactsContract.Settings.CONTENT_URI,
            arrayOf(
                ContactsContract.Settings.ACCOUNT_TYPE,
                ContactsContract.Settings.ACCOUNT_NAME,
                ContactsContract.Settings.SHOULD_SYNC,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            val accounts = mutableListOf<Triple<String, String, Int>>()
            val typeIndex = cursor.getColumnIndex(ContactsContract.Settings.ACCOUNT_TYPE)
            val nameIndex = cursor.getColumnIndex(ContactsContract.Settings.ACCOUNT_NAME)
            val syncIndex = cursor.getColumnIndex(ContactsContract.Settings.SHOULD_SYNC)
            while (cursor.moveToNext()) {
                val type = if (typeIndex >= 0) cursor.getString(typeIndex) ?: "" else ""
                val name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "" else ""
                val shouldSync = if (syncIndex >= 0) cursor.getInt(syncIndex) else 0
                if (type.isNotBlank() && name.isNotBlank()) {
                    accounts.add(Triple(type, name, shouldSync))
                }
            }
            accounts
        } ?: emptyList()

        preferredSettings.firstOrNull { (type, _, shouldSync) ->
            shouldSync != 0 && isWritableContactAccount(type)
        }?.let { return it.first to it.second }

        val rawAccounts = contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(
                ContactsContract.RawContacts.ACCOUNT_TYPE,
                ContactsContract.RawContacts.ACCOUNT_NAME,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            val accounts = linkedSetOf<Pair<String, String>>()
            val typeIndex = cursor.getColumnIndex(ContactsContract.RawContacts.ACCOUNT_TYPE)
            val nameIndex = cursor.getColumnIndex(ContactsContract.RawContacts.ACCOUNT_NAME)
            while (cursor.moveToNext()) {
                val type = if (typeIndex >= 0) cursor.getString(typeIndex) ?: "" else ""
                val name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "" else ""
                if (type.isNotBlank() && name.isNotBlank()) {
                    accounts.add(type to name)
                }
            }
            accounts.toList()
        } ?: emptyList()

        return rawAccounts.firstOrNull { (type, _) -> isWritableContactAccount(type) }
    }

    private fun isWritableContactAccount(accountType: String): Boolean {
        val type = accountType.lowercase()
        if (type.isBlank()) return false
        if (type.contains("sim") || type.contains("usim") || type.contains("local")) {
            return false
        }
        return type == "com.google" ||
            type.contains("exchange") ||
            type.contains("office") ||
            type.contains("outlook") ||
            type.contains("samsung") ||
            type.contains("huawei") ||
            type.contains("xiaomi") ||
            type.contains("miui") ||
            type.contains("icloud") ||
            type.contains("carddav")
    }

    // ── Direct call ──────────────────────────────────────────────────────────

    private fun makeDirectCall(number: String) {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CALL_PHONE)
            == PackageManager.PERMISSION_GRANTED) {
            val intent = Intent(Intent.ACTION_CALL)
            intent.data = Uri.parse("tel:$number")
            startActivity(intent)
        } else {
            pendingNumber = number
            ActivityCompat.requestPermissions(this,
                arrayOf(android.Manifest.permission.CALL_PHONE),
                CALL_PHONE_PERMISSION_CODE)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CALL_PHONE_PERMISSION_CODE && grantResults.isNotEmpty()
            && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            pendingNumber?.let { makeDirectCall(it) }
            pendingNumber = null
        }
    }
}
