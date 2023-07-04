from mythic_payloadtype_container.MythicCommandBase import *
import json

class ShellArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

class ShellCommand(CommandBase):
    cmd = "shell"
    needs_admin = False
    help_cmd = "shell <command>"
    description = "Execute a shell command with 'cmd.exe /r' if on Windows or 'sh -c' if on Linux."
    version = 1
    is_exit = False
    is_file_browse = False
    is_process_list = False
    is_download_file = False
    is_remove_file = False
    is_upload_file = False
    author = "@Sobol"
    argument_class = ShellArguments
    attackmapping = ["T1059"]

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task

    async def process_response(self, response: AgentResponse):
        pass