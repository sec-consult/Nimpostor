from mythic_payloadtype_container.MythicCommandBase import *
import json

class CurlArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="url",
                type=ParameterType.String,
                description="URL to request.",
                default_value="https://www.google.com",
                parameter_group_info=[
                    ParameterGroupInfo(ui_position=1)
                ]
            ),
            CommandParameter(
                name="method",
                type=ParameterType.ChooseOne,
                description="Type of request.",
                choices=["GET", "POST"],
                parameter_group_info=[
                    ParameterGroupInfo(ui_position=2)
                ]
            ),
            CommandParameter(
                name="headers",
                type=ParameterType.String,
                description="base64 encoded json with headers.",
                parameter_group_info=[
                    ParameterGroupInfo(ui_position=3, required=False)
                ]
            ),
            CommandParameter(
                name="body",
                type=ParameterType.String,
                description="base64 encoded body.",
                parameter_group_info=[
                    ParameterGroupInfo(ui_position=4, required=False)
                ]
            ),
        ]

    async def parse_arguments(self):
        self.load_args_from_json_string(self.command_line)

class CurlCommand(CommandBase):
    cmd = "curl"
    needs_admin = False
    help_cmd = 'curl { "url": "https://www.google.com", "method": "GET", "headers": "", "body":"" }'
    description = "Execute a single web request."
    version = 1
    is_exit = False
    is_file_browse = False
    is_process_list = False
    is_download_file = False
    is_remove_file = False
    is_upload_file = False
    author = "@Sobol"
    argument_class = CurlArguments
    attackmapping = []

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task

    async def process_response(self, response: AgentResponse):
        pass
