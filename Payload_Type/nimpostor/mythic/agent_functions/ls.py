from mythic_payloadtype_container.MythicCommandBase import *
import json

class LsArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="path",
                type=ParameterType.String,
                description="Path to list.",
                default_value=".",
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) > 0:
            if self.command_line[0] == "{":
                self.load_args_from_json_string(self.command_line)
            else:
                self.add_arg("path", self.command_line)

class LsCommand(CommandBase):
    cmd = "ls"
    needs_admin = False
    help_cmd = "ls [directory]"
    description = "List files in directory."
    version = 1
    is_exit = False
    is_file_browse = True
    is_process_list = False
    is_download_file = True
    is_remove_file = False
    is_upload_file = False
    supported_ui_features = ["file_browser:list"]
    author = "@Sobol"
    argument_class = LsArguments
    attackmapping = ["T1083"]
    browser_script = BrowserScript(script_name="ls_new", author="@sobol", for_new_ui=True)

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task

    async def process_response(self, response: AgentResponse):
        pass
