# quantum_reflector_wasm.py
# Optimized for Pyodide/WebAssembly execution in the browser

import json
import random
from datetime import datetime

# --- Simplified Core Logic for Client-Side Execution ---

class QuantumReflectorLite:
    def __init__(self):
        self.axiom_definitions = {
            "NSR": "Non-Slavery Rule: No exploitation or coercion",
            "OLF": "One Love First: Cooperation over competition",
            "TFK": "Tutti-Frutti-Karma: Self-correction through consequences"
        }
        
        self.reflection_templates = {
            "NSR": [
                "You ask about {topic}. I wonder: in this situation, who holds power, and how is it being used?",
                "That's an important question about {topic}. What would change if everyone involved had equal voice?"
            ],
            "OLF": [
                "You're exploring {topic}. What if we approached this from a place of cooperation rather than competition?",
                "That question about {topic} resonates. How would 'One Love First' apply here?"
            ],
            "TFK": [
                "You ask about {topic}. How might this decision affect not just today, but seven generations forward?",
                "That's a profound question about {topic}. What legacy does this create?"
            ]
        }

    def _extract_topic(self, query):
        # Simple heuristic topic extraction for WASM efficiency
        words = query.lower().split()
        ignore = {'what', 'why', 'how', 'is', 'are', 'the', 'a', 'an', 'do', 'does'}
        content_words = [w for w in words if w not in ignore]
        return " ".join(content_words[:4]) if content_words else "this matter"

    def _analyze_relevance(self, query):
        q = query.lower()
        # Simplified keyword matching
        scores = {
            "NSR": sum(1 for w in ['power', 'force', 'control', 'free'] if w in q),
            "OLF": sum(1 for w in ['love', 'peace', 'help', 'unity'] if w in q),
            "TFK": sum(1 for w in ['future', 'result', 'karma', 'long'] if w in q)
        }
        # Default to OLF if no clear winner
        if sum(scores.values()) == 0:
            return "OLF"
        return max(scores, key=scores.get)

    def reflect(self, query_json):
        """
        Main entry point called from JavaScript.
        Expects a JSON string: {"query": "user text", "user_id": "..."}
        Returns a JSON string with the reflection response.
        """
        try:
            data = json.loads(query_json)
            query_text = data.get("query", "")
            
            # 1. Analysis
            dominant_axiom = self._analyze_relevance(query_text)
            topic = self._extract_topic(query_text)
            
            # 2. Reflection Generation
            templates = self.reflection_templates.get(dominant_axiom, self.reflection_templates["OLF"])
            reflection_text = random.choice(templates).format(topic=topic)
            
            # 3. Construct Response
            response = {
                "reflected_question": reflection_text,
                "dominant_axiom": dominant_axiom,
                "axiom_definition": self.axiom_definitions[dominant_axiom],
                "timestamp": datetime.now().isoformat(),
                "status": "success"
            }
            return json.dumps(response)
            
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

# --- Global Instance for JS Bridge ---
reflector_instance = QuantumReflectorLite()

def js_bridge_reflect(json_input):
    """Global function exposed to JavaScript"""
    return reflector_instance.reflect(json_input)
