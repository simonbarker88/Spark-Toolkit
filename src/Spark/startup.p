/*------------------------------------------------------------------------
    File        : Spark/startup
    Purpose     : Run any "bootloader" type processes for dynamic code
                : and provide the information necessary to generate a
                : JSDO catalog for use with other Progress technology.
    Description :
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Tue Apr 26 15:03:17 EDT 2016
    Notes       : PAS: Assign as sessionStartupProc in openedge.properties,
                : uses sessionStartupProcParam to pass "ConfigDir" as JSON.
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

&GLOBAL-DEFINE CAN_USE_DOH (lookup(substring(proversion, 1, 4), "11.0,11.1,11.2,11.3,11.4,11.5") = 0 and lookup(substring(proversion(1), 1, 6), "11.6.0,11.6.1,11.6.2") = 0)

block-level on error undo, throw.

/* Standard input parameter as set via sessionStartupProcParam */
define input parameter startup-data as character no-undo.

/* Denote the current version of the Progress Modernization Framework. */
{Spark/version.i} /* Allow framework version to be updated by build process. */
define variable CurrentVersion as character no-undo initial "{&PMFO_VERSION}".

/* Set up a custom log file if not in an MSAS environment. */
if session:client-type eq "4GLCLIENT" then do:
    log-manager:logfile-name = session:temp-directory + "server.log".
end. /* session:client-type */

{Spark/Core/Lib/LogMessage.i &IsClass=false &IsPublic=false}

/* ***************************  Main Block  *************************** */
logMessage(substitute("Starting PMFO, version &1", CurrentVersion), "SPARK-STRT", 0).
logMessage(substitute("Session Startup Param [&1], num-dbs: &2", startup-data, num-dbs), "SPARK-STRT", 3).
logMessage(substitute("Internal Codepage: &1", session:cpinternal), "SPARK-STRT", 2).
logMessage(substitute("Stream Codepage: &1", session:cpstream), "SPARK-STRT", 2).

run getStartupParams. /* Obtain any startup params to use as overrides to default behavior. */

/* Touch the StartupManager:instance to start the framework (bootstrap process). */
logMessage(substitute("Configs: &1", Spark.Core.Util.OSTools:sparkConf), "SPARK-STRT", 3).
Ccs.Common.Application:StartupManager = Spark.Core.Manager.StartupManager:Instance.
logMessage("Session Startup - Application Initialized", "SPARK-STRT", 3).

/* Read business entities from disk and creates method signatures for API requests. */
define variable oManager as Ccs.Common.IManager no-undo.
assign oManager = Ccs.Common.Application:StartupManager:getManager(get-class(Spark.Core.Manager.ICatalogManager)).
if valid-object(oManager) then do:
    cast(oManager, Spark.Core.Manager.ICatalogManager):loadResources().
    logMessage("Session Startup Resources Loaded", "SPARK-STRT", 3).
end. /* valid-object */

/* Create a standard handler for OpenEdge.Web.DataObject.DataObjectHandler events. */
&IF {&CAN_USE_DOH} &THEN
/* Only if using OE 11.6.3 or later. */
new Spark.Core.Handler.DOHEventHandler().

/* Discover all DOH services for this webapp. */
define variable cServiceMapPath as character no-undo.
file-info:file-name = "ROOT.map".
if file-info:full-pathname ne ? then
    assign cServiceMapPath = replace(substring(file-info:full-pathname, 1, length(file-info:full-pathname) - 8), "~\", "/").
if (cServiceMapPath gt "") eq true then do:
    logMessage(substitute("Loading Service Registry data from &1", cServiceMapPath), "SPARK-STRT", 3).
    OpenEdge.Web.DataObject.ServiceRegistry:RegisterAllFromFolder(cServiceMapPath).
end.
&ENDIF

catch err as Progress.Lang.Error:
    logError("Session Startup Error", err, "SPARK-STRT", 0).
end catch.

/* Private procedure to parse any JSON options passed via startup-data. */
procedure getStartupParams private:
    /* If startup params are given, parse the value as a JSON object. */
    if startup-data begins "~{" then do:
        define variable oParser  as Progress.Json.ObjectModel.ObjectModelParser no-undo.
        define variable oStartup as Progress.Json.ObjectModel.JsonObject        no-undo.

        /* Parse the params as JSON. */
        assign oParser = new Progress.Json.ObjectModel.ObjectModelParser().
        assign oStartup = cast(oParser:Parse(replace(startup-data, "~\", "/")),
                               Progress.Json.ObjectModel.JsonObject).

        /* Set a custom project directory for locating the config files.
         * Must be set prior to running any code that depends on configs.
         */
        if valid-object(oStartup) and oStartup:Has("ConfigDir") then
            Spark.Core.Util.OSTools:configProjectDir = oStartup:GetCharacter("ConfigDir").

        delete object oParser  no-error.
        delete object oStartup no-error.
    end. /* startup-data */
end procedure.