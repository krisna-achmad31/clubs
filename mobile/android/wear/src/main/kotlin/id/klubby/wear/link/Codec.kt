package id.klubby.wear.link

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.InvalidClassException
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.io.ObjectStreamClass

/**
 * Wire format of the phone's `watch_connectivity` plugin: a Java-serialized
 * HashMap. Decoding only accepts the plain map/list/number/string classes the
 * phone sends, so a crafted payload cannot instantiate anything else.
 */
object Codec {
    private val allowed = setOf(
        "java.util.HashMap",
        "java.util.LinkedHashMap",
        "java.util.ArrayList",
        "java.lang.String",
        "java.lang.Number",
        "java.lang.Integer",
        "java.lang.Long",
        "java.lang.Double",
        "java.lang.Boolean",
    )

    fun encode(map: Map<String, Any?>): ByteArray {
        val clean = HashMap<String, Any>()
        for ((k, v) in map) if (v != null) clean[k] = if (v is List<*>) ArrayList(v) else v
        val out = ByteArrayOutputStream()
        ObjectOutputStream(out).use { it.writeObject(clean) }
        return out.toByteArray()
    }

    fun decode(bytes: ByteArray): Map<String, Any?>? = runCatching {
        SafeInput(ByteArrayInputStream(bytes)).use { it.readObject() } as? Map<*, *>
    }.getOrNull()?.entries?.associate { (k, v) -> k.toString() to v }

    private class SafeInput(input: InputStream) : ObjectInputStream(input) {
        override fun resolveClass(desc: ObjectStreamClass): Class<*> {
            if (desc.name !in allowed) throw InvalidClassException(desc.name, "not allowed")
            return super.resolveClass(desc)
        }
    }
}
