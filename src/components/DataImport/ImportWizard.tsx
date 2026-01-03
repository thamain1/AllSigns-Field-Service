import { useState } from 'react';
import { X, ArrowRight, ArrowLeft, CheckCircle, AlertCircle, Upload, FileText, Database } from 'lucide-react';
import { DataImportService, ImportEntityType, ColumnMapping, ImportBatch } from '../../services/DataImportService';
import { StepSelectType } from './StepSelectType';
import { StepUploadFile } from './StepUploadFile';
import { StepColumnMapping } from './StepColumnMapping';
import { StepValidation } from './StepValidation';
import { StepImport } from './StepImport';

interface ImportWizardProps {
  onClose: () => void;
}

export type WizardStep = 'select-type' | 'upload' | 'mapping' | 'validation' | 'import';

export function ImportWizard({ onClose }: ImportWizardProps) {
  const [currentStep, setCurrentStep] = useState<WizardStep>('select-type');
  const [entityType, setEntityType] = useState<ImportEntityType>('customers');
  const [file, setFile] = useState<File | null>(null);
  const [fileContent, setFileContent] = useState<string>('');
  const [parsedRows, setParsedRows] = useState<any[]>([]);
  const [columnMapping, setColumnMapping] = useState<ColumnMapping>({});
  const [importBatch, setImportBatch] = useState<ImportBatch | null>(null);
  const [stagingRowIds, setStagingRowIds] = useState<string[]>([]);

  const steps: { id: WizardStep; label: string; icon: any }[] = [
    { id: 'select-type', label: 'Select Type', icon: Database },
    { id: 'upload', label: 'Upload File', icon: Upload },
    { id: 'mapping', label: 'Map Columns', icon: FileText },
    { id: 'validation', label: 'Validate', icon: AlertCircle },
    { id: 'import', label: 'Import', icon: CheckCircle },
  ];

  const currentStepIndex = steps.findIndex(s => s.id === currentStep);

  const handleNext = () => {
    const nextIndex = currentStepIndex + 1;
    if (nextIndex < steps.length) {
      setCurrentStep(steps[nextIndex].id);
    }
  };

  const handleBack = () => {
    const prevIndex = currentStepIndex - 1;
    if (prevIndex >= 0) {
      setCurrentStep(steps[prevIndex].id);
    }
  };

  const handleStepComplete = (data: any) => {
    if (currentStep === 'select-type') {
      setEntityType(data.entityType);
      handleNext();
    } else if (currentStep === 'upload') {
      setFile(data.file);
      setFileContent(data.content);
      setParsedRows(data.parsedRows);
      handleNext();
    } else if (currentStep === 'mapping') {
      setColumnMapping(data.mapping);
      setImportBatch(data.batch);
      setStagingRowIds(data.stagingRowIds);
      handleNext();
    } else if (currentStep === 'validation') {
      handleNext();
    } else if (currentStep === 'import') {
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-6xl w-full max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
          <div>
            <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Data Import Wizard</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              Import customers, open AR, and other data from your previous ERP system
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Progress Steps */}
        <div className="border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-700/50">
          <div className="flex items-center justify-between px-6 py-4">
            {steps.map((step, index) => {
              const Icon = step.icon;
              const isActive = step.id === currentStep;
              const isCompleted = index < currentStepIndex;

              return (
                <div key={step.id} className="flex items-center flex-1">
                  <div className="flex items-center">
                    <div
                      className={`flex items-center justify-center w-10 h-10 rounded-full border-2 transition-colors ${
                        isCompleted
                          ? 'bg-green-600 border-green-600 text-white'
                          : isActive
                          ? 'bg-blue-600 border-blue-600 text-white'
                          : 'bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 text-gray-400'
                      }`}
                    >
                      {isCompleted ? (
                        <CheckCircle className="w-6 h-6" />
                      ) : (
                        <Icon className="w-5 h-5" />
                      )}
                    </div>
                    <div className="ml-3">
                      <p
                        className={`text-sm font-medium ${
                          isActive || isCompleted
                            ? 'text-gray-900 dark:text-white'
                            : 'text-gray-500 dark:text-gray-400'
                        }`}
                      >
                        {step.label}
                      </p>
                    </div>
                  </div>

                  {index < steps.length - 1 && (
                    <div className="flex-1 mx-4">
                      <div
                        className={`h-0.5 ${
                          isCompleted
                            ? 'bg-green-600'
                            : 'bg-gray-300 dark:bg-gray-600'
                        }`}
                      />
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* Step Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {currentStep === 'select-type' && (
            <StepSelectType
              selectedType={entityType}
              onNext={handleStepComplete}
            />
          )}

          {currentStep === 'upload' && (
            <StepUploadFile
              entityType={entityType}
              onNext={handleStepComplete}
              onBack={handleBack}
            />
          )}

          {currentStep === 'mapping' && (
            <StepColumnMapping
              entityType={entityType}
              file={file}
              fileContent={fileContent}
              parsedRows={parsedRows}
              onNext={handleStepComplete}
              onBack={handleBack}
            />
          )}

          {currentStep === 'validation' && importBatch && (
            <StepValidation
              entityType={entityType}
              importBatch={importBatch}
              stagingRowIds={stagingRowIds}
              onNext={handleStepComplete}
              onBack={handleBack}
            />
          )}

          {currentStep === 'import' && importBatch && (
            <StepImport
              entityType={entityType}
              importBatch={importBatch}
              onComplete={handleStepComplete}
              onBack={handleBack}
            />
          )}
        </div>

        {/* Footer - Navigation removed as each step handles its own navigation */}
      </div>
    </div>
  );
}
