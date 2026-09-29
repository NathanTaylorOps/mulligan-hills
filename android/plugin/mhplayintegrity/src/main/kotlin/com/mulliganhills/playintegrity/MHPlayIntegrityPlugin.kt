package com.mulliganhills.playintegrity

import android.util.Log
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Thin Godot 4 (Android plugin v2) wrapper around Play Integrity STANDARD requests.
 *
 * GDScript surface (consumed by game/platform/mh_integrity_service_android.gd):
 *   prepare(cloudProjectNumber: String)      -> emits integrity_prepared(ok, message)
 *   request_token(requestHash: String)       -> emits integrity_token_result(requestHash, ok, token, error)
 *
 * The plugin never decides anything about the verdict. The token is opaque and is decoded ONLY on the server.
 *
 * STATUS: source only. NOT COMPILED, NOT RUN (no Android SDK / Gradle in the authoring sandbox).
 * API names follow https://developer.android.com/google/play/integrity/standard (fetched 2026-09-29).
 */
class MHPlayIntegrityPlugin(godot: Godot) : GodotPlugin(godot) {

    private var provider: StandardIntegrityTokenProvider? = null

    override fun getPluginName(): String = "MHPlayIntegrity"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("integrity_prepared", Boolean::class.javaObjectType, String::class.java),
        SignalInfo(
            "integrity_token_result",
            String::class.java, Boolean::class.javaObjectType, String::class.java, String::class.java
        )
    )

    @UsedByGodot
    fun prepare(cloudProjectNumber: String) {
        val ctx = activity?.applicationContext
        if (ctx == null) {
            emitSignal("integrity_prepared", false, "no_activity")
            return
        }
        val projectNumber = cloudProjectNumber.toLongOrNull()
        if (projectNumber == null) {
            emitSignal("integrity_prepared", false, "bad_cloud_project_number")
            return
        }
        val manager: StandardIntegrityManager = IntegrityManagerFactory.createStandard(ctx)
        manager.prepareIntegrityToken(
            PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(projectNumber).build()
        )
            .addOnSuccessListener { p ->
                provider = p
                emitSignal("integrity_prepared", true, "ok")
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "prepareIntegrityToken failed", e)
                emitSignal("integrity_prepared", false, e.javaClass.simpleName + ":" + (e.message ?: ""))
            }
    }

    @UsedByGodot
    fun request_token(requestHash: String) {
        val p = provider
        if (p == null) {
            emitSignal("integrity_token_result", requestHash, false, "", "not_prepared")
            return
        }
        p.request(StandardIntegrityTokenRequest.builder().setRequestHash(requestHash).build())
            .addOnSuccessListener { r ->
                emitSignal("integrity_token_result", requestHash, true, r.token(), "")
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "integrity request failed", e)
                emitSignal("integrity_token_result", requestHash, false, "", e.javaClass.simpleName + ":" + (e.message ?: ""))
            }
    }

    private companion object {
        const val TAG = "MHPlayIntegrity"
    }
}
