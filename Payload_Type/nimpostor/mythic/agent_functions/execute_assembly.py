from mythic_payloadtype_container.MythicCommandBase import *
from mythic_payloadtype_container.MythicRPC import *
import json, base64, sys, tempfile, os
from shutil import copyfile

class ExecuteAssemblyArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="file",
                cli_name="File",
                display_name="File",
                type=ParameterType.File,
                description="Select the C# binary to execute in memory.",
                parameter_group_info=[
                    ParameterGroupInfo(
                        ui_position=1,
                        group_name="New File"
                    )
                ]
            ),
            CommandParameter(
                name="filename",
                cli_name="registered-filename",
                display_name="Filename within Mythic",
                description="Supply existing binary in Mythic to execute.",
                type=ParameterType.ChooseOne,
                dynamic_query_function=self.get_files,
                parameter_group_info=[
                    ParameterGroupInfo(
                        ui_position=1,
                        group_name="Default"
                    )
                ]
            ),
            CommandParameter(
                name="args",
                display_name="Argument String",
                type=ParameterType.String,
                description="Arguments to pass to the Binary.",
                parameter_group_info=[
                    ParameterGroupInfo(
                        ui_position=2,
                        group_name="Default"
                    ),
                    ParameterGroupInfo(
                        ui_position=2,
                        group_name="New File"
                    ),
                ]
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise Exception("No arguments given.")
        if self.command_line[0] != "{":
            raise Exception("Require JSON blob, but got raw command line.")
        self.load_args_from_json_string(self.command_line)
        pass

    async def parse_dictionary(self, dictionary):
        self.load_args_from_dictionary(dictionary)

    async def get_files(self, callback: dict) -> [str]:
        file_resp = await MythicRPC().execute("get_file",
                                              callback_id=callback["id"],
                                              limit_by_callback=False,
                                              filename="",
                                              max_results=-1)
        if file_resp.status == MythicRPCStatus.Success:
            file_names = []
            for f in file_resp.response:
                if f["filename"] not in file_names:
                    file_names.append(f["filename"])
            return file_names
        else:
            return []

class ExecuteAssemblyCommand(CommandBase):
    cmd = "execute_assembly"
    needs_admin = False
    help_cmd = "execute_assembly (modal popup)"
    description = "Upload a C# binary into memory and execute it with given args."
    version = 1
    is_exit = False
    is_file_browse = False
    is_process_list = False
    is_download_file = False
    is_remove_file = False
    is_upload_file = False
    author = "@Sobol"
    argument_class = ExecuteAssemblyArguments
    attackmapping = ["T1106", "T1620", "T1105"]
    browser_script = BrowserScript(script_name="execute_assembly", author="@Sobol", for_new_ui=True)

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        try:
            groupName = task.args.get_parameter_group_name()
            if groupName == "New File":
                file_resp = await MythicRPC().execute("get_file",
                                                      file_id=task.args.get_arg("file"),
                                                      task_id=task.id,
                                                      get_contents=True)
                if file_resp.status == MythicRPCStatus.Success:
                    original_file_name = file_resp.response[0]["filename"]
                    task.display_params = f"{original_file_name} with arguments {task.args.get_arg('args')}"

                else:
                    raise Exception("Failed to fetch uploaded file from Mythic (ID: {})".format(task.args.get_arg("file")))
            elif groupName == "Default":
                file_resp = await MythicRPC().execute("get_file",
                                                      task_id=task.id,
                                                      filename=task.args.get_arg("filename"),
                                                      limit_by_callback=False,
                                                      get_contents=True)
                if file_resp.status == MythicRPCStatus.Success:
                    if len(file_resp.response) > 0:
                        original_file_name = file_resp.response[0]["filename"]
                        task.args.add_arg("file", file_resp.response[0]['agent_file_id'])
                        task.args.remove_arg("filename")
                        task.display_params = f"{file_resp.response[0]['filename']} with arguments {task.args.get_arg('args')}."
                    elif len(file_resp.response) == 0:
                        raise Exception("Failed to find the named file. Have you uploaded it before? Did it get deleted?")
                else:
                    raise Exception("Error from Myhtic trying to search files:\n" + str(file_resp.error))
        except Exception as e:
            raise Exception("Error from Mythic: " + str(sys.exc_info()[-1].tb_lineno) + " : " + str(e))
        return task

    async def process_response(self, response: AgentResponse):
        pass
