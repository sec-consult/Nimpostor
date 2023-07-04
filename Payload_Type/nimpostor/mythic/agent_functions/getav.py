from mythic_payloadtype_container.MythicCommandBase import *
import json

class GetAvArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

class GetAvCommand(CommandBase):
    cmd = "getav"
    needs_admin = False
    help_cmd = "getav"
    description = "List the installed AntiVirus Programs."
    version = 1
    is_exit = False
    is_file_browse = False
    is_process_list = False
    is_download_file = False
    is_remove_file = False
    is_upload_file = False
    author = "@Sobol"
    argument_class = GetAvArguments
    attackmapping = []
    browser_script = BrowserScript(script_name="getav_new", author="@sobol", for_new_ui=True)

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task

    async def process_response(self, response: AgentResponse):
        pass
