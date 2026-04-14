class RenameModelNameInTokenUsages < ActiveRecord::Migration[8.1]
  def change
    rename_column :token_usages, :model_name, :transcription_model
  end
end
