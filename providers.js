const CHAT_P={
  venice    :{label:"Venice",             base:"https://api.venice.ai/api/v1"},
  openrouter:{label:"OpenRouter",         base:"https://api.openrouter.ai/api/v1"},
  groq      :{label:"Groq",               base:"https://api.groq.com/openai/v1"},
  deepseek  :{label:"DeepSeek",           base:"https://api.deepseek.com/v1"},
  together  :{label:"Together",           base:"https://api.together.xyz/v1"},
  ollama    :{label:"Ollama (local)",     base:"http://localhost:11434/v1", nokey:1},
  lmstudio  :{label:"LM Studio (local)",  base:"http://localhost:1234/v1",  nokey:1},
  custom    :{label:"Custom base…",       base:""}
};
const CHAT_ORDER=["venice","openrouter","groq","deepseek","together","ollama","lmstudio","custom"];

const NEG=[
  "worst quality","low quality","lowres","bad anatomy","bad hands","extra digits","fewer digits",
  "fused fingers","missing fingers","extra limbs","deformed","long neck","blurry","out of focus",
  "watermark","signature","username","text","logo","jpeg artifacts",
  "flat color","plain shading","oversmooth skin","plastic skin","doll","3d render","cel shading artifacts",
  "mosaic censoring","bar censor","censorship"
].join(", ");

const TAIL=[
  "detailed face","detailed eyes","detailed skin","shiny skin","subtle shading","soft lighting",
  "depth of field","bokeh","film grain","4k","absurdres","very aesthetic","anime illustration"
].join(", ");

const STYLE_ANCHORS="wlop, krenz cushart, sakimichan";
const LIM={steps:30, maxDim:1280, minDim:256, dimStep:64};

const IMG_P={
  venice:{
    label:"Venice · wai-Illustrious (PNG)",
    build:(base,key,p,S)=>{
      const full=dedupe(p+", "+TAIL);
      const clamp=(v,d)=>{v=Math.round((+v||d)/LIM.dimStep)*LIM.dimStep;
        return Math.max(LIM.minDim,Math.min(LIM.maxDim,v))};
      return {
        url:base.replace(/\/$/,"")+"/image/generate",
        headers:{"Content-Type":"application/json",...(key?{Authorization:"Bearer "+key}:{})},
        body:JSON.stringify({
          safe_mode:false,hide_watermark:true,model:S.im||"wai-Illustrious",
          prompt:full, negative_prompt:NEG,
          width:clamp(S.iw,832), height:clamp(S.ih,1216),
          steps:Math.max(1,Math.min((/wai/i.test(S.im||"wai-Illustrious")?30:50),+S.steps||30)),
          cfg_scale:Math.max(1,Math.min(20,+S.cfg||6.5)),
          format:"png"
        }),
        parse:j=>j.images?.[0]||j.data?.[0]?.b64_json, mime:"image/png"
      };
    }
  },
  veniceQwen:{
    label:"Venice · qwen-image",
    build:(base,key,p,S)=>({
      url:base.replace(/\/$/,"")+"/image/generate",
      headers:{"Content-Type":"application/json",...(key?{Authorization:"Bearer "+key}:{})},
      body:JSON.stringify({
        model:"qwen-image",
        prompt:dedupe(p+", "+TAIL),
        negative_prompt:NEG,
        aspect_ratio:(S.iw>S.ih?"4:3":(S.iw<S.ih?"3:4":"1:1")),
        steps:Math.max(1,Math.min(50,+S.steps||30)),
        cfg_scale:Math.max(1,Math.min(20,+S.cfg||6.5)),
        format:"png"
      }),
      parse:j=>j.images?.[0]||j.data?.[0]?.b64_json, mime:"image/png"
    })
  },
  a1111:{
    label:"A1111 / Forge / RunPod",
    build:(base,key,p,S)=>{
      const full=p+", "+TAIL+", "+STYLE_ANCHORS;
      return {
        url:base.replace(/\/$/,"")+"/sdapi/v1/txt2img",
        headers:{"Content-Type":"application/json",...(key?{Authorization:"Bearer "+key}:{})},
        body:JSON.stringify({
          prompt:full, negative_prompt:NEG,
          width:+S.iw||832, height:+S.ih||1216,
          steps:+S.steps||40, cfg_scale:+S.cfg||6.5,
          sampler_name:"DPM++ 2M Karras", batch_size:1,
          restore_faces:true, enable_hr:false
        }),
        parse:j=>j.images?.[0], mime:"image/png"
      };
    }
  },
  openai:{
    label:"OpenAI images",
    build:(base,key,p,S)=>({
      url:base.replace(/\/$/,"")+"/images/generations",
      headers:{"Content-Type":"application/json",...(key?{Authorization:"Bearer "+key}:{})},
      body:JSON.stringify({model:S.im||"gpt-image-1",prompt:dedupe(p+", "+TAIL),size:"1024x1536",n:1,response_format:"b64_json"}),
      parse:j=>j.data?.[0]?.b64_json, mime:"image/png"
    })
  },
  stability:{
    label:"Stability",
    build:(base,key,p,S)=>({
      url:base.replace(/\/$/,"")+"/v2beta/stable-image/generate/core",
      headers:{"Authorization":"Bearer "+key,"Accept":"application/json"},
      body:JSON.stringify({prompt:p,aspect_ratio:"2:3",negative_prompt:NEG,output_format:"png"}),
      parse:j=>j.image, mime:"image/png"
    })
  }
};
const IMG_ORDER=["venice","veniceQwen","a1111","openai","stability"];

function modelType(m){
  return String(
    m.type ?? m.model_type ?? m.modelType ??
    m.model_spec?.type ?? m.modelSpec?.type ??
    m.constraints?.type ?? ""
  ).toLowerCase();
}
async function listModels(base,key,type){
  const r=await fetch(base.replace(/\/$/,"")+"/models"+(type?"?type="+type:""),{headers:key?{Authorization:"Bearer "+key}:{}});
  if(!r.ok)throw new Error(r.status+" "+(await r.text()).slice(0,180));
  const j=await r.json();
  const all=Array.isArray(j.data)?j.data:(Array.isArray(j)?j:[]);
  const ids=all.map(m=>typeof m==="string"?m:(m.id||m.name||"")).filter(Boolean);
  if(!type)return ids.sort();
  const t=type.toLowerCase();
  const hit=all.filter(m=>modelType(m)===t).map(m=>(m.id||m.name||"")).filter(Boolean);
  if(hit.length)return hit.sort();
  if(t==="image"){
    return all.filter(m=>{const mt=modelType(m);return mt && mt!=="text" && mt!=="embedding"})
              .map(m=>(m.id||m.name||"")).filter(Boolean).sort();
  }
  return ids;
}

async function streamChat({base,key,model,messages,temp,onToken,signal}){
  const r=await fetch(base.replace(/\/$/,"")+"/chat/completions",{
    method:"POST",signal,
    headers:{"Content-Type":"application/json",...(key?{Authorization:"Bearer "+key}:{})},
    body:JSON.stringify({model,messages,temperature:temp,max_tokens:420,stream:true})
  });
  if(!r.ok)throw new Error(r.status+" "+(await r.text()).slice(0,200));
  const rd=r.body.getReader(),dec=new TextDecoder();let buf="",full="";
  while(true){
    const {done,value}=await rd.read();if(done)break;
    buf+=dec.decode(value,{stream:true});
    const lines=buf.split("\n");buf=lines.pop();
    for(const ln of lines){
      const s=ln.trim();if(!s.startsWith("data:"))continue;
      const d=s.slice(5).trim();if(d==="[DONE]")continue;
      try{const j=JSON.parse(d);const t=j.choices?.[0]?.delta?.content||"";
        if(t){full+=t;onToken&&onToken(t)}}catch{}
    }
  }
  return full;
}
