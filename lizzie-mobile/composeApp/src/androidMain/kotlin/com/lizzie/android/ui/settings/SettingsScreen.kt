package com.lizzie.android.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
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
            SectionTitle("Engine")

            SettingsLabel("Engine Mode")
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
                    onValueChange = { v -> onConfigChanged(config.copy(remoteHost = v)) },
                    label = { Text("Host") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = config.remotePort.toString(),
                    onValueChange = { v -> v.toIntOrNull()?.let { p -> onConfigChanged(config.copy(remotePort = p)) } },
                    label = { Text("Port") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            if (config.engineMode == EngineMode.Local) {
                OutlinedTextField(
                    value = config.engineCommand,
                    onValueChange = { v -> onConfigChanged(config.copy(engineCommand = v)) },
                    label = { Text("Engine Command") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            HorizontalDivider()
            SectionTitle("Display")

            ToggleRow("Show Coordinates", config.showCoordinates) { c -> onConfigChanged(config.copy(showCoordinates = c)) }
            ToggleRow("Show Move Numbers", config.showMoveNumber) { c -> onConfigChanged(config.copy(showMoveNumber = c)) }
            ToggleRow("Show Winrate", config.showWinrate) { c -> onConfigChanged(config.copy(showWinrate = c)) }
            ToggleRow("Show Score Mean", config.showScoreMean) { c -> onConfigChanged(config.copy(showScoreMean = c)) }

            SettingsLabel("Board Size")
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
            SectionTitle("Analysis")

            ToggleRow("Show KataGo Estimate", config.showKataGoEstimate) { c -> onConfigChanged(config.copy(showKataGoEstimate = c)) }
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(title, style = MaterialTheme.typography.titleMedium)
}

@Composable
private fun SettingsLabel(label: String) {
    Text(label, style = MaterialTheme.typography.labelMedium)
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
