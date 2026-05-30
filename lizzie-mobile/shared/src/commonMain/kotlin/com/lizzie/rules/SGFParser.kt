package com.lizzie.rules

/**
 * SGF (Smart Game Format) parser and serializer for Go.
 *
 * Ported from Lizzie's SGFParser.java.
 * Handles standard FF[4] SGF files with Go game trees.
 */
object SGFParser {

    /**
     * Parse SGF text into a game tree.
     * Returns the root properties and the ordered list of move nodes.
     */
    fun parseSgf(sgfContent: String): ParsedSgfGame {
        val cleaned = sgfContent.trim()
        if (!cleaned.startsWith("(") || !cleaned.endsWith(")")) {
            throw IllegalArgumentException("Invalid SGF: missing wrapping parentheses")
        }

        val gameInfo = GameInfo()
        val moves = mutableListOf<ParsedMove>()
        var komi = 6.5
        var boardSize = 19
        var foundRoot = false

        // Parse tokens: ( ) ; and key[value] pairs
        val tokens = tokenize(cleaned)

        var i = 0
        while (i < tokens.size) {
            when (tokens[i]) {
                "(" -> { /* start of game tree — skip */ i++ }
                ")" -> { /* end — skip */ i++ }
                ";" -> {
                    i++ // read properties until next ";" or "(" or ")"
                    val props = mutableMapOf<String, String>()
                    while (i < tokens.size && tokens[i] !in setOf(";", "(", ")")) {
                        val key = tokens[i]
                        i++
                        if (i < tokens.size && tokens[i].startsWith("[")) {
                            val value = tokens[i].trimStart('[').trimEnd(']')
                            props[key] = value
                            i++
                        }
                    }

                    if (!foundRoot) {
                        // Root node — extract game info
                        foundRoot = true
                        boardSize = props["SZ"]?.toIntOrNull() ?: 19
                        komi = props["KM"]?.toDoubleOrNull() ?: 6.5
                        gameInfo.copy(
                            playerBlack = props["PB"] ?: "",
                            playerWhite = props["PW"] ?: "",
                            komi = komi,
                            handicap = props["HA"]?.toIntOrNull() ?: 0,
                            ruleSet = props["RU"] ?: "jp",
                            gameName = props["GN"] ?: "",
                            gameDate = props["DT"] ?: "",
                            result = props["RE"] ?: "",
                        )

                        // Handle handicap setup stones (AB)
                        val abStones = parseSgfStones(props["AB"] ?: "")
                        for (stone in abStones) {
                            moves.add(ParsedMove(stone.first, stone.second, Stone.BLACK, isSetup = true))
                        }
                        val awStones = parseSgfStones(props["AW"] ?: "")
                        for (stone in awStones) {
                            moves.add(ParsedMove(stone.first, stone.second, Stone.WHITE, isSetup = true))
                        }
                    } else {
                        // Move node
                        val b = props["B"]?.takeIf { it.isNotBlank() }
                        val w = props["W"]?.takeIf { it.isNotBlank() }

                        if (b != null) {
                            val coord = sgfCoordToBoard(b, boardSize)
                            if (coord != null) {
                                moves.add(ParsedMove(coord.first, coord.second, Stone.BLACK, isPass = false))
                            } else {
                                moves.add(ParsedMove(0, 0, Stone.BLACK, isPass = true))
                            }
                        } else if (w != null) {
                            val coord = sgfCoordToBoard(w, boardSize)
                            if (coord != null) {
                                moves.add(ParsedMove(coord.first, coord.second, Stone.WHITE, isPass = false))
                            } else {
                                moves.add(ParsedMove(0, 0, Stone.WHITE, isPass = true))
                            }
                        }

                        // Comment
                        val comment = props["C"]
                        if (comment != null && moves.isNotEmpty()) {
                            val lastIdx = moves.lastIndex
                            moves[lastIdx] = moves[lastIdx].copy(comment = comment)
                        }
                    }

                    // Skip nested subtrees for now (basic parser)
                    // Lizzie's original parser handles variations as different branches
                }
                else -> i++ // unknown token
            }
        }

        return ParsedSgfGame(gameInfo, boardSize, moves)
    }

    /**
     * Serialize a game to SGF string.
     */
    fun saveSgf(
        history: BoardHistoryList,
        gameInfo: GameInfo,
        width: Int = 19,
        height: Int = 19
    ): String {
        val sb = StringBuilder()
        sb.append("(;FF[4]GM[1]SZ[$width]")
        sb.append("KM[${gameInfo.komi}]")
        if (gameInfo.playerBlack.isNotEmpty()) sb.append("PB[${escapeSgf(gameInfo.playerBlack)}]")
        if (gameInfo.playerWhite.isNotEmpty()) sb.append("PW[${escapeSgf(gameInfo.playerWhite)}]")
        if (gameInfo.result.isNotEmpty()) sb.append("RE[${escapeSgf(gameInfo.result)}]")
        if (gameInfo.gameName.isNotEmpty()) sb.append("GN[${escapeSgf(gameInfo.gameName)}]")
        if (gameInfo.gameDate.isNotEmpty()) sb.append("DT[${escapeSgf(gameInfo.gameDate)}]")
        if (gameInfo.handicap > 0) sb.append("HA[${gameInfo.handicap}]")
        if (gameInfo.ruleSet.isNotEmpty()) sb.append("RU[${escapeSgf(gameInfo.ruleSet)}]")

        // Serialize move tree
        serializeNode(sb, history.root(), width, height)

        sb.append(")")
        return sb.toString()
    }

    private fun serializeNode(sb: StringBuilder, node: BoardHistoryNode?, width: Int, height: Int) {
        if (node == null) return
        val data = node.data
        val isRoot = node.previous() == null

        if (isRoot) {
            // Root node already written its properties above
            val variations = node.getVariations()
            for (child in variations) {
                serializeNode(sb, child, width, height)
            }
            return
        }

        sb.append(";")
        val color = data.lastMoveColor
        val coord = data.lastMove
        if (coord != null) {
            val sgfCoord = boardCoordToSgf(coord.first, coord.second, width, height)
            if (color == Stone.BLACK) {
                sb.append("B[$sgfCoord]")
            } else {
                sb.append("W[$sgfCoord]")
            }
        } else {
            // Pass
            if (color == Stone.BLACK) {
                sb.append("B[]")
            } else {
                sb.append("W[]")
            }
        }

        if (data.comment.isNotEmpty()) {
            sb.append("C[${escapeSgf(data.comment)}]")
        }

        // Check for variations (multiple children)
        val variations = node.getVariations()
        if (variations.size > 1) {
            // First child in main line, rest in parentheses
            val first = variations.first()
            serializeNode(sb, first, width, height)

            for (i in 1 until variations.size) {
                sb.append("(")
                serializeNode(sb, variations[i], width, height)
                sb.append(")")
            }
        } else if (variations.size == 1) {
            serializeNode(sb, variations.first(), width, height)
        }
    }

    // ---- SGF coordinate conversion ----

    /** SGF coordinates use "ab" for the top-left, with letters a=0, b=1, ... z=25. */
    private const val SGF_ALPHABET = "abcdefghijklmnopqrstuvwxyz"

    fun sgfCoordToBoard(sgfCoord: String, boardSize: Int = 19): Pair<Int, Int>? {
        if (sgfCoord.length < 2) return null
        val x = SGF_ALPHABET.indexOf(sgfCoord[0].lowercaseChar())
        val y = SGF_ALPHABET.indexOf(sgfCoord[1].lowercaseChar())
        if (x < 0 || y < 0 || x >= boardSize || y >= boardSize) return null
        return Pair(x, boardSize - 1 - y) // SGF y=0 is top, our y=0 is bottom
    }

    fun boardCoordToSgf(x: Int, y: Int, width: Int = 19, height: Int = 19): String {
        if (x < 0 || y < 0 || x >= width || y >= height) return ""
        return "${SGF_ALPHABET[x]}${SGF_ALPHABET[height - 1 - y]}"
    }

    fun parseSgfStones(value: String): List<Pair<Int, Int>> {
        val coords = mutableListOf<Pair<Int, Int>>()
        val cleaned = value.replace("\\s".toRegex(), "")
        // Pairs of two characters (e.g., "ab" means position a,b)
        var i = 0
        while (i + 1 < cleaned.length) {
            val x = SGF_ALPHABET.indexOf(cleaned[i].lowercaseChar())
            val y = SGF_ALPHABET.indexOf(cleaned[i + 1].lowercaseChar())
            if (x >= 0 && y >= 0) {
                coords.add(Pair(x, y))
            }
            i += 2
        }
        return coords
    }

    // ---- SGF property helpers ----

    fun addProperty(properties: MutableMap<String, String>, key: String, value: String) {
        when (key) {
            "B", "W", "AB", "AW", "AE" -> {
                // Move properties are handled separately
            }
            else -> {
                val existing = properties[key]
                if (existing != null) {
                    properties[key] = "$existing:$value"
                } else {
                    properties[key] = value
                }
            }
        }
    }

    fun addProperties(properties: MutableMap<String, String>, addProps: Map<String, String>) {
        for ((key, value) in addProps) {
            addProperty(properties, key, value)
        }
    }

    fun getOrDefault(properties: Map<String, String>, key: String, default: String): String {
        return properties[key] ?: default
    }

    fun propertiesString(properties: Map<String, String>): String {
        return properties.entries.joinToString(" ") { (key, value) ->
            "$key[$value]"
        }
    }

    // ---- Tokens ----

    private fun tokenize(sgf: String): List<String> {
        val tokens = mutableListOf<String>()
        var i = 0
        while (i < sgf.length) {
            when (val c = sgf[i]) {
                '(', ')' -> {
                    tokens.add(c.toString())
                    i++
                }
                ';' -> {
                    tokens.add(";")
                    i++
                }
                '\\' -> {
                    // Escape — skip next character
                    i += 2
                }
                '[' -> {
                    // Read value until matching ]
                    val start = i
                    i++
                    val value = StringBuilder()
                    while (i < sgf.length && sgf[i] != ']') {
                        if (sgf[i] == '\\' && i + 1 < sgf.length) {
                            value.append(sgf[i + 1])
                            i += 2
                        } else {
                            value.append(sgf[i])
                            i++
                        }
                    }
                    if (i < sgf.length) i++ // skip ]
                    tokens.add("[$value]")
                }
                else -> {
                    if (!c.isWhitespace()) {
                        val key = StringBuilder()
                        while (i < sgf.length && sgf[i] !in ";([]) \t\r\n" && !sgf[i].isWhitespace()) {
                            key.append(sgf[i])
                            i++
                        }
                        tokens.add(key.toString())
                    } else {
                        i++
                    }
                }
            }
        }
        return tokens
    }

    private fun escapeSgf(s: String): String {
        return s.replace("\\", "\\\\")
            .replace("]", "\\]")
            .replace("\n", "\\n")
    }
}

data class ParsedMove(
    val x: Int,
    val y: Int,
    val color: Stone,
    val isPass: Boolean = false,
    val isSetup: Boolean = false,
    val comment: String = "",
)

data class ParsedSgfGame(
    val gameInfo: GameInfo,
    val boardSize: Int,
    val moves: List<ParsedMove>,
)