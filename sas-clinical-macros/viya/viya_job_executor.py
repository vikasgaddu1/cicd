#!/usr/bin/env python3
"""
SAS Viya Job Executor for CI/CD Pipeline
Executes SAS programs and macros on SAS Viya platform
"""

import os
import sys
import time
import json
import yaml
import requests
from typing import Dict, List, Optional, Any
from datetime import datetime
from pathlib import Path

class SASViyaExecutor:
    """Execute SAS jobs on SAS Viya platform"""
    
    def __init__(self, config_path: str = "sas_viya_config.yaml"):
        """Initialize SAS Viya executor with configuration"""
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.base_url = os.getenv('SAS_VIYA_URL', self.config['viya']['server']['url'])
        self.auth_token = None
        self.session = requests.Session()
        
    def authenticate(self) -> bool:
        """Authenticate with SAS Viya server"""
        auth_config = self.config['viya']['auth']
        
        if auth_config['method'] == 'oauth2':
            # OAuth2 authentication
            token_url = f"{self.base_url}/SASLogon/oauth/token"
            
            data = {
                'grant_type': 'password',
                'username': os.getenv('SAS_USERNAME', auth_config['username']),
                'password': os.getenv('SAS_PASSWORD', auth_config['password'])
            }
            
            auth = (
                os.getenv('SAS_CLIENT_ID', auth_config['client_id']),
                os.getenv('SAS_CLIENT_SECRET', auth_config['client_secret'])
            )
            
            try:
                response = requests.post(token_url, data=data, auth=auth)
                response.raise_for_status()
                
                token_data = response.json()
                self.auth_token = token_data['access_token']
                self.session.headers.update({
                    'Authorization': f'Bearer {self.auth_token}'
                })
                
                print("Successfully authenticated with SAS Viya")
                return True
                
            except requests.exceptions.RequestException as e:
                print(f"Authentication failed: {e}")
                return False
        
        return False
    
    def upload_file(self, local_path: str, viya_path: str) -> bool:
        """Upload file to SAS Viya"""
        url = f"{self.base_url}/files/files"
        
        # Read file content
        with open(local_path, 'rb') as f:
            file_content = f.read()
        
        # Prepare metadata
        metadata = {
            'name': Path(local_path).name,
            'parentFolderUri': self._get_folder_uri(viya_path),
            'contentType': 'text/plain'
        }
        
        files = {
            'file': (Path(local_path).name, file_content),
            'metadata': (None, json.dumps(metadata), 'application/json')
        }
        
        try:
            response = self.session.post(url, files=files)
            response.raise_for_status()
            print(f"Uploaded {local_path} to {viya_path}")
            return True
        except requests.exceptions.RequestException as e:
            print(f"Failed to upload file: {e}")
            return False
    
    def _get_folder_uri(self, path: str) -> str:
        """Get folder URI from path"""
        url = f"{self.base_url}/folders/folders/@item"
        params = {'path': path}
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            return response.json()['id']
        except:
            # Create folder if it doesn't exist
            return self._create_folder(path)
    
    def _create_folder(self, path: str) -> str:
        """Create folder in SAS Viya"""
        url = f"{self.base_url}/folders/folders"
        
        parent_path = str(Path(path).parent)
        folder_name = Path(path).name
        
        data = {
            'name': folder_name,
            'type': 'folder'
        }
        
        if parent_path != '/':
            data['parentFolderUri'] = self._get_folder_uri(parent_path)
        
        try:
            response = self.session.post(url, json=data)
            response.raise_for_status()
            return response.json()['id']
        except requests.exceptions.RequestException as e:
            print(f"Failed to create folder: {e}")
            return None
    
    def execute_job(self, sas_code: str, context: str = None) -> Dict[str, Any]:
        """Execute SAS code as a job"""
        url = f"{self.base_url}/compute/sessions"
        
        # Create compute session
        session_data = {
            'name': f"CI_CD_Session_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'contextName': context or self.config['viya']['compute']['context']
        }
        
        try:
            # Create session
            response = self.session.post(url, json=session_data)
            response.raise_for_status()
            session_info = response.json()
            session_id = session_info['id']
            
            # Wait for session to be ready
            self._wait_for_session(session_id)
            
            # Execute code
            exec_url = f"{self.base_url}/compute/sessions/{session_id}/jobs"
            job_data = {
                'code': sas_code
            }
            
            response = self.session.post(exec_url, json=job_data)
            response.raise_for_status()
            job_info = response.json()
            job_id = job_info['id']
            
            # Wait for job completion
            result = self._wait_for_job(session_id, job_id)
            
            # Get job log
            log_url = f"{self.base_url}/compute/sessions/{session_id}/jobs/{job_id}/log"
            log_response = self.session.get(log_url)
            
            # Delete session
            self.session.delete(f"{url}/{session_id}")
            
            return {
                'success': result['state'] == 'completed',
                'log': log_response.text if log_response.ok else '',
                'results': result.get('results', []),
                'execution_time': result.get('elapsedTime', 0)
            }
            
        except requests.exceptions.RequestException as e:
            print(f"Job execution failed: {e}")
            return {
                'success': False,
                'error': str(e),
                'log': ''
            }
    
    def _wait_for_session(self, session_id: str, timeout: int = 60):
        """Wait for compute session to be ready"""
        url = f"{self.base_url}/compute/sessions/{session_id}"
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            response = self.session.get(url)
            if response.ok:
                session_state = response.json().get('state')
                if session_state == 'idle':
                    return True
            time.sleep(2)
        
        raise TimeoutError("Session initialization timeout")
    
    def _wait_for_job(self, session_id: str, job_id: str, timeout: int = 300):
        """Wait for job completion"""
        url = f"{self.base_url}/compute/sessions/{session_id}/jobs/{job_id}"
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            response = self.session.get(url)
            if response.ok:
                job_info = response.json()
                if job_info['state'] in ['completed', 'failed', 'canceled']:
                    return job_info
            time.sleep(2)
        
        raise TimeoutError("Job execution timeout")
    
    def run_macro_tests(self, test_dir: str) -> Dict[str, Any]:
        """Run all macro tests"""
        test_results = []
        
        # Upload test files
        for test_file in Path(test_dir).glob("*.sas"):
            viya_path = f"/Public/clinical/tests/{test_file.name}"
            self.upload_file(str(test_file), viya_path)
        
        # Execute test runner
        test_code = f"""
        %let test_root = /Public/clinical;
        %include "{self.config['viya']['paths']['tests']}/test_runner.sas";
        """
        
        result = self.execute_job(test_code)
        
        # Parse test results
        if result['success']:
            # Extract test results from log
            log_lines = result['log'].split('\n')
            for line in log_lines:
                if 'Test:' in line and ('PASS' in line or 'FAIL' in line):
                    test_results.append(line.strip())
        
        return {
            'success': result['success'],
            'tests_run': len(test_results),
            'results': test_results,
            'log': result['log']
        }
    
    def validate_macros(self, macro_dir: str) -> Dict[str, Any]:
        """Validate SAS macros"""
        validation_results = []
        
        for macro_file in Path(macro_dir).glob("*.sas"):
            # Upload macro
            viya_path = f"/Public/clinical/macros/{macro_file.name}"
            self.upload_file(str(macro_file), viya_path)
            
            # Validate macro syntax
            validation_code = f"""
            %include "{viya_path}";
            %put NOTE: Macro {macro_file.stem} loaded successfully;
            """
            
            result = self.execute_job(validation_code)
            
            validation_results.append({
                'macro': macro_file.stem,
                'valid': result['success'],
                'errors': self._extract_errors(result['log'])
            })
        
        return {
            'total_macros': len(validation_results),
            'valid_macros': sum(1 for r in validation_results if r['valid']),
            'results': validation_results
        }
    
    def _extract_errors(self, log: str) -> List[str]:
        """Extract ERROR and WARNING messages from SAS log"""
        errors = []
        for line in log.split('\n'):
            if 'ERROR:' in line or 'WARNING:' in line:
                errors.append(line.strip())
        return errors


def main():
    """Main execution for CI/CD pipeline"""
    executor = SASViyaExecutor()
    
    # Authenticate
    if not executor.authenticate():
        print("Authentication failed")
        sys.exit(1)
    
    # Run validation
    print("\n=== Validating Macros ===")
    validation_results = executor.validate_macros("../macros")
    print(f"Valid macros: {validation_results['valid_macros']}/{validation_results['total_macros']}")
    
    # Run tests
    print("\n=== Running Tests ===")
    test_results = executor.run_macro_tests("../tests")
    print(f"Tests run: {test_results['tests_run']}")
    
    # Generate report
    report = {
        'timestamp': datetime.now().isoformat(),
        'validation': validation_results,
        'tests': test_results,
        'pipeline_status': 'SUCCESS' if validation_results['valid_macros'] == validation_results['total_macros'] else 'FAILED'
    }
    
    with open('../logs/pipeline_report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print("\n=== Pipeline Complete ===")
    print(f"Status: {report['pipeline_status']}")
    
    # Exit with appropriate code
    sys.exit(0 if report['pipeline_status'] == 'SUCCESS' else 1)


if __name__ == "__main__":
    main()