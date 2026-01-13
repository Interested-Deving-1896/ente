package io.ente.photos

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import android.accounts.AccountManager
import androidx.appcompat.app.AlertDialog

class LoginActivity : AppCompatActivity() {

    private var account: AccountModel? = null

    companion object {
        private const val ACCOUNT_ACTIVITY_CLASS_NAME =
            "com.unplugged.account.ui.thirdparty.ThirdPartyCredentialsActivity"

        private fun isDebugBuild(context: android.content.Context): Boolean {
            val isDebug = context.packageName.endsWith(".dev") || context.packageName.endsWith(".debug")
            return isDebug
        }
    }

    private val accountLoginLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            when (result.resultCode) {
                Activity.RESULT_OK -> {
                    val servicePassword = result.data?.getStringExtra("service_password") ?: ""
                    val upToken = result.data?.getStringExtra("up_token") ?: ""
                    val usernameRaw = result.data?.getStringExtra("username") ?: ""

                    account = AccountModel(
                        servicePassword,
                        upToken,
//                        "$usernameRaw@matrix.unpluggedsystems.app",
                        usernameRaw,
                    )
                }

                Activity.RESULT_CANCELED -> {
                    when (result.data?.getStringExtra("reason")) {
                        "USER_REJECTED" -> {
                            Log.d("UpEnte", "Login error: User doesn't want backup")
                        }

                        "NO_CREDENTIALS" -> {
                            lifecycleScope.launch {
                                val accountPackage = getString(R.string.account_intent_package)
                                val storePackage = getString(R.string.store_intent_package)

                                val targetPackage = if (isPackageInstalled(accountPackage)) {
                                    accountPackage
                                } else if (isPackageInstalled(storePackage)) {
                                    storePackage
                                } else {
                                    Log.d("UpEnte", "Neither account app nor store found for credential generation")
                                    return@launch
                                }

                                val generateCredentialsIntent = Intent().apply {
                                    component = ComponentName(targetPackage, ACCOUNT_ACTIVITY_CLASS_NAME)
                                    putExtra("action", "generate_credentials")
                                }
                                startActivity(generateCredentialsIntent)
                                finish()
                                return@launch
                            }
                        }

                        "NO_SERVICE_NAME_PROVIDED" -> {
                            Log.d("UpEnte", "Login error: Didn't send service name")
                        }

                        "UP_UNAUTHORIZED" -> {
                            Log.d("UpEnte", "Login error: User is not logged in")
                            openNotConnectedDialog()
                            return@registerForActivityResult
                        }
                    }
                }
            }

            // Only call handleAccountLoginResponse if the activity is not finishing
            if (!isFinishing) {
                handleAccountLoginResponse(account)
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
        // Prevent white screen flash
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        val sharedPrefs: SharedPreferences = getSharedPreferences("ente_prefs", MODE_PRIVATE)
        val savedUsername = sharedPrefs.getString("username", null)


        val accountType =
            if (isDebugBuild(this)) "com.unplugged.account.dev" else "com.unplugged.account"

        val accountManager = AccountManager.get(this)
        val account = accountManager.getAccountsByType(accountType).firstOrNull()
        val accountUsername = account?.let { accountManager.getUserData(it, "username") }

        if (savedUsername.isNullOrEmpty()) {
            // No previous login, just start account app flow
            Log.d("UpEnte", "[DEBUG] No saved username, starting account app flow")

            val accountPackage = getString(R.string.account_intent_package)
            val storePackage = getString(R.string.store_intent_package)

            // Try account app first, if not installed try store
            val targetPackage = if (isPackageInstalled(accountPackage)) {
                Log.d("UpEnte", "[DEBUG] Account app found: $accountPackage")
                accountPackage
            } else if (isPackageInstalled(storePackage)) {
                Log.d("UpEnte", "[DEBUG] Account app not found, using store: $storePackage")
                storePackage
            } else {
                Log.d("UpEnte", "[DEBUG] Neither account app nor store found")
                finish()
                return
            }

            val credentialsIntent = Intent().apply {
                component = ComponentName(targetPackage, ACCOUNT_ACTIVITY_CLASS_NAME)
                putExtra("action", "service_1")
            }
            accountLoginLauncher.launch(credentialsIntent)
            return
        }

        val trimmedSavedUsername = savedUsername.substringBefore('@')
        if (accountUsername.isNullOrEmpty() || trimmedSavedUsername != accountUsername) {
            // Username mismatch or missing in AccountManager, trigger forced logout
            Log.d(
                "UpEnte",
                "[DEBUG] Username missing or mismatch, triggering forced logout via MainActivity"
            )
            val callSecret = generateCallSecret()
            val openFlutterIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("shouldLogout", true)
                putExtra("call_secret", callSecret)
                // Use REORDER_TO_FRONT to bring existing MainActivity to front if it exists
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            }
            startActivity(openFlutterIntent)
            finish()
            return
        } else {
            // If both usernames exist and match, go to MainActivity (no secret needed for re-entry)
            Log.d("UpEnte", "[DEBUG] Usernames match, proceeding to MainActivity")
            val openFlutterIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("username", savedUsername)
                putExtra("from_login", true) // Flag to indicate this came from gallery app
                // Use REORDER_TO_FRONT to bring existing MainActivity to front if it exists
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            }
            startActivity(openFlutterIntent)
            finish()
        }
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }


    private fun handleAccountLoginResponse(retrievedAccount: AccountModel? = null) {
        var loginSuccess = false

        if (retrievedAccount != null && retrievedAccount.servicePassword.isNotEmpty()) {
            // Login was successful
            loginSuccess = true
        } else {
            // Login failed (account is null)
            Log.d("UpEnte", "Login failed: Account details null")
            loginSuccess = false
        }

        if (loginSuccess) {
            // Only start MainActivity if the login was successful
            Log.d("UpEnte", "Proceeding to MainActivity.")
            val callSecret = generateCallSecret()
            val openFlutterIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("service_password", account?.servicePassword)
                putExtra("up_token", account?.upToken)
                putExtra("username", account?.username)
                putExtra("call_secret", callSecret)
                putExtra("from_login", true)
                // Use REORDER_TO_FRONT to bring existing MainActivity to front if it exists
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            }
            startActivity(openFlutterIntent)
            finish()
        } else {
            openErrorDialog()
        }
    }

    private fun openErrorDialog() {
        AlertDialog.Builder(this)
            .setTitle("Login Error")
            .setMessage("An error occurred while trying to login. Please try again or contact support if the problem persists.")
            .setPositiveButton("Try Again") { _, _ ->
                openAccountAppForSync()
                finish()
            }
            .setNegativeButton("Contact Support") { _, _ ->
                openSupportApp()
                finish()
            }
            .setCancelable(false)
            .show()
    }

    private fun openNotConnectedDialog() {
        AlertDialog.Builder(this)
            .setTitle("Not Connected")
            .setMessage("You are not connected to any user. Please connect a user and try again.")
            .setPositiveButton("Exit") { _, _ ->
                // Clear native shared prefs
                val sharedPrefs = getSharedPreferences("ente_prefs", MODE_PRIVATE)
                sharedPrefs.edit().clear().apply()
                // Clear Flutter shared prefs
                val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                flutterPrefs.edit().clear().apply()
                finishAndRemoveTask()
            }
            .setCancelable(false)
            .show()
    }

    private fun openAccountAppForSync() {
        // Clear native shared prefs
        val sharedPrefs = getSharedPreferences("ente_prefs", MODE_PRIVATE)
        sharedPrefs.edit().clear().apply()

        val accountPackage = getString(R.string.account_intent_package)
        val storePackage = getString(R.string.store_intent_package)

        val targetPackage = if (isPackageInstalled(accountPackage)) {
            accountPackage
        } else if (isPackageInstalled(storePackage)) {
            storePackage
        } else {
            Log.d("UpEnte", "Neither account app nor store found")
            return
        }

        try {
            val intent = Intent().apply {
                component = ComponentName(targetPackage, ACCOUNT_ACTIVITY_CLASS_NAME)
                putExtra("action", "sync_credentials")
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("UpEnte", "Failed to open account app for sync", e)
        }
    }

    private fun openSupportApp() {
        // Clear native shared prefs
        val sharedPrefs = getSharedPreferences("ente_prefs", MODE_PRIVATE)
        sharedPrefs.edit().clear().apply()

        try {
            val supportIntent = packageManager.getLaunchIntentForPackage("com.unplugged.support")
            if (supportIntent != null) {
                supportIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(supportIntent)
            } else {
                Log.e("UpEnte", "Support app not found on device")
            }
        } catch (e: Exception) {
            Log.e("UpEnte", "Failed to open support app", e)
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun generateCallSecret(): String {
        val secret = java.util.UUID.randomUUID().toString()
        getSharedPreferences("ente_internal", MODE_PRIVATE)
            .edit().putString("call_secret", secret).apply()
        Log.d("UpEnte", "[DEBUG] Generated call secret for MainActivity")
        return secret
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("UpEnte", "onDestroy: ")
    }
}