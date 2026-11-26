package com.ivy.importdata.csvimport

import android.content.Context
import android.net.Uri
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ivy.frp.test.TestIdlingResource
import com.ivy.legacy.domain.deprecated.logic.csv.CSVImporter
import com.ivy.legacy.domain.deprecated.logic.csv.model.ImportType
import com.ivy.data.backup.BackupDataUseCase
import com.ivy.legacy.utils.asLiveData
import com.ivy.base.legacy.getFileName
import com.ivy.navigation.ImportScreen
import com.ivy.navigation.Navigation
import com.ivy.onboarding.viewmodel.OnboardingViewModel
import com.ivy.wallet.domain.deprecated.logic.csv.CSVMapper
import com.ivy.wallet.domain.deprecated.logic.csv.CSVNormalizer
import com.ivy.data.file.FileSystem
import com.ivy.data.backup.ImportResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.collections.immutable.persistentListOf
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject
import kotlin.math.roundToInt

@HiltViewModel
class ImportViewModel @Inject constructor(
    private val ivyContext: com.ivy.legacy.IvyWalletCtx,
    private val nav: Navigation,
    private val fileReader: FileSystem,
    private val csvNormalizer: CSVNormalizer,
    private val csvMapper: CSVMapper,
    private val csvImporter: CSVImporter,
    private val backupDataUseCase: BackupDataUseCase
) : ViewModel() {
    private val _importStep = MutableLiveData<ImportStep>()
    val importStep = _importStep.asLiveData()

    private val _importType = MutableLiveData<ImportType>()
    val importType = _importType.asLiveData()

    private val _importProgressPercent = MutableLiveData<Int>()
    val importProgressPercent = _importProgressPercent.asLiveData()

    private val _importResult = MutableLiveData<ImportResult>()
    val importResult = _importResult.asLiveData()

    fun start(screen: ImportScreen) {
        nav.onBackPressed[screen] = {
            when (importStep.value) {
                ImportStep.IMPORT_FROM -> false
                ImportStep.INSTRUCTIONS -> {
                    _importStep.value = ImportStep.IMPORT_FROM
                    true
                }

                ImportStep.LOADING -> {
                    // do nothing, disable back
                    true
                }

                ImportStep.RESULT -> {
                    _importStep.value = ImportStep.IMPORT_FROM
                    true
                }

                null -> false
            }
        }
    }

    @ExperimentalStdlibApi
    fun pickFile(context: Context) {
        ivyContext.openFile { fileUri ->
            viewModelScope.launch {
                TestIdlingResource.increment()

                _importStep.value = ImportStep.LOADING
                _importProgressPercent.value = 0

                val kind = detectKind(context, fileUri)
                _importResult.value = try {
                    when (kind) {
                        FileKind.CSV -> restoreCSVFile(
                            fileUri = fileUri,
                            importType = ImportType.IVY,
                            utf16 = hasUtf16Bom(context, fileUri)
                        )

                        FileKind.ZIP -> backupDataUseCase.importBackupFile(
                            backupFileUri = fileUri
                        ) { progressPercent ->
                            com.ivy.legacy.utils.uiThread {
                                _importProgressPercent.value =
                                    (progressPercent * 100).roundToInt()
                            }
                        }

                        FileKind.OTHER -> emptyResult()
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Import failed")
                    emptyResult()
                }

                _importStep.value = ImportStep.RESULT

                TestIdlingResource.decrement()
            }
        }
    }

    private enum class FileKind { CSV, ZIP, OTHER }

    private fun emptyResult() = ImportResult(
        rowsFound = 0,
        transactionsImported = 0,
        accountsImported = 0,
        categoriesImported = 0,
        failedRows = persistentListOf()
    )

    private suspend fun detectKind(context: Context, fileUri: Uri): FileKind =
        com.ivy.legacy.utils.ioThread {
            val name = context.getFileName(fileUri)?.lowercase().orEmpty()
            val head = try {
                context.contentResolver.openInputStream(fileUri)?.use { ins ->
                    val b = ByteArray(4)
                    val n = ins.read(b)
                    if (n >= 2) b.copyOf(n) else ByteArray(0)
                } ?: ByteArray(0)
            } catch (e: Exception) {
                ByteArray(0)
            }
            val isZip = head.size >= 2 && head[0] == 'P'.code.toByte() && head[1] == 'K'.code.toByte()
            when {
                isZip || name.endsWith(".zip") -> FileKind.ZIP
                name.endsWith(".csv") -> FileKind.CSV
                else -> FileKind.OTHER
            }
        }

    private suspend fun hasUtf16Bom(context: Context, fileUri: Uri): Boolean =
        com.ivy.legacy.utils.ioThread {
            try {
                context.contentResolver.openInputStream(fileUri)?.use { ins ->
                    val b0 = ins.read()
                    val b1 = ins.read()
                    (b0 == 0xFF && b1 == 0xFE) || (b0 == 0xFE && b1 == 0xFF)
                } ?: false
            } catch (e: Exception) {
                false
            }
        }

    @ExperimentalStdlibApi
    private suspend fun restoreCSVFile(
        fileUri: Uri,
        importType: ImportType,
        utf16: Boolean
    ): ImportResult {
        return com.ivy.legacy.utils.ioThread {
            val rawCSV = fileReader.read(
                uri = fileUri,
                charset = if (utf16) Charsets.UTF_16 else Charsets.UTF_8
            ).getOrNull()
            if (rawCSV.isNullOrBlank()) {
                return@ioThread ImportResult(
                    rowsFound = 0,
                    transactionsImported = 0,
                    accountsImported = 0,
                    categoriesImported = 0,
                    failedRows = persistentListOf()
                )
            }

            val normalizedCSV = csvNormalizer.normalize(
                rawCSV = rawCSV,
                importType = importType
            )

            val mapping = csvMapper.mapping(
                type = importType,
                headerRow = normalizedCSV.split("\n").getOrNull(0)
            )

            return@ioThread try {
                val result = csvImporter.import(
                    csv = normalizedCSV,
                    rowMapping = mapping,
                    onProgress = { progressPercent ->
                        com.ivy.legacy.utils.uiThread {
                            _importProgressPercent.value =
                                (progressPercent * 100).roundToInt()
                        }
                    }
                )

                if (result.failedRows.isNotEmpty()) {
                    Timber.e("Import failed rows: ${result.failedRows}")
                }

                result
            } catch (e: Exception) {
                e.printStackTrace()
                ImportResult(
                    rowsFound = 0,
                    transactionsImported = 0,
                    accountsImported = 0,
                    categoriesImported = 0,
                    failedRows = persistentListOf()
                )
            }
        }
    }

    fun setImportType(importType: ImportType) {
        _importType.value = importType
        _importStep.value = ImportStep.INSTRUCTIONS
    }

    fun skip(
        screen: ImportScreen,
        onboardingViewModel: OnboardingViewModel
    ) {
        if (screen.launchedFromOnboarding) {
            onboardingViewModel.importSkip()
        }

        nav.back()
        resetState()
    }

    fun finish(
        screen: ImportScreen,
        onboardingViewModel: OnboardingViewModel
    ) {
        if (screen.launchedFromOnboarding) {
            val importSuccess = importResult.value?.transactionsImported?.let { it > 0 } ?: false
            onboardingViewModel.importFinished(
                success = importSuccess
            )
        }

        nav.back()
        resetState()
    }

    private fun resetState() {
        _importStep.value = ImportStep.IMPORT_FROM
    }

    private suspend fun hasCSVExtension(
        context: Context,
        fileUri: Uri
    ): Boolean = com.ivy.legacy.utils.ioThread {
        val fileName = context.getFileName(fileUri)
        fileName?.endsWith(suffix = ".csv", ignoreCase = true) ?: false
    }
}
