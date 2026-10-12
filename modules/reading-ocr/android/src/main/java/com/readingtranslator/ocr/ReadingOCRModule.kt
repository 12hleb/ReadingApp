package com.readingtranslator.ocr

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class ReadingOCRModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ReadingOCR")
    AsyncFunction("recognize") { uri: String, promise: Promise ->
      val context = appContext.reactContext
      if (context == null) {
        promise.reject("OCR_CONTEXT", "OCR context is unavailable", null)
        return@AsyncFunction
      }
      try {
        val image = InputImage.fromFilePath(context, Uri.parse(uri))
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
          .addOnSuccessListener { result ->
            val blocks = result.textBlocks.map { block ->
              mapOf("lines" to block.lines.map { line ->
                mapOf("elements" to line.elements.mapNotNull { element ->
                  val box = element.boundingBox ?: return@mapNotNull null
                  mapOf(
                    "text" to element.text,
                    "confidence" to element.confidence,
                    "frame" to mapOf("left" to box.left, "top" to box.top, "width" to box.width(), "height" to box.height()),
                    "cornerPoints" to element.cornerPoints?.map { mapOf("x" to it.x, "y" to it.y) }
                  )
                })
              })
            }
            promise.resolve(mapOf("blocks" to blocks))
          }
          .addOnFailureListener { error -> promise.reject("OCR_FAILED", "Text recognition failed", error) }
          .addOnCompleteListener { recognizer.close() }
      } catch (error: Exception) {
        promise.reject("OCR_IMAGE", "Cannot open the captured page", error)
      }
    }
  }
}
