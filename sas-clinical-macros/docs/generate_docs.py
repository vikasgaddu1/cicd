#!/usr/bin/env python3
"""
SAS Macro Documentation Generator with Semantic Search
Parses YAML headers from SAS macros and generates searchable documentation
"""

import os
import re
import yaml
import json
from pathlib import Path
from typing import Dict, List, Any
import numpy as np
from sentence_transformers import SentenceTransformer
import faiss
import pickle

class SASMacroDocGenerator:
    def __init__(self, macro_dir: str, output_dir: str):
        self.macro_dir = Path(macro_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Initialize embedding model for semantic search
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
        self.macros = []
        self.embeddings = None
        self.index = None
        
    def extract_yaml_header(self, filepath: Path) -> Dict[str, Any]:
        """Extract YAML header from SAS macro file"""
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Find YAML block between --- markers
        yaml_pattern = r'/\*+\s*\n---\n(.*?)\n---\n'
        match = re.search(yaml_pattern, content, re.DOTALL)
        
        if match:
            yaml_content = match.group(1)
            try:
                return yaml.safe_load(yaml_content)
            except yaml.YAMLError as e:
                print(f"Error parsing YAML in {filepath}: {e}")
                return None
        return None
    
    def process_macros(self):
        """Process all SAS macro files and extract documentation"""
        for sas_file in self.macro_dir.glob("*.sas"):
            print(f"Processing {sas_file.name}...")
            doc = self.extract_yaml_header(sas_file)
            if doc:
                doc['filepath'] = str(sas_file)
                self.macros.append(doc)
    
    def create_embeddings(self):
        """Create embeddings for semantic search"""
        if not self.macros:
            return
        
        # Create text representations for embedding
        texts = []
        for macro in self.macros:
            # Combine relevant fields for embedding
            text_parts = [
                macro.get('name', ''),
                macro.get('description', ''),
                macro.get('category', ''),
                ' '.join(macro.get('tags', [])),
            ]
            
            # Add parameter descriptions
            for param in macro.get('parameters', []):
                text_parts.append(f"{param.get('name', '')} {param.get('description', '')}")
            
            texts.append(' '.join(text_parts))
        
        # Generate embeddings
        print("Generating embeddings for semantic search...")
        self.embeddings = self.model.encode(texts)
        
        # Create FAISS index for efficient similarity search
        dimension = self.embeddings.shape[1]
        self.index = faiss.IndexFlatL2(dimension)
        self.index.add(np.array(self.embeddings, dtype=np.float32))
        
        # Save embeddings and index
        with open(self.output_dir / 'embeddings.pkl', 'wb') as f:
            pickle.dump({
                'embeddings': self.embeddings,
                'macros': self.macros,
                'index': faiss.serialize_index(self.index)
            }, f)
    
    def generate_html_docs(self):
        """Generate HTML documentation"""
        html_template = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SAS Macro Documentation</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; margin: 0; padding: 0; background: #f5f5f5; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 2rem; }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 2rem; }}
        .search-box {{ background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 2rem; }}
        .search-input {{ width: 100%; padding: 0.75rem; font-size: 1rem; border: 2px solid #e0e0e0; border-radius: 4px; }}
        .macro-card {{ background: white; padding: 1.5rem; margin-bottom: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .macro-title {{ color: #333; font-size: 1.5rem; margin-bottom: 0.5rem; }}
        .macro-desc {{ color: #666; margin-bottom: 1rem; }}
        .tag {{ display: inline-block; background: #e3f2fd; color: #1976d2; padding: 0.25rem 0.5rem; border-radius: 4px; margin-right: 0.5rem; font-size: 0.875rem; }}
        .param-table {{ width: 100%; border-collapse: collapse; margin-top: 1rem; }}
        .param-table th {{ background: #f5f5f5; padding: 0.5rem; text-align: left; border-bottom: 2px solid #e0e0e0; }}
        .param-table td {{ padding: 0.5rem; border-bottom: 1px solid #e0e0e0; }}
        .example-code {{ background: #f5f5f5; padding: 1rem; border-radius: 4px; overflow-x: auto; font-family: 'Courier New', monospace; }}
        .category {{ color: #9c27b0; font-weight: 500; }}
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1>SAS Clinical Macro Library</h1>
            <p>Automated documentation for clinical programming macros</p>
        </div>
    </div>
    
    <div class="container">
        <div class="search-box">
            <input type="text" class="search-input" id="searchInput" placeholder="Search macros by name, description, or tags..." onkeyup="searchMacros()">
            <div id="searchResults"></div>
        </div>
        
        <div id="macroList">
            {macro_cards}
        </div>
    </div>
    
    <script>
        const macros = {macros_json};
        
        function searchMacros() {{
            const query = document.getElementById('searchInput').value.toLowerCase();
            const macroList = document.getElementById('macroList');
            
            if (query.length < 2) {{
                // Show all macros
                displayAllMacros();
                return;
            }}
            
            // Filter macros based on query
            const filtered = macros.filter(macro => {{
                const searchText = [
                    macro.name,
                    macro.description,
                    macro.category,
                    ...(macro.tags || []),
                    ...(macro.parameters || []).map(p => p.name + ' ' + p.description)
                ].join(' ').toLowerCase();
                
                return searchText.includes(query);
            }});
            
            displayMacros(filtered);
        }}
        
        function displayMacros(macroList) {{
            const container = document.getElementById('macroList');
            container.innerHTML = macroList.map(macro => createMacroCard(macro)).join('');
        }}
        
        function displayAllMacros() {{
            displayMacros(macros);
        }}
        
        function createMacroCard(macro) {{
            const params = (macro.parameters || []).map(p => `
                <tr>
                    <td><strong>${{p.name}}</strong></td>
                    <td>${{p.type}}</td>
                    <td>${{p.required ? 'Yes' : 'No'}}</td>
                    <td>${{p.description}}</td>
                    <td>${{p.default || '-'}}</td>
                </tr>
            `).join('');
            
            const tags = (macro.tags || []).map(t => `<span class="tag">${{t}}</span>`).join('');
            
            const examples = (macro.examples || []).map(ex => `
                <div>
                    <p>${{ex.description}}</p>
                    <pre class="example-code">${{ex.code}}</pre>
                </div>
            `).join('');
            
            return `
                <div class="macro-card">
                    <h2 class="macro-title">%${{macro.name}}</h2>
                    <p class="macro-desc">${{macro.description}}</p>
                    <p><span class="category">Category:</span> ${{macro.category}}</p>
                    <div>${{tags}}</div>
                    
                    <h3>Parameters</h3>
                    <table class="param-table">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Type</th>
                                <th>Required</th>
                                <th>Description</th>
                                <th>Default</th>
                            </tr>
                        </thead>
                        <tbody>${{params}}</tbody>
                    </table>
                    
                    ${{examples ? '<h3>Examples</h3>' + examples : ''}}
                </div>
            `;
        }}
    </script>
</body>
</html>'''
        
        # Generate macro cards HTML
        macro_cards = []
        for macro in self.macros:
            card = self._create_macro_card_html(macro)
            macro_cards.append(card)
        
        # Generate final HTML
        html_content = html_template.format(
            macro_cards=''.join(macro_cards),
            macros_json=json.dumps(self.macros)
        )
        
        # Write HTML file
        output_file = self.output_dir / 'index.html'
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        print(f"Documentation generated: {output_file}")
    
    def _create_macro_card_html(self, macro: Dict) -> str:
        """Create HTML for a single macro card"""
        # Parameters table
        params_html = ""
        if macro.get('parameters'):
            rows = []
            for param in macro['parameters']:
                row = f'''
                <tr>
                    <td><strong>{param.get('name', '')}</strong></td>
                    <td>{param.get('type', '')}</td>
                    <td>{'Yes' if param.get('required') else 'No'}</td>
                    <td>{param.get('description', '')}</td>
                    <td>{param.get('default', '-')}</td>
                </tr>'''
                rows.append(row)
            
            params_html = f'''
            <h3>Parameters</h3>
            <table class="param-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Type</th>
                        <th>Required</th>
                        <th>Description</th>
                        <th>Default</th>
                    </tr>
                </thead>
                <tbody>{''.join(rows)}</tbody>
            </table>'''
        
        # Tags
        tags_html = ''
        if macro.get('tags'):
            tags = ['<span class="tag">{}</span>'.format(tag) for tag in macro['tags']]
            tags_html = ' '.join(tags)
        
        # Examples
        examples_html = ''
        if macro.get('examples'):
            examples = []
            for ex in macro['examples']:
                example = f'''
                <div>
                    <p>{ex.get('description', '')}</p>
                    <pre class="example-code">{ex.get('code', '')}</pre>
                </div>'''
                examples.append(example)
            examples_html = '<h3>Examples</h3>' + ''.join(examples)
        
        return f'''
        <div class="macro-card" id="{macro.get('name', '')}">
            <h2 class="macro-title">%{macro.get('name', '')}</h2>
            <p class="macro-desc">{macro.get('description', '')}</p>
            <p><span class="category">Category:</span> {macro.get('category', '')}</p>
            <div>{tags_html}</div>
            {params_html}
            {examples_html}
        </div>'''
    
    def generate_markdown_docs(self):
        """Generate Markdown documentation"""
        md_content = "# SAS Clinical Macro Library\n\n"
        md_content += "Automated documentation for clinical programming macros\n\n"
        md_content += "## Table of Contents\n\n"
        
        # TOC
        for macro in self.macros:
            md_content += f"- [{macro['name']}](#{macro['name']})\n"
        
        md_content += "\n---\n\n"
        
        # Macro details
        for macro in self.macros:
            md_content += f"## {macro['name']}\n\n"
            md_content += f"{macro.get('description', '')}\n\n"
            md_content += f"**Category:** {macro.get('category', '')}\n\n"
            
            if macro.get('tags'):
                md_content += f"**Tags:** {', '.join(macro['tags'])}\n\n"
            
            # Parameters
            if macro.get('parameters'):
                md_content += "### Parameters\n\n"
                md_content += "| Name | Type | Required | Description | Default |\n"
                md_content += "|------|------|----------|-------------|----------|\n"
                for param in macro['parameters']:
                    md_content += f"| {param.get('name', '')} | {param.get('type', '')} | "
                    md_content += f"{'Yes' if param.get('required') else 'No'} | "
                    md_content += f"{param.get('description', '')} | {param.get('default', '-')} |\n"
                md_content += "\n"
            
            # Examples
            if macro.get('examples'):
                md_content += "### Examples\n\n"
                for ex in macro['examples']:
                    md_content += f"{ex.get('description', '')}\n\n"
                    md_content += f"```sas\n{ex.get('code', '')}\n```\n\n"
            
            md_content += "---\n\n"
        
        # Write markdown file
        output_file = self.output_dir / 'README.md'
        with open(output_file, 'w') as f:
            f.write(md_content)
        
        print(f"Markdown documentation generated: {output_file}")
    
    def run(self):
        """Run the documentation generation process"""
        print("Starting SAS Macro Documentation Generation...")
        self.process_macros()
        
        if self.macros:
            self.create_embeddings()
            self.generate_html_docs()
            self.generate_markdown_docs()
            print(f"Successfully processed {len(self.macros)} macros")
        else:
            print("No macros found with YAML headers")


if __name__ == "__main__":
    generator = SASMacroDocGenerator(
        macro_dir="../macros",
        output_dir="../docs"
    )
    generator.run()