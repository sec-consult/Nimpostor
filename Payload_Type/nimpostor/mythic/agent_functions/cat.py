from mythic_payloadtype_container.MythicCommandBase import *
import json

class CatArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="path",
                type=ParameterType.String,
                description="path to file (no quotes required)",
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) > 0:
            if self.command_line[0] == "{":
                self.load_args_from_json_string(self.command_line)
            else:
                self.add_arg("path", self.command_line)

class CatCommand(CommandBase):
    cmd = "cat"
    needs_admin = False
    help_cmd = "cat /path/to/file"
    description = "Read the contents of a file and display it to the user. No need for quotes and relative paths are fine"
    version = 1
    is_exit = False
    is_file_browse = False
    is_process_list = False
    is_download_file = False
    is_remove_file = False
    is_upload_file = False
    supported_ui_features = ["cat"]
    author = "@Sobol"
    argument_class = CatArguments
    attackmapping = ["T1005", "T1552.001"]

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task

    async def process_response(self, response: AgentResponse):
        pass
