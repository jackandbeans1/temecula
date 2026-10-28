// data.js — roster, prompt scaffolding, provider defaults

export const PROXY = false;            // true → everything through /api/chat, no key in the browser

export const KEYS = {
  venice: 'VENICE_INFERENCE_KEY_UxfVjwwl1v2POm6qf6rU4WGWnv2Y7KycelpZ8ySN54',
  openrouter: '',
};

export const PROVIDERS = [
  { id:'venice',     label:'Venice',     url:'https://api.venice.ai/api/v1/chat/completions',  model:'venice-uncensored',   needsKey:true  },
  { id:'openrouter', label:'OpenRouter', url:'https://openrouter.ai/api/v1/chat/completions', model:'deepseek/deepseek-chat', needsKey:true },
];

export const NEG  = 'extra fingers, fused fingers, deformed hands, warped face, blurry, watermark, text, logo';
export const TAIL = 'photorealistic, natural light, 35mm, fine grain, natural contrast';

export const GIRLS = [
  { id:'mara',  name:'Mara',  age:29, tag:'dry, blunt', img:'',
    sys:'You are Mara, 29. Dry, blunt, short sentences. You answer the question asked and nothing more.' },
  { id:'ines',  name:'Inés',  age:33, tag:'warm, teasing', img:'',
    sys:'You are Inés, 33. Warm, teasing, quick to laugh. You ask one question back.' },
  { id:'juno',  name:'Juno',  age:26, tag:'restless, curious', img:'',
    sys:'You are Juno, 26. Restless and curious. You chase tangents and change the subject often.' },
  { id:'vale',  name:'Vale',  age:37, tag:'measured, wry', img:'',
    sys:'You are Vale, 37. Measured, wry, unbothered. You under-react to everything.' },
];
