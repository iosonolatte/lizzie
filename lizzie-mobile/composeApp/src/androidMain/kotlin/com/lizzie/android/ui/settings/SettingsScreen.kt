package com.lizzie.android.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lizzie.config.EngineMode
import com.lizzie.config.LizzieConfig

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    config: LizzieConfig,
    onConfigChanged: (LizzieConfig) -> Unit,
    onClose: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    TextButton(onClick = onClose) {
                        Text("Done")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // ---- Engine section ----
            Text("Engine", style = MaterialTheme.typography.titleMedium)

            // Engine mode selector
            Text("Engine Mode", style = MaterialTheme.typography.labelMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                EngineMode.values().forEach { mode ->
                    FilterChip(
                        selected = config.engineMode == mode,
                        onClick = { onConfigChanged(config.copy(engineMode = mode)) },
                        label = { Text(mode.name) },
                    )
                }
            }

            if (config.engineMode == EngineMode.Remote) {
                OutlinedTextField(
                    value = config.remoteHost,
                    onValueChange = { onConfigChanged(config.copy(remoteHost = it)) },
                    label = { Text("Host") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = config.remotePort.toString(),
                    onValueChange = { it.toIntOrNull()?.let { p -> onConfigChanged(config.copy(remotePort = p)) } },
                    label = { Text("Port") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            if (config.engineMode == EngineMode.Local) {
                OutlinedTextField(
                    value = config.engineCommand,
                    onValueChange = { onConfigChanged(config.copy(engineCommand = it)) },
                    label = { Text("Engine Command") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            HorizontalDivider()

            // ---- Display section ----
            Text("Display", style = MaterialTheme.typography.titleMedium)

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show Coordinates")
                Switch(
                    checked = config.showCoordinates,
                    onCheckedChange = { onConfigChanged(config.copy(showCoordinates = it)) },
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show Move Numbers")
                Switch(
                    checked = config.showMoveNumber,
                    onCheckedChange = { onConfigChanged(config.copy(showMoveNumber = it)) },
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show Winrate")
                Switch(
                    checked = config.showWinrate,
                    onCheckedChange = { onConfigChanged(config.copy(showWinrate = it)) },
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show Score Mean")
                Switch(
                    checked = config.showScoreMean,
                    onCheckedChange = { onConfigChanged(config.copy(showScoreMean = it)) },
                )
            }

            // Board size
            Text("Board Size", style = MaterialTheme.typography.labelMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(9, 13, 19).forEach { size ->
                    FilterChip(
                        selected = config.boardSize == size,
                        onClick = { onConfigChanged(config.copy(boardSize = size)) },
                        label = { Text("${size}x$size") },
                    )
                }
            }

            HorizontalDivider()

            // ---- Analysis section ----
            Text("Analysis", style = MaterialTheme.typography.titleMedium)

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show KataGo Estimate")
                Switch(
                    checked = config.showKataGoEstimate,
                    onCheckedChange = { onConfigChanged(config.copy(showKataGoEstimate = it)) },
                )
            }
        }
    }
}