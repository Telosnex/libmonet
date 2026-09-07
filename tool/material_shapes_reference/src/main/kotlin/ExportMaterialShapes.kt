@file:OptIn(androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)

import androidx.compose.material3.MaterialShapes
import androidx.graphics.shapes.Cubic
import androidx.graphics.shapes.RoundedPolygon
import java.io.File

private val material3Version: String =
    requireNotNull(System.getProperty("material3Version"))

private val shapes = linkedMapOf(
    "circle" to MaterialShapes.Circle,
    "square" to MaterialShapes.Square,
    "slanted" to MaterialShapes.Slanted,
    "arch" to MaterialShapes.Arch,
    "fan" to MaterialShapes.Fan,
    "arrow" to MaterialShapes.Arrow,
    "semiCircle" to MaterialShapes.SemiCircle,
    "oval" to MaterialShapes.Oval,
    "pill" to MaterialShapes.Pill,
    "triangle" to MaterialShapes.Triangle,
    "diamond" to MaterialShapes.Diamond,
    "clamShell" to MaterialShapes.ClamShell,
    "pentagon" to MaterialShapes.Pentagon,
    "gem" to MaterialShapes.Gem,
    "sunny" to MaterialShapes.Sunny,
    "verySunny" to MaterialShapes.VerySunny,
    "cookie4Sided" to MaterialShapes.Cookie4Sided,
    "cookie6Sided" to MaterialShapes.Cookie6Sided,
    "cookie7Sided" to MaterialShapes.Cookie7Sided,
    "cookie9Sided" to MaterialShapes.Cookie9Sided,
    "cookie12Sided" to MaterialShapes.Cookie12Sided,
    "ghostish" to MaterialShapes.Ghostish,
    "clover4Leaf" to MaterialShapes.Clover4Leaf,
    "clover8Leaf" to MaterialShapes.Clover8Leaf,
    "burst" to MaterialShapes.Burst,
    "softBurst" to MaterialShapes.SoftBurst,
    "boom" to MaterialShapes.Boom,
    "softBoom" to MaterialShapes.SoftBoom,
    "flower" to MaterialShapes.Flower,
    "puffy" to MaterialShapes.Puffy,
    "puffyDiamond" to MaterialShapes.PuffyDiamond,
    "pixelCircle" to MaterialShapes.PixelCircle,
    "pixelTriangle" to MaterialShapes.PixelTriangle,
    "bun" to MaterialShapes.Bun,
    "heart" to MaterialShapes.Heart,
)

private fun Float.jsonNumber(): String =
    if (isFinite()) toString() else error("Non-finite shape coordinate: $this")

private fun Cubic.toJson(): String = listOf(
    anchor0X,
    anchor0Y,
    control0X,
    control0Y,
    control1X,
    control1Y,
    anchor1X,
    anchor1Y,
).joinToString(prefix = "[", postfix = "]") { it.jsonNumber() }

private fun RoundedPolygon.toJson(): String =
    cubics.joinToString(prefix = "[", postfix = "]") { it.toJson() }

private fun fixture(): String = buildString {
    append("{\n")
    append("  \"source\": \"androidx.compose.material3:material3:$material3Version\",\n")
    append("  \"coordinateOrder\": [\"anchor0X\", \"anchor0Y\", \"control0X\", \"control0Y\", ")
    append("\"control1X\", \"control1Y\", \"anchor1X\", \"anchor1Y\"],\n")
    append("  \"shapes\": {\n")
    shapes.entries.forEachIndexed { index, (name, shape) ->
        append("    \"")
        append(name)
        append("\": ")
        append(shape.toJson())
        if (index != shapes.size - 1) append(',')
        append('\n')
    }
    append("  }\n")
    append("}\n")
}

fun main(args: Array<String>) {
    require(args.size == 1) {
        "Expected output path: gradle run --args=/absolute/path/material_shapes_androidx.json"
    }
    val output = File(args.single()).absoluteFile
    output.parentFile.mkdirs()
    output.writeText(fixture())
    println("Wrote ${shapes.size} AndroidX Material shapes to $output")
}
