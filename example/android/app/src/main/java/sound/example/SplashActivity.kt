package sound.example

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class SplashActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_splash)

    // Immediately forward to the main activity; the layout ensures full-screen image is visible
    // during the brief transition. You can add a small delay if you want to showcase the splash longer.
    startActivity(Intent(this, MainActivity::class.java))
    finish()
  }
}

