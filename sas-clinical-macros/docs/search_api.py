#!/usr/bin/env python3
"""
Semantic Search API for SAS Macro Documentation
Provides REST API for searching macro documentation using embeddings
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import pickle
import numpy as np
from sentence_transformers import SentenceTransformer
import faiss
from pathlib import Path

app = Flask(__name__)
CORS(app)

class MacroSearchEngine:
    def __init__(self, embeddings_path: str):
        """Initialize search engine with pre-computed embeddings"""
        with open(embeddings_path, 'rb') as f:
            data = pickle.load(f)
        
        self.embeddings = data['embeddings']
        self.macros = data['macros']
        self.index = faiss.deserialize_index(data['index'])
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
    
    def search(self, query: str, top_k: int = 5):
        """Perform semantic search on macro documentation"""
        # Encode query
        query_embedding = self.model.encode([query])
        
        # Search in FAISS index
        distances, indices = self.index.search(
            np.array(query_embedding, dtype=np.float32), 
            top_k
        )
        
        # Prepare results
        results = []
        for idx, distance in zip(indices[0], distances[0]):
            if idx < len(self.macros):
                macro = self.macros[idx].copy()
                macro['relevance_score'] = float(1 / (1 + distance))
                results.append(macro)
        
        return results

# Initialize search engine
search_engine = MacroSearchEngine('embeddings.pkl')

@app.route('/api/search', methods=['POST'])
def search():
    """Search endpoint for macro documentation"""
    data = request.json
    query = data.get('query', '')
    top_k = data.get('top_k', 5)
    
    if not query:
        return jsonify({'error': 'Query is required'}), 400
    
    results = search_engine.search(query, top_k)
    return jsonify({'results': results})

@app.route('/api/macros', methods=['GET'])
def list_macros():
    """List all available macros"""
    return jsonify({'macros': search_engine.macros})

@app.route('/api/macro/<name>', methods=['GET'])
def get_macro(name):
    """Get specific macro documentation"""
    for macro in search_engine.macros:
        if macro.get('name') == name:
            return jsonify(macro)
    return jsonify({'error': 'Macro not found'}), 404

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)