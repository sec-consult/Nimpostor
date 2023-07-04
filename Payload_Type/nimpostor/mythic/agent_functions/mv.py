from mythic_payloadtype_container.MythicCommandBase import *
import json

class MvArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="source",
                type=ParameterType.String,
                description="Source file to move.",
            ),
            CommandParameter(
                name="destination",
                type=ParameterType.String,
                description="Destination to move the file to.",
            ),
        ]

    async def parse_arguments(self):
        self.load_args_from_json_string(self.command_line)

class MvCommand(CommandBase):
    cmd = "mv"
    needs_admin = False
    help_cmd = "mv <file> <destination>"
    description = "Move a file from one location to another"
    version = 1
    is_exit = False
    is_file_browse = False
    is_process_list = False
    is_download_file = False
    is_remove_file = False
    is_upload_file = False
    author = "@Sobol"
    argument_class = MvArguments
    attackmapping = []

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task

    async def process_response(self, response: AgentResponse):
        pass