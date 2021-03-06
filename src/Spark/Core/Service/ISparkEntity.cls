/*------------------------------------------------------------------------
    File        : ISparkEntity
    Purpose     :
    Description :
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Tue Mar 17 09:29:59 EDT 2015
    Notes       :
  ----------------------------------------------------------------------*/

interface Spark.Core.Service.ISparkEntity inherits Ccs.BusinessLogic.IBusinessEntity:

    define public property LastCount as int64 no-undo get.

    method public void postRowFill ( input dataset-handle phDataset ).

    method public void readData ( input  filter  as character,
                                  output numRecs as int64,
                                  output dataset-handle phDataSet ).

    method public void createData ( input-output dataset-handle phDataSet ).

    method public void updateData ( input-output dataset-handle phDataSet ).

    method public void deleteData ( input-output dataset-handle phDataSet ).

    method public void submitData ( input-output dataset-handle phDataSet ).

end interface.