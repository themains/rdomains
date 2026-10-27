import json
from piedomains.text import TextClassifier, DEFAULT_TEXT_MODEL, DEFAULT_TEXT_REVISION
from piedomains.text_processor import TextProcessor
from piedomains.config import get_config
f = json.load(open('/tmp/rdomains-extraction-fixture.json'))
a = TextProcessor.process_html_to_text(f['html'])
b = TextProcessor.process_html_to_text(f['r_text'])
print('extractor', get_config().get('extractor'))
print('direct_words',len(a.split()),'R_bridge_words',len(b.split()))
print('direct_prefix',a[:180]); print('R_bridge_prefix',b[:180])
c=TextClassifier(cache_dir='/tmp/rdomains-audit-model-cache'); c.load_models()
for name,t in [('direct',a),('R_bridge',b)]:
    p=c._predict_text(c._model_input('example.com',t))
    print(name, p['text_label'], p['text_prob'],p['text_categories'])
