(function dartProgram(){function copyProperties(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
b[q]=a[q]}}function mixinPropertiesHard(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
if(!b.hasOwnProperty(q)){b[q]=a[q]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var s=function(){}
s.prototype={p:{}}
var r=new s()
if(!(Object.getPrototypeOf(r)&&Object.getPrototypeOf(r).p===s.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var q=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(q))return true}}catch(p){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var s=Object.create(b.prototype)
copyProperties(a.prototype,s)
a.prototype=s}}function inheritMany(a,b){for(var s=0;s<b.length;s++){inherit(b[s],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){var r=d()
if(a[b]!==s){A.rm(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.d(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.mc(b)
return new s(c,this)}:function(){if(s===null)s=A.mc(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.mc(a).prototype
return s}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var s=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var r=staticTearOffGetter(s)
a[b]=r}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var s=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var r=instanceTearOffGetter(c,s)
a[b]=r}function setOrUpdateInterceptorsByTag(a){var s=v.interceptorsByTag
if(!s){v.interceptorsByTag=a
return}copyProperties(a,s)}function setOrUpdateLeafTags(a){var s=v.leafTags
if(!s){v.leafTags=a
return}copyProperties(a,s)}function updateTypes(a){var s=v.types
var r=s.length
s.push.apply(s,a)
return r}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var s=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},r=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:s(0,0,null,["$0"],0),_instance_1u:s(0,1,null,["$1"],0),_instance_2u:s(0,2,null,["$2"],0),_instance_0i:s(1,0,null,["$0"],0),_instance_1i:s(1,1,null,["$1"],0),_instance_2i:s(1,2,null,["$2"],0),_static_0:r(0,null,["$0"],0),_static_1:r(1,null,["$1"],0),_static_2:r(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
mh(a,b,c,d){return{i:a,p:b,e:c,x:d}},
md(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.mf==null){A.r3()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.n(A.n5("Return interceptor for "+A.z(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.kw
if(o==null)o=$.kw=A.la(n)
p=q[o]}if(p!=null)return p
p=A.r8(a)
if(p!=null)return p
if(typeof a=="function")return B.eT
s=Object.getPrototypeOf(a)
if(s==null)return B.bA
if(s===Object.prototype)return B.bA
if(typeof q=="function"){o=$.kw
if(o==null)o=$.kw=A.la(n)
Object.defineProperty(q,o,{value:B.aS,enumerable:false,writable:true,configurable:true})
return B.aS}return B.aS},
mE(a,b){if(a<0||a>4294967295)throw A.n(A.aY(a,0,4294967295,"length",null))
return J.oW(new Array(a),b)},
mF(a,b){if(a<0)throw A.n(A.df("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("o<0>"))},
eC(a,b){if(a<0)throw A.n(A.df("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("o<0>"))},
oW(a,b){var s=A.d(a,b.j("o<0>"))
s.$flags=1
return s},
oX(a,b){var s=t.bP
return J.mn(s.a(a),s.a(b))},
mG(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
oY(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.mG(r))break;++b}return b},
oZ(a,b){var s,r,q
for(s=a.length;b>0;b=r){r=b-1
if(!(r<s))return A.b(a,r)
q=a.charCodeAt(r)
if(q!==32&&q!==13&&!J.mG(q))break}return b},
cJ(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.dt.prototype
return J.eE.prototype}if(typeof a=="string")return J.cs.prototype
if(a==null)return J.du.prototype
if(typeof a=="boolean")return J.eD.prototype
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.c6.prototype
if(typeof a=="symbol")return J.dx.prototype
if(typeof a=="bigint")return J.dv.prototype
return a}if(a instanceof A.N)return a
return J.md(a)},
ae(a){if(typeof a=="string")return J.cs.prototype
if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.c6.prototype
if(typeof a=="symbol")return J.dx.prototype
if(typeof a=="bigint")return J.dv.prototype
return a}if(a instanceof A.N)return a
return J.md(a)},
a5(a){if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.c6.prototype
if(typeof a=="symbol")return J.dx.prototype
if(typeof a=="bigint")return J.dv.prototype
return a}if(a instanceof A.N)return a
return J.md(a)},
qY(a){if(typeof a=="number")return J.cr.prototype
if(a==null)return a
if(!(a instanceof A.N))return J.cC.prototype
return a},
qZ(a){if(typeof a=="number")return J.cr.prototype
if(typeof a=="string")return J.cs.prototype
if(a==null)return a
if(!(a instanceof A.N))return J.cC.prototype
return a},
aQ(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.cJ(a).Y(a,b)},
ml(a,b){if(typeof a=="number"&&typeof b=="number")return a-b
return J.qY(a).U(a,b)},
dc(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.r7(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.ae(a).i(a,b)},
lM(a,b,c){return J.a5(a).h(a,b,c)},
b3(a,b){return J.a5(a).k(a,b)},
mm(a,b){return J.a5(a).B(a,b)},
ok(a,b){return J.a5(a).b2(a,b)},
mn(a,b){return J.qZ(a).N(a,b)},
fR(a,b){return J.a5(a).K(a,b)},
ol(a,b,c,d){return J.a5(a).P(a,b,c,d)},
bZ(a){return J.a5(a).gu(a)},
aR(a){return J.cJ(a).gL(a)},
mo(a){return J.ae(a).gG(a)},
om(a){return J.ae(a).ga0(a)},
a0(a){return J.a5(a).gq(a)},
lN(a){return J.a5(a).gF(a)},
at(a){return J.ae(a).gn(a)},
on(a){return J.a5(a).gcN(a)},
oo(a){return J.cJ(a).gS(a)},
aC(a,b,c){return J.a5(a).aM(a,b,c)},
op(a,b){return J.ae(a).sn(a,b)},
mp(a,b){return J.a5(a).aa(a,b)},
dd(a){return J.cJ(a).t(a)},
eA:function eA(){},
eD:function eD(){},
du:function du(){},
dw:function dw(){},
c7:function c7(){},
f0:function f0(){},
cC:function cC(){},
c6:function c6(){},
dv:function dv(){},
dx:function dx(){},
o:function o(a){this.$ti=a},
eB:function eB(){},
iP:function iP(a){this.$ti=a},
ch:function ch(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
cr:function cr(){},
dt:function dt(){},
eE:function eE(){},
cs:function cs(){}},A={lQ:function lQ(){},
mu(a,b,c){if(t.Y.b(a))return new A.dX(a,b.j("@<0>").A(c).j("dX<1,2>"))
return new A.ci(a,b.j("@<0>").A(c).j("ci<1,2>"))},
mI(a){return new A.eK("Field '"+a+"' has been assigned during initialization.")},
bR(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
jO(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
cI(a,b,c){return a},
mg(a){var s,r
for(s=$.b1.length,r=0;r<s;++r)if(a===$.b1[r])return!0
return!1},
c9(a,b,c,d){A.cZ(b,"start")
if(c!=null){A.cZ(c,"end")
if(b>c)A.bs(A.aY(b,0,c,"start",null))}return new A.dR(a,b,c,d.j("dR<0>"))},
lT(a,b,c,d){if(t.Y.b(a))return new A.co(a,b,c.j("@<0>").A(d).j("co<1,2>"))
return new A.aF(a,b,c.j("@<0>").A(d).j("aF<1,2>"))},
n1(a,b,c){if(t.Y.b(a)){A.kK(b)
return void 1}A.kK(b)
return void 1},
kK(a){A.oq(a,"count",t.S)},
ak(){return new A.dQ("No element")},
cc:function cc(){},
dh:function dh(a,b){this.a=a
this.$ti=b},
ci:function ci(a,b){this.a=a
this.$ti=b},
dX:function dX(a,b){this.a=a
this.$ti=b},
dW:function dW(){},
a9:function a9(a,b){this.a=a
this.$ti=b},
eK:function eK(a){this.a=a},
jC:function jC(){},
B:function B(){},
w:function w(){},
dR:function dR(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aV:function aV(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aF:function aF(a,b,c){this.a=a
this.b=b
this.$ti=c},
co:function co(a,b,c){this.a=a
this.b=b
this.$ti=c},
dD:function dD(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
u:function u(a,b,c){this.a=a
this.b=b
this.$ti=c},
A:function A(a,b,c){this.a=a
this.b=b
this.$ti=c},
dU:function dU(a,b,c){this.a=a
this.b=b
this.$ti=c},
dL:function dL(a,b,c){this.a=a
this.b=b
this.$ti=c},
iB:function iB(a,b,c){this.a=a
this.b=b
this.$ti=c},
dM:function dM(a,b,c){this.a=a
this.b=b
this.$ti=c},
dl:function dl(a){this.$ti=a},
dm:function dm(a){this.$ti=a},
b0:function b0(a,b){this.a=a
this.$ti=b},
bo:function bo(a,b){this.a=a
this.$ti=b},
a_:function a_(){},
bB:function bB(a,b){this.a=a
this.$ti=b},
ec:function ec(){},
mx(){throw A.n(A.bD("Cannot modify unmodifiable Map"))},
my(){throw A.n(A.bD("Cannot modify constant Set"))},
o2(a){var s=A.o1(a)
if(s!=null)return s
return"minified:"+a},
r7(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.dX.b(a)},
z(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.dd(a)
return s},
f2(a){var s,r=$.mM
if(r==null)r=$.mM=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
mT(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.b(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
p8(a){var s,r
if(!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(a))return null
s=parseFloat(a)
if(isNaN(s)){r=B.d.aG(a)
if(r==="NaN"||r==="+NaN"||r==="-NaN")return s
return null}return s},
f3(a){var s,r,q,p
if(a instanceof A.N)return A.aJ(A.a6(a),null)
s=J.cJ(a)
if(s===B.eS||s===B.eU||t.cx.b(a)){r=B.aU(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.aJ(A.a6(a),null)},
mU(a){var s,r,q
if(a==null||typeof a=="number"||A.m7(a))return J.dd(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.aD)return a.t(0)
if(a instanceof A.bf)return a.cs(!0)
s=$.oj()
for(r=0;r<1;++r){q=s[r].es(a)
if(q!=null)return q}return"Instance of '"+A.f3(a)+"'"},
p9(a,b,c){var s,r,q,p
if(c<=500&&b===0&&c===a.length)return String.fromCharCode.apply(null,a)
for(s=b,r="";s<c;s=q){q=s+500
p=q<c?q:c
r+=String.fromCharCode.apply(null,a.subarray(s,p))}return r},
ay(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aZ(s,10)|55296)>>>0,s&1023|56320)}throw A.n(A.aY(a,0,1114111,null,null))},
pa(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.bc(h,1000)
g+=B.c.bw(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
aW(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
f1(a){return a.c?A.aW(a).getUTCFullYear()+0:A.aW(a).getFullYear()+0},
mR(a){return a.c?A.aW(a).getUTCMonth()+1:A.aW(a).getMonth()+1},
mN(a){return a.c?A.aW(a).getUTCDate()+0:A.aW(a).getDate()+0},
mO(a){return a.c?A.aW(a).getUTCHours()+0:A.aW(a).getHours()+0},
mQ(a){return a.c?A.aW(a).getUTCMinutes()+0:A.aW(a).getMinutes()+0},
mS(a){return a.c?A.aW(a).getUTCSeconds()+0:A.aW(a).getSeconds()+0},
mP(a){return a.c?A.aW(a).getUTCMilliseconds()+0:A.aW(a).getMilliseconds()+0},
p7(a){var s=a.$thrownJsError
if(s==null)return null
return A.cK(s)},
bG(a){throw A.n(A.nF(a))},
b(a,b){if(a==null)J.at(a)
throw A.n(A.fM(a,b))},
fM(a,b){var s,r="index"
if(!A.nu(b))return new A.bu(!0,b,r,null)
s=A.aI(J.at(a))
if(b<0||b>=s)return A.iN(b,s,a,r)
return A.lW(b,r)},
nF(a){return new A.bu(!0,a,null,null)},
mb(a){return a},
n(a){return A.af(a,new Error())},
af(a,b){var s
if(a==null)a=new A.bT()
b.dartException=a
s=A.ro
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
ro(){return J.dd(this.dartException)},
bs(a,b){throw A.af(a,b==null?new Error():b)},
ag(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.bs(A.q6(a,b,c),s)},
q6(a,b,c){var s,r,q,p,o,n,m,l,k
if(typeof b=="string")s=b
else{r="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
q=r.length
p=b
if(p>q){c=p/q|0
p%=q}s=r[p]}o=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
n=t.j.b(a)?"list":"ByteData"
m=a.$flags|0
l="a "
if((m&4)!==0)k="constant "
else if((m&2)!==0){k="unmodifiable "
l="an "}else k=(m&1)!==0?"fixed-length ":""
return new A.dT("'"+s+"': Cannot "+o+" "+l+k+n)},
j(a){throw A.n(A.ai(a))},
bU(a){var s,r,q,p,o,n
a=A.o_(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.d([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.jY(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
jZ(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
n4(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
lR(a,b){var s=b==null,r=s?null:b.method
return new A.eG(a,r,s?null:b.receiver)},
bY(a){var s
if(a==null)return new A.jd(a)
if(a instanceof A.dn){s=a.a
return A.cg(a,s==null?A.ed(s):s)}if(typeof a!=="object")return a
if("dartException" in a)return A.cg(a,a.dartException)
return A.qG(a)},
cg(a,b){if(t.fz.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
qG(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aZ(r,16)&8191)===10)switch(q){case 438:return A.cg(a,A.lR(A.z(s)+" (Error "+q+")",null))
case 445:case 5007:A.z(s)
return A.cg(a,new A.dI())}}if(a instanceof TypeError){p=$.o7()
o=$.o8()
n=$.o9()
m=$.oa()
l=$.od()
k=$.oe()
j=$.oc()
$.ob()
i=$.og()
h=$.of()
g=p.ag(s)
if(g!=null)return A.cg(a,A.lR(A.D(s),g))
else{g=o.ag(s)
if(g!=null){g.method="call"
return A.cg(a,A.lR(A.D(s),g))}else if(n.ag(s)!=null||m.ag(s)!=null||l.ag(s)!=null||k.ag(s)!=null||j.ag(s)!=null||m.ag(s)!=null||i.ag(s)!=null||h.ag(s)!=null){A.D(s)
return A.cg(a,new A.dI())}}return A.cg(a,new A.fd(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.dP()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.cg(a,new A.bu(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.dP()
return a},
cK(a){var s
if(a instanceof A.dn)return a.b
if(a==null)return new A.e6(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.e6(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
nW(a){if(a==null)return J.aR(a)
if(typeof a=="object")return A.f2(a)
return J.aR(a)},
qW(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.h(0,a[s],a[r])}return b},
qX(a,b){var s,r=a.length
for(s=0;s<r;++s)b.k(0,a[s])
return b},
qg(a,b,c,d,e,f){t.Z.a(a)
switch(A.aI(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.n(new A.kl("Unsupported number of arguments for wrapped closure"))},
fL(a,b){var s=a.$identity
if(!!s)return s
s=A.qM(a,b)
a.$identity=s
return s},
qM(a,b){var s
switch(b){case 0:s=a.$0
break
case 1:s=a.$1
break
case 2:s=a.$2
break
case 3:s=a.$3
break
case 4:s=a.$4
break
default:s=null}if(s!=null)return s.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.qg)},
oE(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.f6().constructor.prototype):Object.create(new A.cN(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.mw(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.oA(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.mw(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
oA(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.n("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.or)}throw A.n("Error in functionType of tearoff")},
oB(a,b,c,d){var s=A.mt
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
mw(a,b,c,d){if(c)return A.oD(a,b,d)
return A.oB(b.length,d,a,b)},
oC(a,b,c,d){var s=A.mt,r=A.os
switch(b?-1:a){case 0:throw A.n(new A.f5("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
oD(a,b,c){var s,r
if($.mr==null)$.mr=A.mq("interceptor")
if($.ms==null)$.ms=A.mq("receiver")
s=b.length
r=A.oC(s,c,a,b)
return r},
mc(a){return A.oE(a)},
or(a,b){return A.ea(v.typeUniverse,A.a6(a.a),b)},
mt(a){return a.a},
os(a){return a.b},
mq(a){var s,r,q,p=new A.cN("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.n(A.df("Field name "+a+" not found.",null))},
la(a){return v.getIsolateTag(a)},
r8(a){var s,r,q,p,o,n=A.D($.nN.$1(a)),m=$.l6[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.lh[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=A.x($.nD.$2(a,n))
if(q!=null){m=$.l6[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.lh[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.ln(s)
$.l6[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.lh[n]=s
return s}if(p==="-"){o=A.ln(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.nY(a,s)
if(p==="*")throw A.n(A.n5(n))
if(v.leafTags[n]===true){o=A.ln(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.nY(a,s)},
nY(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.mh(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
ln(a){return J.mh(a,!1,null,!!a.$iaU)},
ra(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.ln(s)
else return J.mh(s,c,null,null)},
r3(){if(!0===$.mf)return
$.mf=!0
A.r4()},
r4(){var s,r,q,p,o,n,m,l
$.l6=Object.create(null)
$.lh=Object.create(null)
A.r2()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.nZ.$1(o)
if(n!=null){m=A.ra(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
r2(){var s,r,q,p,o,n,m=B.dj()
m=A.da(B.dk,A.da(B.dl,A.da(B.aV,A.da(B.aV,A.da(B.dm,A.da(B.dn,A.da(B.dp(B.aU),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.nN=new A.le(p)
$.nD=new A.lf(o)
$.nZ=new A.lg(n)},
da(a,b){return a(b)||b},
pO(a,b){var s,r
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.b(b,s)
if(!J.aQ(r,b[s]))return!1}return!0},
qO(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
p_(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.n(A.b4("Illegal RegExp pattern ("+String(o)+")",a,null))},
qT(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
o_(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
rk(a,b,c){var s=A.rl(a,b,c)
return s},
rl(a,b,c){var s,r,q
if(b===""){if(a==="")return c
s=a.length
for(r=c,q=0;q<s;++q)r=r+a[q]+c
return r.charCodeAt(0)==0?r:r}if(a.indexOf(b,0)<0)return a
if(a.length<500||c.indexOf("$",0)>=0)return a.split(b).join(c)
return a.replace(new RegExp(A.o_(b),"g"),A.qT(c))},
m:function m(a,b){this.a=a
this.b=b},
a:function a(a,b,c){this.a=a
this.b=b
this.c=c},
d6:function d6(a){this.a=a},
aP:function aP(a){this.a=a},
di:function di(){},
aT:function aT(a,b,c){this.a=a
this.b=b
this.$ti=c},
dY:function dY(a,b){this.a=a
this.$ti=b},
cF:function cF(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
dj:function dj(){},
c0:function c0(a,b,c){this.a=a
this.b=b
this.$ti=c},
ez:function ez(){},
bL:function bL(a,b){this.a=a
this.$ti=b},
dK:function dK(){},
jY:function jY(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dI:function dI(){},
eG:function eG(a,b,c){this.a=a
this.b=b
this.c=c},
fd:function fd(a){this.a=a},
jd:function jd(a){this.a=a},
dn:function dn(a,b){this.a=a
this.b=b},
e6:function e6(a){this.a=a
this.b=null},
aD:function aD(){},
em:function em(){},
en:function en(){},
f8:function f8(){},
f6:function f6(){},
cN:function cN(a,b){this.a=a
this.b=b},
f5:function f5(a){this.a=a},
bM:function bM(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
iQ:function iQ(a){this.a=a},
iT:function iT(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
aa:function aa(a,b){this.a=a
this.$ti=b},
au:function au(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
av:function av(a,b){this.a=a
this.$ti=b},
M:function M(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
J:function J(a,b){this.a=a
this.$ti=b},
ap:function ap(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
le:function le(a){this.a=a},
lf:function lf(a){this.a=a},
lg:function lg(a){this.a=a},
bf:function bf(){},
d4:function d4(){},
d5:function d5(){},
cH:function cH(){},
eF:function eF(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
kA:function kA(a){this.b=a},
q7(a){return a},
p1(a){return new Int8Array(a)},
p2(a){return new Uint8Array(a)},
bV(a,b,c){if(a>>>0!==a||a>=c)throw A.n(A.fM(b,a))},
cS:function cS(){},
dG:function dG(){},
eP:function eP(){},
cT:function cT(){},
dE:function dE(){},
dF:function dF(){},
eQ:function eQ(){},
eR:function eR(){},
eS:function eS(){},
eT:function eT(){},
eU:function eU(){},
eV:function eV(){},
eW:function eW(){},
dH:function dH(){},
eX:function eX(){},
dZ:function dZ(){},
e_:function e_(){},
e0:function e0(){},
e1:function e1(){},
lX(a,b){var s=b.c
return s==null?b.c=A.e8(a,"bx",[b.x]):s},
n0(a){var s=a.w
if(s===6||s===7)return A.n0(a.x)
return s===11||s===12},
pg(a){return a.as},
nX(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
S(a){return A.kG(v.typeUniverse,a,!1)},
r6(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.cf(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
cf(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.cf(a1,s,a3,a4)
if(r===s)return a2
return A.nf(a1,r,!0)
case 7:s=a2.x
r=A.cf(a1,s,a3,a4)
if(r===s)return a2
return A.ne(a1,r,!0)
case 8:q=a2.y
p=A.d9(a1,q,a3,a4)
if(p===q)return a2
return A.e8(a1,a2.x,p)
case 9:o=a2.x
n=A.cf(a1,o,a3,a4)
m=a2.y
l=A.d9(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.m3(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.d9(a1,j,a3,a4)
if(i===j)return a2
return A.ng(a1,k,i)
case 11:h=a2.x
g=A.cf(a1,h,a3,a4)
f=a2.y
e=A.qD(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.nd(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.d9(a1,d,a3,a4)
o=a2.x
n=A.cf(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.m4(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.n(A.ej("Attempted to substitute unexpected RTI kind "+a0))}},
d9(a,b,c,d){var s,r,q,p,o=b.length,n=A.kH(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.cf(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
qE(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.kH(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.cf(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
qD(a,b,c,d){var s,r=b.a,q=A.d9(a,r,c,d),p=b.b,o=A.d9(a,p,c,d),n=b.c,m=A.qE(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.fm()
s.a=q
s.b=o
s.c=m
return s},
d(a,b){a[v.arrayRti]=b
return a},
kV(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.r0(s)
return a.$S()}return null},
r5(a,b){var s
if(A.n0(b))if(a instanceof A.aD){s=A.kV(a)
if(s!=null)return s}return A.a6(a)},
a6(a){if(a instanceof A.N)return A.k(a)
if(Array.isArray(a))return A.t(a)
return A.m6(J.cJ(a))},
t(a){var s=a[v.arrayRti],r=t.dG
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
k(a){var s=a.$ti
return s!=null?s:A.m6(a)},
m6(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.qe(a,s)},
qe(a,b){var s=a instanceof A.aD?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.pY(v.typeUniverse,s.name)
b.$ccache=r
return r},
r0(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.kG(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
r_(a){return A.bX(A.k(a))},
me(a){var s=A.kV(a)
return A.bX(s==null?A.a6(a):s)},
ma(a){var s
if(a instanceof A.bf)return A.qU(a.$r,a.aQ())
s=a instanceof A.aD?A.kV(a):null
if(s!=null)return s
if(t.aJ.b(a))return J.oo(a).a
if(Array.isArray(a))return A.t(a)
return A.a6(a)},
bX(a){var s=a.r
return s==null?a.r=new A.kF(a):s},
qU(a,b){var s,r,q=b,p=q.length
if(p===0)return t.aK
if(0>=p)return A.b(q,0)
s=A.ea(v.typeUniverse,A.ma(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.b(q,r)
s=A.ni(v.typeUniverse,s,A.ma(q[r]))}return A.ea(v.typeUniverse,s,a)},
bt(a){return A.bX(A.kG(v.typeUniverse,a,!1))},
qd(a){var s=this
s.b=A.qB(s)
return s.b(a)},
qB(a){var s,r,q,p,o
if(a===t.D)return A.qm
if(A.cL(a))return A.qq
s=a.w
if(s===6)return A.qb
if(s===1)return A.nw
if(s===7)return A.qh
r=A.qA(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.cL)){a.f="$i"+q
if(q==="r")return A.qk
if(a===t.m)return A.qj
return A.qp}}else if(s===10){p=A.qO(a.x,a.y)
o=p==null?A.nw:p
return o==null?A.ed(o):o}return A.q9},
qA(a){if(a.w===8){if(a===t.S)return A.nu
if(a===t.i||a===t.H)return A.ql
if(a===t.N)return A.qo
if(a===t.y)return A.m7}return null},
qc(a){var s=this,r=A.q8
if(A.cL(s))r=A.q2
else if(s===t.D)r=A.ed
else if(A.db(s)){r=A.qa
if(s===t.aV)r=A.nl
else if(s===t.bl)r=A.x
else if(s===t.o9)r=A.V
else if(s===t.jh)r=A.y
else if(s===t.jX)r=A.q0
else if(s===t.mU)r=A.q1}else if(s===t.S)r=A.aI
else if(s===t.N)r=A.D
else if(s===t.y)r=A.q_
else if(s===t.H)r=A.az
else if(s===t.i)r=A.W
else if(s===t.m)r=A.nm
s.a=r
return s.a(a)},
q9(a){var s=this
if(a==null)return A.db(s)
return A.nQ(v.typeUniverse,A.r5(a,s),s)},
qb(a){if(a==null)return!0
return this.x.b(a)},
qp(a){var s,r=this
if(a==null)return A.db(r)
s=r.f
if(a instanceof A.N)return!!a[s]
return!!J.cJ(a)[s]},
qk(a){var s,r=this
if(a==null)return A.db(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.N)return!!a[s]
return!!J.cJ(a)[s]},
qj(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.N)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
nv(a){if(typeof a=="object"){if(a instanceof A.N)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
q8(a){var s=this
if(a==null){if(A.db(s))return a}else if(s.b(a))return a
throw A.af(A.nr(a,s),new Error())},
qa(a){var s=this
if(a==null||s.b(a))return a
throw A.af(A.nr(a,s),new Error())},
nr(a,b){return new A.d7("TypeError: "+A.n8(a,A.aJ(b,null)))},
nH(a,b,c,d){if(A.nQ(v.typeUniverse,a,b))return a
throw A.af(A.pQ("The type argument '"+A.aJ(a,null)+"' is not a subtype of the type variable bound '"+A.aJ(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
n8(a,b){return A.et(a)+": type '"+A.aJ(A.ma(a),null)+"' is not a subtype of type '"+b+"'"},
pQ(a){return new A.d7("TypeError: "+a)},
bg(a,b){return new A.d7("TypeError: "+A.n8(a,b))},
qh(a){var s=this
return s.x.b(a)||A.lX(v.typeUniverse,s).b(a)},
qm(a){return a!=null},
ed(a){if(a!=null)return a
throw A.af(A.bg(a,"Object"),new Error())},
qq(a){return!0},
q2(a){return a},
nw(a){return!1},
m7(a){return!0===a||!1===a},
q_(a){if(!0===a)return!0
if(!1===a)return!1
throw A.af(A.bg(a,"bool"),new Error())},
V(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.af(A.bg(a,"bool?"),new Error())},
W(a){if(typeof a=="number")return a
throw A.af(A.bg(a,"double"),new Error())},
q0(a){if(typeof a=="number")return a
if(a==null)return a
throw A.af(A.bg(a,"double?"),new Error())},
nu(a){return typeof a=="number"&&Math.floor(a)===a},
aI(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.af(A.bg(a,"int"),new Error())},
nl(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.af(A.bg(a,"int?"),new Error())},
ql(a){return typeof a=="number"},
az(a){if(typeof a=="number")return a
throw A.af(A.bg(a,"num"),new Error())},
y(a){if(typeof a=="number")return a
if(a==null)return a
throw A.af(A.bg(a,"num?"),new Error())},
qo(a){return typeof a=="string"},
D(a){if(typeof a=="string")return a
throw A.af(A.bg(a,"String"),new Error())},
x(a){if(typeof a=="string")return a
if(a==null)return a
throw A.af(A.bg(a,"String?"),new Error())},
nm(a){if(A.nv(a))return a
throw A.af(A.bg(a,"JSObject"),new Error())},
q1(a){if(a==null)return a
if(A.nv(a))return a
throw A.af(A.bg(a,"JSObject?"),new Error())},
nA(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.aJ(a[q],b)
return s},
qv(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.nA(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.aJ(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
ns(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
if(a5!=null){s=a5.length
if(a4==null)a4=A.d([],t.s)
else a2=a4.length
r=a4.length
for(q=s;q>0;--q)B.a.k(a4,"T"+(r+q))
for(p=t.iD,o="<",n="",q=0;q<s;++q,n=a1){m=a4.length
l=m-1-q
if(!(l>=0))return A.b(a4,l)
o=o+n+a4[l]
k=a5[q]
j=k.w
if(!(j===2||j===3||j===4||j===5||k===p))o+=" extends "+A.aJ(k,a4)}o+=">"}else o=""
p=a3.x
i=a3.y
h=i.a
g=h.length
f=i.b
e=f.length
d=i.c
c=d.length
b=A.aJ(p,a4)
for(a="",a0="",q=0;q<g;++q,a0=a1)a+=a0+A.aJ(h[q],a4)
if(e>0){a+=a0+"["
for(a0="",q=0;q<e;++q,a0=a1)a+=a0+A.aJ(f[q],a4)
a+="]"}if(c>0){a+=a0+"{"
for(a0="",q=0;q<c;q+=3,a0=a1){a+=a0
if(d[q+1])a+="required "
a+=A.aJ(d[q+2],a4)+" "+d[q]}a+="}"}if(a2!=null){a4.toString
a4.length=a2}return o+"("+a+") => "+b},
aJ(a,b){var s,r,q,p,o,n,m,l=a.w
if(l===5)return"erased"
if(l===2)return"dynamic"
if(l===3)return"void"
if(l===1)return"Never"
if(l===4)return"any"
if(l===6){s=a.x
r=A.aJ(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(l===7)return"FutureOr<"+A.aJ(a.x,b)+">"
if(l===8){p=A.qF(a.x)
o=a.y
return o.length>0?p+("<"+A.nA(o,b)+">"):p}if(l===10)return A.qv(a,b)
if(l===11)return A.ns(a,b,null)
if(l===12)return A.ns(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.b(b,n)
return b[n]}return"?"},
qF(a){var s=A.o1(a)
if(s!=null)return s
return"minified:"+a},
pZ(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
pY(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.kG(a,b,!1)
else if(typeof m=="number"){s=m
r=A.e9(a,5,"#")
q=A.kH(s)
for(p=0;p<s;++p)q[p]=r
o=A.e8(a,b,q)
n[b]=o
return o}else return m},
pX(a,b){return A.nj(a.tR,b)},
pW(a,b){return A.nj(a.eT,b)},
kG(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.nh(a,null,b,!1)
r.set(b,s)
return s},
ea(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.nh(a,b,c,!0)
q.set(c,r)
return r},
ni(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.m3(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
nh(a,b,c,d){return A.pM(A.pG(a,b,c,d))},
ce(a,b){b.a=A.qc
b.b=A.qd
return b},
e9(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.bn(null,null)
s.w=b
s.as=c
r=A.ce(a,s)
a.eC.set(c,r)
return r},
nf(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.pU(a,b,r,c)
a.eC.set(r,s)
return s},
pU(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.cL(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.db(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.bn(null,null)
q.w=6
q.x=b
q.as=c
return A.ce(a,q)},
ne(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.pS(a,b,r,c)
a.eC.set(r,s)
return s},
pS(a,b,c,d){var s,r
if(d){s=b.w
if(A.cL(b)||b===t.D)return b
else if(s===1)return A.e8(a,"bx",[b])
else if(b===t.a||b===t.T)return t.gK}r=new A.bn(null,null)
r.w=7
r.x=b
r.as=c
return A.ce(a,r)},
pV(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.bn(null,null)
s.w=13
s.x=b
s.as=q
r=A.ce(a,s)
a.eC.set(q,r)
return r},
e7(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
pR(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
e8(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.e7(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.bn(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.ce(a,r)
a.eC.set(p,q)
return q},
m3(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.e7(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.bn(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.ce(a,o)
a.eC.set(q,n)
return n},
ng(a,b,c){var s,r,q="+"+(b+"("+A.e7(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.bn(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.ce(a,s)
a.eC.set(q,r)
return r},
nd(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.e7(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.e7(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.pR(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.bn(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.ce(a,p)
a.eC.set(r,o)
return o},
m4(a,b,c,d){var s,r=b.as+("<"+A.e7(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.pT(a,b,c,r,d)
a.eC.set(r,s)
return s},
pT(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.kH(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.cf(a,b,r,0)
m=A.d9(a,c,r,0)
return A.m4(a,n,m,c!==m)}}l=new A.bn(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.ce(a,l)},
pG(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
pM(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.pI(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.na(a,r,l,k,!1)
else if(q===46)r=A.na(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.cG(a.u,a.e,k.pop()))
break
case 94:k.push(A.pV(a.u,k.pop()))
break
case 35:k.push(A.e9(a.u,5,"#"))
break
case 64:k.push(A.e9(a.u,2,"@"))
break
case 126:k.push(A.e9(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.pK(a,k)
break
case 38:A.pJ(a,k)
break
case 63:p=a.u
k.push(A.nf(p,A.cG(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.ne(p,A.cG(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.pH(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.nb(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.pN(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-2)
break
case 43:n=l.indexOf("(",r)
k.push(l.substring(r,n))
k.push(-4)
k.push(a.p)
a.p=k.length
r=n+1
break
default:throw"Bad character "+q}}}m=k.pop()
return A.cG(a.u,a.e,m)},
pI(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
na(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.pZ(s,o.x)[p]
if(n==null)A.bs('No "'+p+'" in "'+A.pg(o)+'"')
d.push(A.ea(s,o,n))}else d.push(p)
return m},
pK(a,b){var s,r=a.u,q=A.n9(a,b),p=b.pop()
if(typeof p=="string")b.push(A.e8(r,p,q))
else{s=A.cG(r,a.e,p)
switch(s.w){case 11:b.push(A.m4(r,s,q,a.n))
break
default:b.push(A.m3(r,s,q))
break}}},
pH(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.n9(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.cG(p,a.e,o)
q=new A.fm()
q.a=s
q.b=n
q.c=m
b.push(A.nd(p,r,q))
return
case-4:b.push(A.ng(p,b.pop(),s))
return
default:throw A.n(A.ej("Unexpected state under `()`: "+A.z(o)))}},
pJ(a,b){var s=b.pop()
if(0===s){b.push(A.e9(a.u,1,"0&"))
return}if(1===s){b.push(A.e9(a.u,4,"1&"))
return}throw A.n(A.ej("Unexpected extended operation "+A.z(s)))},
n9(a,b){var s=b.splice(a.p)
A.nb(a.u,a.e,s)
a.p=b.pop()
return s},
cG(a,b,c){if(typeof c=="string")return A.e8(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.pL(a,b,c)}else return c},
nb(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.cG(a,b,c[s])},
pN(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.cG(a,b,c[s])},
pL(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.n(A.ej("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.n(A.ej("Bad index "+c+" for "+b.t(0)))},
nQ(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.ad(a,b,null,c,null)
r.set(c,s)}return s},
ad(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.cL(d))return!0
s=b.w
if(s===4)return!0
if(A.cL(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.ad(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.ad(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.D){if(s===7)return A.ad(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.ad(a,b.x,c,d,e))return!1
return A.ad(a,A.lX(a,b),c,d,e)}if(s===6)return A.ad(a,p,c,d,e)&&A.ad(a,b.x,c,d,e)
if(q===7){if(A.ad(a,b,c,d.x,e))return!0
return A.ad(a,b,c,A.lX(a,d),e)}if(q===6)return A.ad(a,b,c,p,e)||A.ad(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Z)return!0
o=s===10
if(o&&d===t.lZ)return!0
if(q===12){if(b===t.dY)return!0
if(s!==12)return!1
n=b.y
m=d.y
l=n.length
if(l!==m.length)return!1
c=c==null?n:n.concat(c)
e=e==null?m:m.concat(e)
for(k=0;k<l;++k){j=n[k]
i=m[k]
if(!A.ad(a,j,c,i,e)||!A.ad(a,i,e,j,c))return!1}return A.nt(a,b.x,c,d.x,e)}if(q===11){if(b===t.dY)return!0
if(p)return!1
return A.nt(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.qi(a,b,c,d,e)}if(o&&q===10)return A.qn(a,b,c,d,e)
return!1},
nt(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.ad(a3,a4.x,a5,a6.x,a7))return!1
s=a4.y
r=a6.y
q=s.a
p=r.a
o=q.length
n=p.length
if(o>n)return!1
m=n-o
l=s.b
k=r.b
j=l.length
i=k.length
if(o+j<n+i)return!1
for(h=0;h<o;++h){g=q[h]
if(!A.ad(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.ad(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.ad(a3,k[h],a7,g,a5))return!1}f=s.c
e=r.c
d=f.length
c=e.length
for(b=0,a=0;a<c;a+=3){a0=e[a]
for(;;){if(b>=d)return!1
a1=f[b]
b+=3
if(a0<a1)return!1
a2=f[b-2]
if(a1<a0){if(a2)return!1
continue}g=e[a+1]
if(a2&&!g)return!1
g=f[b-1]
if(!A.ad(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
qi(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.ea(a,b,r[o])
return A.nk(a,p,null,c,d.y,e)}return A.nk(a,b.y,null,c,d.y,e)},
nk(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.ad(a,b[s],d,e[s],f))return!1
return!0},
qn(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.ad(a,r[s],c,q[s],e))return!1
return!0},
db(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.cL(a))if(s!==6)r=s===7&&A.db(a.x)
return r},
cL(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.iD},
nj(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
kH(a){return a>0?new Array(a):v.typeUniverse.sEA},
bn:function bn(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
fm:function fm(){this.c=this.b=this.a=null},
kF:function kF(a){this.a=a},
fl:function fl(){},
d7:function d7(a){this.a=a},
pw(){var s,r,q
if(self.scheduleImmediate!=null)return A.qI()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.fL(new A.kg(s),1)).observe(r,{childList:true})
return new A.kf(s,r,q)}else if(self.setImmediate!=null)return A.qJ()
return A.qK()},
px(a){self.scheduleImmediate(A.fL(new A.kh(t.M.a(a)),0))},
py(a){self.setImmediate(A.fL(new A.ki(t.M.a(a)),0))},
pz(a){A.pp(B.dh,t.M.a(a))},
pp(a,b){return A.pP(0,b)},
pP(a,b){var s=new A.kD()
s.d3(a,b)
return s},
nx(a){return new A.ff(new A.an($.ab,a.j("an<0>")),a.j("ff<0>"))},
nq(a,b){a.$2(0,null)
b.b=!0
return b.a},
nn(a,b){A.q3(a,b)},
np(a,b){var s,r,q=b.$ti
q.j("1/?").a(a)
s=a==null?q.c.a(a):a
if(!b.b)b.a.bX(s)
else{r=b.a
if(q.j("bx<1>").b(s))r.c0(s)
else r.c1(s)}},
no(a,b){var s=A.bY(a),r=A.cK(a),q=b.b,p=b.a
if(q)p.bj(new A.bh(s,r))
else p.bY(new A.bh(s,r))},
q3(a,b){var s,r,q=new A.kI(b),p=new A.kJ(b)
if(a instanceof A.an)a.cq(q,p,t.z)
else{s=t.z
if(a instanceof A.an)a.cP(q,p,s)
else{r=new A.an($.ab,t._)
r.a=8
r.c=a
r.cq(q,p,s)}}},
nC(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.ab.cM(new A.kQ(s),t.r,t.S,t.z)},
nc(a,b,c){return 0},
lO(a){var s
if(t.fz.b(a)){s=a.gaN()
if(s!=null)return s}return B.dr},
m1(a,b,c){var s,r,q,p,o={},n=o.a=a
for(s=t._;r=n.a,(r&4)!==0;n=a){a=s.a(n.c)
o.a=a}if(n===b){s=A.pk()
b.bY(new A.bh(new A.bu(!0,n,null,"Cannot complete a future with itself"),s))
return}q=b.a&1
s=n.a=r|q
if((s&24)===0){p=t.F.a(b.c)
b.a=b.a&1|4
b.c=n
n.ci(p)
return}if(!c)if(b.c==null)n=(s&16)===0||q!==0
else n=!1
else n=!0
if(n){p=b.aX()
b.aP(o.a)
A.d3(b,p)
return}b.a^=2
A.fJ(null,null,b.b,t.M.a(new A.kp(o,b)))},
d3(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d={},c=d.a=a
for(s=t.u,r=t.F;;){q={}
p=c.a
o=(p&16)===0
n=!o
if(b==null){if(n&&(p&1)===0){m=s.a(c.c)
A.m9(m.a,m.b)}return}q.a=b
l=b.a
for(c=b;l!=null;c=l,l=k){c.a=null
A.d3(d.a,c)
q.a=l
k=l.a}p=d.a
j=p.c
q.b=n
q.c=j
if(o){i=c.c
i=(i&1)!==0||(i&15)===8}else i=!0
if(i){h=c.b.b
if(n){p=p.b===h
p=!(p||p)}else p=!1
if(p){s.a(j)
A.m9(j.a,j.b)
return}g=$.ab
if(g!==h)$.ab=h
else g=null
c=c.c
if((c&15)===8)new A.kt(q,d,n).$0()
else if(o){if((c&1)!==0)new A.ks(q,j).$0()}else if((c&2)!==0)new A.kr(d,q).$0()
if(g!=null)$.ab=g
c=q.c
if(c instanceof A.an){p=q.a.$ti
p=p.j("bx<2>").b(c)||!p.y[1].b(c)}else p=!1
if(p){f=q.a.b
if((c.a&24)!==0){e=r.a(f.c)
f.c=null
b=f.aY(e)
f.a=c.a&30|f.a&1
f.c=c.c
d.a=c
continue}else A.m1(c,f,!0)
return}}f=q.a.b
e=r.a(f.c)
f.c=null
b=f.aY(e)
c=q.b
p=q.c
if(!c){f.$ti.c.a(p)
f.a=8
f.c=p}else{s.a(p)
f.a=f.a&1|16
f.c=p}d.a=f
c=f}},
qw(a,b){var s
if(t.ng.b(a))return b.cM(a,t.z,t.D,t.l)
s=t.mq
if(s.b(a))return s.a(a)
throw A.n(A.eh(a,"onError",u.c))},
qs(){var s,r
for(s=$.d8;s!=null;s=$.d8){$.ef=null
r=s.b
$.d8=r
if(r==null)$.ee=null
s.a.$0()}},
qC(){$.m8=!0
try{A.qs()}finally{$.ef=null
$.m8=!1
if($.d8!=null)$.mk().$1(A.nG())}},
nB(a){var s=new A.fg(a),r=$.ee
if(r==null){$.d8=$.ee=s
if(!$.m8)$.mk().$1(A.nG())}else $.ee=r.b=s},
qz(a){var s,r,q,p=$.d8
if(p==null){A.nB(a)
$.ef=$.ee
return}s=new A.fg(a)
r=$.ef
if(r==null){s.b=p
$.d8=$.ef=s}else{q=r.b
s.b=q
$.ef=r.b=s
if(q==null)$.ee=s}},
ry(a,b){A.cI(a,"stream",t.D)
return new A.fC(b.j("fC<0>"))},
m9(a,b){A.qz(new A.kP(a,b))},
nz(a,b,c,d,e){var s,r=$.ab
if(r===c)return d.$0()
$.ab=c
s=r
try{r=d.$0()
return r}finally{$.ab=s}},
qy(a,b,c,d,e,f,g){var s,r=$.ab
if(r===c)return d.$1(e)
$.ab=c
s=r
try{r=d.$1(e)
return r}finally{$.ab=s}},
qx(a,b,c,d,e,f,g,h,i){var s,r=$.ab
if(r===c)return d.$2(e,f)
$.ab=c
s=r
try{r=d.$2(e,f)
return r}finally{$.ab=s}},
fJ(a,b,c,d){t.M.a(d)
if(B.u!==c){d=c.dK(d)
d=d}A.nB(d)},
kg:function kg(a){this.a=a},
kf:function kf(a,b,c){this.a=a
this.b=b
this.c=c},
kh:function kh(a){this.a=a},
ki:function ki(a){this.a=a},
kD:function kD(){},
kE:function kE(a,b){this.a=a
this.b=b},
ff:function ff(a,b){this.a=a
this.b=!1
this.$ti=b},
kI:function kI(a){this.a=a},
kJ:function kJ(a){this.a=a},
kQ:function kQ(a){this.a=a},
br:function br(a,b){var _=this
_.a=a
_.e=_.d=_.c=_.b=null
_.$ti=b},
bF:function bF(a,b){this.a=a
this.$ti=b},
bh:function bh(a,b){this.a=a
this.b=b},
cE:function cE(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
an:function an(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
km:function km(a,b){this.a=a
this.b=b},
kq:function kq(a,b){this.a=a
this.b=b},
kp:function kp(a,b){this.a=a
this.b=b},
ko:function ko(a,b){this.a=a
this.b=b},
kn:function kn(a,b){this.a=a
this.b=b},
kt:function kt(a,b,c){this.a=a
this.b=b
this.c=c},
ku:function ku(a,b){this.a=a
this.b=b},
kv:function kv(a){this.a=a},
ks:function ks(a,b){this.a=a
this.b=b},
kr:function kr(a,b){this.a=a
this.b=b},
fg:function fg(a){this.a=a
this.b=null},
fC:function fC(a){this.$ti=a},
eb:function eb(){},
fy:function fy(){},
kC:function kC(a,b){this.a=a
this.b=b},
kP:function kP(a,b){this.a=a
this.b=b},
iU(a,b){return new A.bM(a.j("@<0>").A(b).j("bM<1,2>"))},
X(a,b,c){return b.j("@<0>").A(c).j("mJ<1,2>").a(A.qW(a,new A.bM(b.j("@<0>").A(c).j("bM<1,2>"))))},
l(a,b){return new A.bM(a.j("@<0>").A(b).j("bM<1,2>"))},
eM(a){return new A.be(a.j("be<0>"))},
K(a){return new A.be(a.j("be<0>"))},
al(a,b){return b.j("mK<0>").a(A.qX(a,new A.be(b.j("be<0>"))))},
m2(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
as(a,b,c){var s=new A.Y(a,b,c.j("Y<0>"))
s.c=a.e
return s},
p0(a,b,c){var s=A.iU(b,c)
a.a_(0,new A.iV(s,b,c))
return s},
U(a,b,c){var s=A.iU(b,c)
s.B(0,a)
return s},
cQ(a,b){var s,r,q=A.eM(b)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.j)(a),++r)q.k(0,b.a(a[r]))
return q},
dz(a,b){var s=A.eM(b)
s.B(0,a)
return s},
lS(a){var s,r
if(A.mg(a))return"{...}"
s=new A.d0("")
try{r={}
B.a.k($.b1,a)
s.a+="{"
r.a=!0
a.a_(0,new A.iY(r,s))
s.a+="}"}finally{if(0>=$.b1.length)return A.b($.b1,-1)
$.b1.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
pi(a,b,c){return new A.dN(a,b,c.j("dN<0>"))},
be:function be(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
fs:function fs(a){this.a=a
this.c=this.b=null},
Y:function Y(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
iV:function iV(a,b,c){this.a=a
this.b=b
this.c=c},
H:function H(){},
a7:function a7(){},
iX:function iX(a){this.a=a},
iY:function iY(a,b){this.a=a
this.b=b},
bC:function bC(){},
e2:function e2(){},
cd:function cd(){},
bq:function bq(a,b){var _=this
_.a=a
_.c=_.b=null
_.$ti=b},
bp:function bp(){},
bE:function bE(){},
e3:function e3(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=null
_.d=c
_.$ti=d},
dN:function dN(a,b,c){var _=this
_.d=null
_.e=a
_.f=b
_.c=_.b=_.a=0
_.$ti=c},
e4:function e4(){},
e5:function e5(){},
qu(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.bY(r)
q=A.b4(String(s),null,null)
throw A.n(q)}q=A.kL(p)
return q},
kL(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.fo(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.kL(a[s])
return a},
pD(a,b,c,d,e,f,g,a0){var s,r,q,p,o,n,m,l,k,j,i=a0>>>2,h=3-(a0&3)
for(s=b.length,r=a.length,q=f.$flags|0,p=c,o=0;p<d;++p){if(!(p<s))return A.b(b,p)
n=b[p]
o|=n
i=(i<<8|n)&16777215;--h
if(h===0){m=g+1
l=i>>>18&63
if(!(l<r))return A.b(a,l)
q&2&&A.ag(f)
k=f.length
if(!(g<k))return A.b(f,g)
f[g]=a.charCodeAt(l)
g=m+1
l=i>>>12&63
if(!(l<r))return A.b(a,l)
if(!(m<k))return A.b(f,m)
f[m]=a.charCodeAt(l)
m=g+1
l=i>>>6&63
if(!(l<r))return A.b(a,l)
if(!(g<k))return A.b(f,g)
f[g]=a.charCodeAt(l)
g=m+1
l=i&63
if(!(l<r))return A.b(a,l)
if(!(m<k))return A.b(f,m)
f[m]=a.charCodeAt(l)
i=0
h=3}}if(o>=0&&o<=255){if(h<3){m=g+1
j=m+1
if(3-h===1){s=i>>>2&63
if(!(s<r))return A.b(a,s)
q&2&&A.ag(f)
q=f.length
if(!(g<q))return A.b(f,g)
f[g]=a.charCodeAt(s)
s=i<<4&63
if(!(s<r))return A.b(a,s)
if(!(m<q))return A.b(f,m)
f[m]=a.charCodeAt(s)
g=j+1
if(!(j<q))return A.b(f,j)
f[j]=61
if(!(g<q))return A.b(f,g)
f[g]=61}else{s=i>>>10&63
if(!(s<r))return A.b(a,s)
q&2&&A.ag(f)
q=f.length
if(!(g<q))return A.b(f,g)
f[g]=a.charCodeAt(s)
s=i>>>4&63
if(!(s<r))return A.b(a,s)
if(!(m<q))return A.b(f,m)
f[m]=a.charCodeAt(s)
g=j+1
s=i<<2&63
if(!(s<r))return A.b(a,s)
if(!(j<q))return A.b(f,j)
f[j]=a.charCodeAt(s)
if(!(g<q))return A.b(f,g)
f[g]=61}return 0}return(i<<2|3-h)>>>0}for(p=c;p<d;){if(!(p<s))return A.b(b,p)
n=b[p]
if(n>255)break;++p}if(!(p<s))return A.b(b,p)
throw A.n(A.eh(b,"Not a byte value at index "+p+": 0x"+B.c.bO(b[p],16),null))},
pC(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i="Invalid encoding before padding",h="Invalid character",g=B.c.aZ(a1,2),f=a1&3,e=$.oi()
for(s=a.length,r=e.length,q=d.$flags|0,p=b,o=0;p<c;++p){if(!(p<s))return A.b(a,p)
n=a.charCodeAt(p)
o|=n
m=n&127
if(!(m<r))return A.b(e,m)
l=e[m]
if(l>=0){g=(g<<6|l)&16777215
f=f+1&3
if(f===0){k=a0+1
q&2&&A.ag(d)
m=d.length
if(!(a0<m))return A.b(d,a0)
d[a0]=g>>>16&255
a0=k+1
if(!(k<m))return A.b(d,k)
d[k]=g>>>8&255
k=a0+1
if(!(a0<m))return A.b(d,a0)
d[a0]=g&255
a0=k
g=0}continue}else if(l===-1&&f>1){if(o>127)break
if(f===3){if((g&3)!==0)throw A.n(A.b4(i,a,p))
k=a0+1
q&2&&A.ag(d)
s=d.length
if(!(a0<s))return A.b(d,a0)
d[a0]=g>>>10
if(!(k<s))return A.b(d,k)
d[k]=g>>>2}else{if((g&15)!==0)throw A.n(A.b4(i,a,p))
q&2&&A.ag(d)
if(!(a0<d.length))return A.b(d,a0)
d[a0]=g>>>4}j=(3-f)*3
if(n===37)j+=2
return A.n7(a,p+1,c,-j-1)}throw A.n(A.b4(h,a,p))}if(o>=0&&o<=127)return(g<<2|f)>>>0
for(p=b;p<c;++p){if(!(p<s))return A.b(a,p)
if(a.charCodeAt(p)>127)break}throw A.n(A.b4(h,a,p))},
pA(a,b,c,d){var s=A.pB(a,b,c),r=(d&3)+(s-b),q=B.c.aZ(r,2)*3,p=r&3
if(p!==0&&s<c)q+=p-1
if(q>0)return new Uint8Array(q)
return $.oh()},
pB(a,b,c){var s,r=a.length,q=c,p=q,o=0
for(;;){if(!(p>b&&o<2))break
A:{--p
if(!(p>=0&&p<r))return A.b(a,p)
s=a.charCodeAt(p)
if(s===61){++o
q=p
break A}if((s|32)===100){if(p===b)break;--p
if(!(p>=0&&p<r))return A.b(a,p)
s=a.charCodeAt(p)}if(s===51){if(p===b)break;--p
if(!(p>=0&&p<r))return A.b(a,p)
s=a.charCodeAt(p)}if(s===37){++o
q=p
break A}break}}return q},
n7(a,b,c,d){var s,r,q
if(b===c)return d
s=-d-1
for(r=a.length;s>0;){if(!(b<r))return A.b(a,b)
q=a.charCodeAt(b)
if(s===3){if(q===61){s-=3;++b
break}if(q===37){--s;++b
if(b===c)break
if(!(b<r))return A.b(a,b)
q=a.charCodeAt(b)}else break}if((s>3?s-3:s)===2){if(q!==51)break;++b;--s
if(b===c)break
if(!(b<r))return A.b(a,b)
q=a.charCodeAt(b)}if((q|32)!==100)break;++b;--s
if(b===c)break}if(b!==c)throw A.n(A.b4("Invalid padding character",a,b))
return-s-1},
mH(a,b,c){return new A.dy(a,b)},
q5(a){return a.m()},
pE(a,b){return new A.kx(a,[],A.qN())},
pF(a,b,c){var s,r=new A.d0(""),q=A.pE(r,b)
q.bb(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
fo:function fo(a,b){this.a=a
this.b=b
this.c=null},
fp:function fp(a){this.a=a},
dg:function dg(){},
fT:function fT(){},
kk:function kk(a){this.a=0
this.b=a},
fS:function fS(){},
kj:function kj(){this.a=0},
c_:function c_(){},
ep:function ep(){},
dy:function dy(a,b){this.a=a
this.b=b},
eI:function eI(a,b){this.a=a
this.b=b},
eH:function eH(){},
iS:function iS(a){this.b=a},
iR:function iR(a){this.a=a},
ky:function ky(){},
kz:function kz(a,b){this.a=a
this.b=b},
kx:function kx(a,b,c){this.c=a
this.a=b
this.b=c},
fN(a){var s=A.mT(a,null)
if(s!=null)return s
throw A.n(A.b4(a,null,null))},
nK(a){var s=A.p8(a)
if(s!=null)return s
throw A.n(A.b4("Invalid double",a,null))},
oP(a,b){a=A.af(a,new Error())
if(a==null)a=A.ed(a)
a.stack=b.t(0)
throw a},
bj(a,b,c,d){var s,r=c?J.mF(a,d):J.mE(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
eN(a,b,c){var s,r=A.d([],c.j("o<0>"))
for(s=J.a0(a);s.l();)B.a.k(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
p(a,b){var s,r
if(Array.isArray(a))return A.d(a.slice(0),b.j("o<0>"))
s=A.d([],b.j("o<0>"))
for(r=J.a0(a);r.l();)B.a.k(s,r.gp())
return s},
pm(a){var s
A.cZ(0,"start")
s=A.pn(a,0,null)
return s},
pn(a,b,c){var s=a.length
if(b>=s)return""
return A.p9(a,b,s)},
n_(a){return new A.eF(a,A.p_(a,!1,!0,!1,!1,""))},
n2(a,b,c){var s=J.a0(b)
if(!s.l())return a
if(c.length===0){do a+=A.z(s.gp())
while(s.l())}else{a+=A.z(s.gp())
while(s.l())a=a+c+A.z(s.gp())}return a},
pk(){return A.cK(new Error())},
oF(a,b,c,d,e,f,g,h,i){var s="microsecond",r=A.pa(a,b,c,d,e,f,g,h,i)
if(r==null)return null
if(h>999)A.bs(A.aY(h,0,999,s,null))
if(r<-864e13||r>864e13)A.bs(A.aY(r,-864e13,864e13,"millisecondsSinceEpoch",null))
if(r===864e13&&h!==0)A.bs(A.eh(h,s,"Time including microseconds is outside valid range"))
A.cI(i,"isUtc",t.y)
return new A.bH(r,h,i)},
oH(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.o4().cG(a)
if(c!=null){s=new A.hH()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.fN(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.fN(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.fN(q)
if(4>=r.length)return A.b(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.b(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.b(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.b(r,7)
j=new A.hI().$1(r[7])
i=B.c.bw(j,1000)
q=r.length
if(8>=q)return A.b(r,8)
h=r[8]!=null
if(h){if(9>=q)return A.b(r,9)
g=r[9]
if(g!=null){f=g==="-"?-1:1
if(10>=q)return A.b(r,10)
q=r[10]
q.toString
e=A.fN(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.oF(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.n(A.b4("Time out of range",a,null))
return d}else throw A.n(A.b4("Invalid date format",a,null))},
mA(a){var s,r
try{s=A.oH(a)
return s}catch(r){if(A.bY(r) instanceof A.dq)return null
else throw r}},
mz(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
oG(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
hG(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
bI(a){if(a>=10)return""+a
return"0"+a},
aj(a,b,c){var s,r,q
for(s=a.length,r=0;r<s;++r){q=a[r]
if(q.b===b)return q}throw A.n(A.eh(b,"name","No enum value with that name"))},
et(a){if(typeof a=="number"||A.m7(a)||a==null)return J.dd(a)
if(typeof a=="string")return JSON.stringify(a)
return A.mU(a)},
oQ(a,b){A.cI(a,"error",t.D)
A.cI(b,"stackTrace",t.l)
A.oP(a,b)},
ej(a){return new A.ei(a)},
df(a,b){return new A.bu(!1,null,b,a)},
eh(a,b,c){return new A.bu(!0,a,b,c)},
oq(a,b,c){return a},
lW(a,b){return new A.dJ(null,null,!0,a,b,"Value not in range")},
aY(a,b,c,d,e){return new A.dJ(b,c,!0,a,d,"Invalid value")},
mZ(a,b,c){if(0>a||a>c)throw A.n(A.aY(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.n(A.aY(b,a,c,"end",null))
return b}return c},
cZ(a,b){if(a<0)throw A.n(A.aY(a,0,null,b,null))
return a},
iN(a,b,c,d){return new A.ey(b,!0,a,d,"Index out of range")},
bD(a){return new A.dT(a)},
n5(a){return new A.fb(a)},
lY(a){return new A.dQ(a)},
ai(a){return new A.eo(a)},
b4(a,b,c){return new A.dq(a,b,c)},
oV(a,b,c){var s,r
if(A.mg(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.d([],t.s)
B.a.k($.b1,a)
try{A.qr(a,s)}finally{if(0>=$.b1.length)return A.b($.b1,-1)
$.b1.pop()}r=A.n2(b,t.e7.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
iO(a,b,c){var s,r
if(A.mg(a))return b+"..."+c
s=new A.d0(b)
B.a.k($.b1,a)
try{r=s
r.a=A.n2(r.a,a,", ")}finally{if(0>=$.b1.length)return A.b($.b1,-1)
$.b1.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
qr(a,b){var s,r,q,p,o,n,m,l=J.a0(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.l())return
s=A.z(l.gp())
B.a.k(b,s)
k+=s.length+2;++j}if(!l.l()){if(j<=5)return
if(0>=b.length)return A.b(b,-1)
r=b.pop()
if(0>=b.length)return A.b(b,-1)
q=b.pop()}else{p=l.gp();++j
if(!l.l()){if(j<=4){B.a.k(b,A.z(p))
return}r=A.z(p)
if(0>=b.length)return A.b(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.l();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2;--j}B.a.k(b,"...")
return}}q=A.z(p)
r=A.z(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.a.k(b,m)
B.a.k(b,q)
B.a.k(b,r)},
cV(a,b,c,d){var s
if(B.f===c){s=J.aR(a)
b=J.aR(b)
return A.jO(A.bR(A.bR($.fQ(),s),b))}if(B.f===d){s=J.aR(a)
b=J.aR(b)
c=J.aR(c)
return A.jO(A.bR(A.bR(A.bR($.fQ(),s),b),c))}s=J.aR(a)
b=J.aR(b)
c=J.aR(c)
d=J.aR(d)
d=A.jO(A.bR(A.bR(A.bR(A.bR($.fQ(),s),b),c),d))
return d},
p3(a){var s,r,q=$.fQ()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.j)(a),++r)q=A.bR(q,J.aR(a[r]))
return A.jO(q)},
bH:function bH(a,b,c){this.a=a
this.b=b
this.c=c},
hH:function hH(){},
hI:function hI(){},
cn:function cn(){},
fk:function fk(){},
T:function T(){},
ei:function ei(a){this.a=a},
bT:function bT(){},
bu:function bu(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dJ:function dJ(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
ey:function ey(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
dT:function dT(a){this.a=a},
fb:function fb(a){this.a=a},
dQ:function dQ(a){this.a=a},
eo:function eo(a){this.a=a},
f_:function f_(){},
dP:function dP(){},
kl:function kl(a){this.a=a},
dq:function dq(a,b,c){this.a=a
this.b=b
this.c=c},
h:function h(){},
aq:function aq(a,b,c){this.a=a
this.b=b
this.$ti=c},
aw:function aw(){},
N:function N(){},
fD:function fD(){},
d0:function d0(a){this.a=a},
iL:function iL(a){this.a=a},
iM:function iM(a){this.a=a},
oJ(a){var s,r,q,p=t.P.a(a.i(0,"project")),o=A.x(a.i(0,"lang"))
if(o==null)o="en"
s=t.av
if(s.b(a.i(0,"strings"))){r=t.N
r=A.l(r,r)
for(s=s.a(a.i(0,"strings")).gaL(),s=s.gq(s);s.l();){q=s.gp()
r.h(0,A.z(q.a),A.z(q.b))}s=r}else s=null
r=A.V(a.i(0,"sizeZones"))
q=A.V(a.i(0,"sizeMain"))
return new A.hL(p,o,s,r!==!1,q!==!1)},
qt(){var s=new A.an($.ab,t.cU)
s.bX(null)
return s},
lp(a,b){var s=null
return A.rf(a,b)},
rf(a,a0){var s=0,r=A.nx(t.r),q=1,p=[],o,n,m,l,k,j,i,h,g,f,e,d,c,b
var $async$lp=A.nC(function(a1,a2){if(a1===1){p.push(a2)
s=q}for(;;)switch(s){case 0:c=null
q=3
o=A.oJ(a)
n=A.pb(o.a)
if(o.c!=null&&!$.kN.E(o.b)){g=o.b
f=o.c
f.toString
$.kN.h(0,g,new A.eJ(f))}g=o.b
m=new A.iL(B.a.v(B.f9,g)?g:"en")
l=A.oK(n,new A.lq(m))
g=o.d
f=o.e
e=c
if(e==null)e=A.qS()
s=6
return A.nn(l.b3(new A.lr(a0),f,g,e),$async$lp)
case 6:k=a2
j=A.l(t.N,t.z)
J.lM(j,"type","done")
J.mm(j,new A.hM(k,n.e,n.r).m())
a0.$1(j)
q=1
s=5
break
case 3:q=2
b=p.pop()
i=A.bY(b)
h=A.cK(b)
a0.$1(A.X(["type","error","message",A.z(i),"stack",A.z(h)],t.N,t.z))
s=5
break
case 2:s=1
break
case 5:return A.np(null,r)
case 1:return A.no(p.at(-1),r)}})
return A.nq($async$lp,r)},
hL:function hL(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
hM:function hM(a,b,c){this.a=a
this.b=b
this.c=c},
hN:function hN(){},
lq:function lq(a){this.a=a},
lr:function lr(a){this.a=a},
oK(a,b){var s=Date.now(),r=t.N,q=A.d([],t.k),p=A.d([],t.s),o=A.d([],t.o6),n=A.d([],t.p4),m=A.d([],t.cu),l=A.lU(a).bA()
return new A.er(a,b,l,new A.eq(new A.bH(s,0,!1),A.l(r,t.kV),A.l(r,t.oY),q,p,o,n,m,A.K(r)),A.l(r,r),A.l(r,t.x))},
bv:function bv(a,b){this.a=a
this.b=b},
cl:function cl(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
er:function er(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=null},
i_:function i_(){},
i6:function i6(){},
ij:function ij(){},
ii:function ii(){},
ik:function ik(a,b,c){this.a=a
this.b=b
this.c=c},
hU:function hU(a){this.a=a},
i0:function i0(){},
i5:function i5(a){this.a=a},
i4:function i4(){},
i7:function i7(a){this.a=a},
hV:function hV(a){this.a=a},
hW:function hW(){},
hX:function hX(a){this.a=a},
hY:function hY(){},
hZ:function hZ(a){this.a=a},
ih:function ih(a){this.a=a},
im:function im(){},
io:function io(a,b,c){this.a=a
this.b=b
this.c=c},
i3:function i3(a){this.a=a},
i1:function i1(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
i2:function i2(){},
iw:function iw(){},
iv:function iv(a,b,c){this.a=a
this.b=b
this.c=c},
ix:function ix(a){this.a=a},
iy:function iy(a){this.a=a},
iz:function iz(){},
iA:function iA(){},
ia:function ia(a,b,c){this.a=a
this.b=b
this.c=c},
ib:function ib(a,b){this.a=a
this.b=b},
i8:function i8(a){this.a=a},
i9:function i9(){},
ic:function ic(a,b,c){this.a=a
this.b=b
this.c=c},
id:function id(a,b){this.a=a
this.b=b},
ie:function ie(a,b){this.a=a
this.b=b},
ig:function ig(a){this.a=a},
il:function il(a,b){this.a=a
this.b=b},
iu:function iu(a){this.a=a},
ip:function ip(a){this.a=a},
iq:function iq(){},
ir:function ir(a){this.a=a},
is:function is(){},
it:function it(){},
qR(h8,h9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7,f8,f9,g0,g1,g2,g3,g4,g5,g6,g7,g8,g9,h0,h1,h2,h3,h4=null,h5=h8.e,h6=t.iC,h7=A.p(new A.b0(h5,h6),h6.j("h.E"))
h6=t.mt
s=h6.j("A<h.E>")
r=A.p(new A.A(new A.b0(h5,h6),h6.j("q(h.E)").a(new A.kW()),s),s.j("h.E"))
if(h7.length===0&&r.length===0)return h4
q=h8.b
h6=q.p3
s=q.p4
p=q.R8
o=new A.jD(h6,s,p)
n=1+Math.max(0,q.RG)/100
m=A.d([],t.kD)
l=A.d([],t.ou)
k=A.d([],t.s)
j=t.N
i=t.i
h=A.l(j,i)
g=new A.dk(m,l,k,h)
f=t.cA
e=A.p(new A.b0(h5,f),f.j("h.E"))
if(h7.length===0){B.a.k(k,"elec_no_controller")
return g}h5=Math.max(q.x,0.1)
f=A.d([],t.K)
d=A.d([],t.oA)
c=t.L
b=new A.k4(h5,f,d,A.l(t.gn,c))
for(h5=r.length,a=0;a<r.length;r.length===h5||(0,A.j)(r),++a){a0=r[a]
for(f=a0.d,a1=a0.a,a2=1;a2<f.length;++a2){a3=b.cJ(f[a2-1])
if(!(a2<f.length))return A.b(f,a2)
b.bz(a3,b.cJ(f[a2]),a1)}}h5=t.S
a4=A.l(j,h5)
for(f=h7.length,a=0;a<h7.length;h7.length===f||(0,A.j)(h7),++a){a5=h7[a]
a6=b.cC(a5.d)
if(a6!=null)a4.h(0,a5.a,a6)}a7=A.l(j,h5)
for(f=e.length,a=0;a<e.length;e.length===f||(0,A.j)(e),++a){a8=e[a]
a6=b.cC(a8.d)
if(a6!=null)a7.h(0,a8.a,a6)}a9=b.dI()
f=A.l(j,t.lJ)
for(a1=new A.J(a4,a4.$ti.j("J<1,2>")).gq(0);a1.l();){b0=a1.d
f.h(0,b0.a,b.cW(b0.b,a9))}b1=A.l(j,j)
b2=A.l(j,i)
for(a1=e.length,a=0;a3=e.length,a<a3;e.length===a1||(0,A.j)(e),++a){a3=e[a].a
a6=a7.i(0,a3)
if(a6==null)continue
for(b3=h7.length,b4=0;b4<h7.length;h7.length===b3||(0,A.j)(h7),++b4){b5=h7[b4].a
b6=f.i(0,b5)
b7=b6==null?h4:b6.a.i(0,a6)
if(b7!=null){b6=b2.i(0,a3)
b6=b7<(b6==null?1/0:b6)}else b6=!1
if(b6){b2.h(0,a3,b7)
b1.h(0,a3,b5)}}}for(a=0;a<e.length;e.length===a3||(0,A.j)(e),++a){a1=e[a].a
if(!b1.E(a1))B.a.k(k,"elec_unwired:"+a1)}a1=A.K(h5)
for(a3=new A.M(f,f.r,f.e,f.$ti.j("M<2>"));a3.l();)a1.B(0,a3.d.a.ga8())
for(a3=r.length,a=0;a<r.length;r.length===a3||(0,A.j)(r),++a){a0=r[a]
b8=b.bF(B.a.gu(a0.d))
if(b8==null||!a1.v(0,b8))B.a.k(k,"elec_wire_orphan:"+a0.a)}for(a1=h7.length,a=0;a<h7.length;h7.length===a1||(0,A.j)(h7),++a){a3=h7[a].a
if(!a4.E(a3))B.a.k(k,"elec_ctrl_unwired:"+a3)}b9=h8.c.gdZ()
if(b9.length===0&&b1.a!==0)B.a.k(k,"elec_no_wires")
if(b9.length===0)c0=A.d([new A.Z("","","","",1.5,12.066666666666668,0,!0)],t.lS)
else c0=b9
for(a1=h7.length,p-=1e-9,a3=t.e,b3=t.pf,b5=t.fG,b6=t.iJ,c1=t.oi,c2=t.bC,c3=t.pj,c4=t.ey,c5=t.t,c6=t.l1,a=0;a<h7.length;h7.length===a1||(0,A.j)(h7),++a){a5=h7[a]
c7=A.d([],c6)
for(c8=e.length,c9=a5.a,b4=0;b4<e.length;e.length===c8||(0,A.j)(e),++b4){a8=e[b4]
if(b1.i(0,a8.a)===c9)c7.push(a8)}B.a.ak(c7,new A.kX(b2))
c8=c7.length
if(c8===0){B.a.k(l,new A.c1(c9,a5.c,a5.e,0,h4,0,0,0,0))
continue}d0=a5.e
if(c8>d0)B.a.k(k,"elec_stations:"+c9)
d1=f.i(0,c9).b
d2=A.l(j,c)
for(c8=c7.length,b4=0;b4<c7.length;c7.length===c8||(0,A.j)(c7),++b4){a8=c7[b4]
d3=A.d([],c5)
d4=a8.a
d5=a7.i(0,d4)
d5.toString
a6=d5
d6=0
for(;;){if(a6!==a4.i(0,c9)){d7=d6+1
d5=d6<1e5
d6=d7}else d5=!1
if(!d5)break
d5=d1.i(0,a6)
d5.toString
B.a.k(d3,d5)
if(!(d5>=0&&d5<d.length))return A.b(d,d5)
d5=d[d5]
d8=d5.a
a6=a6===d8?d5.b:d8}d2.h(0,d4,d3)}c8=A.K(h5)
for(d4=new A.M(d2,d2.r,d2.e,d2.$ti.j("M<2>"));d4.l();)for(d5=J.a0(d4.d);d5.l();)c8.k(0,A.aI(d5.gp()))
d9=c8.P(0,0,new A.kY(b),i)
c8=A.K(j)
for(d4=c7.length,b4=0;b4<c7.length;c7.length===d4||(0,A.j)(c7),++b4)c8.k(0,c7[b4].a)
e0=A.d([],c4)
for(d4=h9.length,b4=0;b4<h9.length;h9.length===d4||(0,A.j)(h9),++b4){e1=h9[b4].ed(c8)
if(e1.ga0(0))B.a.k(e0,e1)}for(c8=c7.length,b4=0;b4<c7.length;c7.length===c8||(0,A.j)(c7),++b4){a8=c7[b4]
if(!B.a.Z(e0,new A.kZ(a8)))B.a.k(e0,A.al([a8.a],j))}e2=B.a.P(e0,0,new A.l_(),h5)
c8=a5.w
if(c8>0&&e2>c8)B.a.k(k,"elec_simultaneous:"+c9)
e3=new A.l4(d2,o,b,n)
c8=A.l(j,i)
for(d4=c7.length,b4=0;d5=c7.length,b4<d5;c7.length===d4||(0,A.j)(c7),++b4){a8=c7[b4]
c8.h(0,a8.a,new A.aF(new A.A(e0,b3.a(new A.l0(a8)),b5),c2.a(new A.l1(e3,a8)),c3).P(0,0,B.m,i))}d4=A.l(j,h5)
for(b4=0;b4<c7.length;c7.length===d5||(0,A.j)(c7),++b4){a8=c7[b4]
d4.h(0,a8.a,new A.aF(new A.A(e0,b3.a(new A.l2(a8)),b5),b6.a(new A.l3()),c1).P(0,1,B.dd,h5))}e4=new A.l5(a5,o,b2,n,c8)
for(c8=c0.length,d5=d9*n,e5=h4,e6=e5,e7=1/0,b4=0;b4<c0.length;c0.length===c8||(0,A.j)(c0),++b4){e8=c0[b4]
e9=A.l(j,a3)
f0=d5*e8.r
f2=c7.length
f3=0
for(;;){if(!(f3<c7.length)){f1=!0
break}a8=c7[f3]
for(f4=c0.length,f5=a8.a,f6=h4,f7=0;f7<c0.length;c0.length===f4||(0,A.j)(c0),++f7){f8=c0[f7]
f9=e4.$3(f5,f8,e8)
if(typeof f9!=="number")return f9.cU()
if(f9>=p)f9=f6==null||f8.r<f6.r-1e-12
else f9=!1
if(f9)f6=f8}if(f6==null){f1=!1
break}e9.h(0,f5,f6)
f4=b2.i(0,f5)
f4.toString
f0+=f4*n*f6.r
c7.length===f2||(0,A.j)(c7);++f3}if(f1&&f0<e7-1e-9){e7=f0
e5=e9
e6=e8}}g0=e6==null?B.a.gF(c0):e6
if(e5==null){c8=A.l(j,a3)
for(f2=c7.length,b4=0;b4<c7.length;c7.length===f2||(0,A.j)(c7),++b4)c8.h(0,c7[b4].a,B.a.gF(c0))
g1=c8}else g1=e5
for(c8=e0.length,g2=0,b4=0;b4<e0.length;e0.length===c8||(0,A.j)(e0),++b4){g3=e0[b4]
g2=Math.max(g2,h6+(g3.gn(g3)-1)*s)}for(c8=c7.length,f2=g0.a,f4=f2.length===0,g4=0,b4=0;b4<c7.length;c7.length===c8||(0,A.j)(c7),++b4){a8=c7[b4]
f5=a8.a
f9=g1.i(0,f5)
f9.toString
g5=e4.$3(f5,f9,g0)
g6=g5>=p
if(!g6)B.a.k(k,"elec_voltage:"+f5)
g7=b2.i(0,f5)
g7.toString
g8=g7*n
g7=a8.f
g7=g7.length!==0?g7:a8.c;++g4
g9=b2.i(0,f5)
g9.toString
f9=f9.a
h0=f9.length===0
h1=h0?h4:f9
h2=f4?h4:f2
h3=d4.i(0,f5)
h3.toString
B.a.k(m,new A.cD(f5,g7,c9,g4,g9,g8,h1,h2,g5,g6,h3))
if(!h0){f5=h.i(0,f9)
h.h(0,f9,(f5==null?0:f5)+g8)}}if(!f4){c8=h.i(0,f2)
h.h(0,f2,(c8==null?0:c8)+d5)}c8=a5.c
c7=c7.length
B.a.k(l,new A.c1(c9,c8,d0,c7,f4?h4:f2,d9,d5,e2,g2))}return g},
cD:function cD(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k},
c1:function c1(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
dk:function dk(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
iC:function iC(){},
iD:function iD(){},
dV:function dV(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
k4:function k4(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
k8:function k8(){},
k7:function k7(){},
k5:function k5(){},
k6:function k6(){},
k9:function k9(){},
jD:function jD(a,b,c){this.a=a
this.b=b
this.c=c},
kW:function kW(){},
kX:function kX(a){this.a=a},
kY:function kY(a){this.a=a},
kZ:function kZ(a){this.a=a},
l_:function l_(){},
l4:function l4(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
l0:function l0(a){this.a=a},
l1:function l1(a,b){this.a=a
this.b=b},
l2:function l2(a){this.a=a},
l3:function l3(){},
l5:function l5(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
nM(a,b,c,d){var s,r=new A.l9()
if(c>0&&Math.abs(c-b)>0.5)s=A.z(r.$1(b))+" \xd7 "+A.z(r.$1(c))+" mm"
else s=b>0?A.z(r.$1(b))+" mm":""
return B.d.aG(A.z(d.$1("fit."+a.b))+" "+s)},
rh(f5,f6,f7,f8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7=null,e8=f5.c,e9=t.N,f0=A.l(e9,t.kh),f1=new A.lC(f0),f2=new A.lE(e8,f7),f3=new A.lB(),f4=A.l(e9,t.h)
for(s=f5.e,r=s.length,q=0;p=s.length,q<p;s.length===r||(0,A.j)(s),++q){o=s[q]
f4.h(0,o.a,o)}r=A.K(e9)
for(q=0;q<s.length;s.length===p||(0,A.j)(s),++q){o=s[q]
if(o instanceof A.am||o instanceof A.aG)r.k(0,o.a)}for(p=f6.a,n=A.k(p).j("M<2>"),m=new A.M(p,p.r,p.e,n),l=t.n,k=t.K;m.l();){j=m.d
i=j.w
h=A.t(i)
g=h.j("q(1)")
h=h.j("A<1>")
f=h.j("h.E")
e=A.p(new A.A(i,g.a(new A.lt(f2)),h),f)
d=A.t(e)
c=d.j("q(1)")
d=d.j("A<1>")
b=d.j("h.E")
a=A.p(new A.A(e,c.a(new A.lu(r)),d),b)
a0=A.p(new A.A(e,c.a(new A.lv(r)),d),b)
for(d=j.r,c=A.k(d),b=new A.Y(d,d.r,c.j("Y<1>")),b.c=d.e,c=c.c,a1=e7,a2=a1,a3=a2,a4=a3;b.l();){d=b.d
o=f4.i(0,d==null?c.a(d):d)
if(o instanceof A.ao){a4=o
continue}if(o instanceof A.b6||o instanceof A.bA){a3=o
continue}if(o instanceof A.aH){a2=o
continue}if(o instanceof A.b7){a1=o
continue}continue}a5=A.p(new A.A(i,g.a(new A.lw()),h),f)
i=a5.length
if(i!==0)h=a4!=null||a3!=null
else h=!1
if(h)for(h=a3 instanceof A.b6,g=a4!=null,f=j.a,d=A.t(a),c=d.j("e(1)"),d=d.j("u<1,e>"),q=0;q<a5.length;a5.length===i||(0,A.j)(a5),++q){if(a5[q].b!==f)continue
if(g){b=e8.a9(a4.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}else a6=0
if(h){b=e8.a9(a3.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}if(a.length!==0)a7=new A.u(a,c.a(f2),d).M(0,B.m)
else a7=a0.length!==0?f2.$1(B.a.gu(a0)):0
if(a6<=0)a6=a7
b=a6>0
if(b)f1.$3$qty(B.ao,a6,2)
if(a7>0&&b&&Math.abs(a7-a6)>0.5)f1.$4$qty$size2(B.v,Math.max(a7,a6),2,Math.min(a7,a6))}if(a.length===0)continue
i=A.t(a)
h=i.j("u<1,e>")
a8=A.p(new A.u(a,i.j("e(1)").a(f2),h),h.j("w.E"))
a9=B.a.M(a8,B.m)
b0=a.length
b1=a4!=null||a3!=null||a2!=null||a1!=null
if(b0===1){if(!b1&&a0.length===0&&a5.length===0)f1.$2(B.K,B.a.gu(a8))
if(a1!=null){b2=e8.a1(a1.f)
if(b2!=null)f1.$2(B.n,b2.w)}continue}if(b0===2){if(0>=b0)return A.b(a,0)
b3=a[0]
if(1>=b0)return A.b(a,1)
b4=a[1]
j=j.a
b5=f3.$2(b3,j)
b6=f3.$2(b4,j)
j=b5.a
i=b5.b
b7=Math.acos(B.b.a7(-j*b6.a+-i*b6.b,-1,1))*180/3.141592653589793
b8=f2.$1(b3)
b9=f2.$1(b4)
c0=Math.abs(b8-b9)>0.5
if(b7>60)f1.$2(B.al,a9)
else if(b7>15)f1.$2(B.am,a9)
else if(b3.f!==b4.f&&!c0&&a5.length===0)f1.$2(B.W,a9)
if(c0)f1.$3$size2(B.v,Math.max(b8,b9),Math.min(b8,b9))
if(a1!=null){b2=e8.a1(a1.f)
if(b2!=null){j=b2.w
f1.$3$size2(B.J,a9,j>0?Math.min(j,a9):0)
f1.$2(B.n,j)}}continue}if(b0===3){for(j=j.a,c1=0,c2=1/0,c3=0;c3<3;++c3){i=A.d([],k)
for(c4=0;c4<3;++c4)if(c4!==c3){if(!(c4<a.length))return A.b(a,c4)
i.push(f3.$2(a[c4],j))}h=i.length
if(0>=h)return A.b(i,0)
g=i[0]
if(1>=h)return A.b(i,1)
i=i[1]
c5=-(-g.a*i.a+-g.b*i.b)
if(c5<c2){c2=c5
c1=c3}}j=A.d([],l)
for(c3=0;c3<3;++c3)if(c3!==c1){if(!(c3<a.length))return A.b(a,c3)
j.push(f2.$1(a[c3]))}c6=B.a.M(j,B.m)
if(!(c1>=0&&c1<a.length))return A.b(a,c1)
c7=f2.$1(a[c1])
i=Math.max(c6,c7)
f1.$3$size2(B.J,i,c7<c6-0.5?c7:0)
i=j.length
if(0>=i)return A.b(j,0)
h=j[0]
if(1>=i)return A.b(j,1)
if(Math.abs(h-j[1])>0.5)f1.$3$size2(B.v,B.a.M(j,B.m),B.a.M(j,B.H))
if(c7>c6+0.5)f1.$3$size2(B.v,c7,c6)
continue}f1.$2(B.an,a9)
for(j=a8.length,i=a9-0.5,q=0;q<a8.length;a8.length===j||(0,A.j)(a8),++q){b2=a8[q]
if(b2<i)f1.$3$size2(B.v,a9,b2)}}c8=A.l(e9,t.cr)
for(f4=new A.M(p,p.r,p.e,n);f4.l();){p=f4.d
n=p.b
c8.h(0,B.b.a4(n.a,3)+"|"+B.b.a4(n.b,3)+"|"+p.d.b,p)}c9=new A.lD(c8)
d0=new A.lz(r)
for(f4=s.length,r=f6.z,p=f5.b.ok,n=p>0,m=f6.b,l=A.t(m),k=l.j("q(1)"),l=l.j("A<1>"),j=l.j("h.E"),q=0;q<s.length;s.length===f4||(0,A.j)(s),++q){o=s[q]
if(r.v(0,o.a))continue
A:{i={}
i.a=null
h=o instanceof A.am
if(h)i.a=o
if(h){d1=new A.A(m,k.a(new A.lx(i)),l)
if(!d1.gq(0).l())break A
d2=d1.gq(0)
if(!d2.l())A.bs(A.ak())
h=d2.gp().x
h=e8.R(h==null?i.a.e:h)
d3=h==null?e7:h.e
if(d3==null)d3=16
d4=d0.$2(c9.$2(J.bZ(i.a.d),B.h),i.a.a)
d5=d0.$2(c9.$2(J.lN(i.a.d),B.h),i.a.a)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.K,d3)
if(!d5)f1.$2(B.K,d3)
a1=e8.a1(i.a.r)
if(a1!=null&&i.a.gb8()>0)f1.$3$qty(B.n,a1.w,i.a.gb8())
break A}i=o instanceof A.aG
d6=i?o:e7
if(i){d7=e8.ai(d6.e)
d3=d7==null?e7:d7.e
if(d3==null)d3=16
i=d6.d
h=J.a5(i)
g=c9.$2(h.gu(i),B.h)
f=d6.a
d4=d0.$2(g,f)
d5=d0.$2(c9.$2(h.gF(i),B.h),f)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.L,d3)
if(!d5)f1.$2(B.L,d3)
break A}i={}
i.a=null
h=o instanceof A.aM
if(h)i.a=o
if(h){if(n){d1=A.p(new A.A(m,k.a(new A.ly(i)),l),j)
if(d1.length===0)break A
h=f7.$1(B.a.gu(d1))
d3=h==null?e7:h.e
if(d3==null)d3=0
d8=B.b.I(A.b2(i.a.d)/p)
if(d3>0&&d8>0)f1.$3$qty(B.W,d3,d8)}break A}break A}}d9=A.l(e9,t.q)
e0=A.d([],t.e0)
e1=new A.ls()
for(e9=new A.M(f0,f0.r,f0.e,f0.$ti.j("M<2>"));e9.l();){f4=e9.d
d8=f4.a
e2=f4.b
f4=d8.a
s=d8.b
r=d8.c
e3=e8.e3(f4,s,r)
if(e3==null){B.a.k(e0,d8)
e4=A.nM(f4,s,r,f8)+" *"
e5="generic|"+e4
e6=d9.i(0,e5)
if(e6!=null)e6.d+=e2
else d9.h(0,e5,new A.ah(e1.$1(f4),e4,"un",e2,0,e7,"",""))
continue}s=e3.a
e6=d9.i(0,s)
if(e6!=null)e6.d+=e2
else d9.h(0,s,new A.ah(e1.$1(f4),e3.b,"un",e2,e3.w,s,e3.d,e3.c))}for(e9=d9.$ti,f4=new A.M(d9,d9.r,d9.e,e9.j("M<2>"));f4.l();){s=f4.d
s.d=Math.ceil(s.d)}e9=e9.j("av<2>")
e9=A.p(new A.av(d9,e9),e9.j("h.E"))
return new A.iI(e9,e0)},
dp:function dp(a,b,c){this.a=a
this.b=b
this.c=c},
iI:function iI(a,b){this.a=a
this.b=b},
l9:function l9(){},
lC:function lC(a){this.a=a},
lE:function lE(a,b){this.a=a
this.b=b},
lB:function lB(){},
lt:function lt(a){this.a=a},
lu:function lu(a){this.a=a},
lv:function lv(a){this.a=a},
lw:function lw(){},
lD:function lD(a){this.a=a},
lz:function lz(a){this.a=a},
lA:function lA(a,b){this.a=a
this.b=b},
lx:function lx(a){this.a=a},
ly:function ly(a){this.a=a},
ls:function ls(){},
ri(c2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7={},b8=c2.b,b9=b8.length,c0=c2.c,c1=c0.length
if(b9===0)return new A.cR(B.N,B.bp,0,0)
s=A.d([],t.ot)
r=A.d([],t.n)
for(q=c0.length,p=0,o=0,n=0;n<c0.length;c0.length===q||(0,A.j)(c0),++n){m=c0[n]
l=m.b
k=m.c
if(k<0){k=-k
switch(l.a){case 0:j=B.bt
break
case 2:j=B.a0
break
case 1:j=B.ar
break
default:j=null}l=j}B.a.k(s,l)
B.a.k(r,k)
if(l!==B.ar)++p
if(l!==B.a0)++o}i=b9+p
h=i+o
g=h+1
f=J.eC(c1,t.kI)
for(e=0;e<c1;++e)f[e]=new Float64Array(g)
q=t.S
d=A.bj(c1,-1,!1,q)
c=A.d([],t.t)
for(b=i,a=b9,a0=0;a0<c1;++a0){if(!(a0<c0.length))return A.b(c0,a0)
m=c0[a0]
a1=m.c<0?-1:1
if(!(a0<f.length))return A.b(f,a0)
a2=f[a0]
m.a.a_(0,new A.lF(b9,a2,a1))
if(!(a0<r.length))return A.b(r,a0)
j=r[a0]
a2.$flags&2&&A.ag(a2)
a3=a2.length
if(!(h<a3))return A.b(a2,h)
a2[h]=j
if(!(a0<s.length))return A.b(s,a0)
switch(s[a0].a){case 0:if(!(a<a3))return A.b(a2,a)
a2[a]=1
a4=a+1
B.a.h(d,a0,a)
a=a4
break
case 2:if(!(a<a3))return A.b(a2,a)
a2[a]=-1;++a
if(!(b<a3))return A.b(a2,b)
a2[b]=1
B.a.h(d,a0,b)
a5=b+1
B.a.k(c,b)
b=a5
break
case 1:if(!(b<a3))return A.b(a2,b)
a2[b]=1
B.a.h(d,a0,b)
a5=b+1
B.a.k(c,b)
b=a5
break}}b7.a=0
a6=new A.lG(f,g,c1,d)
a7=new A.lI(b7,new A.lH(g,h,c1,d,f),50*(c1+h)+1000,1e-9,h,c1,f,d,a6)
c0=c.length
if(c0!==0){a8=new Float64Array(g)
for(n=0;n<c0;++n){a9=c[n]
if(!(a9<g))return A.b(a8,a9)
a8[a9]=1}b0=a7.$2(a8,B.FL)
if(b0===B.bu)return new A.cR(b0,A.bj(b9,0,!1,t.i),0,b7.a)
for(b1=0,a0=0;a0<c1;++a0)if(B.a.v(c,d[a0])){if(!(a0<f.length))return A.b(f,a0)
c0=f[a0]
if(!(h<c0.length))return A.b(c0,h)
b1+=c0[h]}if(b1>0.000001)return new A.cR(B.fq,A.bj(b9,0,!1,t.i),0,b7.a)
for(a0=0;a0<c1;++a0){if(!B.a.v(c,d[a0]))continue
c0=f.length
b3=0
for(;;){if(!(b3<i)){b2=-1
break}if(!(a0<c0))return A.b(f,a0)
j=f[a0]
if(!(b3<j.length))return A.b(j,b3)
if(Math.abs(j[b3])>1e-7){b2=b3
break}++b3}if(b2>=0)a6.$2(a0,b2)}}b4=new Float64Array(g)
for(c0=b8.length,b3=0;b3<b9;++b3){if(!(b3<c0))return A.b(b8,b3)
j=b8[b3]
if(!(b3<g))return A.b(b4,b3)
b4[b3]=j}b0=a7.$2(b4,A.cQ(c,q))
b5=A.bj(b9,0,!1,t.i)
for(a0=0;a0<c1;++a0){c0=d[a0]
if(c0<b9){if(!(a0<f.length))return A.b(f,a0)
q=f[a0]
if(!(h<q.length))return A.b(q,h)
B.a.h(b5,c0,q[h])}}for(c0=b8.length,b6=0,b3=0;b3<b9;++b3){if(!(b3<c0))return A.b(b8,b3)
b6+=b8[b3]*b5[b3]}b8=b0===B.N?B.N:b0
return new A.cR(b8,b5,b6,b7.a)},
cw:function cw(a,b){this.a=a
this.b=b},
cv:function cv(a,b,c){this.a=a
this.b=b
this.c=c},
iW:function iW(a,b,c){this.b=a
this.c=b
this.d=c},
cR:function cR(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bN:function bN(a,b){this.a=a
this.b=b},
lF:function lF(a,b,c){this.a=a
this.b=b
this.c=c},
lH:function lH(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
lG:function lG(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
lI:function lI(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
nR(b9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3=t.N,b4=A.l(b3,t.dV),b5=t.n,b6=A.d([],b5),b7=A.d([],t.nx),b8=A.d([],t.s)
for(s=b9.a,r=s.length,q=b9.w,p=b9.x,o=b9.r,n=t.S,m=b9.c,l=b9.b,k=0;k<s.length;s.length===r||(0,A.j)(s),++k){j=s[k]
i=l.i(0,j)
if(i==null)i=B.bs
h=m.i(0,j)
if(h==null)h=0
g=A.l(b3,n)
for(f=i.length,e=j+":",d=0;d<i.length;i.length===f||(0,A.j)(i),++d){c=i[d]
b=p.$1(c)
if(b==null)b=c.Q
if(typeof b!=="number")return b.aj()
a=q?o:1
a0=c.a
B.a.k(b6,b*h*a)
B.a.k(b8,e+a0)
g.h(0,a0,b6.length-1)}b4.h(0,j,g)}a1=A.l(n,n)
for(r=b9.e,p=t.i,o=t.jq,a2=0;a2<r.length;++a2){a3=r[a2]
if(a3.b!=null)continue
a4=a3.a
a4=a4>0?a4:0.001
B.a.k(b6,q?a4:Math.max(a4,0.001))
B.a.k(b8,"H"+a3.d)
a1.h(0,a2,b6.length-1)
m=a3.c
if(m!=null&&m>0){f=a1.i(0,a2)
f.toString
B.a.k(b7,new A.cv(o.a(A.X([f,1],n,p)),B.a0,m))}}for(q=s.length,k=0;k<s.length;s.length===q||(0,A.j)(s),++k){g=b4.i(0,s[k])
if(g.a===0)continue
m=A.l(n,p)
for(f=new A.M(g,g.r,g.e,A.k(g).j("M<2>"));f.l();)m.h(0,f.d,1)
B.a.k(b7,new A.cv(o.a(m),B.ar,1))}for(q=b9.f,m=q.length,k=0;k<q.length;q.length===m||(0,A.j)(q),++k){a5=q[k]
a6=A.l(n,p)
f=a5.a
if(!(f<r.length))return A.b(r,f)
e=r[f].b
if(e!=null)a7=0+e
else{f=a1.i(0,f)
f.toString
a6.h(0,f,1)
a7=0}a5.b.a_(0,new A.lj(b4,a6))
if(a6.a===0)continue
f=a5.d
if(f!=null){e=A.iU(n,p)
e.B(0,a6)
B.a.k(b7,new A.cv(o.a(e),B.bt,f+a5.c-a7))}f=a5.e
if(f!=null&&isFinite(f)){e=A.iU(n,p)
e.B(0,a6)
B.a.k(b7,new A.cv(o.a(e),B.a0,f+a5.c-a7))}}if(b6.length===0){b3=A.d([],b5)
for(b5=r.length,k=0;k<r.length;r.length===b5||(0,A.j)(r),++k){b6=r[k].b
b3.push(b6==null?0:b6)}return new A.dA(!0,B.bx)}a8=A.ri(new A.iW(b6,b7,b8))
if(a8.a!==B.N)return new A.dA(!1,B.bx)
a9=A.l(b3,t.x)
for(b3=s.length,b6=b9.d,b7=a8.b,b8=b7.length,q=t.an,k=0;k<s.length;s.length===b3||(0,A.j)(s),++k){j=s[k]
p=b4.i(0,j)
p.toString
i=l.i(0,j)
if(i==null)i=B.bs
if(p.a===0)continue
b0=A.d([],q)
for(o=i.length,d=0;d<i.length;i.length===o||(0,A.j)(i),++d){c=i[d]
n=p.i(0,c.a)
n.toString
if(!(n>=0&&n<b8))return A.b(b7,n)
b1=b7[n]
if(b1>0.02)B.a.k(b0,new A.m(c,b1))}if(b0.length===0)B.a.k(b0,new A.m(B.a.gF(i),1))
B.a.ak(b0,new A.lk())
p=b6.i(0,j)
a9.h(0,j,A.re(b0,p==null?1:p))}b2=A.d([],b5)
for(a2=0;a2<r.length;++a2){b3=r[a2].b
if(b3==null){b3=a1.i(0,a2)
b3.toString
if(!(b3>=0&&b3<b8))return A.b(b7,b3)
b3=b7[b3]}B.a.k(b2,b3)}return new A.dA(!0,a9)},
re(a,b){var s,r,q,p,o,n,m=Math.max(1,b)
if(a.length<=m)return A.ny(a)
s=A.t(a).c
r=A.c9(a,0,A.cI(m,"count",t.S),s).cQ(0)
for(s=A.c9(a,m,null,s),q=s.$ti,s=new A.aV(s,s.gn(0),q.j("aV<w.E>")),q=q.j("w.E"),p=0;s.l();){o=s.d
p+=(o==null?q.a(o):o).b}n=B.a.gF(r)
B.a.h(r,r.length-1,new A.m(n.a,n.b+p))
return A.ny(r)},
ny(a){var s,r,q,p,o=B.a.P(a,0,new A.kM(),t.i)
if(o<=0)return a
s=A.d([],t.an)
for(r=a.length,q=0;q<a.length;a.length===r||(0,A.j)(a),++q){p=a[q]
s.push(new A.m(p.a,p.b/o))}return s},
dC:function dC(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dB:function dB(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
eO:function eO(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
dA:function dA(a,b){this.a=a
this.b=b},
lj:function lj(a,b){this.a=a
this.b=b},
li:function li(a,b){this.a=a
this.b=b},
lk:function lk(){},
kM:function kM(){},
lP(a,b,c,d){return new A.b5(b,c,a,d,A.d([],t.hz),A.K(t.N),A.d([],t.I))},
mD(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return new A.I(h,g,s,i,n,f,o,j,l,r,c,a0,k,d,p,a1,m,q,a,b,e)},
lU(a){var s=t.N,r=t.C
return new A.iZ(a,new A.jb(A.l(s,t.cr),A.d([],t.I),A.l(s,t.kM),A.l(s,s),A.l(s,s),A.l(s,r),A.l(s,r),A.K(s),A.K(s),A.d([],t.s),A.K(s)),A.l(t.S,t.g2))},
c4:function c4(a,b){this.a=a
this.b=b},
bi:function bi(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
b5:function b5(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=0
_.f=e
_.r=f
_.w=g
_.x=null
_.y=!1
_.Q=_.z=null},
I:function I(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0
_.db=a1
_.dx=null},
jb:function jb(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=null},
iZ:function iZ(a,b,c){var _=this
_.a=a
_.d=_.c=_.b=$
_.e=b
_.f=c
_.r=0},
j0:function j0(){},
j1:function j1(){},
j7:function j7(){},
j9:function j9(){},
j8:function j8(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
j2:function j2(a,b,c){this.a=a
this.b=b
this.c=c},
j3:function j3(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
j4:function j4(a){this.a=a},
j5:function j5(){},
j6:function j6(a){this.a=a},
ja:function ja(a){this.a=a},
j_:function j_(){},
m5(a,b){var s=a.f/1000
if(b<=0||s<=0)return 0
switch(a.x.a){case 0:return A.nP(a.r,s,b,1)
case 1:return A.nJ(s,b,a.y,1,a.w/1000)}},
l7(a,b){var s,r=a.gbR(),q=a.c+a.ax
if(r<=0||q<=0)return 0
s=B.b.a7(b/q,0,1)
return a.a===B.E?r*(1-s*s):r*(1-s)},
l8(a,b){var s,r,q,p,o,n,m
if(b<=0)return 0
s=Math.max(4,200)
r=b/s
for(q=a.as,p=0,o=0;o<s;){n=o*r;++o
m=o*r
p+=(A.m5(a,A.l7(a,n)+q)+4*A.m5(a,A.l7(a,(n+m)/2)+q)+A.m5(a,A.l7(a,m)+q))/6*r}return p},
qH(c9,d0,d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8=A.d([],t.s),b9=d0==null?new A.kR():d0,c0=c9.gbR(),c1=c9.as,c2=c0+c1,c3=c9.c,c4=A.l8(c9,c3),c5=b9.$1(c3),c6=c9.Q,c7=c1>0?c9.at:0,c8=Math.max(c6,c7)
c7=c9.z
s=c9.cx
r=c8+c4+c5+c7+s
q=A.d([],t.i5)
p=c9.gcR()
o=A.d([0],t.n)
for(n=c9.e,m=1;m<=p;++m)o.push(m*n)
if(c3-c9.gcR()*n>0.000001)o.push(c3)
for(l=o.length,k=0;j=o.length,k<j;o.length===l||(0,A.j)(o),++k){i=o[k]
j=A.l8(c9,i)
h=b9.$1(i)
if(typeof h!=="number")return A.bG(h)
g=c6+j+h+c7+s
if(g>r)r=g}for(l=r-c7-s,f=0,k=0;k<o.length;o.length===j||(0,A.j)(o),++k,f=d){i=o[k]
h=A.l8(c9,i)
e=b9.$1(i)
if(typeof e!=="number")return A.bG(e)
d=f+1
B.a.k(q,new A.cy(f,i,A.l7(c9,i)+c1,l-h-e,b9.$1(i)))}c=c9.f/1000
b=c>0?A.fO(c,c2):0
if(b>c9.dx+0.000001)B.a.k(b8,"velocity_exceeded:"+d1)
a=c0*3600
o=c9.a
j=o===B.E
if(j){h=c9.ax
a0=c3+h
a1=a0>0&&c9.CW>0?2000*a/(a0*c9.CW):0}else{h=c9.ax
e=c3+h
a1=e>0&&c9.CW>0?1000*a/(e*c9.CW):0}a2=a1*4/3.141592653589793
e=c9.cy
if(e>0&&a2>e+0.000001)B.a.k(b8,"pivot_app_rate:"+d1)
if(c0<=0)B.a.k(b8,"pivot_no_flow:"+d1)
if(c6<=0)B.a.k(b8,"pivot_no_end_pressure:"+d1)
a3=A.d([],t.eN)
if(n>0&&c3>0){a0=c3+h
for(c6=c3-0.000001,h=a0<=0,e=c9.b,a4=a0*a0,m=0,a5=0;a5<c6;a5=a6){a6=a5+n
a7=Math.min(a6,c3)
a8=a7-a5
a9=Math.max(1,B.b.a2(a8/Math.max(e,0.1)))
if(h)b0=0
else b0=j?c0*(a7*a7-a5*a5)/a4:c0*a8/a0
b1=(a5+a7)/2
a8=A.l8(c9,b1)
b2=b9.$1(b1)
if(typeof b2!=="number")return A.bG(b2)
b3=l-a8-b2
b4=b0/a9
a8=d3.length
b5=""
if(a8!==0&&b4>0)for(b6=1/0,k=0;k<d3.length;d3.length===a8||(0,A.j)(d3),++k){b2=d3[k]
b7=b2.a
c=Math.abs(b2.b.af(Math.max(b3,0.1))-b4)
if(c<b6){b6=c
b5=b7}}++m
B.a.k(a3,new A.bO(m,a5,a7,a9,b4,b3,b5))}}return new A.cW(d1,a3,d2,o,c2,c1,r,c4,c5,c8,c7,s,p,q,c9.gcB(),c9.ay,c9.ch,a1,a2,b,b8)},
r1(a,b,c,d){return new A.ld(A.l(t.S,t.i),a,72,c,d,b,d.$1(b))},
cx:function cx(a,b){this.a=a
this.b=b},
jo:function jo(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0
_.db=a1
_.dx=a2},
cy:function cy(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
bO:function bO(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cW:function cW(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0
_.db=a1
_.dx=null},
jl:function jl(){},
jm:function jm(){},
jn:function jn(){},
kR:function kR(){},
ld:function ld(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
m0(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){return new A.d2(a0,a4,d,q,f,a1,p,j,i,b,a,k,r,o,l,e,a3,s,a2,g,n,c,m,h)},
bl:function bl(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s},
aA:function aA(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k},
c2:function c2(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
d2:function d2(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0
_.db=a1
_.dx=a2
_.dy=a3
_.fr=a4},
kb:function kb(){},
ka:function ka(){},
kc:function kc(){},
kd:function kd(){},
ke:function ke(){},
cA:function cA(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k},
b_:function b_(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bd:function bd(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k},
jK:function jK(){},
jL:function jL(){},
jM:function jM(){},
jN:function jN(){},
ah:function ah(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cp:function cp(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
bQ:function bQ(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
eq:function eq(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=""
_.c=b
_.d=c
_.e=d
_.f=e
_.r=f
_.w=g
_.x=h
_.y=i
_.z=null
_.at=_.as=_.Q=0},
hO:function hO(){},
hP:function hP(){},
hQ:function hQ(){},
hR:function hR(){},
hS:function hS(){},
hT:function hT(){},
mC(a){var s,r=A.az(a.i(0,"k")),q=A.az(a.i(0,"x")),p=A.y(a.i(0,"ra"))
if(p==null)p=null
if(p==null)p=0
s=A.y(a.i(0,"rb"))
if(s==null)s=null
return new A.c3(r,q,p,s==null?0:s)},
nO(a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=!0
if(!(a0<=0))if(!(a1<=0))a=a2<=0
if(a)return 0
s=Math.min(40,B.b.an(a0/a1))
r=Math.min(40,B.b.an(a0/a2))
q=A.d([],t.n)
for(p=-s,a=s+1,o=-r,n=r+1,m=0;m<24;++m)for(l=(m+0.5)/24*a1,k=0;k<24;++k){j=(k+0.5)/24*a2
for(i=p,h=0;i<=a;++i)for(g=i*a1,f=o;f<=n;++f){e=l-g
d=j-f*a2
c=Math.sqrt(e*e+d*d)
if(c<a0)h+=1-c/a0}B.a.k(q,h)}b=B.a.M(q,new A.lb())/q.length
if(b<=0)return 0
return 100*(1-B.a.P(q,0,new A.lc(b),t.i)/q.length/b)},
c3:function c3(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
lb:function lb(){},
lc:function lc(a){this.a=a},
nP(a,b,c,d){var s
if(c===0||d===0)return 0
s=10.67*d*Math.pow(Math.abs(c),1.852)/(Math.pow(a,1.852)*Math.pow(b,4.871))
return c<0?-s:s},
fO(a,b){return b/(3.141592653589793*a*a/4)},
nI(a,b){var s,r,q,p,o,n
if(b<=0)return 0
if(b<2000)return 64/b
if(b<4000){s=a/3.7+5.74/Math.pow(4000,0.9)
r=-0.8685889638065035*Math.log(s)
q=Math.pow(r,-2)
p=q*(2-0.00514215/(s*r))
o=b/2000
return 7*q-p+o*(0.128-17*q+2.5*p+o*(-0.128+13*q-2*p+o*(0.032-3*q+0.5*p)))}n=Math.log(a/3.7+5.74/Math.pow(b,0.9))/2.302585092994046
return 0.25/(n*n)},
nJ(a,b,c,d,e){var s,r
if(b===0||d===0)return 0
s=A.fO(a,Math.abs(b))
r=A.nI(e/a,s*a/c)*(d/a)*s*s/19.6133
return b<0?-r:r},
nL(a,b,c,d,e,f,g){switch(f.a){case 0:return A.nP(a,b,c,e)
case 1:return A.nJ(b,c,d,e,g)}},
cq:function cq(a,b){this.a=a
this.b=b},
nV(a,b,c){var s=A.fO(a,Math.abs(b)),r=c*s*s/19.6133
return b<0?-r:r},
rc(a,b){var s=3.141592653589793*a*a/4
return b/(19.6133*s*s)},
aK:function aK(a,b,c){this.a=a
this.b=b
this.c=c},
eu(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.dr(f,d,n,g,c,h,e,l,i,a,k,b,j,B.o)},
mL(a,b){return new A.jc(b,a)},
ds:function ds(a,b){this.a=a
this.b=b},
by:function by(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=d
_.f=e
_.r=f
_.w=g},
c5:function c5(a,b){this.a=a
this.b=b},
cP:function cP(a,b){this.a=a
this.b=b},
dr:function dr(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.ay=n},
jc:function jc(a,b){this.a=a
this.b=b},
eY:function eY(a,b){this.a=a
this.b=b},
eL:function eL(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.e=d},
cU:function cU(a,b,c){this.a=a
this.c=b
this.d=c},
ew:function ew(a,b,c){this.a=a
this.b=b
this.c=c},
iK:function iK(){},
mY(a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.t(a4),a2=a1.j("A<1>"),a3=A.p(new A.A(a4,a1.j("q(1)").a(new A.jy()),a2),a2.j("h.E"))
a1=a3.length
if(a1===0)return B.fF
if(a1===1){s=B.a.gu(a3)
r=s.a
q=s.b
return A.mY(A.d([new A.m(0,1.33*q),new A.m(r,q),new A.m(2*r,0)],t.fU))}if(a1===2){if(0>=a1)return A.b(a3,0)
p=a3[0]
o=p.a
n=p.b
if(1>=a1)return A.b(a3,1)
m=a3[1]
l=(m.b-n)/(m.a-o)
return new A.cY(0,l,n-l*o,1)}for(k=0,j=0,i=0,h=0,g=0,f=0,a2=0,e=0;e<a1;++e){d=a3[e]
c=d.a
b=d.b
k+=c
d=c*c
j+=d
a=d*c
i+=a
h+=a*c
g+=b
f+=c*b
a2+=d*b}d=t.n
a0=A.pd(A.d([A.d([h,i,j,a2],d),A.d([i,j,k,f],d),A.d([j,k,a1,g],d)],t.iA))
d=a0.length
if(0>=d)return A.b(a0,0)
g=a0[0]
if(1>=d)return A.b(a0,1)
a1=a0[1]
if(2>=d)return A.b(a0,2)
return new A.cY(g,a1,a0[2],1)},
pd(a){var s,r,q,p,o,n,m,l,k,j
for(s=0;s<3;s=r){for(r=s+1,q=r,p=s;q<3;++q){o=a[q][s]
if(!(p>=0&&p<3))return A.b(a,p)
if(Math.abs(o)>Math.abs(a[p][s]))p=q}n=a[s]
if(!(p>=0&&p<3))return A.b(a,p)
a[s]=a[p]
a[p]=n
if(Math.abs(a[s][s])<1e-18)continue
for(q=0;q<3;++q){if(q===s)continue
m=a[q][s]/a[s][s]
for(l=s;l<4;++l){o=a[q]
B.a.h(o,l,o[l]-m*a[s][l])}}}o=A.d([],t.n)
for(s=0;s<3;++s){k=a[s]
j=k[s]
o.push(Math.abs(j)<1e-18?0:k[3]/j)}return o},
fK(a,b){var s
if(b<=0)return 1
if(a<=0)return 1/b
s=Math.pow(1+a,b)
return a*s/(s-1)},
nE(a,b,c,d,e){return 9788.99803*b*c/Math.max(e,0.05)/1000*d*a},
cY:function cY(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
jz:function jz(){},
jy:function jy(){},
ph(a){var s,r,q,p=J.eC(a,t.jq)
for(s=t.S,r=t.i,q=0;q<a;++q)p[q]=A.l(s,r)
return new A.jE(a,p,A.bj(a,0,!1,r))},
jE:function jE(a,b,c){this.a=a
this.b=b
this.c=c},
jF:function jF(){},
jG:function jG(){},
jH:function jH(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
jI:function jI(a,b,c){this.a=a
this.b=b
this.c=c},
jJ:function jJ(){},
pu(a,b,c){var s,r,q,p,o,n,m,l,k,j,i=A.t(a),h=i.j("A<1>"),g=A.p(new A.A(a,i.j("q(1)").a(new A.k_()),h),h.j("h.E"))
i=g.length
if(i===0)return B.da
s=B.a.M(g,new A.k0())/i
h=t.i
r=A.eN(g,!0,h)
B.a.a5(r)
q=B.a.gu(r)
p=B.a.gF(r)
if(s<=0)return new A.dS(i,s,q,p,0,0,0,0,0,0)
o=B.a.P(g,0,new A.k1(s),h)
n=Math.max(1,B.b.an(i/4))
m=A.c9(r,0,A.cI(n,"count",t.S),A.t(r).c).M(0,new A.k2())/n
h=B.a.P(g,0,new A.k3(s),h)
l=Math.sqrt(h/(i>1?i-1:1))/s
h=Math.sqrt(Math.max(1,b))
k=Math.sqrt(l*l+c*c)
j=p>0?100*(p-q)/p:0
return new A.dS(i,s,q,p,100*(1-o/i/s),100*m/s,100*(1-1.27*c/h)*(m/s),100*(1-k),j,l)},
dS:function dS(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
k_:function k_(){},
k0:function k0(){},
k1:function k1(a){this.a=a},
k2:function k2(){},
k3:function k3(a){this.a=a},
b8:function b8(a,b,c){this.c=a
this.a=b
this.b=c},
mi(a,b){return $.kN.i(0,a)==null?null:B.as.i(0,b)},
eJ:function eJ(a){this.a=a},
iJ:function iJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ax(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.L(e,h,l,a,i,f,g,d,k,j,n,b,m,c)},
p6(a){var s,r,q,p,o,n,m,l,k,j,i,h=null,g=A.D(a.i(0,"id")),f=A.D(a.i(0,"name")),e=A.x(a.i(0,"sup"))
if(e==null)e=""
s=A.x(a.i(0,"code"))
if(s==null)s=""
r=A.az(a.i(0,"nominalMm"))
q=A.az(a.i(0,"idMm"))
p=A.x(a.i(0,"material"))
if(p==null)p="pvc"
p=A.aj(B.f3,p,t.f7)
o=A.y(a.i(0,"c"))
if(o==null)o=h
if(o==null)o=150
n=A.y(a.i(0,"roughMm"))
if(n==null)n=h
if(n==null)n=0.0015
m=A.y(a.i(0,"ratingM"))
if(m==null)m=h
if(m==null)m=60
l=A.y(a.i(0,"wallMm"))
if(l==null)l=h
if(l==null)l=2
k=A.y(a.i(0,"cost"))
if(k==null)k=h
if(k==null)k=0
j=t.O.a(a.i(0,"usage"))
if(j==null)j=["zone","mainline"]
j=J.aC(j,new A.jj(),t.W).aw(0)
i=A.V(a.i(0,"enabled"))
return A.ax(s,k,i!==!1,o,g,q,p,f,r,m,n,e,j,l)},
p4(a){var s,r,q,p,o,n,m,l=A.D(a.i(0,"id")),k=A.D(a.i(0,"name")),j=A.x(a.i(0,"sup"))
if(j==null)j=""
s=A.x(a.i(0,"code"))
if(s==null)s=""
r=A.aj(B.f1,A.D(a.i(0,"kind")),t.hF)
q=J.aC(t.j.a(a.i(0,"nozzles")),new A.je(),t.mP)
q=A.p(q,q.$ti.j("w.E"))
p=A.y(a.i(0,"cost"))
if(p==null)p=null
if(p==null)p=0
o=A.y(a.i(0,"inletMm"))
if(o==null)o=null
if(o==null)o=20
n=A.y(a.i(0,"riser"))
if(n==null)n=null
if(n==null)n=0
m=A.V(a.i(0,"enabled"))
return new A.a8(l,k,j,s,r,q,p,o,n,m!==!1)},
d1(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){return new A.aZ(j,n,r,b,o,k,g,f,a,d,m,l,e,a0,s,p,q,i,c,h)},
ar(a,b,c,d,e,f,g,h,i,j,k,l){return new A.aX(e,h,l,a,j,k,i,A.mY(i),c,g,f,b,d)},
pe(a){var s,r,q,p,o,n,m,l,k,j,i=null,h=A.D(a.i(0,"id")),g=A.V(a.i(0,"sub"))
if(g==null)g=B.FK.v(0,a.i(0,"id"))
s=A.D(a.i(0,"name"))
r=A.x(a.i(0,"sup"))
if(r==null)r=""
q=A.x(a.i(0,"code"))
if(q==null)q=""
p=A.y(a.i(0,"kw"))
if(p==null)p=i
if(p==null)p=0
o=J.aC(t.j.a(a.i(0,"points")),new A.jA(),t.aL)
o=A.p(o,o.$ti.j("w.E"))
n=A.y(a.i(0,"eff"))
if(n==null)n=i
if(n==null)n=0.7
m=A.y(a.i(0,"minQ"))
if(m==null)m=i
if(m==null)m=0
l=A.y(a.i(0,"maxQ"))
if(l==null)l=i
if(l==null)l=1
k=A.y(a.i(0,"cost"))
if(k==null)k=i
if(k==null)k=0
j=A.V(a.i(0,"enabled"))
return A.ar(q,k,n,j!==!1,h,l,m,s,o,p,g,r)},
mv(a,b,c,d,e,f,g){return new A.fU(c,b,e,f,d,a,g)},
oz(a){var s,r,q,p,o,n=t.O,m=n.a(a.i(0,"pipes"))
if(m==null)m=[]
m=J.aC(m,new A.h7(),t.p)
m=A.p(m,m.$ti.j("w.E"))
s=n.a(a.i(0,"outlets"))
if(s==null)s=[]
s=J.aC(s,new A.h8(),t.fa)
s=A.p(s,s.$ti.j("w.E"))
r=n.a(a.i(0,"tapes"))
if(r==null)r=[]
r=J.aC(r,new A.h9(),t.gs)
r=A.p(r,r.$ti.j("w.E"))
q=n.a(a.i(0,"valves"))
if(q==null)q=[]
q=J.aC(q,new A.ha(),t.e4)
q=A.p(q,q.$ti.j("w.E"))
p=n.a(a.i(0,"pumps"))
if(p==null)p=[]
p=J.aC(p,new A.hb(),t.dz)
p=A.p(p,p.$ti.j("w.E"))
o=n.a(a.i(0,"fittings"))
if(o==null)o=[]
o=J.aC(o,new A.hc(),t.kN)
o=A.p(o,o.$ti.j("w.E"))
n=n.a(a.i(0,"wires"))
if(n==null)n=[]
n=J.aC(n,new A.hd(),t.e)
n=A.p(n,n.$ti.j("w.E"))
return A.mv(o,s,m,p,r,q,n)},
ow(){var s=A.ou("en"),r=A.qV("BRL","BRL")
if(r!=null)A.rg(s,r)
return s},
ou(a7){var s,r,q,p,o,n,m,l,k,j="Microaspersor 360\xb0",i="Microaspersor PC",h='Aspersor de impacto 3/4"',g=1500,f='V\xe1lvula hidr\xe1ulica 3"',e='V\xe1lvula hidr\xe1ulica 4"',d='V\xe1lvula hidr\xe1ulica 6"',c='Filtro de discos 2" (120 mesh)',b='Filtro de discos 3" (120 mesh)',a='Filtro de discos 4" (120 mesh)',a0='Ventosa 1"',a1='Ventosa 2"',a2='Ventosa 3"',a3=new A.fW(a7),a4=new A.fX(),a5=t.W,a6=A.d([A.ax("",0.9,!0,140,"pe16",13.6,B.aw,"PE 16 mm (PN 4)",16,40,0.003,"",A.al([B.q],a5),1.2),A.ax("",1.3,!0,140,"pe20",17,B.aw,"PE 20 mm (PN 4)",20,40,0.003,"",A.al([B.q],a5),1.5),A.ax("",2.1,!0,145,"pe25",21,B.y,"PE 25 mm (PN 6)",25,60,0.003,"",A.al([B.q,B.j],a5),2),A.ax("",3.2,!0,145,"pe32",27.2,B.y,"PE 32 mm (PN 6)",32,60,0.003,"",A.al([B.q,B.j],a5),2.4),A.ax("",4.9,!0,145,"pe40",34,B.y,"PE 40 mm (PN 6)",40,60,0.003,"",A.al([B.j],a5),3),A.ax("",7.4,!0,145,"pe50",42.6,B.y,"PE 50 mm (PN 6)",50,60,0.003,"",A.al([B.j],a5),3.7),A.ax("",4.5,!0,150,"pvc35",32,B.p,"PVC DN 35 PN 80",35,80,0.0015,"",A.al([B.j,B.k],a5),1.5),A.ax("",7.2,!0,150,"pvc50",46.4,B.p,"PVC DN 50 PN 80",50,80,0.0015,"",A.al([B.j,B.k],a5),1.8),A.ax("",14.5,!0,150,"pvc75",70.6,B.p,"PVC DN 75 PN 80",75,80,0.0015,"",A.al([B.j,B.k],a5),2.2),A.ax("",24,!0,150,"pvc100",96,B.p,"PVC DN 100 PN 80",100,80,0.0015,"",A.al([B.j,B.k],a5),2.5),A.ax("",36,!0,150,"pvc125",118.6,B.p,"PVC DN 125 PN 80",125,80,0.0015,"",A.al([B.k],a5),3.2),A.ax("",52,!0,150,"pvc150",144,B.p,"PVC DN 150 PN 80",150,80,0.0015,"",A.al([B.k],a5),3.8),A.ax("",88,!0,150,"pvc200",191.6,B.p,"PVC DN 200 PN 80",200,80,0.0015,"",A.al([B.k],a5),4.9),A.ax("",135,!0,150,"pvc250",239.4,B.p,"PVC DN 250 PN 80",250,80,0.0015,"",A.al([B.k],a5),6.2),A.ax("",42,!0,150,"pead110",96.8,B.y,"PEAD 110 mm PN 10",110,100,0.002,"",A.al([B.k],a5),6.6),A.ax("",85,!0,150,"pead160",141,B.y,"PEAD 160 mm PN 10",160,100,0.002,"",A.al([B.k],a5),9.5),A.ax("",160,!1,120,"steel150",154,B.bz,a3.$3('A\xe7o galvanizado 6"','Galvanised steel 6"','Acero galvanizado 6"'),150,200,0.15,"",A.al([B.k],a5),4.5)],t.nD)
a5=t.nB
s=A.d([new A.a8("drip_pc",a3.$3("Gotejador PC (bot\xe3o)","PC dripper (button)","Gotero PC (bot\xf3n)"),"","",B.au,A.d([new A.G("pc2","2 L/h PC",a4.$3(2,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.G("pc4","4 L/h PC",a4.$3(4,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.G("pc8","8 L/h PC",a4.$3(8,10,0.03),360,5,40,10,0.03,0.05,0.05)],a5),0.6,0,0,!0),new A.a8("drip_turb",a3.$3("Gotejador turbulento","Turbulent dripper","Gotero turbulento"),"","",B.au,A.d([new A.G("t2","2 L/h",a4.$3(2,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.G("t4","4 L/h",a4.$3(4,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.G("t8","8 L/h",a4.$3(8,10,0.5),360,5,25,10,0.04,0.05,0.05)],a5),0.35,0,0,!0),new A.a8("micro",a3.$3(j,"Micro-sprinkler 360\xb0",j),"","",B.at,A.d([new A.G("m35",a3.$3("35 L/h (raio 3,0 m)","35 L/h (radius 3.0 m)","35 L/h (radio 3,0 m)"),a4.$4$radiusM(35,15,0.5,3),360,10,30,15,0.05,0.05,0.05),new A.G("m50",a3.$3("50 L/h (raio 3,5 m)","50 L/h (radius 3.5 m)","50 L/h (radio 3,5 m)"),a4.$4$radiusM(50,15,0.5,3.5),360,10,30,15,0.05,0.05,0.05),new A.G("m70",a3.$3("70 L/h (raio 4,0 m)","70 L/h (radius 4.0 m)","70 L/h (radio 4,0 m)"),a4.$4$radiusM(70,15,0.5,4),360,10,30,15,0.05,0.05,0.05),new A.G("m120",a3.$3("120 L/h (raio 5,0 m)","120 L/h (radius 5.0 m)","120 L/h (radio 5,0 m)"),a4.$4$radiusM(120,20,0.5,5),360,15,35,20,0.05,0.05,0.05)],a5),2.8,0,0.3,!0),new A.a8("micro_pc",a3.$3(i,"PC micro-sprinkler",i),"","",B.at,A.d([new A.G("mpc40",a3.$3("40 L/h PC (raio 3,5 m)","40 L/h PC (radius 3.5 m)","40 L/h PC (radio 3,5 m)"),a4.$4$radiusM(40,15,0.05,3.5),360,12,40,20,0.05,0.05,0.05),new A.G("mpc70",a3.$3("70 L/h PC (raio 4,5 m)","70 L/h PC (radius 4.5 m)","70 L/h PC (radio 4,5 m)"),a4.$4$radiusM(70,15,0.05,4.5),360,12,40,20,0.05,0.05,0.05)],a5),3.9,0,0.3,!0),new A.a8("impact34",a3.$3(h,'Impact sprinkler 3/4"',h),"","",B.a2,A.d([new A.G("i3.5",a3.$3("Bocal 3,5 mm (0,9 m\xb3/h, R 12 m)","Nozzle 3.5 mm (0.9 m\xb3/h, R 12 m)","Boquilla 3,5 mm (0,9 m\xb3/h, R 12 m)"),a4.$4$radiusM(900,30,0.5,12),360,20,45,30,0.03,0.05,0.05),new A.G("i4.0",a3.$3("Bocal 4,0 mm (1,2 m\xb3/h, R 13 m)","Nozzle 4.0 mm (1.2 m\xb3/h, R 13 m)","Boquilla 4,0 mm (1,2 m\xb3/h, R 13 m)"),a4.$4$radiusM(1200,30,0.5,13),360,20,45,30,0.03,0.05,0.05),new A.G("i4.5",a3.$3("Bocal 4,5 mm (1,5 m\xb3/h, R 14 m)","Nozzle 4.5 mm (1.5 m\xb3/h, R 14 m)","Boquilla 4,5 mm (1,5 m\xb3/h, R 14 m)"),a4.$4$radiusM(g,30,0.5,14),360,20,45,30,0.03,0.05,0.05),new A.G("i5.0",a3.$3("Bocal 5,0 mm (1,9 m\xb3/h, R 15 m)","Nozzle 5.0 mm (1.9 m\xb3/h, R 15 m)","Boquilla 5,0 mm (1,9 m\xb3/h, R 15 m)"),a4.$4$radiusM(1900,30,0.5,15),360,25,50,35,0.03,0.05,0.05)],a5),18,20,1,!0),new A.a8("gun",a3.$3('Canh\xe3o hidr\xe1ulico 1,5"','Big gun 1.5"','Ca\xf1\xf3n de riego 1,5"'),"","",B.by,A.d([new A.G("g14",a3.$3("Bocal 14 mm (15 m\xb3/h, R 32 m)","Nozzle 14 mm (15 m\xb3/h, R 32 m)","Boquilla 14 mm (15 m\xb3/h, R 32 m)"),a4.$4$radiusM(15e3,40,0.5,32),360,30,70,40,0.03,0.05,0.05),new A.G("g18",a3.$3("Bocal 18 mm (25 m\xb3/h, R 40 m)","Nozzle 18 mm (25 m\xb3/h, R 40 m)","Boquilla 18 mm (25 m\xb3/h, R 40 m)"),a4.$4$radiusM(25e3,45,0.5,40),360,35,80,45,0.03,0.05,0.05)],a5),420,40,1.5,!0),new A.a8("rotor",a3.$3('Rotor de jardim 1/2"','Turf rotor 1/2"','Rotor de jard\xedn 1/2"'),"","",B.a2,A.d([new A.G("r1.5","#1.5 (0,35 m\xb3/h, R 8 m)",a4.$4$radiusM(350,25,0.5,8),360,17,45,25,0.03,0.05,0.05),new A.G("r3","#3 (0,70 m\xb3/h, R 10 m)",a4.$4$radiusM(700,25,0.5,10),360,17,45,25,0.03,0.05,0.05),new A.G("r3_180","#3 180\xb0 (0,35 m\xb3/h, R 10 m)",a4.$4$radiusM(350,25,0.5,10),180,17,45,25,0.03,0.05,0.05),new A.G("r3_90","#3 90\xb0 (0,18 m\xb3/h, R 10 m)",a4.$4$radiusM(180,25,0.5,10),90,17,45,25,0.03,0.05,0.05)],a5),45,15,0.1,!0),new A.a8("spray",a3.$3('Spray pop-up 4"','Pop-up spray 4"','Difusor emergente 4"'),"","",B.a2,A.d([new A.G("s12","12F (0,60 m\xb3/h, R 3,7 m)",a4.$4$radiusM(600,20,0.5,3.7),360,10,30,20,0.04,0.05,0.05),new A.G("s12h","12H (0,30 m\xb3/h, R 3,7 m)",a4.$4$radiusM(300,20,0.5,3.7),180,10,30,20,0.04,0.05,0.05),new A.G("s12q","12Q (0,15 m\xb3/h, R 3,7 m)",a4.$4$radiusM(150,20,0.5,3.7),90,10,30,20,0.04,0.05,0.05),new A.G("s15","15F (0,84 m\xb3/h, R 4,6 m)",a4.$4$radiusM(840,20,0.5,4.6),360,10,30,20,0.04,0.05,0.05)],a5),12,15,0,!0),new A.a8("demand",a3.$3("Ponto de demanda","Demand point","Punto de demanda"),"","",B.av,A.d([new A.G("d5","5 m\xb3/h @ 20 m",a4.$3(5000,20,0),360,20,80,20,0,0.5,0.5),new A.G("d10","10 m\xb3/h @ 20 m",a4.$3(1e4,20,0),360,20,80,20,0,0.5,0.5),new A.G("d20","20 m\xb3/h @ 25 m",a4.$3(2e4,25,0),360,25,80,25,0,0.5,0.5)],a5),0,50,0,!0)],t.dO)
a5=a3.$3("Fita gotejadora 16 mm, 1,0 L/h @ 0,30 m","Drip tape 16 mm, 1.0 L/h @ 0.30 m","Cinta de goteo 16 mm, 1,0 L/h @ 0,30 m")
a5=A.d1(0.3,"",0.45,0.03,8,a4.$3(1,7,0.5),0.3,!0,140,"tape16_10_30",15.6,12,4,a5,16,15,0.002,"",20,30)
r=a3.$3("Fita gotejadora 16 mm, 1,6 L/h @ 0,20 m","Drip tape 16 mm, 1.6 L/h @ 0.20 m","Cinta de goteo 16 mm, 1,6 L/h @ 0,20 m")
r=A.d1(0.3,"",0.55,0.03,8,a4.$3(1.6,7,0.5),0.2,!0,140,"tape16_16_20",15.6,12,4,r,16,15,0.002,"",20,30)
q=a3.$3("Tubo gotejador 16 mm, 1,6 L/h @ 0,50 m","Dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo 16 mm, 1,6 L/h @ 0,50 m")
q=A.d1(0.4,"",1.1,0.03,10,a4.$3(1.6,10,0.5),0.5,!0,140,"drip16_16_50",13.8,25,5,q,16,30,0.002,"",20,30)
p=a3.$3("Tubo gotejador 16 mm, 2,4 L/h @ 0,75 m","Dripline 16 mm, 2.4 L/h @ 0.75 m","Tuber\xeda de goteo 16 mm, 2,4 L/h @ 0,75 m")
p=A.d1(0.4,"",1.05,0.03,10,a4.$3(2.4,10,0.5),0.75,!0,140,"drip16_24_75",13.8,25,5,p,16,30,0.002,"",20,30)
o=a3.$3("Tubo gotejador PC 16 mm, 1,6 L/h @ 0,50 m","PC dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo PC 16 mm, 1,6 L/h @ 0,50 m")
o=A.d1(0.4,"",1.6,0.03,15,a4.$3(1.6,10,0.04),0.5,!0,140,"drip16pc_16_50",13.8,40,6,o,16,40,0.002,"",150,50)
n=a3.$3("Tubo gotejador PC 20 mm, 2,3 L/h @ 0,75 m","PC dripline 20 mm, 2.3 L/h @ 0.75 m","Tuber\xeda de goteo PC 20 mm, 2,3 L/h @ 0,75 m")
m=A.d([a5,r,q,p,o,A.d1(0.4,"",2.1,0.03,15,a4.$3(2.3,10,0.04),0.75,!0,140,"drip20pc_23_75",17.5,40,6,n,20,40,0.002,"",150,50)],t.ik)
n=new A.fV()
l=A.d([new A.F("ev25",a3.$3('V\xe1lvula el\xe9trica 1"','Solenoid valve 1"','Electrov\xe1lvula 1"'),"","",B.B,25,n.$2(6,25),0.00005555555555555556,0.0016666666666666666,120,0,!0),new A.F("ev40",a3.$3('V\xe1lvula el\xe9trica 1\xbd"','Solenoid valve 1\xbd"','Electrov\xe1lvula 1\xbd"'),"","",B.B,40,n.$2(5.5,40),0.0002777777777777778,0.0044444444444444444,260,0,!0),new A.F("ev50",a3.$3('V\xe1lvula el\xe9trica 2"','Solenoid valve 2"','Electrov\xe1lvula 2"'),"","",B.B,50,n.$2(5,50),0.0005555555555555556,0.008333333333333333,380,0,!0),new A.F("ev80",a3.$3(f,'Hydraulic valve 3"',f),"","",B.B,80,n.$2(4.5,80),0.001388888888888889,0.022222222222222223,900,0,!0),new A.F("ev100",a3.$3(e,'Hydraulic valve 4"',e),"","",B.B,100,n.$2(4,100),0.002777777777777778,0.03888888888888889,g,0,!0),new A.F("ev150",a3.$3(d,'Hydraulic valve 6"',d),"","",B.B,150,n.$2(3.5,150),0.006944444444444444,0.08333333333333333,2800,0,!0),new A.F("prv50",a3.$3('V\xe1lvula reguladora de press\xe3o 2"','Pressure reducing valve 2"','V\xe1lvula reguladora de presi\xf3n 2"'),"","",B.S,50,n.$2(3,50),0,0.008333333333333333,650,25,!0),new A.F("prv80",a3.$3('V\xe1lvula reguladora de press\xe3o 3"','Pressure reducing valve 3"','V\xe1lvula reguladora de presi\xf3n 3"'),"","",B.S,80,n.$2(3,80),0,0.022222222222222223,1200,30,!0),new A.F("prv100",a3.$3('V\xe1lvula reguladora de press\xe3o 4"','Pressure reducing valve 4"','V\xe1lvula reguladora de presi\xf3n 4"'),"","",B.S,100,n.$2(3,100),0,0.03888888888888889,2100,30,!0),new A.F("gate50",a3.$3('Registro gaveta 2"','Gate valve 2"','V\xe1lvula de compuerta 2"'),"","",B.T,50,n.$2(0.2,50),0,0.011111111111111112,90,0,!0),new A.F("gate80",a3.$3('Registro gaveta 3"','Gate valve 3"','V\xe1lvula de compuerta 3"'),"","",B.T,80,n.$2(0.2,80),0,0.025,220,0,!0),new A.F("gate100",a3.$3('Registro gaveta 4"','Gate valve 4"','V\xe1lvula de compuerta 4"'),"","",B.T,100,n.$2(0.2,100),0,0.041666666666666664,420,0,!0),new A.F("gate150",a3.$3('Registro gaveta 6"','Gate valve 6"','V\xe1lvula de compuerta 6"'),"","",B.T,150,n.$2(0.2,150),0,0.09722222222222222,900,0,!0),new A.F("check50",a3.$3('V\xe1lvula de reten\xe7\xe3o 2"','Check valve 2"','V\xe1lvula de retenci\xf3n 2"'),"","",B.U,50,n.$2(2,50),0,0.011111111111111112,150,0,!0),new A.F("check80",a3.$3('V\xe1lvula de reten\xe7\xe3o 3"','Check valve 3"','V\xe1lvula de retenci\xf3n 3"'),"","",B.U,80,n.$2(2,80),0,0.025,260,0,!0),new A.F("check100",a3.$3('V\xe1lvula de reten\xe7\xe3o 4"','Check valve 4"','V\xe1lvula de retenci\xf3n 4"'),"","",B.U,100,n.$2(2,100),0,0.041666666666666664,380,0,!0),new A.F("filter_disc50",a3.$3(c,'Disc filter 2" (120 mesh)',c),"","",B.C,50,new A.aK(62208,2,0),0,0.006944444444444444,850,0,!0),new A.F("filter_disc80",a3.$3(b,'Disc filter 3" (120 mesh)',b),"","",B.C,80,new A.aK(15552,2,0),0,0.013888888888888888,1600,0,!0),new A.F("filter_disc100",a3.$3(a,'Disc filter 4" (120 mesh)',a),"","",B.C,100,new A.aK(4800,2,0),0,0.025,2600,0,!0),new A.F("filter_screen80",a3.$3('Filtro de tela 3"','Screen filter 3"','Filtro de malla 3"'),"","",B.C,80,new A.aK(9000,2,0),0,0.016666666666666666,1400,0,!0),new A.F("filter_screen100",a3.$3('Filtro de tela 4"','Screen filter 4"','Filtro de malla 4"'),"","",B.C,100,new A.aK(3240,2,0),0,0.027777777777777776,2100,0,!0),new A.F("filter_screen150",a3.$3('Filtro de tela 6"','Screen filter 6"','Filtro de malla 6"'),"","",B.C,150,new A.aK(810,2,0),0,0.05555555555555555,3800,0,!0),new A.F("meter50",a3.$3('Hidr\xf4metro 2"','Water meter 2"','Contador de agua 2"'),"","",B.a8,50,n.$2(7,50),0,0.005555555555555556,700,0,!0),new A.F("meter80",a3.$3('Hidr\xf4metro 3"','Water meter 3"','Contador de agua 3"'),"","",B.a8,80,n.$2(7,80),0,0.016666666666666666,1100,0,!0),new A.F("meter100",a3.$3('Hidr\xf4metro 4"','Water meter 4"','Contador de agua 4"'),"","",B.a8,100,n.$2(7,100),0,0.03333333333333333,1600,0,!0),new A.F("backflow50",a3.$3('V\xe1lvula anti-refluxo 2"','Backflow preventer 2"','V\xe1lvula antirretorno 2"'),"","",B.aT,50,n.$2(8,50),0,0.006944444444444444,900,0,!0),new A.F("backflow80",a3.$3('V\xe1lvula anti-refluxo 3"','Backflow preventer 3"','V\xe1lvula antirretorno 3"'),"","",B.aT,80,n.$2(8,80),0,0.016666666666666666,g,0,!0),new A.F("air25",a3.$3(a0,'Air release valve 1"',a0),"","",B.a9,25,B.I,0,1,90,0,!0),new A.F("air50",a3.$3(a1,'Air release valve 2"',a1),"","",B.a9,50,B.I,0,1,180,0,!0),new A.F("air80",a3.$3(a2,'Air release valve 3"',a2),"","",B.a9,80,B.I,0,1,320,0,!0)],t.bD)
n=t.fU
k=A.d([A.ar("",900,0.45,!0,"pump_c1",0.0016666666666666666,0,a3.$3("Bomba centr\xedfuga 1 cv (4 m\xb3/h @ 20 m)","Centrifugal pump 1 hp (4 m\xb3/h @ 20 m)","Bomba centr\xedfuga 1 CV (4 m\xb3/h @ 20 m)"),A.d([B.fJ,B.h1,B.h0,B.fG],n),0.75,!1,""),A.ar("",g,0.5,!0,"pump_c2",0.002777777777777778,0,a3.$3("Bomba centr\xedfuga 2 cv (7 m\xb3/h @ 28 m)","Centrifugal pump 2 hp (7 m\xb3/h @ 28 m)","Bomba centr\xedfuga 2 CV (7 m\xb3/h @ 28 m)"),A.d([B.fK,B.hV,B.hi,B.h_],n),1.5,!1,""),A.ar("",2200,0.55,!0,"pump_small",0.004166666666666667,0,a3.$3("Bomba centr\xedfuga 3 cv (10 m\xb3/h @ 35 m)","Centrifugal pump 3 hp (10 m\xb3/h @ 35 m)","Bomba centr\xedfuga 3 CV (10 m\xb3/h @ 35 m)"),A.d([B.fL,B.h3,B.hO,B.hF],n),2.2,!1,""),A.ar("",3200,0.6,!0,"pump_c5",0.0075,0,a3.$3("Bomba centr\xedfuga 5 cv (18 m\xb3/h @ 38 m)","Centrifugal pump 5 hp (18 m\xb3/h @ 38 m)","Bomba centr\xedfuga 5 CV (18 m\xb3/h @ 38 m)"),A.d([B.fM,B.hA,B.hW,B.hs],n),3.7,!1,""),A.ar("",4500,0.62,!0,"pump_c7_5",0.011666666666666667,0,a3.$3("Bomba centr\xedfuga 7,5 cv (28 m\xb3/h @ 40 m)","Centrifugal pump 7.5 hp (28 m\xb3/h @ 40 m)","Bomba centr\xedfuga 7,5 CV (28 m\xb3/h @ 40 m)"),A.d([B.fN,B.hB,B.hz,B.hp],n),5.5,!1,""),A.ar("",6500,0.65,!0,"pump_mid",0.016666666666666666,0,a3.$3("Bomba centr\xedfuga 10 cv (40 m\xb3/h @ 45 m)","Centrifugal pump 10 hp (40 m\xb3/h @ 45 m)","Bomba centr\xedfuga 10 CV (40 m\xb3/h @ 45 m)"),A.d([B.fO,B.he,B.hr,B.hl],n),7.5,!1,""),A.ar("",9000,0.68,!0,"pump_c15",0.022222222222222223,0,a3.$3("Bomba centr\xedfuga 15 cv (55 m\xb3/h @ 45 m)","Centrifugal pump 15 hp (55 m\xb3/h @ 45 m)","Bomba centr\xedfuga 15 CV (55 m\xb3/h @ 45 m)"),A.d([B.fP,B.hx,B.hk,B.h9],n),11,!1,""),A.ar("",12e3,0.7,!0,"pump_c20",0.027777777777777776,0,a3.$3("Bomba centr\xedfuga 20 cv (70 m\xb3/h @ 48 m)","Centrifugal pump 20 hp (70 m\xb3/h @ 48 m)","Bomba centr\xedfuga 20 CV (70 m\xb3/h @ 48 m)"),A.d([B.fQ,B.hY,B.hL,B.hy],n),15,!1,""),A.ar("",18e3,0.72,!0,"pump_big",0.05,0,a3.$3("Bomba centr\xedfuga 30 cv (120 m\xb3/h @ 55 m)","Centrifugal pump 30 hp (120 m\xb3/h @ 55 m)","Bomba centr\xedfuga 30 CV (120 m\xb3/h @ 55 m)"),A.d([B.fR,B.hS,B.h5,B.hR],n),22,!1,""),A.ar("",28e3,0.74,!0,"pump_c50",0.06388888888888888,0,a3.$3("Bomba centr\xedfuga 50 cv (160 m\xb3/h @ 55 m)","Centrifugal pump 50 hp (160 m\xb3/h @ 55 m)","Bomba centr\xedfuga 50 CV (160 m\xb3/h @ 55 m)"),A.d([B.fS,B.hJ,B.fW,B.h2],n),37,!1,""),A.ar("",4e4,0.76,!0,"pump_c75",0.09166666666666666,0,a3.$3("Bomba centr\xedfuga 75 cv (230 m\xb3/h @ 60 m)","Centrifugal pump 75 hp (230 m\xb3/h @ 60 m)","Bomba centr\xedfuga 75 CV (230 m\xb3/h @ 60 m)"),A.d([B.bD,B.hj,B.hT,B.hv],n),55,!1,""),A.ar("",55e3,0.78,!0,"pump_c100",0.11666666666666667,0,a3.$3("Bomba centr\xedfuga 100 cv (300 m\xb3/h @ 65 m)","Centrifugal pump 100 hp (300 m\xb3/h @ 65 m)","Bomba centr\xedfuga 100 CV (300 m\xb3/h @ 65 m)"),A.d([B.fV,B.fZ,B.hN,B.hI],n),75,!1,""),A.ar("",2800,0.55,!0,"pump_s3",0.003333333333333333,0,a3.$3("Bomba submersa 3 cv (8 m\xb3/h @ 55 m)","Submersible pump 3 hp (8 m\xb3/h @ 55 m)","Bomba sumergible 3 CV (8 m\xb3/h @ 55 m)"),A.d([B.bD,B.hg,B.hc,B.hf],n),2.2,!0,""),A.ar("",3900,0.58,!0,"pump_s5",0.005,0,a3.$3("Bomba submersa 5 cv (12 m\xb3/h @ 65 m)","Submersible pump 5 hp (12 m\xb3/h @ 65 m)","Bomba sumergible 5 CV (12 m\xb3/h @ 65 m)"),A.d([B.bE,B.ht,B.hX,B.hM],n),3.7,!0,""),A.ar("",5400,0.68,!0,"pump_sub",0.009722222222222222,0,a3.$3("Bomba submersa 7,5 cv (25 m\xb3/h @ 60 m)","Submersible pump 7.5 hp (25 m\xb3/h @ 60 m)","Bomba sumergible 7,5 CV (25 m\xb3/h @ 60 m)"),A.d([B.fT,B.hQ,B.hd,B.hD],n),5.5,!0,""),A.ar("",9500,0.65,!0,"pump_s15",0.016666666666666666,0,a3.$3("Bomba submersa 15 cv (40 m\xb3/h @ 65 m)","Submersible pump 15 hp (40 m\xb3/h @ 65 m)","Bomba sumergible 15 CV (40 m\xb3/h @ 65 m)"),A.d([B.bE,B.hm,B.fH,B.hq],n),11,!0,""),A.ar("",15e3,0.68,!0,"pump_s25",0.022222222222222223,0,a3.$3("Bomba submersa 25 cv (55 m\xb3/h @ 80 m)","Submersible pump 25 hp (55 m\xb3/h @ 80 m)","Bomba sumergible 25 CV (55 m\xb3/h @ 80 m)"),A.d([B.fI,B.hK,B.hU,B.hC],n),18.5,!0,""),A.ar("",19e3,0.72,!0,"pump_s30",0.03888888888888889,0,a3.$3("Bomba submersa 30 cv (100 m\xb3/h @ 60 m)","Submersible pump 30 hp (100 m\xb3/h @ 60 m)","Bomba sumergible 30 CV (100 m\xb3/h @ 60 m)"),A.d([B.fU,B.hH,B.hG,B.hb],n),22,!0,"")],t.fH)
return A.mv(A.ox(a6,a7),s,a6,k,m,l,A.oy(a7))},
oy(a){var s,r,q,p,o,n,m,l,k=new A.h4(a).$3("Fio de cobre","Copper wire","Cable de cobre"),j=new A.h3(),i=A.d([],t.lS)
for(s=k+" ",r=0;r<6;++r){q=B.fb[r]
p=q.a
o=A.z(j.$1(p))
n=A.z(j.$1(p))
m=p>0?18.1/p:1/0
i.push(new A.Z("w"+o,s+n+" mm\xb2","","",p,m,q.b,!0))}for(s=k+" AWG ",r=0;r<6;++r){q=B.fj[r]
l=q.a
o=""+l
n=(36-l)/39
m=A.nK(B.b.a4(0.7853981633974483*Math.pow(0.127*Math.pow(92,n),2),2))
n=0.7853981633974483*Math.pow(0.127*Math.pow(92,n),2)
i.push(new A.Z("awg"+o,s+o,"","",m,A.nK(B.b.a4(n>0?18.1/n:1/0,2)),q.b,!1))}return i},
ox(a,b){var s=A.ov(a,b)
return s},
ov(a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d="Adaptador roscado",c="Conector inicial de lateral",b="Tubo de subida",a="Riser",a0=new A.h1(a6),a1=A.t(a5),a2=a1.j("e(1)"),a3=new A.u(a5,a2.a(new A.fY()),a1.j("u<1,e>")).aw(0),a4=A.p(a3,A.k(a3).c)
B.a.a5(a4)
s=A.d([],t.eK)
r=new A.h0()
q=new A.h2()
for(a3=a4.length,p=a3,o=0;o<p;h===a3||(0,A.j)(a4),++o,p=h){n=a4[o]
m=r.$1(n)
B.a.k(s,new A.a1("cpl"+m,A.z(a0.$3("Luva","Coupler","Manguito"))+" "+m+" mm","","",B.W,n,0,q.$2(4,n),!0,""))
B.a.k(s,new A.a1("el90_"+m,A.z(a0.$3("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0"))+" "+m+" mm","","",B.al,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.a1("el45_"+m,A.z(a0.$3("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0"))+" "+m+" mm","","",B.am,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.a1("tee"+m,A.z(a0.$3("T\xea","Tee","Te"))+" "+m+" mm","","",B.J,n,0,q.$2(8,n),!0,""))
B.a.k(s,new A.a1("cross"+m,A.z(a0.$3("Cruzeta","Cross","Cruz"))+" "+m+" mm","","",B.an,n,0,q.$2(11,n),!0,""))
B.a.k(s,new A.a1("cap"+m,A.z(a0.$3("Tamp\xe3o (cap)","End cap","Tap\xf3n"))+" "+m+" mm","","",B.K,n,0,q.$2(3,n),!0,""))
B.a.k(s,new A.a1("adp"+m,A.z(a0.$3(d,"Threaded adapter",d))+" "+m+" mm","","",B.ao,n,0,q.$2(5,n),!0,""))
for(p=a4.length,l="red"+m+"x",k=n<=75,j="teer"+m+"x",i=0;h=a4.length,i<h;a4.length===p||(0,A.j)(a4),++i){g=a4[i]
if(g>=n)continue
f=r.$1(g)
B.a.k(s,new A.a1(l+f,A.z(a0.$3("Redu\xe7\xe3o","Reducer","Reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.v,n,g,q.$2(5,n),!0,""))
if(g>=20||k)B.a.k(s,new A.a1(j+f,A.z(a0.$3("T\xea de redu\xe7\xe3o","Reducing tee","Te de reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.J,n,g,q.$2(9,n),!0,""))}}a3=A.al([16,20],t.i)
a3.B(0,new A.aF(new A.A(a5,a1.j("q(1)").a(new A.fZ()),a1.j("A<1>")),a2.a(new A.h_()),a1.j("aF<1,e>")))
e=A.p(a3,a3.$ti.c)
B.a.a5(e)
for(a1=e.length,o=0;o<e.length;e.length===a1||(0,A.j)(e),++o){n=e[o]
m=r.$1(n)
B.a.k(s,new A.a1("to"+m,A.z(a0.$3(c,"Lateral take-off",c))+" "+m+" mm","","",B.w,n,0,1.2,!0,""))
B.a.k(s,new A.a1("te"+m,A.z(a0.$3("Final de linha","Line end","Final de l\xednea"))+" "+m+" mm","","",B.L,n,0,0.9,!0,""))}B.a.k(s,new A.a1("riser_micro",a0.$3("Haste/tubinho de microaspersor","Micro-sprinkler stake/tube","Estaca/microtubo de microaspersor"),"","",B.n,0,0,1.1,!0,""))
B.a.k(s,new A.a1("riser20",A.z(a0.$3(b,a,b))+" 20 mm","","",B.n,20,0,6,!0,""))
B.a.k(s,new A.a1("riser25",A.z(a0.$3(b,a,b))+" 25 mm","","",B.n,25,0,8,!0,""))
B.a.k(s,new A.a1("riser40",A.z(a0.$3(b,a,b))+" 40 mm","","",B.n,40,0,18,!0,""))
return s},
b9:function b9(a,b){this.a=a
this.b=b},
L:function L(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n},
jk:function jk(){},
jj:function jj(){},
bk:function bk(a,b){this.a=a
this.b=b},
G:function G(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
a8:function a8(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
jf:function jf(a){this.a=a},
jg:function jg(a){this.a=a},
jh:function jh(){},
je:function je(){},
aZ:function aZ(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0},
aO:function aO(a,b){this.a=a
this.b=b},
F:function F(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l},
aX:function aX(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m},
jB:function jB(){},
jA:function jA(){},
ac:function ac(a,b){this.a=a
this.b=b},
a1:function a1(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
Z:function Z(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
fU:function fU(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
hE:function hE(a){this.a=a},
hF:function hF(){},
h5:function h5(){},
h6:function h6(){},
hg:function hg(a){this.a=a},
hh:function hh(){},
he:function he(a){this.a=a},
hf:function hf(){},
ht:function ht(a){this.a=a},
hu:function hu(){},
hC:function hC(a){this.a=a},
hD:function hD(){},
hk:function hk(a){this.a=a},
hl:function hl(){},
hi:function hi(a){this.a=a},
hj:function hj(){},
hv:function hv(){},
hw:function hw(){},
hx:function hx(){},
hy:function hy(){},
hz:function hz(){},
hA:function hA(){},
hB:function hB(){},
h7:function h7(){},
h8:function h8(){},
h9:function h9(){},
ha:function ha(){},
hb:function hb(){},
hc:function hc(){},
hd:function hd(){},
hs:function hs(){},
hq:function hq(){},
hr:function hr(){},
hm:function hm(){},
hn:function hn(a){this.a=a},
ho:function ho(a){this.a=a},
hp:function hp(a){this.a=a},
fW:function fW(a){this.a=a},
fX:function fX(){},
fV:function fV(){},
h4:function h4(a){this.a=a},
h3:function h3(){},
h1:function h1(a){this.a=a},
fY:function fY(){},
h0:function h0(){},
h2:function h2(){},
fZ:function fZ(){},
h_:function h_(){},
qP(a){var s,r,q=B.d.aG(a).toUpperCase()
for(s=0;s<77;++s){r=B.bn[s]
if(r.a===q)return r}return null},
qV(a,b){var s,r,q=B.d.aG(a).toUpperCase(),p=B.d.aG(b).toUpperCase()
if(q===p&&q.length!==0)return 1
s=B.bw.i(0,q)
r=B.bw.i(0,p)
if(s==null||r==null||s<=0)return null
return r/s},
qQ(a){var s,r,q,p,o=B.d.aG(a)
if(o.length===0)return null
s=A.qP(o)
if(s!=null)return s.a
for(r=0;r<77;++r){q=B.bn[r]
if(q.b===o)return q.a}A:{if("$"===o){p="USD"
break A}if("\xa5"===o||"\u5186"===o){p="JPY"
break A}if("\u5143"===o||"\uffe5"===o){p="CNY"
break A}if("Rs."===o||"\u20a8"===o){p="PKR"
break A}if("S/."===o){p="PEN"
break A}if("\u0631.\u0633"===o||"\ufdfc"===o){p="SAR"
break A}if("\u062c.\u0645"===o){p="EGP"
break A}p=null
break A}return p},
rg(a,b){var s,r,q
if(b===1)return
for(s=a.a,r=s.length,q=0;q<r;++q)s[q].Q*=b
for(s=a.b,r=s.length,q=0;q<r;++q)s[q].r*=b
for(s=a.c,r=s.length,q=0;q<r;++q)s[q].cx*=b
for(s=a.d,r=s.length,q=0;q<r;++q)s[q].y*=b
for(s=a.e,r=s.length,q=0;q<r;++q)s[q].Q*=b
for(s=a.f,r=s.length,q=0;q<r;++q)s[q].w*=b
for(s=a.r,r=s.length,q=0;q<r;++q)s[q].r*=b},
v:function v(a,b){this.a=a
this.b=b},
oO(b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=null,a6="rot",a7="scope",a8="spec",a9="depth",b0="zone",b1="mainline",b2=A.aj(B.fp,A.D(b5.i(0,"type")),t.od),b3=A.D(b5.i(0,"id")),b4=A.x(b5.i(0,"layer"))
if(b4==null)b4="DRAWING"
s=A.x(b5.i(0,"name"))
if(s==null)s=""
r=new A.iG(b5)
q=new A.iF(b5)
p=new A.iE(b5)
switch(b2.a){case 0:r=t.j
return new A.cu(A.bm(r.a(b5.i(0,"a"))),A.bm(r.a(b5.i(0,"b"))),b3,b4,s)
case 1:r=r.$0()
q=A.V(b5.i(0,"closed"))
return new A.cX(r,q===!0,b3,b4,s)
case 2:return new A.el(q.$0(),p.$1("r"),b3,b4,s)
case 3:return new A.de(q.$0(),p.$1("r"),p.$1("s"),p.$1("w"),b3,b4,s)
case 4:r=r.$0()
q=A.V(b5.i(0,"closed"))
return new A.d_(r,q===!0,b3,b4,s)
case 5:r=r.$0()
q=p.$2("ang",45)
p=p.$2("sp",1)
o=A.V(b5.i(0,"solid"))
return new A.ev(r,q,p,o===!0,b3,b4,s)
case 6:r=q.$0()
q=A.x(b5.i(0,"kind"))
if(q==null)q="tree"
return new A.f7(r,A.aj(B.fc,q,t.ai),p.$2("size",2),p.$1(a6),b3,b4,s)
case 7:r=q.$0()
q=A.x(b5.i(0,"text"))
if(q==null)q=""
return new A.fa(r,q,p.$2("h",1),p.$1(a6),b3,b4,s)
case 8:r=t.j
return new A.es(A.bm(r.a(b5.i(0,"a"))),A.bm(r.a(b5.i(0,"b"))),p.$2("off",1),b3,b4,s)
case 9:r=t.j
return new A.eg(A.bm(r.a(b5.i(0,"v"))),A.bm(r.a(b5.i(0,"a"))),A.bm(r.a(b5.i(0,"b"))),p.$2("r",2),b3,b4,s)
case 10:r=A.bm(t.j.a(b5.i(0,"c")))
q=q.$0()
p=A.V(b5.i(0,"dia"))
return new A.f4(r,q,p===!0,b3,b4,s)
case 11:r=r.$0()
q=A.x(b5.i(0,"text"))
if(q==null)q=""
return new A.cO(r,q,p.$2("h",1),b3,b4,s)
case 12:r=q.$0()
q=p.$2("w",1)
o=p.$2("h",1)
n=p.$1(a6)
p=p.$2("op",1)
m=A.x(b5.i(0,"mime"))
if(m==null)m="image/png"
l=b5.i(0,"data")!=null?B.df.bB(A.D(b5.i(0,"data"))):a5
k=A.x(b5.i(0,"src"))
return new A.ex(r,q,o,n,p,m,l,k==null?"":k,b3,b4,s)
case 13:r=r.$0()
p=p.$1("z")
q=A.V(b5.i(0,"gen"))
return new A.cj(r,p,q===!0,b3,b4,s)
case 14:return new A.dO(q.$0(),p.$1("z"),b3,b4,s)
case 15:r=r.$0()
q=A.aj(B.D,A.D(b5.i(0,a7)),t.E)
o=A.x(b5.i(0,a8))
n=A.V(b5.i(0,"auto"))
return A.p5(n!==!1,p.$1(a9),b3,b4,s,o,r,q)
case 16:r=r.$0()
q=A.x(b5.i(0,a8))
o=A.V(b5.i(0,"auto"))
n=A.x(b5.i(0,"outlet"))
if(n==null)n=""
m=A.x(b5.i(0,"nozzle"))
l=p.$2("head",20)
k=p.$2("sp",5)
j=p.$2("off",0)
i=p.$2("arc",360)
h=p.$1("riser")
return A.pj(i,o!==!1,p.$1(a9),l,b3,b4,s,m,j,n,q,r,h,k)
case 17:r=r.$0()
q=A.x(b5.i(0,a8))
if(q==null)q=""
o=p.$2("inlet",10)
n=A.V(b5.i(0,"reg"))
m=p.$2("submin",0)
return A.po(p.$1(a9),p.$1("flush"),b3,o,b4,s,r,n===!0,m,q)
case 18:r=q.$0()
q=A.x(b5.i(0,a7))
if(q==null)q=b0
q=A.aj(B.D,q,t.E)
o=A.x(b5.i(0,"outlet"))
if(o==null)o=""
n=A.x(b5.i(0,"nozzle"))
m=p.$2("head",20)
l=p.$2("arc",360)
k=p.$1(a6)
p=p.$1("riser")
j=A.x(b5.i(0,b0))
return new A.b7(r,q,o,n,m,l,k,p,j==null?"":j,b3,b4,s)
case 19:r=q.$0()
q=A.x(b5.i(0,a8))
o=A.x(b5.i(0,b0))
if(o==null)o=s
n=p.$1(a6)
m=A.y(b5.i(0,"fixed"))
if(m==null)m=a5
return new A.ao(r,q,o,n,m,p.$1(a9),b3,b4,s)
case 20:r=q.$0()
q=A.V(b5.i(0,"calc"))
return new A.aH(r,q!==!1,p.$1("dh"),p.$1("mh"),p.$1("dq"),p.$1("mq"),p.$1("wl"),b3,b4,s)
case 21:r=q.$0()
q=A.x(b5.i(0,a8))
o=p.$2("speed",1)
p=p.$1(a6)
n=A.x(b5.i(0,a7))
if(n==null)n=b1
return new A.bA(r,q,o,p,A.aj(B.D,n,t.E),b3,b4,s)
case 22:r=q.$0()
q=A.x(b5.i(0,a8))
o=A.x(b5.i(0,a7))
if(o==null)o=b1
return new A.b6(r,q,A.aj(B.D,o,t.E),p.$1("set"),p.$1(a6),b3,b4,s)
case 23:r=q.$0()
q=A.x(b5.i(0,a7))
if(q==null)q=b0
q=A.aj(B.D,q,t.E)
p=A.y(b5.i(0,"z"))
return new A.ct(r,q,p==null?a5:p,b3,b4,s)
case 24:r=r.$0()
q=p.$2(a9,5)
o=p.$2("eff",0.9)
n=A.x(b5.i(0,"crop"))
if(n==null)n=""
m=A.y(b5.i(0,"epp"))
m=m==null?a5:B.b.a3(m)
if(m==null)m=0
l=A.V(b5.i(0,"wb"))
return new A.cM(r,q,o,n,m,l===!0,p.$2("eto",5),p.$2("kc",1),p.$2("awc",120),p.$2("root",0.6),p.$2("mad",0.5),p.$1("psp"),p.$1("rsp"),p.$2("wf",1),b3,b4,s)
case 25:r=q.$0()
q=p.$2("r",400)
o=p.$1("ang")
n=A.x(b5.i(0,"kind"))
if(n==null)n="pivot"
n=A.aj(B.f6,n,t.n7)
m=p.$1("travel")
l=p.$2("span",50)
k=A.x(b5.i(0,a8))
j=p.$2("idmm",162)
i=p.$2("c",130)
h=p.$2("hp",3.5)
g=p.$2("hend",14)
f=p.$1("qg")
e=p.$1("hg")
d=p.$2("throw",5)
c=p.$2(a9,8)
b=p.$2("hours",24)
a=p.$2("ww",18)
a0=p.$2("hm",2)
a1=p.$1("imax")
a2=p.$2("sector",360)
a3=p.$1("cost")
a4=A.x(b5.i(0,b0))
if(a4==null)a4=""
return new A.ba(p.$2("ssp",2.5),A.x(b5.i(0,"sspec")),A.x(b5.i(0,"rspec")),p.$1("tcost"),r,q,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,b3,b4,s)
case 26:r=q.$0()
q=A.y(b5.i(0,"st"))
q=q==null?a5:B.b.a3(q)
if(q==null)q=12
o=p.$2("v",24)
p=p.$1("cost")
n=A.y(b5.i(0,"sim"))
n=n==null?a5:B.b.a3(n)
return new A.ck(r,q,o,p,n==null?0:n,b3,b4,s)
case 27:return new A.cb(r.$0(),b3,b4,s)
case 28:r=q.$0()
q=t.j
p=A.bm(q.a(b5.i(0,"e")))
q=b5.i(0,"o")==null?B.O:A.bm(q.a(b5.i(0,"o")))
o=A.V(b5.i(0,"x"))
return new A.eZ(r,p,q,o!==!1,b3,b4,s)}},
bW(a){var s=J.aC(a,new A.kO(),t.bd)
s=A.p(s,s.$ti.j("w.E"))
return s},
p5(a,b,c,d,e,f,g,h){return new A.aM(g,h,f,a,b,c,d,e)},
pj(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.am(l,k,b,j,h,d,n,i,a,m,c,e,f,g)},
po(a,b,c,d,e,f,g,h,i,j){return new A.aG(g,j,d,h,i,a,b,c,e,f)},
oM(a){var s,r=a.gC()
A:{s=B.ab===r||B.ac===r||B.ad===r||B.ae===r||B.af===r||B.ag===r||B.ah===r||B.ai===r||B.aj===r||B.ak===r
break A}return s},
oL(a){var s
A:{s=null
if(a instanceof A.aM){s=a.e
break A}if(a instanceof A.am){s=B.h
break A}if(a instanceof A.aG){s=B.h
break A}if(a instanceof A.b7){s=a.e
break A}if(a instanceof A.ao)break A
if(a instanceof A.aH){s=B.i
break A}if(a instanceof A.bA){s=a.w
break A}if(a instanceof A.b6){s=a.f
break A}if(a instanceof A.ct){s=a.e
break A}if(a instanceof A.ba){s=B.i
break A}break A}return s},
oN(a){var s
A:{if(a instanceof A.cu){s=A.d([a.d,a.e],t.K)
break A}if(t.Q.b(a)){s=a.gO()
break A}if(a instanceof A.de){s=a.ek()
break A}s=null
break A}return s},
aL:function aL(a,b){this.a=a
this.b=b},
O:function O(a,b){this.a=a
this.b=b},
E:function E(){},
iG:function iG(a){this.a=a},
iH:function iH(){},
iF:function iF(a){this.a=a},
iE:function iE(a){this.a=a},
bb:function bb(){},
a4:function a4(){},
kO:function kO(){},
cu:function cu(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cX:function cX(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
el:function el(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
de:function de(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
d_:function d_(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
ev:function ev(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
aN:function aN(a,b){this.a=a
this.b=b},
f7:function f7(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
fa:function fa(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
es:function es(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
eg:function eg(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
f4:function f4(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
cO:function cO(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
ex:function ex(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.z=h
_.a=i
_.b=j
_.c=k},
cj:function cj(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
dO:function dO(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
aM:function aM(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
am:function am(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.z=h
_.Q=i
_.as=j
_.at=k
_.a=l
_.b=m
_.c=n},
aG:function aG(a,b,c,d,e,f,g,h,i,j){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.a=h
_.b=i
_.c=j},
b7:function b7(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.z=h
_.Q=i
_.a=j
_.b=k
_.c=l},
ao:function ao(a,b,c,d,e,f,g,h,i){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.a=g
_.b=h
_.c=i},
aH:function aH(a,b,c,d,e,f,g,h,i,j){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.a=h
_.b=i
_.c=j},
bA:function bA(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
b6:function b6(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
ct:function ct(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
ba:function ba(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.z=h
_.Q=i
_.as=j
_.at=k
_.ax=l
_.ay=m
_.ch=n
_.CW=o
_.cx=p
_.cy=q
_.db=r
_.dx=s
_.dy=a0
_.fr=a1
_.fx=a2
_.fy=a3
_.go=a4
_.id=a5
_.k1=a6
_.a=a7
_.b=a8
_.c=a9},
cM:function cM(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.y=g
_.z=h
_.Q=i
_.as=j
_.at=k
_.ax=l
_.ay=m
_.ch=n
_.a=o
_.b=p
_.c=q},
ck:function ck(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
cb:function cb(a,b,c,d){var _=this
_.d=a
_.a=b
_.b=c
_.c=d},
eZ:function eZ(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
fe:function fe(){},
fh:function fh(){},
fi:function fi(){},
fj:function fj(){},
fn:function fn(){},
fq:function fq(){},
fr:function fr(){},
ft:function ft(){},
fu:function fu(){},
fv:function fv(){},
fw:function fw(){},
fx:function fx(){},
fz:function fz(){},
fA:function fA(){},
fB:function fB(){},
fE:function fE(){},
fF:function fF(){},
fG:function fG(){},
fH:function fH(){},
fI:function fI(){},
mX(a,b,c){var s=a.a,r=a.b
return new A.C(s+(b.a-s)*c,r+(b.b-r)*c)},
bm(a){var s=J.ae(a)
return new A.C(A.az(s.i(a,0)),A.az(s.i(a,1)))},
ot(a){var s,r,q,p,o,n
for(s=a.$ti,r=new A.aV(a,a.gn(0),s.j("aV<w.E>")),s=s.j("w.E"),q=B.dc;r.l();){p=r.d
if(p==null)p=s.a(p)
o=p.a
n=Math.min(q.a,o)
p=p.b
q=new A.ek(n,Math.min(q.b,p),Math.max(q.c,o),Math.max(q.d,p))}return q},
kU(a,b,c){var s,r=c.U(0,b),q=r.cE(r)
if(q===0)return new A.m(b,0)
s=B.b.a7(a.U(0,b).cE(r)/q,0,1)
return new A.m(b.ap(0,r.aj(0,s)),s)},
b2(a){var s,r,q,p,o,n
for(s=J.ae(a),r=0,q=1;q<s.gn(a);++q){p=s.i(a,q-1)
o=s.i(a,q)
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)}return r},
rd(a,b){var s,r,q,p,o,n,m,l,k,j,i,h
for(s=b.length,r=s-1,q=a.b,p=a.a,o=!1,n=0;n<s;m=n+1,r=n,n=m){l=b[n]
if(!(r>=0&&r<s))return A.b(b,r)
k=b[r]
j=l.b
i=k.b
if(j>q!==i>q){h=l.a
h=p<(k.a-h)*(q-j)/(i-j)+h
j=h}else j=!1
if(j)o=!o}return o},
lo(a,b){var s,r,q,p,o,n,m,l,k=J.ae(a)
if(k.gG(a))return B.O
for(s=b,r=1;r<k.gn(a);++r){q=r-1
p=k.i(a,q)
o=k.i(a,r)
n=p.a-o.a
o=p.b-o.b
m=Math.sqrt(n*n+o*o)
if(s<=m||r===k.gn(a)-1){l=m===0?0:B.b.a7(s/m,0,1)
return A.mX(k.i(a,q),k.i(a,r),l)}s-=m}return k.gF(a)},
o0(a,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.t(a0),c=d.j("A<1>"),b=A.p(new A.A(a0,d.j("q(1)").a(new A.lK(a)),c),c.j("h.E"))
B.a.a5(b)
if(b.length===0){d=A.p(a,t.g)
return A.d([d],t.gv)}s=A.d([],t.gv)
d=J.a5(a)
c=t.K
r=A.d([d.gu(a)],c)
for(q=0,p=0,o=1;o<d.gn(a);++o,q=i){n=d.i(a,o-1)
m=d.i(a,o)
l=n.a-m.a
k=n.b-m.b
j=Math.sqrt(l*l+k*k)
l=j===0
i=q+j
k=i+1e-12
for(;;){h=b.length
if(p<h){if(!(p>=0))return A.b(b,p)
g=b[p]<=k}else g=!1
if(!g)break
if(l)f=0
else{if(!(p>=0&&p<h))return A.b(b,p)
f=(b[p]-q)/j}e=A.mX(n,m,f)
B.a.k(r,e)
B.a.k(s,r)
r=A.d([e],c);++p}B.a.k(r,m)}B.a.k(s,r)
d=t.ji
d=A.p(new A.A(s,t.eV.a(new A.lL()),d),d.j("h.E"))
return d},
qL(c1,c2,c3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=J.ae(c1)
if(c0.gn(c1)<2){c0=A.p(c1,t.g)
return c0}if(c0.gn(c1)===2)return A.d([c0.i(c1,0),c0.i(c1,1)],t.K)
s=c0.gn(c1)
r=new A.kS(c2,c1,s)
q=A.d([],t.K)
p=c2?s:s-1
for(o=0;o<p;o=l){n=r.$1(o-1)
m=r.$1(o)
l=o+1
k=r.$1(l)
j=r.$1(o+2)
i=new A.kT()
h=i.$3(0,n,m)
g=i.$3(h,m,k)
f=i.$3(g,k,j)
if(h<1e-9||g-h<1e-9||f-g<1e-9){B.a.k(q,m)
continue}for(e=g-h,d=n.a,c=n.b,b=m.a,a=m.b,a0=k.a,a1=k.b,a2=f-g,a3=j.a,a4=j.b,a5=f-h,a6=0;a6<c3;++a6){a7=h+e*a6/c3
a8=(h-a7)/h
a9=a7/h
b0=g-a7
b1=b0/e
b2=a7-h
b3=b2/e
b4=b*b1+a0*b3
b5=a*b1+a1*b3
b6=f-a7
b7=b6/a2
b8=(a7-g)/a2
b0/=g
b9=a7/g
b6/=a5
b2/=a5
B.a.k(q,new A.C(((d*a8+b*a9)*b0+b4*b9)*b1+(b4*b6+(a0*b7+a3*b8)*b2)*b3,((c*a8+a*a9)*b0+b5*b9)*b1+(b5*b6+(a1*b7+a4*b8)*b2)*b3))}}B.a.k(q,c2?c0.gu(c1):c0.gF(c1))
return q},
C:function C(a,b){this.a=a
this.b=b},
ek:function ek(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
lK:function lK(a){this.a=a},
lL:function lL(){},
kS:function kS(a,b,c){this.a=a
this.b=b
this.c=c},
kT:function kT(){},
mB(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9){return new A.hJ(b5,i,b7,a1,q,o,a2,a,c,m,b1,a4,a5,l,b9,b4,n,s,k,j,b2,d,e,a7,p,f,r,h,g,b,b6,a6,a3,a0,b3,a9,a8,b0,b8)},
oI(c0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8=null,b9="currency"
if(c0==null)return A.mB(!0,!0,0.05,"R$","BRL",1,1,0.3,B.ap,0,1,2000,0.1,1,2,3,2,100,3,0,1.5,5,6,0.75,0.65,!0,B.a7,0.22,0.37,20,10,5,B.aR,!0,B.db,0,20,10,500)
s=new A.hK(c0)
r=A.pv(t.dZ.a(c0.i(0,"units")))
q=A.x(c0.i(0,"method"))
if(q==null)q="hazenWilliams"
q=A.aj(B.f4,q,t.m1)
p=s.$2("temp",20)
o=s.$2("vZone",1.5)
n=s.$2("vMain",2)
m=s.$2("vLat",2)
l=s.$2("minorPct",5)
k=A.V(c0.i(0,"minor"))
j=s.$2("tol",0.05)
i=s.$2("interest",0.1)
h=A.y(c0.i(0,"term"))
h=h==null?b8:B.b.a3(h)
if(h==null)h=10
g=s.$2("kwh",0.75)
f=s.$2("eff",0.65)
e=s.$2("hours",2000)
d=s.$2("zoneHours",500)
c=A.V(c0.i(0,"trade"))
b=A.y(c0.i(0,"latSizes"))
b=b==null?b8:B.b.a3(b)
if(b==null)b=1
a=A.y(c0.i(0,"subSizes"))
a=a==null?b8:B.b.a3(a)
if(a==null)a=3
a0=s.$2("cScale",1)
a1=s.$2("cOffset",0)
a2=s.$2("densify",5)
a3=A.x(c0.i(0,b9))
if(a3==null)a3="R$"
a4=A.x(c0.i(0,"currencyCode"))
if(a4==null){a4=A.x(c0.i(0,b9))
a4=A.qQ(a4==null?"R$":a4)}if(a4==null)a4=""
a5=A.x(c0.i(0,"sizing"))
if(a5==null)a5="lp"
a5=A.aj(B.f7,a5,t.fA)
a6=A.y(c0.i(0,"mainSizes"))
a6=a6==null?b8:B.b.a3(a6)
if(a6==null)a6=3
a7=A.y(c0.i(0,"epp"))
a7=a7==null?b8:B.b.a3(a7)
if(a7==null)a7=1
a8=A.y(c0.i(0,"maxNodes"))
a8=a8==null?b8:B.b.a3(a8)
if(a8==null)a8=100
a9=s.$2("flushV",0.3)
b0=s.$2("flushH",1)
b1=A.V(c0.i(0,"surge"))
b2=s.$2("closure",0)
b3=A.V(c0.i(0,"fittings"))
b4=s.$2("stick",6)
b5=s.$2("zoneVar",0)
b6=A.x(c0.i(0,"terrain"))
if(b6==null)b6="idw"
b6=A.aj(B.f8,b6,t.oW)
b7=s.$2("inrushA",0.37)
return A.mB(k!==!1,b1!==!1,j,a3,a4,a7,b0,a9,q,a1,a0,e,i,b,m,a6,n,a8,a,b5,o,l,b4,g,f,b3!==!1,a5,s.$2("holdA",0.22),b7,s.$2("minV",20),h,a2,b6,c!==!1,r,b2,p,s.$2("slack",10),d)},
n3(a,b,c,d,e){return new A.bc(b,c,e,d,a)},
mV(a,b,c,d,e,f,g,h,i){var s
if(i==null){$.lV=$.lV+1
s="p"+B.c.bO(1000*Date.now(),36)+B.c.bO((A.cV(Date.now(),0,B.f,B.f)^$.lV*2654435761)>>>0,36)}else s=i
return new A.jq(s,b==null?new A.bH(Date.now(),0,!1):b,e,f,a,h,c,g,d)},
mW(){var s,r,q,p=A.d([],t.j8)
for(s=0;s<25;++s){r=B.f5[s]
q=B.bv.i(0,r)
p.push(new A.aE(r,q==null?4294967295:q,!0,!1))}return p},
pb(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=null
if(!J.aQ(a.i(0,"format"),"opencadirrigation")&&!J.aQ(a.i(0,"format"),"irrigationcad"))throw A.n(B.eO)
s=t.O
r=s.a(a.i(0,"entities"))
if(r==null)r=[]
r=J.aC(r,new A.jr(),t.h)
q=A.p(r,r.$ti.j("w.E"))
r=t.dZ
p=r.a(a.i(0,"meta"))
if(p==null)p=A.mV("",e,"",e,e,"New project","","",e)
else{o=A.x(p.i(0,"uid"))
n=A.x(p.i(0,"created"))
n=A.mA(n==null?"":n)
m=A.x(p.i(0,"modified"))
m=A.mA(m==null?"":m)
l=A.x(p.i(0,"name"))
if(l==null)l=""
k=A.x(p.i(0,"client"))
if(k==null)k=""
j=A.x(p.i(0,"site"))
if(j==null)j=""
i=A.x(p.i(0,"designer"))
if(i==null)i=""
h=A.x(p.i(0,"notes"))
if(h==null)h=""
if(p.i(0,"georef")!=null){p=t.P.a(p.i(0,"georef"))
g=B.b.a3(A.az(p.i(0,"zone")))
f=A.V(p.i(0,"north"))
p=new A.iJ(g,f!==!1,A.az(p.i(0,"e0")),A.az(p.i(0,"n0")))}else p=e
o=A.mV(k,n,i,p,m,l,h,j,o)
p=o}r=A.oI(r.a(a.i(0,"params")))
o=a.i(0,"catalog")!=null?A.oz(t.P.a(a.i(0,"catalog"))):A.ow()
n=s.a(a.i(0,"layers"))
if(n==null)n=[]
n=J.aC(n,new A.js(),t.df)
n=A.p(n,n.$ti.j("w.E"))
n=new A.jt().$1(n)
s=s.a(a.i(0,"systemFlows"))
if(s==null)s=[]
s=J.aC(s,new A.ju(),t.f)
s=A.p(s,s.$ti.j("w.E"))
m=A.y(a.i(0,"nextId"))
m=m==null?e:B.b.a3(m)
if(m==null)m=1
m=Math.max(m,A.pc(q))
if(n==null)n=A.mW()
s=new A.jp(p,r,o,n,q,s,m)
r=A.x(a.i(0,"currentLayer"))
s.w=r==null?"DRAWING":r
return s},
pc(a){var s,r,q,p,o,n,m
for(s=a.length,r=1,q=0;q<a.length;a.length===s||(0,A.j)(a),++q){p=a[q]
o=$.o6().cG(p.a)
if(o==null)continue
n=o.b
if(1>=n.length)return A.b(n,1)
n=n[1]
n.toString
m=A.mT(n,null)
if(m!=null&&m>=r)r=m+1}return r},
aE:function aE(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cz:function cz(a,b){this.a=a
this.b=b},
hJ:function hJ(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0
_.db=a1
_.dx=a2
_.dy=a3
_.fr=a4
_.fx=a5
_.fy=a6
_.go=a7
_.id=a8
_.k1=a9
_.k2=b0
_.k3=b1
_.k4=b2
_.ok=b3
_.p1=b4
_.p2=b5
_.p3=b6
_.p4=b7
_.R8=b8
_.RG=b9},
hK:function hK(a){this.a=a},
bc:function bc(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
jq:function jq(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
jp:function jp(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w="DRAWING"},
jv:function jv(){},
jw:function jw(){},
jx:function jx(){},
jr:function jr(){},
js:function js(){},
jt:function jt(){},
ju:function ju(){},
rj(c2,c3,c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=null,c1=A.oN(c2)
if(c1==null||J.at(c1)<2)return A.d([c2],t.w)
s=A.t(c3)
r=s.j("A<1>")
r=A.dz(new A.A(c3,s.j("q(1)").a(new A.lJ(A.b2(c1))),r),r.j("h.E"))
q=A.p(r,A.k(r).c)
B.a.a5(q)
if(q.length===0)return A.d([c2],t.w)
p=A.o0(c1,q)
if(p.length<2)return A.d([c2],t.w)
s=t.w
o=A.d([],s)
for(r=c2 instanceof A.cO,n=c2 instanceof A.d_,m=c2 instanceof A.aG,l=c2 instanceof A.am,k=c2 instanceof A.aM,j=c2 instanceof A.cj,i=c2 instanceof A.cX,h=c2 instanceof A.cu,g=c2.a,f=t.g,e=0,d=0;d<p.length;++d){c=d===0
b=c?g:c4.$0()
a=c2.c
if(a.length===0)a0=""
else a0=c?a:a+" ("+(d+1)+")"
if(!(d<p.length))return A.b(p,d)
a1=p[d]
a2=A.b2(a1)
A:{a3=h?c2:c0
if(h){c=a3.b
a=J.a5(a1)
B.a.k(o,new A.cu(a.gu(a1),a.gF(a1),b,c,a0))
break A}a4=i?c2:c0
if(i){B.a.k(o,new A.cX(a1,!1,b,a4.b,a0))
break A}a5=j?c2:c0
if(j){c=a5.b
B.a.k(o,new A.cj(a1,a5.e,a5.f,b,c,a0))
break A}a4=k?c2:c0
if(k){c=a4.b
a=a4.e
a6=a4.f
a7=a4.r
a8=a4.w
B.a.k(o,new A.aM(a1,a,a6,a7,a8,b,c,a0))
break A}if(l){a=!(c2.y>0)
a9=c2}else{a9=c0
a=!1}if(a){a=a9.z
b0=(a>0?a:a9.y)-e
if(c)b1=b0>=0&&b0<=a2+1e-9
else b1=b0>1e-9&&b0<=a2+1e-9
c=a9.b
a=a9.c
a6=A.p(a9.d,f)
c=new A.am(a6,a9.e,a9.f,a9.r,a9.w,a9.x,a9.y,a9.z,a9.Q,a9.as,a9.at,b,c,a)
c.c=a0
c.sO(a1)
c.z=b1?Math.max(b0,1e-9):a2+1
B.a.k(o,c)
break A}a9=l?c2:c0
if(l){b2=a9.z
b2=b2>0?b2:a9.y
c=a9.y
b3=B.b.an((e-b2)/c)
b4=b2+(b3<0?0:b3)*c
if(b4<e-1e-9)b4+=c
b5=(d>0&&b4<=e+1e-9*c?b4+c:b4)-e
a=a9.b
a6=a9.e
a7=a9.f
a8=a9.r
b6=a9.w
b7=a9.x
b8=b5<=1e-9?1e-9:b5
B.a.k(o,new A.am(a1,a6,a7,a8,b6,b7,c,b8,a9.Q,a9.as,a9.at,b,a,a0))
break A}b9=m?c2:c0
if(m){c=b9.b
a=b9.e
a6=b9.f
a7=b9.r
a8=b9.w
b6=b9.x
B.a.k(o,new A.aG(a1,a,a6,a7,a8,b6,d===p.length-1?b9.y:0,b,c,a0))
break A}a9=n?c2:c0
if(n){B.a.k(o,new A.d_(a1,!1,b,a9.b,a0))
break A}a3=r?c2:c0
if(r){c=a3.b
B.a.k(o,new A.cO(a1,a3.e,a3.f,b,c,a0))
break A}return A.d([c2],s)}e+=a2}return o},
lJ:function lJ(a){this.a=a},
cB:function cB(a,b){this.a=a
this.b=b},
bS:function bS(a,b){this.a=a
this.b=b},
f9:function f9(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=10
_.f=!1
_.r=null},
jP:function jP(){},
jQ:function jQ(){},
jR:function jR(){},
lZ(a,b,c,d){var s=new A.jS(a,b,c,d,A.l(t.S,t.L))
s.dj()
return s},
pq(c9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3=t.S,c4=A.l(t.N,c3),c5=t.n,c6=A.d([],c5),c7=A.d([],c5),c8=A.d([],c5)
for(c5=c9.length,s=0;s<c9.length;c9.length===c5||(0,A.j)(c9),++s){r=c9[s]
q=r.a
p=r.b
o=r.c
if(!isFinite(q)||!isFinite(p)||!isFinite(o))continue
n=""+B.b.a2(q*1000)+"|"+B.b.a2(p*1000)
m=c4.i(0,n)
if(m!=null){B.a.h(c8,m,o)
continue}c4.h(0,n,c6.length)
B.a.k(c6,q)
B.a.k(c7,p)
B.a.k(c8,o)}l=c6.length
if(l<3)return A.lZ(c6,c7,c8,A.d([],t.ae))
k=B.a.M(c6,B.H)
j=B.a.M(c6,B.m)
i=B.a.M(c7,B.H)
h=B.a.M(c7,B.m)
g=Math.max(Math.max(j-k,h-i),0.000001)
if(g<1e-9)return A.lZ(c6,c7,c8,A.d([],t.ae))
f=(k+j)/2
e=(i+h)/2
c5=t.i
r=A.p(c6,c5)
d=20*g
r.push(f-d)
r.push(f)
r.push(f+d)
c5=A.p(c7,c5)
c5.push(e-g*20)
c5.push(e+d)
c5.push(e-d)
d=t.ae
c=A.d([],d)
b=new A.jV(r,c5)
a=new A.ca(l,l+1,l+2)
b.$1(a)
B.a.k(c,a)
a0=J.eC(l,c3)
for(m=0;m<l;++m)a0[m]=m
B.a.ak(a0,new A.jW(new A.jU(r,k,g,B.c.a7(B.b.an(Math.sqrt(l)/2),1,512),c5,i)))
a1=A.d([],d)
B.a.k(a1,a)
for(a2=a0.length,a3=t.hD,s=0;s<a0.length;a0.length===a2||(0,A.j)(a0),++s){m=a0[s]
if(!(m<r.length))return A.b(r,m)
q=r[m]
if(!(m<c5.length))return A.b(c5,m)
p=c5[m]
a4=A.d([],d)
a5=A.d([],d)
for(a6=a1.length,a7=0;a7<a1.length;a1.length===a6||(0,A.j)(a1),++a7){a8=a1[a7]
a9=q-a8.d
b0=p-a8.e
if(a9*a9+b0*b0<=a8.f*1.000000000001)B.a.k(a4,a8)
else B.a.k(a5,a8)}if(a4.length===0)continue
b1=A.l(c3,c3)
b2=A.d([],a3)
b3=new A.jX(b1,b2)
for(a6=a4.length,a7=0;a7<a4.length;a4.length===a6||(0,A.j)(a4),++a7){a8=a4[a7]
b4=a8.a
b5=a8.b
b3.$2(b4,b5)
b6=a8.c
b3.$2(b5,b6)
b3.$2(b6,b4)}for(a6=b2.length,a7=0;a7<b2.length;b2.length===a6||(0,A.j)(b2),++a7){b4=b2[a7]
b7=b4.a
b8=b4.b
if(b1.i(0,b7<b8?b7*4194304+b8:b8*4194304+b7)!==1)continue
a8=new A.ca(b7,b8,m)
b.$1(a8)
B.a.k(a5,a8)}a1=a5}b9=A.d([],d)
for(c3=a1.length,s=0;s<a1.length;a1.length===c3||(0,A.j)(a1),++s){a8=a1[s]
d=a8.a
if(d>=l||a8.b>=l||a8.c>=l)continue
a2=a8.b
a3=r.length
if(!(a2>=0&&a2<a3))return A.b(r,a2)
a6=r[a2]
if(!(d>=0&&d<a3))return A.b(r,d)
b4=r[d]
b5=a8.c
b6=c5.length
if(!(b5>=0&&b5<b6))return A.b(c5,b5)
c0=c5[b5]
if(!(d<b6))return A.b(c5,d)
c1=c5[d]
if(!(a2<b6))return A.b(c5,a2)
b6=c5[a2]
if(!(b5<a3))return A.b(r,b5)
c2=(a6-b4)*(c0-c1)-(b6-c1)*(r[b5]-b4)
if(Math.abs(c2)<1e-12)continue
B.a.k(b9,c2>0?a8:new A.ca(d,b5,a2))}return A.lZ(c6,c7,c8,b9)},
ca:function ca(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=0},
jS:function jS(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=1
_.w=_.r=0},
jV:function jV(a,b){this.a=a
this.b=b},
jU:function jU(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
jW:function jW(a){this.a=a},
jX:function jX(a,b){this.a=a
this.b=b},
jT:function jT(){},
fP(a){var s=B.b.a7(a,0,60)
return 0.000001792/(1+0.0337*s+0.000221*s*s)},
pv(a){var s,r,q,p
if(a==null)return B.db
s=A.x(a.i(0,"length"))
if(s==null)s="m"
s=A.aj(B.fk,s,t.hu)
r=A.x(a.i(0,"flow"))
if(r==null)r="lph"
r=A.aj(B.fm,r,t.mf)
q=A.x(a.i(0,"pressure"))
if(q==null)q="mH2O"
q=A.aj(B.fl,q,t.c4)
p=A.x(a.i(0,"diameter"))
if(p==null)p="mm"
return new A.fc(s,r,q,A.aj(B.f2,p,t.ks))},
bz:function bz(a,b){this.a=a
this.b=b},
bw:function bw(a,b){this.a=a
this.b=b},
bP:function bP(a,b){this.a=a
this.b=b},
cm:function cm(a,b){this.a=a
this.b=b},
fc:function fc(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
r9(){var s,r=v.G,q=new A.lm(r)
if(typeof q=="function")A.bs(A.df("Attempting to rewrap a JS function.",null))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.q4,q)
s[$.mj()]=q
r.addEventListener("message",s)},
lm:function lm(a){this.a=a},
ll:function ll(a){this.a=a},
o1(a){return v.mangledGlobalNames[a]},
rm(a){throw A.af(A.mI(a),new Error())},
rn(){throw A.af(A.mI(""),new Error())},
q4(a,b,c){t.Z.a(a)
if(A.aI(c)>=1)return a.$1(b)
return a.$0()},
nU(a,b,c){A.nH(c,t.H,"T","min")
return Math.min(c.a(a),c.a(b))},
nT(a,b,c){A.nH(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.lQ.prototype={}
J.eA.prototype={
Y(a,b){return a===b},
gL(a){return A.f2(a)},
t(a){return"Instance of '"+A.f3(a)+"'"},
gS(a){return A.bX(A.m6(this))}}
J.eD.prototype={
t(a){return String(a)},
gL(a){return a?519018:218159},
gS(a){return A.bX(t.y)},
$iQ:1,
$iq:1}
J.du.prototype={
Y(a,b){return null==b},
t(a){return"null"},
gL(a){return 0},
$iQ:1}
J.dw.prototype={$ia3:1}
J.c7.prototype={
gL(a){return 0},
t(a){return String(a)}}
J.f0.prototype={}
J.cC.prototype={}
J.c6.prototype={
t(a){var s=a[$.o3()]
if(s==null)s=a[$.mj()]
if(s==null)return this.d2(a)
return"JavaScript function for "+J.dd(s)},
$ibK:1}
J.dv.prototype={
gL(a){return 0},
t(a){return String(a)}}
J.dx.prototype={
gL(a){return 0},
t(a){return String(a)}}
J.o.prototype={
b2(a,b){return new A.a9(a,A.t(a).j("@<1>").A(b).j("a9<1,2>"))},
k(a,b){A.t(a).c.a(b)
a.$flags&1&&A.ag(a,29)
a.push(b)},
el(a,b){a.$flags&1&&A.ag(a,"removeAt",1)
if(b<0||b>=a.length)throw A.n(A.lW(b,null))
return a.splice(b,1)[0]},
e8(a,b,c){A.t(a).c.a(c)
a.$flags&1&&A.ag(a,"insert",2)
if(b<0||b>a.length)throw A.n(A.lW(b,null))
a.splice(b,0,c)},
T(a,b){var s
a.$flags&1&&A.ag(a,"remove",1)
for(s=0;s<a.length;++s)if(J.aQ(a[s],b)){a.splice(s,1)
return!0}return!1},
B(a,b){var s
A.t(a).j("h<1>").a(b)
a.$flags&1&&A.ag(a,"addAll",2)
if(Array.isArray(b)){this.d4(a,b)
return}for(s=J.a0(b);s.l();)a.push(s.gp())},
d4(a,b){var s,r
t.dG.a(b)
s=b.length
if(s===0)return
if(a===b)throw A.n(A.ai(a))
for(r=0;r<s;++r)a.push(b[r])},
W(a){a.$flags&1&&A.ag(a,"clear","clear")
a.length=0},
aM(a,b,c){var s=A.t(a)
return new A.u(a,s.A(c).j("1(2)").a(b),s.j("@<1>").A(c).j("u<1,2>"))},
ee(a,b){var s,r=A.bj(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.h(r,s,A.z(a[s]))
return r.join(b)},
aa(a,b){return A.c9(a,b,null,A.t(a).c)},
M(a,b){var s,r,q
A.t(a).j("1(1,1)").a(b)
s=a.length
if(s===0)throw A.n(A.ak())
if(0>=s)return A.b(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.n(A.ai(a))}return r},
P(a,b,c,d){var s,r,q
d.a(b)
A.t(a).A(d).j("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.n(A.ai(a))}return r},
ae(a,b,c){var s,r,q,p=A.t(a)
p.j("q(1)").a(b)
p.j("1()?").a(c)
s=a.length
for(r=0;r<s;++r){q=a[r]
if(b.$1(q))return q
if(a.length!==s)throw A.n(A.ai(a))}p=c.$0()
return p},
K(a,b){if(!(b>=0&&b<a.length))return A.b(a,b)
return a[b]},
d0(a,b,c){var s=a.length
if(b>s)throw A.n(A.aY(b,0,s,"start",null))
if(c<b||c>s)throw A.n(A.aY(c,b,s,"end",null))
if(b===c)return A.d([],A.t(a))
return A.d(a.slice(b,c),A.t(a))},
gu(a){if(a.length>0)return a[0]
throw A.n(A.ak())},
gF(a){var s=a.length
if(s>0)return a[s-1]
throw A.n(A.ak())},
Z(a,b){var s,r
A.t(a).j("q(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.n(A.ai(a))}return!1},
gcN(a){return new A.bB(a,A.t(a).j("bB<1>"))},
ak(a,b){var s,r,q,p,o,n=A.t(a)
n.j("f(1,1)?").a(b)
a.$flags&2&&A.ag(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.qf()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cV()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.fL(b,2))
if(p>0)this.dw(a,p)},
a5(a){return this.ak(a,null)},
dw(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
cH(a,b){var s,r=a.length
if(0>=r)return-1
for(s=0;s<r;++s){if(!(s<a.length))return A.b(a,s)
if(J.aQ(a[s],b))return s}return-1},
v(a,b){var s
for(s=0;s<a.length;++s)if(J.aQ(a[s],b))return!0
return!1},
gG(a){return a.length===0},
ga0(a){return a.length!==0},
t(a){return A.iO(a,"[","]")},
gq(a){return new J.ch(a,a.length,A.t(a).j("ch<1>"))},
gL(a){return A.f2(a)},
gn(a){return a.length},
sn(a,b){a.$flags&1&&A.ag(a,"set length","change the length of")
if(b<0)throw A.n(A.aY(b,0,null,"newLength",null))
if(b>a.length)A.t(a).c.a(null)
a.length=b},
i(a,b){if(!(b>=0&&b<a.length))throw A.n(A.fM(a,b))
return a[b]},
h(a,b,c){A.t(a).c.a(c)
a.$flags&2&&A.ag(a)
if(!(b>=0&&b<a.length))throw A.n(A.fM(a,b))
a[b]=c},
$iB:1,
$ih:1,
$ir:1}
J.eB.prototype={
es(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.f3(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.iP.prototype={}
J.ch.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.j(q)
throw A.n(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iR:1}
J.cr.prototype={
N(a,b){var s
A.az(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gb6(b)
if(this.gb6(a)===s)return 0
if(this.gb6(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gb6(a){return a===0?1/a<0:a<0},
a3(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.n(A.bD(""+a+".toInt()"))},
an(a){var s,r
if(a>=0){if(a<=2147483647){s=a|0
return a===s?s:s+1}}else if(a>=-2147483648)return a|0
r=Math.ceil(a)
if(isFinite(r))return r
throw A.n(A.bD(""+a+".ceil()"))},
I(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.n(A.bD(""+a+".floor()"))},
a2(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.n(A.bD(""+a+".round()"))},
b9(a){if(a<0)return-Math.round(-a)
else return Math.round(a)},
a7(a,b,c){if(B.c.N(b,c)>0)throw A.n(A.nF(b))
if(this.N(a,b)<0)return b
if(this.N(a,c)>0)return c
return a},
a4(a,b){var s
if(b>20)throw A.n(A.aY(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gb6(a))return"-"+s
return s},
bO(a,b){var s,r,q,p,o
if(b<2||b>36)throw A.n(A.aY(b,2,36,"radix",null))
s=a.toString(b)
r=s.length
q=r-1
if(!(q>=0))return A.b(s,q)
if(s.charCodeAt(q)!==41)return s
p=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(s)
if(p==null)A.bs(A.bD("Unexpected toString result: "+s))
r=p.length
if(1>=r)return A.b(p,1)
s=p[1]
if(3>=r)return A.b(p,3)
o=+p[3]
r=p[2]
if(r!=null){s+=r
o-=r.length}return s+B.d.aj("0",o)},
t(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gL(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
U(a,b){return a-b},
bc(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
if(b<0)return s-b
else return s+b},
bw(a,b){return(a|0)===a?a/b|0:this.dF(a,b)},
dF(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.n(A.bD("Result of truncating division is "+A.z(s)+": "+A.z(a)+" ~/ "+b))},
aZ(a,b){var s
if(a>0)s=this.dB(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
dB(a,b){return b>31?0:a>>>b},
gS(a){return A.bX(t.H)},
$iaS:1,
$ie:1,
$iaB:1}
J.dt.prototype={
gS(a){return A.bX(t.S)},
$iQ:1,
$if:1}
J.eE.prototype={
gS(a){return A.bX(t.i)},
$iQ:1}
J.cs.prototype={
az(a,b,c){return a.substring(b,A.mZ(b,c,a.length))},
aG(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(0>=o)return A.b(p,0)
if(p.charCodeAt(0)===133){s=J.oY(p,1)
if(s===o)return""}else s=0
r=o-1
if(!(r>=0))return A.b(p,r)
q=p.charCodeAt(r)===133?J.oZ(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
aj(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.n(B.dq)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
ej(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aj(c,s)+a},
N(a,b){var s
A.D(b)
if(a===b)s=0
else s=a<b?-1:1
return s},
t(a){return a},
gL(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gS(a){return A.bX(t.N)},
gn(a){return a.length},
i(a,b){if(b>=a.length)throw A.n(A.fM(a,b))
return a[b]},
$iQ:1,
$iaS:1,
$iji:1,
$ic:1}
A.cc.prototype={
gq(a){return new A.dh(J.a0(this.gac()),A.k(this).j("dh<1,2>"))},
gn(a){return J.at(this.gac())},
gG(a){return J.mo(this.gac())},
ga0(a){return J.om(this.gac())},
aa(a,b){var s=A.k(this)
return A.mu(J.mp(this.gac(),b),s.c,s.y[1])},
K(a,b){return A.k(this).y[1].a(J.fR(this.gac(),b))},
gu(a){return A.k(this).y[1].a(J.bZ(this.gac()))},
gF(a){return A.k(this).y[1].a(J.lN(this.gac()))},
t(a){return J.dd(this.gac())}}
A.dh.prototype={
l(){return this.a.l()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iR:1}
A.ci.prototype={
gac(){return this.a}}
A.dX.prototype={$iB:1}
A.dW.prototype={
i(a,b){return this.$ti.y[1].a(J.dc(this.a,b))},
h(a,b,c){var s=this.$ti
J.lM(this.a,b,s.c.a(s.y[1].a(c)))},
sn(a,b){J.op(this.a,b)},
k(a,b){var s=this.$ti
J.b3(this.a,s.c.a(s.y[1].a(b)))},
$iB:1,
$ir:1}
A.a9.prototype={
b2(a,b){return new A.a9(this.a,this.$ti.j("@<1>").A(b).j("a9<1,2>"))},
gac(){return this.a}}
A.eK.prototype={
t(a){return"LateInitializationError: "+this.a}}
A.jC.prototype={}
A.B.prototype={}
A.w.prototype={
gq(a){var s=this
return new A.aV(s,s.gn(s),A.k(s).j("aV<w.E>"))},
gG(a){return this.gn(this)===0},
gu(a){if(this.gn(this)===0)throw A.n(A.ak())
return this.K(0,0)},
gF(a){var s=this
if(s.gn(s)===0)throw A.n(A.ak())
return s.K(0,s.gn(s)-1)},
bP(a,b){return this.d1(0,A.k(this).j("q(w.E)").a(b))},
aM(a,b,c){var s=A.k(this)
return new A.u(this,s.A(c).j("1(w.E)").a(b),s.j("@<w.E>").A(c).j("u<1,2>"))},
M(a,b){var s,r,q,p=this
A.k(p).j("w.E(w.E,w.E)").a(b)
s=p.gn(p)
if(s===0)throw A.n(A.ak())
r=p.K(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.K(0,q))
if(s!==p.gn(p))throw A.n(A.ai(p))}return r},
aa(a,b){return A.c9(this,b,null,A.k(this).j("w.E"))},
aw(a){var s,r=this,q=A.eM(A.k(r).j("w.E"))
for(s=0;s<r.gn(r);++s)q.k(0,r.K(0,s))
return q}}
A.dR.prototype={
gdf(){var s=J.at(this.a),r=this.c
if(r==null||r>s)return s
return r},
gdD(){var s=J.at(this.a),r=this.b
if(r>s)return s
return r},
gn(a){var s,r=J.at(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
K(a,b){var s=this,r=s.gdD()+b
if(b<0||r>=s.gdf())throw A.n(A.iN(b,s.gn(0),s,"index"))
return J.fR(s.a,r)},
aa(a,b){var s,r,q=this
A.cZ(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.dl(q.$ti.j("dl<1>"))
return A.c9(q.a,s,r,q.$ti.c)},
eq(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.ae(n),l=m.gn(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=p.$ti.c
return b?J.mF(0,n):J.mE(0,n)}r=A.bj(s,m.K(n,o),b,p.$ti.c)
for(q=1;q<s;++q){B.a.h(r,q,m.K(n,o+q))
if(m.gn(n)<l)throw A.n(A.ai(p))}return r},
cQ(a){return this.eq(0,!0)}}
A.aV.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=J.ae(q),o=p.gn(q)
if(r.b!==o)throw A.n(A.ai(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.K(q,s);++r.c
return!0},
$iR:1}
A.aF.prototype={
gq(a){return new A.dD(J.a0(this.a),this.b,A.k(this).j("dD<1,2>"))},
gn(a){return J.at(this.a)},
gG(a){return J.mo(this.a)},
gu(a){return this.b.$1(J.bZ(this.a))},
gF(a){return this.b.$1(J.lN(this.a))},
K(a,b){return this.b.$1(J.fR(this.a,b))}}
A.co.prototype={$iB:1}
A.dD.prototype={
l(){var s=this,r=s.b
if(r.l()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iR:1}
A.u.prototype={
gn(a){return J.at(this.a)},
K(a,b){return this.b.$1(J.fR(this.a,b))}}
A.A.prototype={
gq(a){return new A.dU(J.a0(this.a),this.b,this.$ti.j("dU<1>"))}}
A.dU.prototype={
l(){var s,r
for(s=this.a,r=this.b;s.l();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iR:1}
A.dL.prototype={
aa(a,b){this.b.ap(0,A.kK(b))
return void 1},
gq(a){return new A.dM(J.a0(this.a),this.b,A.k(this).j("dM<1>"))}}
A.iB.prototype={
gn(a){var s=B.c.U(J.at(this.a),this.b)
if(s>=0)return s
return 0},
aa(a,b){this.b.ap(0,A.kK(b))
return void 1},
$iB:1}
A.dM.prototype={
l(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.l()
this.b=0
return s.l()},
gp(){return this.a.gp()},
$iR:1}
A.dl.prototype={
gq(a){return B.di},
gG(a){return!0},
gn(a){return 0},
gu(a){throw A.n(A.ak())},
gF(a){throw A.n(A.ak())},
K(a,b){throw A.n(A.aY(b,0,0,"index",null))},
aa(a,b){A.cZ(b,"count")
return this}}
A.dm.prototype={
l(){return!1},
gp(){throw A.n(A.ak())},
$iR:1}
A.b0.prototype={
gq(a){return new A.bo(J.a0(this.a),this.$ti.j("bo<1>"))}}
A.bo.prototype={
l(){var s,r
for(s=this.a,r=this.$ti.c;s.l();)if(r.b(s.gp()))return!0
return!1},
gp(){return this.$ti.c.a(this.a.gp())},
$iR:1}
A.a_.prototype={
sn(a,b){throw A.n(A.bD("Cannot change the length of a fixed-length list"))},
k(a,b){A.a6(a).j("a_.E").a(b)
throw A.n(A.bD("Cannot add to a fixed-length list"))}}
A.bB.prototype={
gn(a){return J.at(this.a)},
K(a,b){var s=this.a,r=J.ae(s)
return r.K(s,r.gn(s)-1-b)}}
A.ec.prototype={}
A.m.prototype={$r:"+(1,2)",$s:1}
A.a.prototype={$r:"+(1,2,3)",$s:2}
A.d6.prototype={$r:"+(1,2,3,4)",$s:3}
A.aP.prototype={$r:"+run,stage,zoneId,zoneIndex(1,2,3,4)",$s:4}
A.di.prototype={
gG(a){return this.gn(this)===0},
t(a){return A.lS(this)},
h(a,b,c){var s=A.k(this)
s.c.a(b)
s.y[1].a(c)
A.mx()},
T(a,b){A.mx()},
gaL(){return new A.bF(this.e1(),A.k(this).j("bF<aq<1,2>>"))},
e1(){var s=this
return function(){var r=0,q=1,p=[],o,n,m,l,k
return function $async$gaL(a,b,c){if(b===1){p.push(c)
r=q}for(;;)switch(r){case 0:o=s.ga8(),o=o.gq(o),n=A.k(s),m=n.y[1],n=n.j("aq<1,2>")
case 2:if(!o.l()){r=3
break}l=o.gp()
k=s.i(0,l)
r=4
return a.b=new A.aq(l,k==null?m.a(k):k,n),1
case 4:r=2
break
case 3:return 0
case 1:return a.c=p.at(-1),3}}}},
$ii:1}
A.aT.prototype={
gn(a){return this.b.length},
gc7(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
E(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.E(b))return null
return this.b[this.a[b]]},
a_(a,b){var s,r,q,p
this.$ti.j("~(1,2)").a(b)
s=this.gc7()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])},
ga8(){return new A.dY(this.gc7(),this.$ti.j("dY<1>"))}}
A.dY.prototype={
gn(a){return this.a.length},
gG(a){return 0===this.a.length},
ga0(a){return 0!==this.a.length},
gq(a){var s=this.a
return new A.cF(s,s.length,this.$ti.j("cF<1>"))}}
A.cF.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c
if(r>=s.b){s.d=null
return!1}s.d=s.a[r]
s.c=r+1
return!0},
$iR:1}
A.dj.prototype={
k(a,b){A.k(this).c.a(b)
A.my()},
T(a,b){A.my()}}
A.c0.prototype={
gn(a){return this.b},
gG(a){return this.b===0},
ga0(a){return this.b!==0},
gq(a){var s,r=this,q=r.$keys
if(q==null){q=Object.keys(r.a)
r.$keys=q}s=q
return new A.cF(s,s.length,r.$ti.j("cF<1>"))},
v(a,b){if(typeof b!="string")return!1
if("__proto__"===b)return!1
return this.a.hasOwnProperty(b)}}
A.ez.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.bL&&this.a.Y(0,b.a)&&A.me(this)===A.me(b)},
gL(a){return A.cV(this.a,A.me(this),B.f,B.f)},
t(a){var s=B.a.ee([A.bX(this.$ti.c)],", ")
return this.a.t(0)+" with "+("<"+s+">")}}
A.bL.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.r6(A.kV(this.a),this.$ti)}}
A.dK.prototype={}
A.jY.prototype={
ag(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
if(p==null)return null
s=Object.create(null)
r=q.b
if(r!==-1)s.arguments=p[r+1]
r=q.c
if(r!==-1)s.argumentsExpr=p[r+1]
r=q.d
if(r!==-1)s.expr=p[r+1]
r=q.e
if(r!==-1)s.method=p[r+1]
r=q.f
if(r!==-1)s.receiver=p[r+1]
return s}}
A.dI.prototype={
t(a){return"Null check operator used on a null value"}}
A.eG.prototype={
t(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.fd.prototype={
t(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.jd.prototype={
t(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.dn.prototype={}
A.e6.prototype={
t(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$ic8:1}
A.aD.prototype={
t(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.o2(r==null?"unknown":r)+"'"},
$ibK:1,
gey(){return this},
$C:"$1",
$R:1,
$D:null}
A.em.prototype={$C:"$0",$R:0}
A.en.prototype={$C:"$2",$R:2}
A.f8.prototype={}
A.f6.prototype={
t(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.o2(s)+"'"}}
A.cN.prototype={
Y(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.cN))return!1
return this.$_target===b.$_target&&this.a===b.a},
gL(a){return(A.nW(this.a)^A.f2(this.$_target))>>>0},
t(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.f3(this.a)+"'")}}
A.f5.prototype={
t(a){return"RuntimeError: "+this.a}}
A.bM.prototype={
gn(a){return this.a},
gG(a){return this.a===0},
ga8(){return new A.aa(this,A.k(this).j("aa<1>"))},
gaL(){return new A.J(this,A.k(this).j("J<1,2>"))},
E(a){var s,r
if(typeof a=="string"){s=this.b
if(s==null)return!1
return s[a]!=null}else if(typeof a=="number"&&(a&0x3fffffff)===a){r=this.c
if(r==null)return!1
return r[a]!=null}else return this.e9(a)},
e9(a){var s=this.d
if(s==null)return!1
return this.b5(this.c4(s,a),a)>=0},
B(a,b){A.k(this).j("i<1,2>").a(b).a_(0,new A.iQ(this))},
i(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.ea(b)},
ea(a){var s,r,q=this.d
if(q==null)return null
s=this.c4(q,a)
r=this.b5(s,a)
if(r<0)return null
return s[r].b},
h(a,b,c){var s,r,q=this,p=A.k(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.bS(s==null?q.b=q.br():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.bS(r==null?q.c=q.br():r,b,c)}else q.ec(b,c)},
ec(a,b){var s,r,q,p,o=this,n=A.k(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.br()
r=o.bH(a)
q=s[r]
if(q==null)s[r]=[o.be(a,b)]
else{p=o.b5(q,a)
if(p>=0)q[p].b=b
else q.push(o.be(a,b))}},
X(a,b){var s,r,q=this,p=A.k(q)
p.c.a(a)
p.j("2()").a(b)
if(q.E(a)){s=q.i(0,a)
return s==null?p.y[1].a(s):s}r=b.$0()
q.h(0,a,r)
return r},
T(a,b){var s=this
if(typeof b=="string")return s.bT(s.b,b)
else if(typeof b=="number"&&(b&0x3fffffff)===b)return s.bT(s.c,b)
else return s.eb(b)},
eb(a){var s,r,q,p,o=this,n=o.d
if(n==null)return null
s=o.bH(a)
r=n[s]
q=o.b5(r,a)
if(q<0)return null
p=r.splice(q,1)[0]
o.bU(p)
if(r.length===0)delete n[s]
return p.b},
W(a){var s=this
if(s.a>0){s.b=s.c=s.d=s.e=s.f=null
s.a=0
s.bd()}},
a_(a,b){var s,r,q=this
A.k(q).j("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.n(A.ai(q))
s=s.c}},
bS(a,b,c){var s,r=A.k(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.be(b,c)
else s.b=c},
bT(a,b){var s
if(a==null)return null
s=a[b]
if(s==null)return null
this.bU(s)
delete a[b]
return s.b},
bd(){this.r=this.r+1&1073741823},
be(a,b){var s=this,r=A.k(s),q=new A.iT(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else{r=s.f
r.toString
q.d=r
s.f=r.c=q}++s.a
s.bd()
return q},
bU(a){var s=this,r=a.d,q=a.c
if(r==null)s.e=q
else r.c=q
if(q==null)s.f=r
else q.d=r;--s.a
s.bd()},
bH(a){return J.aR(a)&1073741823},
c4(a,b){return a[this.bH(b)]},
b5(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aQ(a[r].a,b))return r
return-1},
t(a){return A.lS(this)},
br(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$imJ:1}
A.iQ.prototype={
$2(a,b){var s=this.a,r=A.k(s)
s.h(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.k(this.a).j("~(1,2)")}}
A.iT.prototype={}
A.aa.prototype={
gn(a){return this.a.a},
gG(a){return this.a.a===0},
gq(a){var s=this.a
return new A.au(s,s.r,s.e,this.$ti.j("au<1>"))},
v(a,b){return this.a.E(b)}}
A.au.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.n(A.ai(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iR:1}
A.av.prototype={
gn(a){return this.a.a},
gG(a){return this.a.a===0},
gq(a){var s=this.a
return new A.M(s,s.r,s.e,this.$ti.j("M<1>"))}}
A.M.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.n(A.ai(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iR:1}
A.J.prototype={
gn(a){return this.a.a},
gG(a){return this.a.a===0},
gq(a){var s=this.a
return new A.ap(s,s.r,s.e,this.$ti.j("ap<1,2>"))}}
A.ap.prototype={
gp(){var s=this.d
s.toString
return s},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.n(A.ai(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.aq(s.a,s.b,r.$ti.j("aq<1,2>"))
r.c=s.c
return!0}},
$iR:1}
A.le.prototype={
$1(a){return this.a(a)},
$S:28}
A.lf.prototype={
$2(a,b){return this.a(a,b)},
$S:34}
A.lg.prototype={
$1(a){return this.a(A.D(a))},
$S:55}
A.bf.prototype={
t(a){return this.cs(!1)},
cs(a){var s,r,q,p,o,n=this.dg(),m=this.aQ(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.b(m,q)
o=m[q]
l=a?l+A.mU(o):l+A.z(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
dg(){var s,r=this.$s
while($.kB.length<=r)B.a.k($.kB,null)
s=$.kB[r]
if(s==null){s=this.da()
B.a.h($.kB,r,s)}return s},
da(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.D,j=J.eC(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.a.h(j,q,r[s])}}j=A.eN(j,!1,k)
j.$flags=3
return j}}
A.d4.prototype={
aQ(){return[this.a,this.b]},
Y(a,b){if(b==null)return!1
return b instanceof A.d4&&this.$s===b.$s&&J.aQ(this.a,b.a)&&J.aQ(this.b,b.b)},
gL(a){return A.cV(this.$s,this.a,this.b,B.f)}}
A.d5.prototype={
aQ(){return[this.a,this.b,this.c]},
Y(a,b){var s=this
if(b==null)return!1
return b instanceof A.d5&&s.$s===b.$s&&J.aQ(s.a,b.a)&&J.aQ(s.b,b.b)&&J.aQ(s.c,b.c)},
gL(a){var s=this
return A.cV(s.$s,s.a,s.b,s.c)}}
A.cH.prototype={
aQ(){return this.a},
Y(a,b){if(b==null)return!1
return b instanceof A.cH&&this.$s===b.$s&&A.pO(this.a,b.a)},
gL(a){return A.cV(this.$s,A.p3(this.a),B.f,B.f)}}
A.eF.prototype={
t(a){return"RegExp/"+this.a+"/"+this.b.flags},
cG(a){var s=this.b.exec(a)
if(s==null)return null
return new A.kA(s)},
$iji:1,
$ipf:1}
A.kA.prototype={
i(a,b){var s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.cS.prototype={
gS(a){return B.FY},
$iQ:1}
A.dG.prototype={}
A.eP.prototype={
gS(a){return B.FZ},
$iQ:1}
A.cT.prototype={
gn(a){return a.length},
$iaU:1}
A.dE.prototype={
i(a,b){A.bV(b,a,a.length)
return a[b]},
h(a,b,c){A.W(c)
a.$flags&2&&A.ag(a)
A.bV(b,a,a.length)
a[b]=c},
$iB:1,
$ih:1,
$ir:1}
A.dF.prototype={
h(a,b,c){A.aI(c)
a.$flags&2&&A.ag(a)
A.bV(b,a,a.length)
a[b]=c},
$iB:1,
$ih:1,
$ir:1}
A.eQ.prototype={
gS(a){return B.G_},
$iQ:1}
A.eR.prototype={
gS(a){return B.G0},
$iQ:1,
$ibJ:1}
A.eS.prototype={
gS(a){return B.G1},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1}
A.eT.prototype={
gS(a){return B.G2},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1}
A.eU.prototype={
gS(a){return B.G3},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1}
A.eV.prototype={
gS(a){return B.G5},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1}
A.eW.prototype={
gS(a){return B.G6},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1}
A.dH.prototype={
gS(a){return B.G7},
gn(a){return a.length},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1}
A.eX.prototype={
gS(a){return B.G8},
gn(a){return a.length},
i(a,b){A.bV(b,a,a.length)
return a[b]},
$iQ:1,
$im_:1}
A.dZ.prototype={}
A.e_.prototype={}
A.e0.prototype={}
A.e1.prototype={}
A.bn.prototype={
j(a){return A.ea(v.typeUniverse,this,a)},
A(a){return A.ni(v.typeUniverse,this,a)}}
A.fm.prototype={}
A.kF.prototype={
t(a){return A.aJ(this.a,null)}}
A.fl.prototype={
t(a){return this.a}}
A.d7.prototype={$ibT:1}
A.kg.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:25}
A.kf.prototype={
$1(a){var s,r
this.a.a=t.M.a(a)
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:40}
A.kh.prototype={
$0(){this.a.$0()},
$S:2}
A.ki.prototype={
$0(){this.a.$0()},
$S:2}
A.kD.prototype={
d3(a,b){if(self.setTimeout!=null)self.setTimeout(A.fL(new A.kE(this,b),0),a)
else throw A.n(A.bD("`setTimeout()` not found."))}}
A.kE.prototype={
$0(){this.b.$0()},
$S:0}
A.ff.prototype={}
A.kI.prototype={
$1(a){return this.a.$2(0,a)},
$S:102}
A.kJ.prototype={
$2(a,b){this.a.$2(1,new A.dn(a,t.l.a(b)))},
$S:104}
A.kQ.prototype={
$2(a,b){this.a(A.aI(a),b)},
$S:167}
A.br.prototype={
gp(){var s=this.b
return s==null?this.$ti.c.a(s):s},
dz(a,b){var s,r,q
a=A.aI(a)
b=b
s=this.a
for(;;)try{r=s(this,a,b)
return r}catch(q){b=q
a=1}},
l(){var s,r,q,p,o=this,n=null,m=0
for(;;){s=o.d
if(s!=null)try{if(s.l()){o.b=s.gp()
return!0}else o.d=null}catch(r){n=r
m=1
o.d=null}q=o.dz(m,n)
if(1===q)return!0
if(0===q){o.b=null
p=o.e
if(p==null||p.length===0){o.a=A.nc
return!1}if(0>=p.length)return A.b(p,-1)
o.a=p.pop()
m=0
n=null
continue}if(2===q){m=0
n=null
continue}if(3===q){n=o.c
o.c=null
p=o.e
if(p==null||p.length===0){o.b=null
o.a=A.nc
throw n
return!1}if(0>=p.length)return A.b(p,-1)
o.a=p.pop()
m=1
continue}throw A.n(A.lY("sync*"))}return!1},
ez(a){var s,r,q=this
if(a instanceof A.bF){s=a.a()
r=q.e
if(r==null)r=q.e=[]
B.a.k(r,q.a)
q.a=s
return 2}else{q.d=J.a0(a)
return 2}},
$iR:1}
A.bF.prototype={
gq(a){return new A.br(this.a(),this.$ti.j("br<1>"))}}
A.bh.prototype={
t(a){return A.z(this.a)},
$iT:1,
gaN(){return this.b}}
A.cE.prototype={
eg(a){if((this.c&15)!==6)return!0
return this.b.b.bL(t.iW.a(this.d),a.a,t.y,t.D)},
e5(a){var s,r=this,q=r.e,p=null,o=t.z,n=t.D,m=a.a,l=r.b.b
if(t.ng.b(q))p=l.en(q,m,a.b,o,n,t.l)
else p=l.bL(t.mq.a(q),m,o,n)
try{o=r.$ti.j("2/").a(p)
return o}catch(s){if(t.do.b(A.bY(s))){if((r.c&1)!==0)throw A.n(A.df("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.n(A.df("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.an.prototype={
cP(a,b,c){var s,r,q=this.$ti
q.A(c).j("1/(2)").a(a)
s=$.ab
if(s===B.u){if(!t.ng.b(b)&&!t.mq.b(b))throw A.n(A.eh(b,"onError",u.c))}else{c.j("@<0/>").A(q.c).j("1(2)").a(a)
b=A.qw(b,s)}r=new A.an(s,c.j("an<0>"))
this.bf(new A.cE(r,3,a,b,q.j("@<1>").A(c).j("cE<1,2>")))
return r},
cq(a,b,c){var s,r=this.$ti
r.A(c).j("1/(2)").a(a)
s=new A.an($.ab,c.j("an<0>"))
this.bf(new A.cE(s,19,a,b,r.j("@<1>").A(c).j("cE<1,2>")))
return s},
dA(a){this.a=this.a&1|16
this.c=a},
aP(a){this.a=a.a&30|this.a&1
this.c=a.c},
bf(a){var s,r=this,q=r.a
if(q<=3){a.a=t.F.a(r.c)
r.c=a}else{if((q&4)!==0){s=t._.a(r.c)
if((s.a&24)===0){s.bf(a)
return}r.aP(s)}A.fJ(null,null,r.b,t.M.a(new A.km(r,a)))}},
ci(a){var s,r,q,p,o,n,m=this,l={}
l.a=a
if(a==null)return
s=m.a
if(s<=3){r=t.F.a(m.c)
m.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){n=t._.a(m.c)
if((n.a&24)===0){n.ci(a)
return}m.aP(n)}l.a=m.aY(a)
A.fJ(null,null,m.b,t.M.a(new A.kq(l,m)))}},
aX(){var s=t.F.a(this.c)
this.c=null
return this.aY(s)},
aY(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
c1(a){var s,r=this
r.$ti.c.a(a)
s=r.aX()
r.a=8
r.c=a
A.d3(r,s)},
d9(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.aX()
q.aP(a)
A.d3(q,r)},
bj(a){var s=this.aX()
this.dA(a)
A.d3(this,s)},
bX(a){var s=this.$ti
s.j("1/").a(a)
if(s.j("bx<1>").b(a)){this.c0(a)
return}this.d8(a)},
d8(a){var s=this
s.$ti.c.a(a)
s.a^=2
A.fJ(null,null,s.b,t.M.a(new A.ko(s,a)))},
c0(a){A.m1(this.$ti.j("bx<1>").a(a),this,!1)
return},
bY(a){this.a^=2
A.fJ(null,null,this.b,t.M.a(new A.kn(this,a)))},
$ibx:1}
A.km.prototype={
$0(){A.d3(this.a,this.b)},
$S:0}
A.kq.prototype={
$0(){A.d3(this.b,this.a.a)},
$S:0}
A.kp.prototype={
$0(){A.m1(this.a.a,this.b,!0)},
$S:0}
A.ko.prototype={
$0(){this.a.c1(this.b)},
$S:0}
A.kn.prototype={
$0(){this.a.bj(this.b)},
$S:0}
A.kt.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.em(t.mY.a(q.d),t.z)}catch(p){s=A.bY(p)
r=A.cK(p)
if(k.c&&t.u.a(k.b.a.c).a===s){q=k.a
q.c=t.u.a(k.b.a.c)}else{q=s
o=r
if(o==null)o=A.lO(q)
n=k.a
n.c=new A.bh(q,o)
q=n}q.b=!0
return}if(j instanceof A.an&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=t.u.a(j.c)
q.b=!0}return}if(j instanceof A.an){m=k.b.a
l=new A.an(m.b,m.$ti)
j.cP(new A.ku(l,m),new A.kv(l),t.r)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.ku.prototype={
$1(a){this.a.d9(this.b)},
$S:25}
A.kv.prototype={
$2(a,b){A.ed(a)
t.l.a(b)
this.a.bj(new A.bh(a,b))},
$S:112}
A.ks.prototype={
$0(){var s,r,q,p,o,n,m,l
try{q=this.a
p=q.a
o=p.$ti
n=o.c
m=n.a(this.b)
q.c=p.b.b.bL(o.j("2/(1)").a(p.d),m,o.j("2/"),n)}catch(l){s=A.bY(l)
r=A.cK(l)
q=s
p=r
if(p==null)p=A.lO(q)
o=this.a
o.c=new A.bh(q,p)
o.b=!0}},
$S:0}
A.kr.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=t.u.a(l.a.a.c)
p=l.b
if(p.a.eg(s)&&p.a.e!=null){p.c=p.a.e5(s)
p.b=!1}}catch(o){r=A.bY(o)
q=A.cK(o)
p=t.u.a(l.a.a.c)
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.lO(p)
m=l.b
m.c=new A.bh(p,n)
p=m}p.b=!0}},
$S:0}
A.fg.prototype={}
A.fC.prototype={}
A.eb.prototype={$in6:1}
A.fy.prototype={
eo(a){var s,r,q
t.M.a(a)
try{if(B.u===$.ab){a.$0()
return}A.nz(null,null,this,a,t.r)}catch(q){s=A.bY(q)
r=A.cK(q)
A.m9(A.ed(s),t.l.a(r))}},
dK(a){return new A.kC(this,t.M.a(a))},
i(a,b){return null},
em(a,b){b.j("0()").a(a)
if($.ab===B.u)return a.$0()
return A.nz(null,null,this,a,b)},
bL(a,b,c,d){c.j("@<0>").A(d).j("1(2)").a(a)
d.a(b)
if($.ab===B.u)return a.$1(b)
return A.qy(null,null,this,a,b,c,d)},
en(a,b,c,d,e,f){d.j("@<0>").A(e).A(f).j("1(2,3)").a(a)
e.a(b)
f.a(c)
if($.ab===B.u)return a.$2(b,c)
return A.qx(null,null,this,a,b,c,d,e,f)},
cM(a,b,c,d){return b.j("@<0>").A(c).A(d).j("1(2,3)").a(a)}}
A.kC.prototype={
$0(){return this.a.eo(this.b)},
$S:0}
A.kP.prototype={
$0(){A.oQ(this.a,this.b)},
$S:0}
A.be.prototype={
cc(){return new A.be(A.k(this).j("be<1>"))},
gq(a){var s=this,r=new A.Y(s,s.r,A.k(s).j("Y<1>"))
r.c=s.e
return r},
gn(a){return this.a},
gG(a){return this.a===0},
ga0(a){return this.a!==0},
v(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.X.a(s[b])!=null}else if(typeof b=="number"&&(b&1073741823)===b){r=this.c
if(r==null)return!1
return t.X.a(r[b])!=null}else return this.dc(b)},
dc(a){var s=this.d
if(s==null)return!1
return this.bp(s[this.bk(a)],a)>=0},
gu(a){var s=this.e
if(s==null)throw A.n(A.lY("No elements"))
return A.k(this).c.a(s.a)},
gF(a){var s=this.f
if(s==null)throw A.n(A.lY("No elements"))
return A.k(this).c.a(s.a)},
k(a,b){var s,r,q=this
A.k(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.bV(s==null?q.b=A.m2():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.bV(r==null?q.c=A.m2():r,b)}else return q.aH(b)},
aH(a){var s,r,q,p=this
A.k(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.m2()
r=p.bk(a)
q=s[r]
if(q==null)s[r]=[p.bs(a)]
else{if(p.bp(q,a)>=0)return!1
q.push(p.bs(a))}return!0},
T(a,b){var s=this
if(typeof b=="string"&&b!=="__proto__")return s.cl(s.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return s.cl(s.c,b)
else return s.du(b)},
du(a){var s,r,q,p,o=this,n=o.d
if(n==null)return!1
s=o.bk(a)
r=n[s]
q=o.bp(r,a)
if(q<0)return!1
p=r.splice(q,1)[0]
if(0===r.length)delete n[s]
o.ct(p)
return!0},
bV(a,b){A.k(this).c.a(b)
if(t.X.a(a[b])!=null)return!1
a[b]=this.bs(b)
return!0},
cl(a,b){var s
if(a==null)return!1
s=t.X.a(a[b])
if(s==null)return!1
this.ct(s)
delete a[b]
return!0},
bq(){this.r=this.r+1&1073741823},
bs(a){var s,r=this,q=new A.fs(A.k(r).c.a(a))
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.c=s
r.f=s.b=q}++r.a
r.bq()
return q},
ct(a){var s=this,r=a.c,q=a.b
if(r==null)s.e=q
else r.b=q
if(q==null)s.f=r
else q.c=r;--s.a
s.bq()},
bk(a){return J.aR(a)&1073741823},
bp(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aQ(a[r].a,b))return r
return-1},
$imK:1}
A.fs.prototype={}
A.Y.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.n(A.ai(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.j("1?").a(r.a)
s.c=r.b
return!0}},
$iR:1}
A.iV.prototype={
$2(a,b){this.a.h(0,this.b.a(a),this.c.a(b))},
$S:93}
A.H.prototype={
gq(a){return new A.aV(a,this.gn(a),A.a6(a).j("aV<H.E>"))},
K(a,b){return this.i(a,b)},
gG(a){return this.gn(a)===0},
ga0(a){return!this.gG(a)},
gu(a){if(this.gn(a)===0)throw A.n(A.ak())
return this.i(a,0)},
gF(a){if(this.gn(a)===0)throw A.n(A.ak())
return this.i(a,this.gn(a)-1)},
Z(a,b){var s,r
A.a6(a).j("q(H.E)").a(b)
s=this.gn(a)
for(r=0;r<s;++r){if(b.$1(this.i(a,r)))return!0
if(s!==this.gn(a))throw A.n(A.ai(a))}return!1},
ae(a,b,c){var s,r,q,p=A.a6(a)
p.j("q(H.E)").a(b)
p.j("H.E()?").a(c)
s=this.gn(a)
for(r=0;r<s;++r){q=this.i(a,r)
if(b.$1(q))return q
if(s!==this.gn(a))throw A.n(A.ai(a))}p=c.$0()
return p},
aM(a,b,c){var s=A.a6(a)
return new A.u(a,s.A(c).j("1(H.E)").a(b),s.j("@<H.E>").A(c).j("u<1,2>"))},
P(a,b,c,d){var s,r,q
d.a(b)
A.a6(a).A(d).j("1(1,H.E)").a(c)
s=this.gn(a)
for(r=b,q=0;q<s;++q){r=c.$2(r,this.i(a,q))
if(s!==this.gn(a))throw A.n(A.ai(a))}return r},
aa(a,b){return A.c9(a,b,null,A.a6(a).j("H.E"))},
aw(a){var s,r=A.eM(A.a6(a).j("H.E"))
for(s=0;s<this.gn(a);++s)r.k(0,this.i(a,s))
return r},
k(a,b){var s
A.a6(a).j("H.E").a(b)
s=this.gn(a)
this.sn(a,s+1)
this.h(a,s,b)},
b2(a,b){return new A.a9(a,A.a6(a).j("@<H.E>").A(b).j("a9<1,2>"))},
gcN(a){return new A.bB(a,A.a6(a).j("bB<H.E>"))},
t(a){return A.iO(a,"[","]")}}
A.a7.prototype={
a_(a,b){var s,r,q,p=A.k(this)
p.j("~(a7.K,a7.V)").a(b)
for(s=this.ga8(),s=s.gq(s),p=p.j("a7.V");s.l();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
gaL(){return this.ga8().aM(0,new A.iX(this),A.k(this).j("aq<a7.K,a7.V>"))},
E(a){return this.ga8().v(0,a)},
gn(a){var s=this.ga8()
return s.gn(s)},
gG(a){var s=this.ga8()
return s.gG(s)},
t(a){return A.lS(this)},
$ii:1}
A.iX.prototype={
$1(a){var s=this.a,r=A.k(s)
r.j("a7.K").a(a)
s=s.i(0,a)
if(s==null)s=r.j("a7.V").a(s)
return new A.aq(a,s,r.j("aq<a7.K,a7.V>"))},
$S(){return A.k(this.a).j("aq<a7.K,a7.V>(a7.K)")}}
A.iY.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.z(a)
r.a=(r.a+=s)+": "
s=A.z(b)
r.a+=s},
$S:18}
A.bC.prototype={
gG(a){return this.gn(this)===0},
ga0(a){return this.gn(this)!==0},
B(a,b){var s
for(s=J.a0(A.k(this).j("h<1>").a(b));s.l();)this.k(0,s.gp())},
t(a){return A.iO(this,"{","}")},
P(a,b,c,d){var s,r
d.a(b)
A.k(this).A(d).j("1(1,2)").a(c)
for(s=this.gq(this),r=b;s.l();)r=c.$2(r,s.gp())
return r},
e2(a,b){var s
A.k(this).j("q(1)").a(b)
for(s=this.gq(this);s.l();)if(!b.$1(s.gp()))return!1
return!0},
aa(a,b){return A.n1(this,b,A.k(this).c)},
gu(a){var s=this.gq(this)
if(!s.l())throw A.n(A.ak())
return s.gp()},
gF(a){var s,r=this.gq(this)
if(!r.l())throw A.n(A.ak())
do s=r.gp()
while(r.l())
return s},
K(a,b){var s,r
A.cZ(b,"index")
s=this.gq(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.n(A.iN(b,b-r,this,"index"))},
$iB:1,
$ih:1,
$iP:1}
A.e2.prototype={
ed(a){var s,r,q,p=this,o=p.cc()
for(s=A.as(p,p.r,A.k(p).c),r=s.$ti.c;s.l();){q=s.d
if(q==null)q=r.a(q)
if(a.v(0,q))o.k(0,q)}return o}}
A.cd.prototype={
sab(a){this.b=this.$ti.j("cd.1?").a(a)},
sa6(a){this.c=this.$ti.j("cd.1?").a(a)}}
A.bq.prototype={}
A.bp.prototype={
bu(a){var s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=null
g.$ti.j("bp.K").a(a)
s=g.d
if(s==null){g.e.$2(a,a)
return-1}r=g.e
for(q=f,p=s,o=q,n=o,m=n,l=m;;){q=r.$2(p.a,a)
if(q>0){k=p.b
if(k==null)break
q=r.$2(k.a,a)
if(q>0){p.sab(k.c)
k.sa6(p)
j=k.b
if(j==null){p=k
break}p=k
k=j}if(l==null)m=p
else l.sab(p)
l=p
p=k}else{if(q<0){i=p.c
if(i==null)break
q=r.$2(i.a,a)
if(q<0){p.sa6(i.b)
i.sab(p)
h=i.c
if(h==null){p=i
break}p=i
i=h}if(n==null)o=p
else n.sa6(p)}else break
n=p
p=i}}if(n!=null){n.sa6(p.b)
p.sab(o)}if(l!=null){l.sab(p.c)
p.sa6(m)}if(g.d!==p){g.d=p;++g.c}return q},
bv(a){var s,r,q
this.$ti.j("bp.1").a(a)
for(s=a,r=0;;s=q,r=1){q=s.b
if(q!=null){s.sab(q.c)
q.sa6(s)}else break}this.c+=r
return s},
cn(a){var s,r,q
this.$ti.j("bp.1").a(a)
for(s=a,r=0;;s=q,r=1){q=s.c
if(q!=null){s.sa6(q.b)
q.sab(s)}else break}this.c+=r
return s},
dv(){var s,r=this,q=r.d,p=q.b,o=q.c
if(p==null)r.d=o
else if(o==null)r.d=p
else{s=r.cn(p)
s.sa6(o)
r.d=s}--r.a;++r.b},
cu(a){if(!this.$ti.j("bp.K").b(a))return null
if(this.bu(a)===0)return this.d
return null}}
A.bE.prototype={
gp(){var s=this.b
if(s.length===0){this.$ti.j("bE.T").a(null)
return null}return this.$ti.y[1].a(B.a.gF(s)).a},
dt(a){var s,r,q,p=this
p.$ti.j("bE.K").a(a)
s=p.b
B.a.W(s)
r=p.a
if(r.bu(a)===0){q=r.d
q.toString
B.a.k(s,q)
p.d=r.c
return}throw A.n(A.ai(p))},
l(){var s,r,q=this,p=q.c,o=q.a,n=o.b
if(p!==n){if(p==null){q.c=n
s=o.d
for(p=q.b;s!=null;){B.a.k(p,s)
s=s.b}return p.length!==0}throw A.n(A.ai(o))}p=q.b
if(p.length===0)return!1
if(q.d!==o.c)q.dt(B.a.gF(p).a)
s=B.a.gF(p)
r=s.c
if(r!=null){while(r!=null){B.a.k(p,r)
r=r.b}return!0}if(0>=p.length)return A.b(p,-1)
p.pop()
for(;;){if(!(p.length!==0&&B.a.gF(p).c===s))break
if(0>=p.length)return A.b(p,-1)
s=p.pop()}return p.length!==0},
$iR:1}
A.e3.prototype={}
A.dN.prototype={
gq(a){var s=this.$ti
return new A.e3(this,A.d([],s.j("o<bq<1>>")),this.c,s.j("e3<1,bq<1>>"))},
gn(a){return this.a},
gG(a){return this.d==null},
ga0(a){return this.d!=null},
gu(a){var s,r=this.d
if(r==null)throw A.n(A.ak())
s=this.bv(r)
this.d=s
return s.a},
gF(a){var s,r=this.d
if(r==null)throw A.n(A.ak())
s=this.cn(r)
this.d=s
return s.a},
v(a,b){return this.cu(b)!=null},
k(a,b){return this.aH(this.$ti.c.a(b))},
aH(a){var s,r,q=this,p=q.$ti
p.c.a(a)
s=q.bu(a)
if(s===0)return!1
p=p.j("bp.1").a(new A.bq(a,p.j("bq<1>")))
r=q.d
if(r!=null)if(s<0){p.sab(r)
p.sa6(r.c)
r.sa6(null)}else{p.sa6(r)
p.sab(r.b)
r.sab(null)}++q.b;++q.a
q.d=p
return!0},
T(a,b){if(this.cu(b)==null)return!1
this.dv()
return!0},
t(a){return A.iO(this,"{","}")},
$iB:1,
$iP:1}
A.e4.prototype={}
A.e5.prototype={}
A.fo.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.dr(b):s}},
gn(a){return this.b==null?this.c.a:this.aI().length},
gG(a){return this.gn(0)===0},
ga8(){if(this.b==null){var s=this.c
return new A.aa(s,A.k(s).j("aa<1>"))}return new A.fp(this)},
h(a,b,c){var s,r,q=this
A.D(b)
if(q.b==null)q.c.h(0,b,c)
else if(q.E(b)){s=q.b
s[b]=c
r=q.a
if(r==null?s!=null:r!==s)r[b]=null}else q.cv().h(0,b,c)},
E(a){if(this.b==null)return this.c.E(a)
if(typeof a!="string")return!1
return Object.prototype.hasOwnProperty.call(this.a,a)},
T(a,b){if(this.b!=null&&!this.E(b))return null
return this.cv().T(0,b)},
a_(a,b){var s,r,q,p,o=this
t.lc.a(b)
if(o.b==null)return o.c.a_(0,b)
s=o.aI()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.kL(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.n(A.ai(o))}},
aI(){var s=t.O.a(this.c)
if(s==null)s=this.c=A.d(Object.keys(this.a),t.s)
return s},
cv(){var s,r,q,p,o,n=this
if(n.b==null)return n.c
s=A.l(t.N,t.z)
r=n.aI()
for(q=0;p=r.length,q<p;++q){o=r[q]
s.h(0,o,n.i(0,o))}if(p===0)B.a.k(r,"")
else B.a.W(r)
n.a=n.b=null
return n.c=s},
dr(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.kL(this.a[a])
return this.b[a]=s}}
A.fp.prototype={
gn(a){return this.a.gn(0)},
K(a,b){var s=this.a
if(s.b==null)s=s.ga8().K(0,b)
else{s=s.aI()
if(!(b>=0&&b<s.length))return A.b(s,b)
s=s[b]}return s},
gq(a){var s=this.a
if(s.b==null){s=s.ga8()
s=s.gq(s)}else{s=s.aI()
s=new J.ch(s,s.length,A.t(s).j("ch<1>"))}return s},
v(a,b){return this.a.E(b)}}
A.dg.prototype={
gbE(){return B.dg}}
A.fT.prototype={
bB(a){var s
t.L.a(a)
s=a.length
if(s===0)return""
s=new A.kk("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/").e0(a,0,s,!0)
s.toString
return A.pm(s)}}
A.kk.prototype={
e0(a,b,c,d){var s,r,q,p,o
t.L.a(a)
s=this.a
r=(s&3)+(c-b)
q=B.c.bw(r,3)
p=q*4
if(r-q*3>0)p+=4
o=new Uint8Array(p)
this.a=A.pD(this.b,a,b,c,!0,o,0,s)
if(p>0)return o
return null}}
A.fS.prototype={
bB(a){var s,r,q,p=A.mZ(0,null,a.length)
if(0===p)return new Uint8Array(0)
s=new A.kj()
r=s.dR(a,0,p)
r.toString
q=s.a
if(q<-1)A.bs(A.b4("Missing padding character",a,p))
if(q>0)A.bs(A.b4("Invalid length, must be multiple of four",a,p))
s.a=-1
return r}}
A.kj.prototype={
dR(a,b,c){var s,r=this,q=r.a
if(q<0){r.a=A.n7(a,b,c,q)
return null}if(b===c)return new Uint8Array(0)
s=A.pA(a,b,c,q)
r.a=A.pC(a,b,c,s,0,r.a)
return s}}
A.c_.prototype={}
A.ep.prototype={}
A.dy.prototype={
t(a){var s=A.et(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.eI.prototype={
t(a){return"Cyclic error in JSON stringify"}}
A.eH.prototype={
dQ(a,b){var s=A.qu(a,this.gdS().a)
return s},
e_(a,b){var s=A.pF(a,this.gbE().b,null)
return s},
gbE(){return B.eW},
gdS(){return B.eV}}
A.iS.prototype={}
A.iR.prototype={}
A.ky.prototype={
cT(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.d.az(a,r,q)
r=q+1
o=A.ay(92)
s.a+=o
o=A.ay(117)
s.a+=o
o=A.ay(100)
s.a+=o
o=p>>>8&15
o=A.ay(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.ay(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.ay(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.d.az(a,r,q)
r=q+1
o=A.ay(92)
s.a+=o
switch(p){case 8:o=A.ay(98)
s.a+=o
break
case 9:o=A.ay(116)
s.a+=o
break
case 10:o=A.ay(110)
s.a+=o
break
case 12:o=A.ay(102)
s.a+=o
break
case 13:o=A.ay(114)
s.a+=o
break
default:o=A.ay(117)
s.a+=o
o=A.ay(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.ay(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.ay(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.d.az(a,r,q)
r=q+1
o=A.ay(92)
s.a+=o
o=A.ay(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.d.az(a,r,m)},
bi(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.n(new A.eI(a,null))}B.a.k(s,a)},
bb(a){var s,r,q,p,o=this
if(o.cS(a))return
o.bi(a)
try{s=o.b.$1(a)
if(!o.cS(s)){q=A.mH(a,null,o.gcd())
throw A.n(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.bY(p)
q=A.mH(a,r,o.gcd())
throw A.n(q)}},
cS(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.t(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.cT(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.bi(a)
q.ew(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return!0}else if(t.av.b(a)){q.bi(a)
r=q.ex(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return r}else return!1},
ew(a){var s,r,q=this.c
q.a+="["
s=J.ae(a)
if(s.ga0(a)){this.bb(s.i(a,0))
for(r=1;r<s.gn(a);++r){q.a+=","
this.bb(s.i(a,r))}}q.a+="]"},
ex(a){var s,r,q,p,o,n,m=this,l={}
if(a.gG(a)){m.c.a+="{}"
return!0}s=a.gn(a)*2
r=A.bj(s,null,!1,t.iD)
q=l.a=0
l.b=!0
a.a_(0,new A.kz(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.cT(A.D(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.b(r,n)
m.bb(r[n])}p.a+="}"
return!0}}
A.kz.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.h(s,r.a++,a)
B.a.h(s,r.a++,b)},
$S:18}
A.kx.prototype={
gcd(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.bH.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.bH&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gL(a){return A.cV(this.a,this.b,B.f,B.f)},
N(a,b){var s
t.cs.a(b)
s=B.c.N(this.a,b.a)
if(s!==0)return s
return B.c.N(this.b,b.b)},
t(a){var s=this,r=A.mz(A.f1(s)),q=A.bI(A.mR(s)),p=A.bI(A.mN(s)),o=A.bI(A.mO(s)),n=A.bI(A.mQ(s)),m=A.bI(A.mS(s)),l=A.hG(A.mP(s)),k=s.b,j=k===0?"":A.hG(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
bN(){var s=this,r=A.f1(s)>=-9999&&A.f1(s)<=9999?A.mz(A.f1(s)):A.oG(A.f1(s)),q=A.bI(A.mR(s)),p=A.bI(A.mN(s)),o=A.bI(A.mO(s)),n=A.bI(A.mQ(s)),m=A.bI(A.mS(s)),l=A.hG(A.mP(s)),k=s.b,j=k===0?"":A.hG(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iaS:1}
A.hH.prototype={
$1(a){if(a==null)return 0
return A.fN(a)},
$S:19}
A.hI.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.b(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:19}
A.cn.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.cn},
gL(a){return B.c.gL(0)},
N(a,b){t.jS.a(b)
return 0},
t(a){return"0:00:00."+B.d.ej(B.c.t(0),6,"0")},
$iaS:1}
A.fk.prototype={
t(a){return this.H()},
$ia2:1}
A.T.prototype={
gaN(){return A.p7(this)}}
A.ei.prototype={
t(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.et(s)
return"Assertion failed"}}
A.bT.prototype={}
A.bu.prototype={
gbo(){return"Invalid argument"+(!this.a?"(s)":"")},
gbn(){return""},
t(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gbo()+q+o
if(!s.a)return n
return n+s.gbn()+": "+A.et(s.gbI())},
gbI(){return this.b}}
A.dJ.prototype={
gbI(){return A.y(this.b)},
gbo(){return"RangeError"},
gbn(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.z(q):""
else if(q==null)s=": Not greater than or equal to "+A.z(r)
else if(q>r)s=": Not in inclusive range "+A.z(r)+".."+A.z(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.z(r)
return s}}
A.ey.prototype={
gbI(){return A.aI(this.b)},
gbo(){return"RangeError"},
gbn(){if(A.aI(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gn(a){return this.f}}
A.dT.prototype={
t(a){return"Unsupported operation: "+this.a}}
A.fb.prototype={
t(a){return"UnimplementedError: "+this.a}}
A.dQ.prototype={
t(a){return"Bad state: "+this.a}}
A.eo.prototype={
t(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.et(s)+"."}}
A.f_.prototype={
t(a){return"Out of Memory"},
gaN(){return null},
$iT:1}
A.dP.prototype={
t(a){return"Stack Overflow"},
gaN(){return null},
$iT:1}
A.kl.prototype={
t(a){return"Exception: "+this.a}}
A.dq.prototype={
t(a){var s,r,q,p,o,n,m,l,k,j,i,h=this.a,g=""!==h?"FormatException: "+h:"FormatException",f=this.c,e=this.b
if(typeof e=="string"){if(f!=null)s=f<0||f>e.length
else s=!1
if(s)f=null
if(f==null){if(e.length>78)e=B.d.az(e,0,75)+"..."
return g+"\n"+e}for(r=e.length,q=1,p=0,o=!1,n=0;n<f;++n){if(!(n<r))return A.b(e,n)
m=e.charCodeAt(n)
if(m===10){if(p!==n||!o)++q
p=n+1
o=!1}else if(m===13){++q
p=n+1
o=!0}}g=q>1?g+(" (at line "+q+", character "+(f-p+1)+")\n"):g+(" (at character "+(f+1)+")\n")
for(n=f;n<r;++n){if(!(n>=0))return A.b(e,n)
m=e.charCodeAt(n)
if(m===10||m===13){r=n
break}}l=""
if(r-p>78){k="..."
if(f-p<75){j=p+75
i=p}else{if(r-f<75){i=r-75
j=r
k=""}else{i=f-36
j=f+36}l="..."}}else{j=r
i=p
k=""}return g+l+B.d.az(e,i,j)+k+"\n"+B.d.aj(" ",f-i+l.length)+"^\n"}else return f!=null?g+(" (at offset "+A.z(f)+")"):g}}
A.h.prototype={
b2(a,b){return A.mu(this,A.a6(this).j("h.E"),b)},
aM(a,b,c){var s=A.a6(this)
return A.lT(this,s.A(c).j("1(h.E)").a(b),s.j("h.E"),c)},
bP(a,b){var s=A.a6(this)
return new A.A(this,s.j("q(h.E)").a(b),s.j("A<h.E>"))},
v(a,b){var s
for(s=this.gq(this);s.l();)if(J.aQ(s.gp(),b))return!0
return!1},
P(a,b,c,d){var s,r
d.a(b)
A.a6(this).A(d).j("1(1,h.E)").a(c)
for(s=this.gq(this),r=b;s.l();)r=c.$2(r,s.gp())
return r},
Z(a,b){var s
A.a6(this).j("q(h.E)").a(b)
for(s=this.gq(this);s.l();)if(b.$1(s.gp()))return!0
return!1},
gn(a){var s,r=this.gq(this)
for(s=0;r.l();)++s
return s},
gG(a){return!this.gq(this).l()},
ga0(a){return!this.gG(this)},
aa(a,b){return A.n1(this,b,A.a6(this).j("h.E"))},
gu(a){var s=this.gq(this)
if(!s.l())throw A.n(A.ak())
return s.gp()},
gF(a){var s,r=this.gq(this)
if(!r.l())throw A.n(A.ak())
do s=r.gp()
while(r.l())
return s},
ae(a,b,c){var s,r
A.a6(this).j("q(h.E)").a(b)
for(s=this.gq(this);s.l();){r=s.gp()
if(b.$1(r))return r}throw A.n(A.ak())},
e4(a,b){return this.ae(0,b,null)},
K(a,b){var s,r
A.cZ(b,"index")
s=this.gq(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.n(A.iN(b,b-r,this,"index"))},
t(a){return A.oV(this,"(",")")}}
A.aq.prototype={
t(a){return"MapEntry("+A.z(this.a)+": "+A.z(this.b)+")"}}
A.aw.prototype={
gL(a){return A.N.prototype.gL.call(this,0)},
t(a){return"null"}}
A.N.prototype={$iN:1,
Y(a,b){return this===b},
gL(a){return A.f2(this)},
t(a){return"Instance of '"+A.f3(this)+"'"},
gS(a){return A.r_(this)},
toString(){return this.t(this)}}
A.fD.prototype={
t(a){return""},
$ic8:1}
A.d0.prototype={
gn(a){return this.a.length},
t(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$ipl:1}
A.iL.prototype={
gdi(){var s,r=this.a
A:{if("pt"===r){s=0
break A}if("en"===r){s=1
break A}if("es"===r){s=2
break A}s=-1
break A}return s},
$2(a,b){var s,r,q,p={}
A.D(a)
t.md.a(b)
s=B.fs.i(0,a)
p.a=null
if(s==null)p.a=a
else{r=this.gdi()
A:{if(0===r){q=s.a
break A}if(2===r){q=s.c
break A}if(1===r){q=s.b
break A}q=$.kN.i(0,this.a)
q=q==null?null:q.a.i(0,a)
if(q==null)q=s.b
break A}p.a=q}if(b!=null)b.a_(0,new A.iM(p))
return p.a},
$1(a){return this.$2(a,null)}}
A.iM.prototype={
$2(a,b){var s,r
A.D(a)
A.D(b)
s=this.a
r=s.a
return s.a=A.rk(r,"{"+a+"}",b)},
$S:91}
A.hL.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"project",r.a)
q.h(0,"lang",r.b)
s=r.c
if(s!=null)q.h(0,"strings",s)
q.h(0,"sizeZones",r.d)
q.h(0,"sizeMain",r.e)
return q}}
A.hM.prototype={
m(){var s=this.a.m(),r=this.b,q=A.t(r),p=q.j("u<1,i<c,@>>")
r=A.p(new A.u(r,q.j("i<c,@>(1)").a(new A.hN()),p),p.j("w.E"))
return A.X(["results",s,"entities",r,"nextId",this.c],t.N,t.z)}}
A.hN.prototype={
$1(a){return t.h.a(a).m()},
$S:21}
A.lq.prototype={
$1(a){return this.a.$1(A.D(a))},
$S:90}
A.lr.prototype={
$1(a){var s=A.l(t.N,t.z)
J.lM(s,"type","progress")
J.mm(s,a.m())
return this.a.$1(s)},
$S:89}
A.bv.prototype={
H(){return"DesignStage."+this.b}}
A.cl.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"stage",r.a.b)
q.h(0,"done",r.b)
q.h(0,"total",r.c)
s=r.d
if(s!=null)q.h(0,"zone",s)
q.h(0,"zi",r.e)
q.h(0,"zn",r.f)
return q},
t(a){var s=this,r=s.d==null?"":" zone "+s.e+"/"+s.f
return"DesignProgress("+s.a.b+" "+s.b+"/"+s.c+r+")"}}
A.er.prototype={
aq(a){var s=this.c.c.i(0,a)
s=s==null?null:s.a
return s==null?this.c.e.i(0,a):s},
cz(a){var s,r,q,p,o,n,m,l=null,k=this.a,j=k.c,i=j.R(a.at),h=i==null,g=h?l:i.f
if(g==null)g=a.ax
k=k.b
s=h?l:i.w
if(s==null)s=a.ay
h=h?l:i.x
if(h==null)h=0.15
r=new A.jo(a.z,a.d,a.x,a.Q,a.as,g,s*k.cx+k.cy,h,k.b,A.fP(k.c),a.ch,a.CW,a.cx,a.cy,a.db,a.dx,a.dy,a.fr,a.fx,a.fy,a.go,Math.max(k.e,3))
q=this.c.Q
p=q==null||q.c.length===0?l:A.r1(r,a.w,a.y*3.141592653589793/180,q.gdY())
o=a.c
if(!(o.length!==0)){k=a.k1
o=k.length!==0?k:this.b.$1("tool.pivot")}k=A.d([],t.dD)
j=j.a1(a.e)
j=j==null?l:j.f
if(j==null)j=B.fg
h=j.length
n=0
for(;n<j.length;j.length===h||(0,A.j)(j),++n){m=j[n]
k.push(new A.m(m.b,m.c))}return A.qH(r,p,a.a,o,k)},
bl(a){var s,r,q,p,o=this
if(o.c.e.E(a)){s=o.a.ad(a)
if(!(s instanceof A.ba))return B.bC
r=o.d.d
q=r.i(0,a)
if(q==null)q=o.cz(s)
r.h(0,a,q)
return new A.m(q.e,q.r)}r=o.d.c
p=r.i(0,a)
if(p==null)p=o.aD(a)
r.h(0,a,p)
return new A.m(p.d,p.r)},
b_(a){var s=this.e.i(0,a.f)
if(s==null)s=a.x
return this.a.c.R(s)},
aA(a){var s,r,q=a.y
if(q!=null)return this.a.c.ai(q).f/1000
s=this.b_(a)
if(s!=null)return s.f/1000
r=this.a.c.ah(a.Q)
return r.length===0?0.05:B.a.gu(r).f/1000},
aC(a){var s
switch(a.Q.a){case 0:s=this.a.b.f
break
case 1:s=this.a.b.d
break
case 2:s=this.a.b.e
break
default:s=null}return s},
bm(a){var s=this.a.b
s=s.w&&a.Q!==B.q?1+s.r/100:1
return Math.max(a.w*s,0.001)},
cr(a){var s,r,q,p,o,n,m,l,k,j=this,i=null
switch(a.d.a){case 0:s=j.a
r=s.c.ai(a.y)
q=j.b_(a)
s=s.b
p=r==null
o=p?i:r.CW
if(o==null)o=q==null?i:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?i:q.x/1000
n=p==null?0.0000015:p}p=j.aA(a)
m=j.bm(a)
l=s.w?a.as:0
return A.eu(!1,i,p,a.b,o*s.cx+s.cy,a.a,B.aq,m,l,0,i,n,a,a.c)
case 1:q=j.a.c.a9(a.ay)
s=q==null?i:q.r
if(s==null)s=B.aY
return A.eu(!1,s,0.05,a.b,150,a.a,B.bl,1,0,0,i,0.0000015,a,a.c)
case 3:q=j.a.c.a9(a.ay)
s=q==null
k=s?i:q.r
if(k==null)k=B.I
p=k.a>0?k:B.aY
return A.eu((s?i:q.e)===B.U,p,0.05,a.b,150,a.a,B.bl,1,0,0,i,0.0000015,a,a.c)
case 4:q=j.a.c.a9(a.ay)
s=q==null?i:q.r
return A.eu(!1,s,0.05,a.b,150,a.a,B.M,1,0,a.ax,i,0.0000015,a,a.c)
case 2:q=j.a.c.av(a.ch)
if(q==null)s=i
else{s=q.w
s=new A.cY(s.a,s.b,s.c,a.CW)}return A.eu(!1,i,0.05,a.b,150,a.a,B.bk,1,0,0,s,0.0000015,a,a.c)}},
c8(a,b,c){var s,r,q,p
if(c<=0)return 0
s=this.a.b
r=b.f/1000
q=this.bm(a)
p=A.nL(b.w*s.cx+s.cy,r,c,A.fP(s.c),q,s.b,b.x/1000)
return p+(s.w&&a.as>0?A.nV(r,c,a.as):0)},
c2(a,b){var s,r,q,p,o,n,m,l,k=this
if(b<=0)return 0
s=k.a
r=s.c.ai(a.y)
q=k.b_(a)
s=s.b
p=r==null
o=p?null:r.CW
if(o==null)o=q==null?null:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?null:q.x/1000
n=p==null?0.0000015:p}m=k.aA(a)
p=k.bm(a)
l=A.nL(o*s.cx+s.cy,m,b,A.fP(s.c),p,s.b,n)
return l+(s.w&&a.as>0?A.nV(m,b,a.as):0)},
aV(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.C.a(c)
s=A.X([a,null],t.N,t.B)
r=A.d([a],t.s)
for(q=0;q<r.length;q=p){p=q+1
o=r[q]
if(o===b)break
for(n=this.c.a.i(0,o).w,m=n.length,l=0;l<n.length;n.length===m||(0,A.j)(n),++l){k=n[l]
if(!c.v(0,k.a))continue
j=k.b
if(o===j)j=k.c
if(!s.E(j)){s.h(0,j,k)
B.a.k(r,j)}}}if(!s.E(b))return B.fe
i=A.d([],t.I)
for(h=b;h!==a;){n=s.i(0,h)
n.toString
B.a.k(i,n)
g=n.b
h=h===g?n.c:g}n=t.g9
n=A.p(new A.bB(i,n),n.j("w.E"))
return n},
aO(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.bq.a(a)
t.C.a(b)
s=t.N
r=A.l(s,t.B)
q=A.l(s,s)
p=A.l(s,t.S)
o=A.d([],t.s)
for(s=J.a0(a);s.l();){n=s.gp()
r.h(0,n,null)
q.h(0,n,n)
p.h(0,n,0)
B.a.k(o,n)}for(m=0;m<o.length;m=l){l=m+1
k=o[m]
for(s=this.c.a.i(0,k).w,n=s.length,j=0;j<s.length;s.length===n||(0,A.j)(s),++j){i=s[j]
if(!b.v(0,i.a))continue
h=i.b
if(k===h)h=i.c
if(!r.E(h)){r.h(0,h,i)
g=q.i(0,k)
g.toString
q.h(0,h,g)
g=p.i(0,k)
g.toString
p.h(0,h,g+1)
B.a.k(o,h)}}}return new A.a(r,q,p)},
ce(a,b){var s,r,q,p
t.c8.a(a)
s=A.d([],t.I)
for(r=b;;){q=a.i(0,r)
if(q==null)break
B.a.k(s,q)
p=q.b
r=r===p?q.c:p}return s},
aU(a,b){var s,r,q,p
t.d.a(b)
for(s=b.length,r=a.f+1e-9,q=0;q<s;++q){p=b[q]
if(p.f>r)return p}return null},
V(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a.b
e=A.mL(A.fP(e.c),e.b)
s=t.N
r=A.l(s,t.b)
q=A.d([],t.lp)
p=new A.ew(e,r,q)
o=f.c.c.i(0,a).b
n=f.c.f.i(0,a)
if(n==null)n=A.K(s)
for(e=A.as(n,n.r,A.k(n).c),m=e.$ti.c;e.l();){l=e.d
if(l==null)l=m.a(l)
k=f.c.a.i(0,l)
k.toString
if(l===o){j=k.Q
i=j==null
h=i?k.c-k.e:j
r.h(0,l,new A.by(l,B.a_,h,(i?k.c-k.e:j)+b,null,1,0))
continue}j=k.Q
g=new A.by(l,B.Z,j==null?k.c-k.e:j,null,null,1,0)
r.h(0,l,g)
f.bZ(p,g,k,c)}e=f.c.r.i(0,a)
if(e==null)e=A.K(s)
e=A.as(e,e.r,A.k(e).c)
s=e.$ti.c
while(e.l()){r=e.d
if(r==null)r=s.a(r)
r=f.c.ao(r)
r.toString
B.a.k(q,f.cr(r))}return p},
bZ(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=c.f,e=f.length
if(e===0)return
if(!d){b.d=B.a.P(f,0,new A.i_(),t.i)
return}for(s=a.b,r=c.a,q=a.c,p=r+"_s",o=c.c,n=!0,m=0,l=0;l<f.length;f.length===e||(0,A.j)(f),++l){k=f[l]
if(n){b.f=k.c
b.r=k.d
b.w=k.x
n=!1}else{j=k.c
if(b.f===j&&Math.abs(b.w-k.x)<1e-9)b.r=b.r+k.d
else{i=m+1
h=p+m
g=c.Q
if(g==null)g=o-c.e
s.h(0,h,new A.by(h,B.Z,g,null,j,k.d,k.x))
B.a.k(q,new A.dr("sat_"+h,r,h,B.aq,0.5,0.01,150,0.0000015,0,!1,null,null,0,B.o))
m=i}}}},
aT(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this.c.f.i(0,a)
if(d==null)d=A.K(t.N)
d=A.as(d,d.r,A.k(d).c)
s=this.a
r=b.c
q=d.$ti.c
p=0
o=0
n=0
while(d.l()){m=d.d
if(m==null)m=q.a(m)
l=this.c.a.i(0,m)
l.toString
m=r.i(0,m)
k=m==null?null:m.a
if(k==null)continue
for(m=l.f,j=m.length,i=l.c,h=0;h<m.length;m.length===j||(0,A.j)(m),++h){g=m[h]
f=g.b
if(f===-2)continue
e=g.a
if(e.length!==0&&s.ad(e) instanceof A.aG&&f!==0)continue
f=l.Q
if(f==null)f=i-l.e
e=g.d
p+=(k-(f+g.x))*e
o+=g.e*e
n+=e}}if(n===0)return B.bC
return new A.m(p/n,o/n)},
am(g3,g4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8=f6.a,f9=t.cH.a(f8.ad(g3)),g0=t.s,g1=A.d([],g0),g2=f9==null
if(g2||!f6.c.c.E(g3)){f8=g2?f7:f9.f
if(f8==null)f8=""
return f6.c3(g3,f8,A.d(["valve_missing"],g0))}s=f6.c.c.i(0,g3)
r=s.a
q=s.b
g2=f6.c.a.i(0,q)
g2.toString
p=f6.c.f.i(0,g3)
if(p==null)p=A.K(t.N)
if(p.a>1){o=f6.c.r.i(0,g3)
o=o==null?f7:o.a===0
o=o!==!1}else o=!0
if(o)return f6.c3(g3,f9.f,A.d(["zone_empty"],g0))
n=f9.w
g0=n==null
if(!g0)m=f6.V(g3,n,g4).J()
else if(!g4){l=f6.aT(g3,f6.V(g3,10,!1).J())
n=10+(l.b-l.a)
m=f6.V(g3,n,!1).J()}else{k=f6.aT(g3,f6.V(g3,10,!1).J()).b
j=Math.max(k*3,5)
m=f6.V(g3,j,!0).J()
i=0
for(;;){if(!(f6.aT(g3,m).a<k&&i<20))break
j*=2
m=f6.V(g3,j,!0).J();++i}for(h=0,g=0;g<28;++g){f=(h+j)/2
if(f6.aT(g3,f6.V(g3,f,!0).J()).a>k)j=f
else h=f
if(j-h<0.001)break}n=(h+j)/2
m=f6.V(g3,n,!0).J()
g4=!0}if(!m.a)B.a.k(g1,"not_converged")
if(g0){g0=f6.dq(g3,m).a
e=g0[0]
d=g0[1]
c=g0[2]
b=g0[3]
if(d-e<=b-c+1e-9)g0=e<c-0.000001||d>b+0.000001
else g0=!1
if(g0){n+=(c+b)/2-(e+d)/2
m=f6.V(g3,n,g4).J()}}a=A.d([],t.A)
a0=A.d([],t.n)
for(g0=A.as(p,p.r,A.k(p).c),o=m.c,a1=g0.$ti.c,a2=0,a3=1/0,a4=-1/0,a5=-1/0,a6=1/0,a7=0,a8=0,a9=0,b0=0;g0.l();){b1=g0.d
if(b1==null)b1=a1.a(b1)
b2=f6.c.a.i(0,b1)
b2.toString
b3=o.i(0,b1)
if(b3==null)continue
for(b1=b2.f,b4=b1.length,b5=b2.b,b6=b3.a,b7=b2.c,b8=0;b8<b1.length;b1.length===b4||(0,A.j)(b1),++b8){b9=b1[b8]
c0=b2.Q
if(c0==null)c0=b7-b2.e
c1=b9.x
c2=b6-(c0+c1)
c0=b9.c
c3=g4?c0.af(Math.max(c2,0)):c0.af(b9.e)
c4=b9.d
a2+=c3*c4
c5=b9.b
if(c5===-2)continue
c6=b2.Q
if(c6==null)c6=b7-b2.e
c7=b9.e
c8=b9.f
c9=b9.r
B.a.k(a,new A.aA(b9.a,c5,b5,c6+c1,c2,c3,c0.af(c7),c4,c8,c9,b9.y))
for(d0=0;d0<c4;++d0)B.a.k(a0,c0.af(Math.max(c2,0)))
b0+=c4
a3=Math.min(a3,c2)
a4=Math.max(a4,c2)
a5=Math.max(a5,c8)
a6=Math.min(a6,c9)
a7+=c7*c4
a8+=c4
a9+=b9.w*c4}}if(a.length===0){a3=0
a4=0
a5=0
a6=0}g0=a8>0
d1=g0?a7/a8:0
a1=f8.b
b1=a1.p1
if(b1>0&&d1>0){b1/=200
a5=Math.max(a5,d1*(1-b1))
a6=Math.min(a6,d1*(1+b1))}d2=g0?a9/a8:0
d3=f6.de(a)
d4=A.pu(a0,d3,d2)
d5=A.d([],t.dI)
d6=A.d([],t.c)
g0=f6.c.r.i(0,g3)
if(g0==null)g0=A.K(t.N)
g0=A.as(g0,g0.r,A.k(g0).c)
b1=m.d
b2=g0.$ti.c
f8=f8.c
b4=f6.e
while(g0.l()){b5=g0.d
if(b5==null)b5=b2.a(b5)
b6=f6.c.ao(b5)
b6.toString
d7=b1.i(0,b5)
if(d7==null)continue
b7=b6.b
c0=f6.c.a.i(0,b7)
c0.toString
c1=b6.c
c4=f6.c.a.i(0,c1)
c4.toString
d8=o.i(0,b7).a
d9=o.i(0,c1).a
b7=b6.f
if(b6.d===B.e){e0=b4.i(0,b7)
e1=f8.R(e0==null?b6.x:e0)
e2=f8.ai(b6.y)
e3=f6.aA(b6)
c1=d7.a
e4=Math.abs(c1)/(3.141592653589793*e3*e3/4)
c5=c0.Q
c6=c5==null
c7=c6?c0.c-c0.e:c5
c8=c4.Q
c9=c8==null
e5=c9?c4.c-c4.e:c8
e6=e2==null
e7=e6?f7:e2.a
if(e7==null)e7=e1==null?f7:e1.a
e8=e6?f7:e2.b
if(e8==null)e8=e1==null?f7:e1.b
if(e8==null)e8="?"
e9=d7.c
if(c6)c5=c0.c-c0.e
c6=c9?c4.c-c4.e:c8
c8=e6?f7:e2.ay
if(c8==null)c8=e1==null?f7:e1.y
if(c8==null)c8=0
B.a.k(d5,new A.bl(b5,b7,b6.r,b6.cx,b6.cy,c7,e5,b6.w,e3,e7,e8,c1,e4,e9,d8-c5,d9-c6,c8,g3,e4>f6.aC(b6)+0.000001))
if(e4>f6.aC(b6)+0.000001)B.a.k(g1,"velocity_exceeded:"+b7)
b5=e6?f7:e2.ay
if(b5==null)b5=e1==null?f7:e1.y
if((b5==null?0:b5)>0){b5=c0.Q
if(b5==null)b5=c0.c-c0.e
b6=c4.Q
if(b6==null)b6=c4.c-c4.e
b6=Math.max(d8-b5,d9-b6)
b5=e6?f7:e2.ay
b5=b6>(b5==null?e1.y:b5)}else b5=!1
if(b5)B.a.k(g1,"pressure_rating_exceeded:"+b7)}else{c1=d7.a
c5=d7.c
c6=d7.e
c7=c0.Q
c8=c7==null
c9=c8?c0.c-c0.e:c7
e5=c4.Q
c4=e5==null?c4.c-c4.e:e5
e5=d7.d
if(c8)c7=c0.c-c0.e
B.a.k(d6,new A.c2(b7,b5,c1,c5,c6,d8-c9,d9-c4,e5.b,c7))
b5=c0.Q
c1=b5==null
c4=c1?c0.c-c0.e:b5
if(c1)b5=c0.c-c0.e
if(f6.cp(b6,d7,d8-c4,b5))B.a.k(g1,"pump_suction_lift:"+b7)}}for(g0=a.length,o=a5-0.000001,b1=a6+0.000001,b8=0;b8<g0;++b8){f0=a[b8]
b2=f0.e
if(!(b2>=o&&b2<=b1)){g0=f0.a
B.a.k(g1,b2<a5?"outlet_under_pressure:"+g0:"outlet_over_pressure:"+g0)
break}}f1=f8.a9(f9.e)
g0=f1==null
f2=g0?f7:f1.r.b7(a2)
if(f2==null)f2=0
if(!g0)o=a2>f1.x+1e-9||a2<f1.w-1e-9
else o=!1
if(o)B.a.k(g1,"valve_flow_out_of_range")
o=f6.c.r.i(0,g3)
if(o==null)o=A.K(t.N)
o=A.as(o,o.r,A.k(o).c)
b1=o.$ti.c
f3=0
while(o.l()){b2=o.d
if(b2==null)b2=b1.a(b2)
f4=f6.c.ao(b2)
if(f4.d!==B.e)continue
e2=f8.ai(f4.y)
b2=e2==null?f7:e2.cx
if(b2==null){e0=b4.i(0,f4.f)
b2=f8.R(e0==null?f4.x:e0)
b2=b2==null?f7:b2.Q}if(b2==null)b2=0
f3+=b2*f4.w}f8=n+f2
f5=A.nE(a1.Q,a2,f8,a1.ax,a1.as)
a1=f6.c.a.i(0,r)
a1.toString
o=f9.f
g2=g2.gaE()
b1=a1.gaE()
b2=A.cQ(g1,t.N)
b2=A.p(b2,A.k(b2).c)
a1=a1.gaE()
g0=g0?f7:f1.b
if(g0==null)g0=""
b4=g4?f6.dn(g3,a):0
return A.m0(a6,a5,f5,m.a,d6,n,b0,d3,a4,a3,d1,a,b4,f3,d5,f8+(g2-b1),a2,d4,a1,g3,f2,g0,b2,o)},
aD(a){return this.am(a,!0)},
de(a){var s,r,q,p,o,n,m,l,k,j
t.ms.a(a)
if(a.length===0)return Math.max(1,this.a.b.fy)
for(s=this.a,r=B.a.gq(s.e),q=new A.bo(r,t.jc),p=t.mu;q.l();){o=p.a(r.gp())
n=o.w
if(n<=0||o.d.length<3)continue
for(m=a.length,o=o.d,l=0,k=0;j=a.length,k<j;a.length===m||(0,A.j)(a),++k)if(A.rd(a[k].c,o))++l
if(l*2>=j)return n}return Math.max(1,s.b.fy)},
dn(a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=null
t.ms.a(a8)
if(a8.length===0)return 0
s=A.t(a8)
r=new A.u(a8,s.j("c(1)").a(new A.i6()),s.j("u<1,c>")).aw(0)
q=A.d([],t.h0)
p=A.d([],t.iv)
for(s=A.as(r,r.r,A.k(r).c),o=this.a,n=s.$ti.c;s.l();){m=s.d
l=o.ad(m==null?n.a(m):m)
if(l instanceof A.am)B.a.k(q,l)
if(l instanceof A.b7)B.a.k(p,l)}for(s=a8.length,k=0,j=0,i=0;i<s;++i){h=a8[i]
n=h.w
k+=h.e*n
j+=n}k=j>0?k/j:0
if(q.length!==0){g=B.a.gu(q)
s=o.c.a1(g.r)
f=s==null?a6:s.aF(g.w)
e=f==null?a6:f.c.cL(k)
if(e==null)e=0
if(e<=0)return 0
d=A.d([],t.n)
for(s=q.length,i=0;i<q.length;q.length===s||(0,A.j)(q),++i){c=q[i]
if(J.at(c.d)<2)continue
o=c.d
b=A.lo(o,A.b2(o)/2)
for(o=q.length,a=1/0,a0=0;a0<q.length;q.length===o||(0,A.j)(q),++a0){a1=q[a0]
if(c===a1)continue
a=Math.min(a,a1.dW(b))}if(isFinite(a))B.a.k(d,a)}if(d.length===0)return 0
B.a.a5(d)
s=d.length
o=s/2|0
if(!(o<s))return A.b(d,o)
return A.nO(e,g.y,d[o])}if(p.length>=4){h=B.a.gu(p)
s=o.c.a1(h.f)
f=s==null?a6:s.aF(h.r)
e=f==null?a6:f.c.cL(k)
if(e==null)e=0
if(e<=0)return 0
a2=A.d([],t.n)
a3=p.length>400?B.a.d0(p,0,400):p
for(s=a3.length,i=0;o=a3.length,i<o;a3.length===s||(0,A.j)(a3),++i){c=a3[i]
for(n=c.d,m=n.a,n=n.b,a=1/0,a0=0;a0<a3.length;a3.length===o||(0,A.j)(a3),++a0){a1=a3[a0]
if(c===a1)continue
a4=a1.d
a5=m-a4.a
a4=n-a4.b
a=Math.min(a,Math.sqrt(a5*a5+a4*a4))}if(isFinite(a))B.a.k(a2,a)}if(a2.length===0)return 0
B.a.a5(a2)
s=a2.length
o=s/2|0
if(!(o<s))return A.b(a2,o)
g=a2[o]
return A.nO(e,g,g)}return 0},
dq(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this.c.f.i(0,a)
if(c==null)c=A.K(t.N)
c=A.as(c,c.r,A.k(c).c)
s=b.c
r=c.$ti.c
q=1/0
p=-1/0
o=-1/0
n=1/0
while(c.l()){m=c.d
if(m==null)m=r.a(m)
l=this.c.a.i(0,m)
l.toString
k=s.i(0,m)
if(k==null)continue
for(m=l.f,j=m.length,i=k.a,h=l.Q,l=l.c-l.e,g=0;g<j;++g){f=m[g]
if(f.b===-2)continue
e=h==null?l:h
d=i-(e+f.x)
q=Math.min(q,d)
p=Math.max(p,d)
o=Math.max(o,f.f)
n=Math.min(n,f.r)}}if(!isFinite(q))return B.FJ
return new A.d6([q,p,o,n])},
c3(a,b,c){return A.m0(0,0,0,!1,B.bq,0,0,1,0,0,0,B.ff,0,0,B.br,0,0,B.da,0,a,0,"",t.bF.a(c),b)},
bx(a){var s,r,q,p,o,n
t.bq.a(a)
s=A.l(t.N,t.e5)
for(r=A.as(a,a.r,A.k(a).c),q=this.a.c,p=r.$ti.c;r.l();){o=r.d
if(o==null)o=p.a(o)
n=this.c.ao(o)
if(n.d!==B.e||!n.z||n.y!=null)continue
if(q.ah(n.Q).length===0)continue
J.b3(s.X(n.f,new A.ij()),n)}return s},
al(a){var s=this.r
if(s==null)s=this.r=this.a.c.cZ()
s=s.i(0,a.a)
return s==null?a.Q:s},
aR(a,b,c,d){var s,r,q,p,o,n
t.e5.a(a)
t.U.a(c)
t.hZ.a(d)
for(s=J.a0(a),r=b.f/1000,q=0;s.l();){p=s.gp()
if(!d.v(0,p))continue
o=this.aA(p)
n=c.i(0,p.a)
if(n==null)n=0
q+=Math.abs(n)*(1-Math.pow(o/r,4.871))}return q},
aB(a){return J.ol(t.e5.a(a),0,new A.ii(),t.i)},
b1(a,b){var s=this.a.c.ah(a.Q),r=A.t(s),q=r.j("A<1>"),p=A.p(new A.A(s,r.j("q(1)").a(new A.ik(this,b,a)),q),q.j("h.E"))
return p.length===0?A.d([B.a.gF(s)],t.nD):p},
cb(a){var s
switch(a.Q.a){case 0:s=Math.max(1,this.a.b.ch)
break
case 1:s=Math.max(1,this.a.b.CW)
break
case 2:s=Math.max(1,this.a.b.fx)
break
default:s=null}return s},
bg(a){a.b.a_(0,new A.hU(this))},
dG(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.J.a(b)
s=A.d([],t.s)
for(r=A.k(b),q=new A.J(b,r.j("J<1,2>")).gq(0),p=t.G,o=d.a.c,n=d.e;q.l();){m=q.d
n.h(0,m.a,B.a.gu(o.ah(p.a(J.bZ(m.b)).Q)).a)}for(r=r.j("ap<1,2>"),l=0;l<4;++l){k=d.V(a,10,!1).J()
for(q=new A.ap(b,b.r,b.e,r),p=k.d,j=!1;q.l();){m=q.d
for(o=m.b,i=J.a5(o),h=i.gq(o),g=0;h.l();){f=p.i(0,h.gp().a)
f=f==null?null:f.a
g=Math.max(g,Math.abs(f==null?0:f))}e=B.a.gu(d.b1(i.gu(o),g))
h=e.f/1000
if(g/(3.141592653589793*h*h/4)>d.aC(i.gu(o))+0.000001)B.a.k(s,"velocity_exceeded:"+m.a)
o=m.a
i=e.a
if(n.i(0,o)!==i){n.h(0,o,i)
j=!0}}if(!j)break}return s},
cm(a9,b0,b1,b2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=this
t.J.a(b0)
t.bF.a(b1)
s=a8.c.c.i(0,a9).b
r=a8.c.r.i(0,a9)
if(r==null)r=A.K(t.N)
q=a8.e
p=a8.f
o=A.k(b0).j("ap<1,2>")
n=a8.a.c
m=t.G
l=t.N
k=t.i
j=0
for(;;){if(j<400)i=!(b2.w>=b2.y-0.000001&&b2.x<=b2.z+0.000001)
else i=!1
if(!i)break
h=b2.gbK()
if(h==null)break
g=a8.bt(a9,h)
if(g==null)break
i=a8.aV(s,g,r)
f=A.cQ(i,A.t(i).c)
i=A.l(l,k)
for(e=b2.at,d=e.length,c=0;c<e.length;e.length===d||(0,A.j)(e),++c){b=e[c]
i.h(0,b.a,b.at)}for(e=new A.ap(b0,b0.r,b0.e,o),a=null,a0=null,a1=0;e.l();){a2=e.d
d=a2.b
a3=J.a5(d)
if(!a3.Z(d,f.gaK(f)))continue
a4=m.a(a3.gu(d))
a5=q.i(0,a4.f)
a4=n.R(a5==null?a4.x:a5)
a4.toString
a6=a8.aU(a4,n.ah(m.a(a3.gu(d)).Q))
if(a6==null)continue
a7=a8.aR(d,a6,i,f)/Math.max((a8.al(a6)-a8.al(a4))*a8.aB(d),0.000001)
if(a7>a1){a=a2.a
a1=a7
a0=a6}}if(a==null){B.a.k(b1,"cannot_meet_pressure_window")
break}q.h(0,a,a0.a)
p.T(0,a)
b2=a8.am(a9,!1);++j}return b2},
dd(a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.dV.a(a2)
s=t.N
r=A.l(s,t.bF)
q=this.c.f.i(0,a1)
if(q==null)q=A.K(s)
q=A.as(q,q.r,A.k(q).c)
p=q.$ti.c
while(q.l()){o=q.d
if(o==null)o=p.a(o)
for(n=this.c.a.i(0,o).f,m=n.length,l=0;l<n.length;n.length===m||(0,A.j)(n),++l){k=n[l]
if(k.b===-2)continue
J.b3(r.X(k.a,new A.i0()),o)}}j=A.K(s)
for(s=new A.M(r,r.r,r.e,r.$ti.j("M<2>")),q=t.s;s.l();){p=s.d
o=J.ae(p)
if(o.gn(p)===1){j.k(0,o.gu(p))
continue}for(p=o.gq(p),i=null,h=null,g=null,f=-1,e=-1/0,d=1/0;p.l();){c=p.gp()
o=this.c.a.i(0,c)
o.toString
b=a2.i(0,c)
if(b==null)b=0
if(b>f){f=b
i=c}a=o.Q
if(a==null)a=o.c-o.e
if(a>e){e=a
h=c}if(a<d){d=a
g=c}}p=A.d([],q)
if(i!=null)p.push(i)
if(h!=null)p.push(h)
if(g!=null)p.push(g)
j.B(0,p)}if(j.a>1500){a0=A.p(j,j.$ti.c)
return A.c9(a0,0,A.cI(1500,"count",t.S),A.t(a0).c).aw(0)}return j},
c9(d2,d3,d4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0=this,d1=null
t.J.a(d3)
t.C.a(d4)
s=d0.c.c.i(0,d2).b
r=d0.c.r.i(0,d2)
if(r==null)r=A.K(t.N)
q=d0.V(d2,10,!1).J()
p=new A.i5(q)
o=d0.aO(A.d([s],t.s),r)
n=o.a
m=t.N
l=A.l(m,m)
for(k=A.k(d3),j=k.j("J<1,2>"),i=new A.J(d3,j).gq(0);i.l();){h=i.d
for(g=J.a0(h.b),f=h.a;g.l();)l.h(0,g.gp().a,f)}e=A.l(m,t.d)
d=A.l(m,t.i)
c=A.l(m,t.S)
for(j=new A.J(d3,j).gq(0);j.l();){h=j.d
for(i=h.b,g=J.a5(i),f=g.gq(i),b=0;f.l();)b=Math.max(b,A.mb(p.$1(f.gp())))
f=h.a
e.h(0,f,d0.b1(g.gu(i),b))
d.h(0,f,d0.aB(i))
c.h(0,f,d0.cb(g.gu(i)))}j=d0.c.f.i(0,d2)
if(j==null)j=A.K(m)
j=A.as(j,j.r,A.k(j).c)
i=j.$ti.c
a=0
while(j.l()){g=j.d
if(g==null)g=i.a(g)
for(g=d0.c.a.i(0,g).f,f=g.length,a0=0;a0<g.length;g.length===f||(0,A.j)(g),++a0){h=g[a0]
a+=h.c.af(h.e)*h.d}}j=d0.a.b
i=j.ay
a1=i?A.nE(j.Q,a,1,j.ax,j.as):0
a2=d0.c.a.i(0,s).gaE()
g=A.dz(d0.dd(d2,o.c),m)
g.B(0,d4)
a3=A.d([],t.nE)
for(g=A.as(g,g.r,A.k(g).c),f=q.d,a4=t.U,a5=j.p1,a6=a5>0,a7=g.$ti.c,a5/=200,a8=1-a5,a5=1+a5;g.l();){a9=g.d
if(a9==null)a9=a7.a(a9)
b0=d0.c.a.i(0,a9)
if(b0==null||!n.E(a9))continue
for(b1=b0.f,b2=b1.length,b3=-1/0,b4=1/0,b5=0,b6=0,b7=0,a0=0;a0<b2;++a0){h=b1[a0]
if(h.b===-2)continue
b3=Math.max(b3,h.f)
b4=Math.min(b4,h.r)
b5=Math.max(b5,h.x)
b8=h.d
b6+=h.e*b8
b7+=b8}if(!isFinite(b3)&&!isFinite(b4))continue
if(a6&&b7>0){b9=b6/b7
b3=Math.max(b3,b9*a8)
b4=Math.min(b4,b9*a5)}c0=A.l(m,a4)
for(a9=d0.ce(n,a9),b1=a9.length,c1=0,a0=0;a0<a9.length;a9.length===b1||(0,A.j)(a9),++a0){c2=a9[a0]
b2=c2.a
c3=l.i(0,b2)
if(c3!=null){c4=c0.X(c3,new A.i4())
for(b2=e.i(0,c3),b8=b2.length,c5=0;c5<b2.length;b2.length===b8||(0,A.j)(b2),++c5){c6=b2[c5]
c7=c6.a
c8=c4.i(0,c7)
if(c8==null)c8=0
c4.h(0,c7,c8+d0.c8(c2,c6,p.$1(c2)))}}else if(c2.d===B.e)c1+=d0.c2(c2,p.$1(c2))
else{b2=f.i(0,b2)
b2=b2==null?d1:b2.c
c1+=b2==null?0:b2}}a9=b0.Q
c9=(a9==null?b0.c-b0.e:a9)+b5-a2
a9=isFinite(b3)?b3+c9:d1
B.a.k(a3,new A.dB(0,c0,c1,a9,isFinite(b4)?b4+c9:d1))}m=k.j("aa<1>")
m=A.p(new A.aa(d3,m),m.j("h.E"))
return A.nR(new A.eO(m,e,d,c,A.d([new A.dC(a1,d1,d1,"zone")],t.jv),a3,A.fK(j.y,j.z),i,d0.gcf()))},
dm(a,b){return this.c9(a,b,B.FM)},
cY(c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1=this,c2=c1.a,c3=t.cH.a(c2.ad(c4))
if(c3==null||!c1.c.c.E(c4))return c1.aD(c4)
s=c1.c.r.i(0,c4)
if(s==null)s=A.K(t.N)
r=c1.bx(s)
if(r.a===0)return c1.aD(c4)
q=c1.c.c.i(0,c4).b
p=A.d([],t.s)
B.a.B(p,c1.dG(c4,r))
o=c2.b
if(o.fr===B.a7){n=c1.dm(c4,r)
m=n.a
if(m){c1.bg(n)
l=c1.am(c4,!1)
k=t.N
j=A.K(k)
i=t.A
h=0
for(;;){if(h<4)g=!(l.w>=l.y-0.000001&&l.x<=l.z+0.000001)
else g=!1
if(!g)break
f=A.K(k)
g=A.d([],i)
e=l.gbK()
if(e!=null)g.push(e)
e=l.geh()
if(e!=null)g.push(e)
e=g.length
d=0
for(;d<g.length;g.length===e||(0,A.j)(g),++d){c=c1.bt(c4,g[d])
if(c!=null)f.k(0,c)}if(f.e2(0,j.gaK(j)))break
g=A.eM(k)
g.B(0,j)
g.B(0,f)
n=c1.c9(c4,r,g)
if(!n.a)break
c1.bg(n)
l=c1.am(c4,!1);++h
j=g}}else{B.a.k(c1.d.f,"lp_infeasible:"+c3.f)
l=c1.am(c4,!1)}}else{l=c1.am(c4,!1)
m=!1}l=c1.cm(c4,r,p,l)
if(!m&&o.ay){b=A.fK(o.y,o.z)
for(k=c1.e,i=A.k(r).j("ap<1,2>"),g=o.ax,e=o.Q,o=o.as,c2=c2.c,a=t.G,a0=t.N,a1=t.i,a2=0;a2<200;++a2){a3=l.gbK()
if(a3==null)break
a4=c1.bt(c4,a3)
if(a4==null)break
a5=c1.aV(q,a4,s)
a6=A.cQ(a5,A.t(a5).c)
a5=A.l(a0,a1)
for(a7=l.at,a8=a7.length,d=0;d<a7.length;a7.length===a8||(0,A.j)(a7),++d){a9=a7[d]
a5.h(0,a9.a,a9.at)}for(a7=new A.ap(r,r.r,r.e,i),a8=9788.99803*l.d,b0=null,b1=null,b2=0;a7.l();){b3=a7.d
b4=b3.b
b5=J.a5(b4)
if(!b5.Z(b4,a6.gaK(a6)))continue
b6=a.a(b5.gu(b4))
b7=k.i(0,b6.f)
b6=c2.R(b7==null?b6.x:b7)
b6.toString
b8=c1.aU(b6,c2.ah(a.a(b5.gu(b4)).Q))
if(b8==null)continue
b9=a8*c1.aR(b4,b8,a5,a6)/Math.max(o,0.05)/1000*g*e-(c1.al(b8)-c1.al(b6))*c1.aB(b4)*b
if(b9>b2){b0=b3.a
b2=b9
b1=b8}}if(b0==null)break
k.h(0,b0,b1.a)
l=c1.am(c4,!1)}}c1.cj(q,s,r)
c1.by(r)
c0=c1.am(c4,!0)
c2=A.dz(p,t.N)
c2.B(0,c0.ch)
c2=A.p(c2,A.k(c2).c)
return c0.cD(c2)},
bt(a,b){var s,r,q,p,o,n,m,l,k=this.c.f.i(0,a)
if(k==null)k=A.K(t.N)
k=A.as(k,k.r,A.k(k).c)
s=b.a
r=b.b
q=k.$ti.c
while(k.l()){p=k.d
if(p==null)p=q.a(p)
for(o=this.c.a.i(0,p).f,n=o.length,m=0;m<n;++m){l=o[m]
if(l.a===s&&l.b===r)return p}}return null},
cj(b1,b2,b3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this
t.C.a(b2)
t.J.a(b3)
s=t.N
r=A.l(s,s)
for(q=new A.J(b3,A.k(b3).j("J<1,2>")).gq(0);q.l();){p=q.d
for(o=J.a0(p.b),n=p.a;o.l();)r.h(0,o.gp().a,n)}m=A.X([b1,null],s,t.B)
l=A.d([b1],t.s)
k=A.d([],t.I)
for(j=0;j<l.length;j=i){i=j+1
h=l[j]
for(s=b0.c.a.i(0,h).w,q=s.length,g=0;g<s.length;s.length===q||(0,A.j)(s),++g){f=s[g]
if(!b2.v(0,f.a))continue
e=f.b
if(h===e)e=f.c
if(!m.E(e)){m.h(0,e,f)
B.a.k(k,f)
B.a.k(l,e)}}}for(s=t.g9,q=s.j("aV<w.E>"),o=b0.a.c,n=b0.e,d=A.k(m).j("J<1,2>"),c=s.j("w.E"),b=b0.f,a=0;a<5;++a){for(a0=new A.bB(k,s),a0=new A.aV(a0,a0.gn(0),q),a1=!1;a0.l();){a2=a0.d
if(a2==null)a2=c.a(a2)
a3=r.i(0,a2.a)
if(a3==null)continue
a4=new A.J(m,d).e4(0,new A.i7(a2))
a5=a2.b
a6=m.i(0,a4.a===a5?a2.c:a5)
if(a6==null)continue
a7=r.i(0,a6.a)
if(a7==null||a7===a3)continue
h=n.i(0,a2.f)
a2=o.R(h==null?a2.x:h)
a2.toString
h=n.i(0,a6.f)
a2=a2.f
if(a2>o.R(h==null?a6.x:h).f+1e-9){a8=o.ah(a6.Q)
for(a4=a8.length,a2-=1e-9,g=0;g<a4;++g){a9=a8[g]
if(a9.f>=a2){n.h(0,a7,a9.a)
b.T(0,a7)
a1=!0
break}}}}if(!a1)break}},
by(a){var s,r,q,p,o,n,m
t.J.a(a)
for(s=new A.J(a,A.k(a).j("J<1,2>")).gq(0),r=this.a,q=this.e;s.l();){p=s.d
o=p.a
n=q.i(0,o)
if(n==null)continue
m=r.ad(o)
if(m instanceof A.aM)m.f=n
if(m instanceof A.am)m.e=n
for(o=J.a0(p.b);o.l();)o.gp().x=n}},
d7(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5=this,b6=b5.f
if(b6.a===0)return 0
s=t.N
r=A.K(s)
for(q=b5.c.c,q=new A.M(q,q.r,q.e,A.k(q).j("M<2>"));q.l();)r.k(0,q.d.b)
q=b5.c.d
p=A.k(q).j("av<2>")
o=A.dz(new A.av(q,p),p.j("h.E"))
s=A.K(s)
for(q=b5.c.r,q=new A.M(q,q.r,q.e,A.k(q).j("M<2>"));q.l();){p=q.d
for(p=p.gq(p);p.l();)s.k(0,A.D(p.gp()))}n=b5.aO(r,s).c
m=b5.aO(o,b5.c.x).c
for(s=new A.J(b6,A.k(b6).j("J<1,2>")).gq(0),r=b5.a,q=r.e,p=t.n,l=t.Q,k=t.bw,j=t.pa,i=j.j("w.E"),h=t.s,g=0;s.l();){f=s.d
e=r.ad(f.a)
if(e!=null)d=!(e instanceof A.aM||e instanceof A.am||e instanceof A.aG)
else d=!0
if(d)continue
d=b5.c.b
c=A.t(d)
b=c.j("A<1>")
a=A.p(new A.A(d,c.j("q(1)").a(new A.hV(e)),b),b.j("h.E"))
B.a.ak(a,new A.hW())
if(a.length===0)continue
a0=B.a.gu(a).e===B.i?m:n
d=A.d([B.a.gu(a).b],h)
for(c=a.length,a1=0;a1<a.length;a.length===c||(0,A.j)(a),++a1)d.push(a[a1].c)
a2=A.p(new A.u(d,k.a(new A.hX(a0)),j),i)
if(B.a.Z(a2,new A.hY()))continue
for(d=a2.length,a3=!0,a4=!0,a5=1;a5<d;++a5){c=a2[a5]
c.toString
b=a2[a5-1]
b.toString
if(c<b)a3=!1
if(c>b)a4=!1}if(a3===a4)continue
a6=f.b
l.a(e)
a7=e.gn(e)
if(a3)a8=a6
else{d=J.on(a6)
a8=A.p(d,d.$ti.j("w.E"))}a9=A.d([],p)
for(d=J.ae(a8),b0=0,a5=0;a5<d.gn(a8)-1;++a5){b0+=d.i(a8,a5).b*a7
B.a.k(a9,b0)}b1=A.rj(e,a9,new A.hZ(b5))
if(b1.length<2)continue
b2=B.a.cH(q,e)
B.a.el(q,b2)
for(a5=0;a5<b1.length;++a5){b3=b1[a5]
b4=d.i(a8,Math.min(a5,d.gn(a8)-1)).a
if(b3 instanceof A.aM)b3.f=b4.a
if(b3 instanceof A.am)b3.e=b4.a
B.a.e8(q,b2+a5,b3)}++g}b6.W(0)
b5.e.W(0)
b5.c=A.lU(r).bA()
return g},
aS(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=t.U
c.a(a)
c.a(b)
c=d.a
s=c.b
s=A.mL(A.fP(s.c),s.b)
r=A.l(t.N,t.b)
q=A.d([],t.lp)
p=new A.ew(s,r,q)
for(s=d.c.w,s=A.as(s,s.r,A.k(s).c),o=s.$ti.c,n=t.v;s.l();){m=s.d
if(m==null)m=o.a(m)
l=d.c.a.i(0,m)
if(l.y){k=l.z
k.toString
j=a.i(0,n.a(c.ad(k)).a)
if(j==null)j=0
k=l.Q
i=k==null
h=i?l.c-l.e:k
r.h(0,m,new A.by(m,B.a_,h,(i?l.c-l.e:k)+j,null,1,0))
continue}k=l.Q
g=new A.by(m,B.Z,k==null?l.c-l.e:k,null,null,1,0)
r.h(0,m,g)
d.bZ(p,g,l,!0)}for(c=d.c.c,c=new A.J(c,A.k(c).j("J<1,2>")).gq(0);c.l();){f=c.d
e=r.i(0,f.b.a)
if(e==null)continue
s=e.d
o=b.i(0,f.a)
e.d=s+(o==null?0:o)}for(c=d.c.e,c=new A.J(c,A.k(c).j("J<1,2>")).gq(0);c.l();){f=c.d
e=r.i(0,f.b)
if(e==null)continue
s=e.d
o=b.i(0,f.a)
e.d=s+(o==null?0:o)}for(c=d.c.x,c=A.as(c,c.r,A.k(c).c),s=c.$ti.c;c.l();){r=c.d
if(r==null)r=s.a(r)
r=d.c.ao(r)
r.toString
B.a.k(q,d.cr(r))}return p},
gb0(){var s=t.lF,r=s.j("A<h.E>")
s=A.p(new A.A(new A.b0(this.a.e,s),s.j("q(h.E)").a(new A.ih(this)),r),r.j("h.E"))
return s},
cp(a,b,c,d){var s
if(a.d!==B.Y||b.a<=0)return!1
s=this.a.c.av(a.ch)
if(s==null||s.f)return!1
return-c>10.33*Math.pow(1-0.0000225577*B.b.a7(d,-500,8000),5.25588)-0.24-3+0.000001},
cA(e3,e4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=null,e1=A.d([],t.s),e2=d9.gb0()
if(e2.length===0)return new A.bd(e3.a,e3.b,!1,B.fh,B.fi,B.br,B.bq,B.fo,0,e3.e,0)
s=t.N
r=t.i
q=A.l(s,r)
p=A.l(s,r)
for(o=e3.c,o=A.as(o,o.r,A.k(o).c),n=o.$ti.c;o.l();){m=o.d
if(m==null)m=n.a(m)
if(d9.aq(m)==null)continue
l=d9.bl(m)
q.h(0,m,l.a)
p.h(0,m,l.b)}r=A.l(s,r)
for(o=e2.length,k=0;k<e2.length;e2.length===o||(0,A.j)(e2),++k){j=e2[k]
n=j.e?0:j.f
r.h(0,j.a,n)}i=d9.aS(r,q).J()
o=A.t(e2)
n=o.j("A<1>")
h=A.p(new A.A(e2,o.j("q(1)").a(new A.im()),n),n.j("h.E"))
g=new A.io(d9,q,p)
if(h.length!==0){f=g.$1(i)
if(f>0){for(o=h.length,k=0;k<h.length;h.length===o||(0,A.j)(h),++k)r.h(0,h[k].a,f)
i=d9.aS(r,q).J()}}else f=0
o=i.a
if(!o)B.a.k(e1,"not_converged")
e=A.d([],t.eZ)
for(n=new A.au(q,q.r,q.e,q.$ti.j("au<1>")),m=i.c,d=d9.d,c=d.d,d=d.c;n.l();){b=n.d
a=d9.aq(b)
if(a==null)a=""
a0=m.i(0,a)
a1=c.i(0,b)
a2=a1==null
a3=a2?e0:a1.c
if(a3==null){a3=d.i(0,b)
a3=a3==null?e0:a3.b
a4=a3}else a4=a3
if(a4==null)a4=b
if(a0==null){B.a.k(e1,"valve_unreachable:"+b)
continue}a3=q.i(0,b)
a3.toString
a5=a0.b
a6=p.i(0,b)
a6.toString
B.a.k(e,new A.b_(b,a4,a3,a5,a6,d9.c.a.i(0,a).b))
a2=!a2
if(a2)a1.dx=a5
a3=p.i(0,b)
a3.toString
if(a5<a3-0.01)B.a.k(e1,a2?"pivot_pressure_deficit:"+b:"valve_pressure_deficit:"+b)}a7=A.d([],t.iF)
for(n=e2.length,d=i.d,c=d9.b,a8=0,k=0;k<e2.length;e2.length===n||(0,A.j)(e2),++k){j=e2[k]
a2=j.a
a3=d9.c.d.i(0,a2)
a3.toString
for(a5=d9.c.a.i(0,a3).w,a6=a5.length,a9=0,b0=0;b0<a5.length;a5.length===a6||(0,A.j)(a5),++b0){b1=a5[b0]
b2=d.i(0,b1.a)
if(b2==null)continue
b3=b2.a
a9+=b1.b===a3?b3:-b3}a8+=a9
a5=r.i(0,a2)
a5.toString
a6=j.e
if(a6)b4=f
else{b3=g.$1(i)
if(typeof b3!=="number")return A.bG(b3)
b4=j.f+b3}b3=j.c
if(b3.length===0)b3=c.$1("name.supply")
a3=d9.c.a.i(0,a3)
b5=a3.Q
a3=b5==null?a3.c-a3.e:b5
b5=j.r
b6=j.w
B.a.k(a7,new A.cA(a2,b3,a9,a5,b4,a3,a6,j.f,b5,b6,j.x))
if(b6>0&&a9>b6+1e-9)B.a.k(e1,"supply_flow_exceeded:"+a2)
if(b5>0&&b4>b5+0.000001)B.a.k(e1,"supply_head_exceeded:"+a2)}b7=A.d([],t.dI)
b8=A.d([],t.c)
for(r=d9.c.x,r=A.as(r,r.r,A.k(r).c),n=r.$ti.c,c=d9.a,a2=c.c,a3=d9.e;r.l();){a5=r.d
if(a5==null)a5=n.a(a5)
a6=d9.c.ao(a5)
a6.toString
b2=d.i(0,a5)
if(b2==null)continue
b3=a6.b
b5=d9.c.a.i(0,b3)
b5.toString
b6=a6.c
b9=d9.c.a.i(0,b6)
b9.toString
c0=m.i(0,b3).a
c1=m.i(0,b6).a
b3=a6.d
b6=a6.f
if(b3===B.e){c2=a3.i(0,b6)
c3=a2.R(c2==null?a6.x:c2)
c4=d9.aA(a6)
b3=b2.a
c5=Math.abs(b3)/(3.141592653589793*c4*c4/4)
c6=b5.Q
c7=c6==null
c8=c7?b5.c-b5.e:c6
c9=b9.Q
d0=c9==null
d1=d0?b9.c-b9.e:c9
d2=c3==null
d3=d2?e0:c3.a
d4=d2?e0:c3.b
if(d4==null)d4="?"
d5=b2.c
if(c7)c6=b5.c-b5.e
c7=d0?b9.c-b9.e:c9
c9=d2?e0:c3.y
if(c9==null)c9=0
B.a.k(b7,new A.bl(a5,b6,a6.r,a6.cx,a6.cy,c8,d1,a6.w,c4,d3,d4,b3,c5,d5,c0-c6,c1-c7,c9,e0,c5>d9.aC(a6)+0.000001))
if(c5>d9.aC(a6)+0.000001)B.a.k(e1,"velocity_exceeded:"+b6)
a5=d2?e0:c3.y
if((a5==null?0:a5)>0){a5=b5.Q
if(a5==null)a5=b5.c-b5.e
a6=b9.Q
if(a6==null)a6=b9.c-b9.e
a6=Math.max(c0-a5,c1-a6)>c3.y
a5=a6}else a5=!1
if(a5)B.a.k(e1,"pressure_rating_exceeded:"+b6)}else{c6=b2.a
c7=b2.c
c8=b2.e
c9=b5.Q
d0=c9==null
d1=d0?b5.c-b5.e:c9
d2=b9.Q
b9=d2==null?b9.c-b9.e:d2
d2=b2.d
if(d0)c9=b5.c-b5.e
B.a.k(b8,new A.c2(b6,a5,c6,c7,c8,c0-d1,c1-b9,d2.b,c9))
if(b3===B.Y){c3=a2.av(a6.ch)
if(c3!=null)a5=c6>c3.z+1e-9||c6<=0
else a5=!1
if(a5)B.a.k(e1,"pump_out_of_range:"+b6)
a5=b5.Q
b3=a5==null
b9=b3?b5.c-b5.e:a5
if(b3)a5=b5.c-b5.e
if(d9.cp(a6,b2,c0-b9,a5))B.a.k(e1,"pump_suction_lift:"+b6)}}}d6=e4>0?e3.e/e4:1
r=c.b
d7=r.at*d6
for(n=a7.length,m=r.Q,r=r.as,d8=0,k=0;k<n;++k){c4=a7[k]
if(c4.r&&c4.e>0)d8+=9788.99803*c4.c*c4.e/Math.max(r,0.05)/1000*d7*m}for(n=b8.length,k=0;k<b8.length;b8.length===n||(0,A.j)(b8),++k){c4=b8[k]
d=c4.e
if(d>0){c3=a2.av(d9.c.ao(c4.b).ch)
c=c3==null?e0:c3.x
if(c==null)c=r
d8+=9788.99803*c4.c*d/Math.max(c,0.05)/1000*d7*m}}s=A.cQ(e1,s)
s=A.p(s,A.k(s).c)
return new A.bd(e3.a,e3.b,o,a7,e,b7,b8,s,a8,e3.e,d8)},
bD(){var s,r,q=this,p=q.a.f
if(p.length!==0)return p
p=q.b.$1("name.allZones")
s=q.c.c
s=A.dz(new A.aa(s,A.k(s).j("aa<1>")),t.N)
r=q.c.e
s.B(0,new A.aa(r,A.k(r).j("aa<1>")))
return A.d([A.n3(1,"auto",p,0,s)],t.cD)},
dl(d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8=this,c9=null,d0={}
t.J.a(d1)
t.k6.a(d2)
s=c8.gb0()
r=t.N
q=A.l(r,t.v)
for(p=s.length,o=0;o<s.length;s.length===p||(0,A.j)(s),++o){n=s[o]
m=c8.c.d.i(0,n.a)
m.toString
q.h(0,m,n)}d0.a=d0.b=null
l=c8.aO(new A.aa(q,q.$ti.j("aa<1>")),c8.c.x)
d0.b=l.a
d0.a=l.b
p=A.l(r,r)
for(m=A.k(d1),k=m.j("J<1,2>"),j=new A.J(d1,k).gq(0);j.l();){i=j.d
for(h=J.a0(i.b),g=i.a;h.l();)p.h(0,h.gp().a,g)}f=A.d([],t.lH)
e=A.d([],t.gN)
for(j=d2.length,h=t.i,o=0;o<d2.length;d2.length===j||(0,A.j)(d2),++o){d=A.l(r,h)
for(g=d2[o].c,c=A.k(g),b=new A.Y(g,g.r,c.j("Y<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
if(c8.aq(g)==null)continue
d.h(0,g,c8.bl(g).a)}B.a.k(e,d)
g=A.l(r,h)
for(c=s.length,a=0;a<s.length;s.length===c||(0,A.j)(s),++a){n=s[a]
b=n.e?0:n.f
g.h(0,n.a,b)}B.a.k(f,c8.aS(g,d).J())}a0=A.l(r,t.d)
a1=A.l(r,h)
j=t.S
a2=A.l(r,j)
for(k=new A.J(d1,k).gq(0);k.l();){i=k.d
for(h=f.length,g=i.b,c=J.a5(g),a3=0,o=0;o<f.length;f.length===h||(0,A.j)(f),++o){a4=f[o]
for(b=c.gq(g),a5=a4.d;b.l();){a6=a5.i(0,b.gp().a)
a6=a6==null?c9:a6.a
a3=Math.max(a3,Math.abs(a6==null?0:a6))}}h=i.a
a0.h(0,h,c8.b1(c.gu(g),a3))
a1.h(0,h,c8.aB(g))
a2.h(0,h,c8.cb(c.gu(g)))}a7=A.d([],t.jv)
a8=A.l(r,j)
for(r=c8.a.b,k=r.ay,j=r.at,h=r.Q,g=r.as,c=d3>0,a9=0;a9<d2.length;++a9){b0=c?d2[a9].e/d3:1
for(b=s.length,a5=a9,a6=j*b0,o=0;o<s.length;s.length===b||(0,A.j)(s),++o){n=s[o]
b1=n.a
b2=c8.c.d.i(0,b1)
b2.toString
for(b3=c8.c.a.i(0,b2).w,b4=b3.length,b5=0,a=0;a<b3.length;b3.length===b4||(0,A.j)(b3),++a){b6=b3[a]
if(!(a9<f.length))return A.b(f,a9)
b7=f[a9].d.i(0,b6.a)
if(b7==null)continue
b8=b7.a
b5+=b6.b===b2?b8:-b8}b2=n.e
b9=b2&&k?9788.99803*Math.max(b5,0)/Math.max(g,0.05)/1000*a6*h:0
a8.h(0,b1+"|"+a5,a7.length)
b1=b2?c9:n.f
b2=b2&&n.r>0?n.r:c9
b3=n.c
if(!(a9<d2.length))return A.b(d2,a9)
B.a.k(a7,new A.dC(b9,b1,b2,b3+"|"+d2[a9].b))}}c0=A.d([],t.nE)
for(j=c8.d,h=j.c,j=j.d,a9=0;a9<d2.length;++a9){if(!(a9<f.length))return A.b(f,a9)
a4=f[a9]
c1=new A.i1(d0,c8,q,p,a0,new A.i3(a4),a4,c0,a8,a9)
for(g=d2[a9].c,c=A.k(g),b=new A.Y(g,g.r,c.j("Y<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
c2=c8.aq(g)
if(c2==null)continue
c3=j.i(0,g)
if(c3!=null){c1.$4(c2,c3.r,c9,0)
continue}c4=h.i(0,g)
if(c4==null)continue
c1.$4(c2,c4.r,c9,0)}for(g=c8.c.w,c=A.k(g),b=new A.Y(g,g.r,c.j("Y<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
a5=c8.c.a.i(0,g).f
a6=a5.length
if(a6===0)continue
for(c5=-1/0,c6=1/0,c7=0,o=0;o<a6;++o){i=a5[o]
c5=Math.max(c5,i.f)
c6=Math.min(c6,i.r)
c7=Math.max(c7,i.x)}if(isFinite(c5))c1.$4(g,c5,isFinite(c6)?c6:c9,c7)}}q=m.j("aa<1>")
q=A.p(new A.aa(d1,q),q.j("h.E"))
return A.nR(new A.eO(q,a0,a1,a2,a7,c0,A.fK(r.y,r.z),k,c8.gcf()))},
cX(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5=this,d6=null,d7=d5.bD(),d8=t.i,d9=B.a.P(d7,0,new A.iw(),d8),e0=d5.bx(d5.c.x),e1=new A.iv(d5,d7,d9)
if(e0.a===0||d5.gb0().length===0){d8=d5.d.e
B.a.W(d8)
B.a.B(d8,e1.$0())
return}s=d5.gb0()
r=A.t(s)
q=new A.u(s,r.j("c(1)").a(new A.ix(d5)),r.j("u<1,c>")).aw(0)
for(r=A.k(e0),p=new A.J(e0,r.j("J<1,2>")).gq(0),o=t.G,n=d5.a,m=n.c,l=d5.e;p.l();){k=p.d
l.h(0,k.a,B.a.gu(m.ah(o.a(J.bZ(k.b)).Q)).a)}for(r=r.j("ap<1,2>"),p=t.N,j=0;j<4;++j){i=A.l(p,d8)
for(h=d7.length,g=0;g<d7.length;d7.length===h||(0,A.j)(d7),++g){f=A.l(p,d8)
for(e=d7[g].c,d=A.k(e),c=new A.Y(e,e.r,d.j("Y<1>")),c.c=e.e,d=d.c;c.l();){e=c.d
if(e==null)e=d.a(e)
if(d5.aq(e)==null)continue
f.h(0,e,d5.bl(e).a)}e=A.l(p,d8)
for(d=s.length,b=0;b<s.length;s.length===d||(0,A.j)(s),++b){a=s[b]
c=a.e?0:a.f
e.h(0,a.a,c)}a0=d5.aS(e,f).J()
for(e=new A.ap(e0,e0.r,e0.e,r),d=a0.d;e.l();){k=e.d
for(c=J.a0(k.b),a1=k.a;c.l();){a2=c.gp()
a3=i.i(0,a1)
if(a3==null)a3=0
a2=d.i(0,a2.a)
a2=a2==null?d6:a2.a
i.h(0,a1,Math.max(a3,Math.abs(a2==null?0:a2)))}}}for(h=new A.ap(e0,e0.r,e0.e,r),a4=!1;h.l();){k=h.d
e=J.bZ(k.b)
d=k.a
c=i.i(0,d)
e=B.a.gu(d5.b1(e,c==null?0:c)).a
if(l.i(0,d)!==e){l.h(0,d,e)
a4=!0}}if(!a4)break}n=n.b
if(n.fr===B.a7){h=d5.c.x
e=A.k(h)
a5=new A.A(h,e.j("q(1)").a(new A.iy(d5)),e.j("A<1>")).gn(0)
h=d5.c.w.a
if(a5>=h&&h!==0)B.a.k(d5.d.f,"lp_loops_approx")
a6=d5.dl(e0,d7,d9)
a7=a6.a
if(a7)d5.bg(a6)
else B.a.k(d5.d.f,"lp_infeasible:"+A.z(d5.b.$1("menu.mainline")))}else a7=!1
a8=e1.$0()
if(B.a.Z(s,new A.iz()))for(h=d5.f,e=A.k(q),d=e.j("Y<1>"),e=e.c,a9=0;a9<400;++a9){for(c=a8.length,b0=d6,b1=b0,g=0;g<c;++g){b2=a8[g]
for(a1=b2.e,a2=a1.length,b=0;b<a2;++b){b3=a1[b]
a3=b3.e-b3.d
if(a3>0.01)a3=b0==null||a3>b0.e-b0.d
else a3=!1
if(a3){b0=b3
b1=b2}}}if(b1==null||b0==null)break
c=d5.aq(b0.a)
c.toString
b4=A.K(o)
for(a1=new A.Y(q,q.r,d),a1.c=q.e;a1.l();){a2=a1.d
if(a2==null)a2=e.a(a2)
b5=d5.aV(a2,c,d5.c.x)
a2=b5.length
if(a2!==0){a3=b4.a
a2=a3===0||a2<a3}else a2=!1
if(a2)b4=A.cQ(b5,A.t(b5).c)}c=A.l(p,d8)
for(a1=b1.f,a2=a1.length,g=0;g<a1.length;a1.length===a2||(0,A.j)(a1),++g){b5=a1[g]
c.h(0,b5.a,b5.at)}for(a1=new A.ap(e0,e0.r,e0.e,r),b6=d6,b7=b6,b8=0;a1.l();){k=a1.d
a2=k.b
a3=J.a5(a2)
if(!a3.Z(a2,b4.gaK(b4)))continue
b9=o.a(a3.gu(a2))
c0=l.i(0,b9.f)
b9=m.R(c0==null?b9.x:c0)
b9.toString
c1=d5.aU(b9,m.ah(o.a(a3.gu(a2)).Q))
if(c1==null)continue
c2=d5.aR(a2,c1,c,b4)/Math.max((d5.al(c1)-d5.al(b9))*d5.aB(a2),0.000001)
if(c2>b8){b7=k.a
b8=c2
b6=c1}}if(b7==null){B.a.k(d5.d.f,"mainline_cannot_meet_pressure")
break}l.h(0,b7,b6.a)
h.T(0,b7)
a8=e1.$0()}if(!a7&&n.ay){c3=A.fK(n.y,n.z)
for(h=n.at,e=n.Q,n=n.as,d=d9>0,c=A.k(q),a1=c.j("Y<1>"),c=c.c,a9=0;a9<300;++a9){for(a2=new A.ap(e0,e0.r,e0.e,r),b6=d6,b7=b6,c4=0;a2.l();){k=a2.d
a3=k.b
b9=J.a5(a3)
c5=o.a(b9.gu(a3))
c0=l.i(0,c5.f)
c5=m.R(c0==null?c5.x:c0)
c5.toString
c1=d5.aU(c5,m.ah(o.a(b9.gu(a3)).Q))
if(c1==null)continue
for(c6=a8.length,c7=0,g=0;g<a8.length;a8.length===c6||(0,A.j)(a8),++g){b2=a8[g]
c8=b2.e
if(c8.length===0)continue
c8=d5.aq(B.a.M(c8,new A.iA()).a)
c8.toString
b4=A.K(o)
for(c9=new A.Y(q,q.r,a1),c9.c=q.e;c9.l();){d0=c9.d
if(d0==null)d0=c.a(d0)
b5=d5.aV(d0,c8,d5.c.x)
d0=b5.length
if(d0!==0){d1=b4.a
d0=d1===0||d0<d1}else d0=!1
if(d0)b4=A.cQ(b5,A.t(b5).c)}if(!b9.Z(a3,b4.gaK(b4)))continue
c8=A.l(p,d8)
for(c9=b2.f,d0=c9.length,b=0;b<c9.length;c9.length===d0||(0,A.j)(c9),++b){b5=c9[b]
c8.h(0,b5.a,b5.at)}d2=d5.aR(a3,c1,c8,b4)
d3=d?b2.y/d9:1
c7+=9788.99803*b2.x*d2/Math.max(n,0.05)/1000*(h*d3)*e}d4=c7-(d5.al(c1)-d5.al(c5))*d5.aB(a3)*c3
if(d4>c4){b7=k.a
c4=d4
b6=c1}}if(b7==null)break
l.h(0,b7,b6.a)
a8=e1.$0()}}for(d8=A.as(q,q.r,A.k(q).c),r=d8.$ti.c;d8.l();){p=d8.d
if(p==null)p=r.a(p)
d5.cj(p,d5.c.x,e0)}d5.by(e0)
d8=d5.d.e
B.a.W(d8)
B.a.B(d8,e1.$0())},
co(a,b){return new A.bF(this.dE(a,b),t.iG)},
dE(a,b){var s=this
return function(){var r=a,q=b
var p=0,o=1,n=[],m,l,k,j,i,h,g,f,e
return function $async$co(c,d,a0){if(d===1){n.push(a0)
p=o}for(;;)switch(p){case 0:e=s.d
e.y.B(0,s.c.z)
B.a.B(e.f,s.c.y)
e.b=q||r?s.a.b.fr.b:"analysis"
e=s.c.c,e=new A.au(e,e.r,e.e,A.k(e).j("au<1>")),m=0
case 2:if(!e.l()){p=3
break}l=e.d;++m
p=4
return c.b=new A.aP([new A.ia(s,q,l),B.aX,l,m]),1
case 4:p=2
break
case 3:e=B.a.gq(s.a.e),l=new A.bo(e,t.bo),k=t.m9
case 5:if(!l.l()){p=6
break}j=k.a(e.gp())
i=s.c
h=j.a
if(!i.e.E(h)){p=5
break}++m
p=7
return c.b=new A.aP([new A.ib(s,j),B.aX,h,m]),1
case 7:p=5
break
case 6:g=new A.i8(s)
p=8
return c.b=new A.aP([new A.ic(s,r,g),B.eG,null,0]),1
case 8:p=s.f.a!==0?9:10
break
case 9:f={}
f.a=0
p=11
return c.b=new A.aP([new A.id(f,s),B.V,null,0]),1
case 11:p=f.a>0?12:13
break
case 12:e=s.c.c,e=new A.au(e,e.r,e.e,A.k(e).j("au<1>")),m=0
case 14:if(!e.l()){p=15
break}l=e.d;++m
p=16
return c.b=new A.aP([new A.ie(s,l),B.V,l,m]),1
case 16:p=14
break
case 15:p=17
return c.b=new A.aP([g,B.V,null,0]),1
case 17:case 13:case 10:p=18
return c.b=new A.aP([new A.ig(s),B.eH,null,0]),1
case 18:p=19
return c.b=new A.aP([s.gdO(),B.eI,null,0]),1
case 19:p=20
return c.b=new A.aP([s.gdU(),B.aa,null,0]),1
case 20:p=21
return c.b=new A.aP([s.gdL(),B.aa,null,0]),1
case 21:return 0
case 1:return c.c=n.at(-1),3}}}},
ds(a){var s,r,q,p,o,n,m,l=this,k=l.aD(a)
if(k.gev())return k
s=l.c.r.i(0,a)
r=l.bx(s==null?A.K(t.N):s)
if(r.a===0)return k
q=A.d([],t.s)
for(s=new A.J(r,A.k(r).j("J<1,2>")).gq(0),p=l.a.c,o=l.e;s.l();){n=s.d
m=p.R(J.bZ(n.b).x)
if(m!=null)o.h(0,n.a,m.a)}l.cm(a,r,q,l.am(a,!1))
l.by(r)
k=l.aD(a)
s=A.dz(q,t.N)
s.B(0,k.ch)
s=A.p(s,A.k(s).c)
return k.cD(s)},
b3(a,b,c,d){return this.dT(t.dn.a(a),b,c,t.ga.a(d))},
dT(a,b,c,d){var s=0,r=A.nx(t.nJ),q,p=this,o,n,m,l,k,j,i,h,g
var $async$b3=A.nC(function(e,f){if(e===1)return A.no(f,r)
for(;;)switch(s){case 0:h=p.c.c.a
g=h+5
o=p.co(b,c),n=o.$ti,o=new A.br(o.a(),n.j("br<1>")),n=n.c,m=0,l=!1
case 3:if(!o.l()){s=4
break}k=o.b
j=(k==null?n.a(k):k).a
i=j[1]
if(i===B.V&&!l){g+=p.c.c.a+2
l=!0}a.$1(new A.cl(i,m,g,j[2],j[3],p.c.c.a))
s=5
return A.nn(d.$0(),$async$b3)
case 5:j[0].$0();++m
s=3
break
case 4:a.$1(new A.cl(B.aa,g,g,null,0,h))
q=p.d
s=1
break
case 1:return A.np(q,r)}})
return A.nq($async$b3,r)},
dJ(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=d9.d.w
B.a.W(e0)
b7=d9.a
b8=t.hP
b9=A.p(new A.b0(b7.e,b8),b8.j("h.E"))
s=b9
if(J.at(s)===0||b7.b.id<=0)return e0
b8=t.N
c0=A.l(b8,t.i)
for(c1=s,c2=c1.length,c3=0;c3<c1.length;c1.length===c2||(0,A.j)(c1),++c3){c4=c1[c3]
c0.h(0,c4.a,c4.y)}r=c0
for(c0=s,c1=c0.length,c2=b7.c,c4=b7.b,c5=c4.id,c6=c5*3.141592653589793,c3=0;c3<c0.length;c0.length===c1||(0,A.j)(c0),++c3){c7=c0[c3]
c8=c2.ai(c7.e)
if(c8==null)continue
if(c7.y<=0){c9=c8.f/1000
c7.y=c6*c9*c9/4}}q=d9.c
try{c0=A.lU(b7).bA()
d9.c=c0
for(c0=c0.c,c0=new A.au(c0,c0.r,c0.e,A.k(c0).j("au<1>")),c4=c4.k1,c1=t.s,c6=t.cH;c0.l();){p=c0.d
o=c6.a(b7.ad(p))
if(o==null)continue
d0=d9.c.f.i(0,p)
n=d0==null?A.K(b8):d0
m=A.d([],c1)
l=0
k=A.K(b8)
for(c7=n,c9=A.k(c7),d1=new A.Y(c7,c7.r,c9.j("Y<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
j=c7==null?c9.a(c7):c7
for(c7=d9.c.a.i(0,j).f,d2=c7.length,c3=0;c3<c7.length;c7.length===d2||(0,A.j)(c7),++c3){i=c7[c3]
if(i.b===-2){J.b3(m,j)
J.b3(k,i.a)}}}l=k.a
if(J.at(m)===0)continue
h=null
g=null
c7=d9.c.c.i(0,p)
c7.toString
f=c7
h=f.a
g=f.b
e=new A.il(d9,m)
d=0
c=20
b=d9.V(p,c,!0).J()
a=0
for(;;){c7=e.$1(b)
if(typeof c7!=="number")return c7.bQ()
if(c7<c4){c7=a
if(typeof c7!=="number")return c7.bQ()
c7=c7<12}else c7=!1
if(!c7)break
c7=c
if(typeof c7!=="number")return c7.aj()
c=c7*2
b=d9.V(p,c,!0).J()
c7=a
if(typeof c7!=="number")return c7.ap()
a=c7+1}a0=0
for(;;){c7=a0
if(typeof c7!=="number")return c7.bQ()
if(!(c7<30))break
c7=d
c9=c
if(typeof c7!=="number")return c7.ap()
if(typeof c9!=="number")return A.bG(c9)
a1=(c7+c9)/2
b=d9.V(p,a1,!0).J()
c7=e.$1(b)
if(typeof c7!=="number")return c7.cU()
if(c7>=c4)c=a1
else d=a1
c7=c
c9=d
if(typeof c7!=="number")return c7.U()
if(typeof c9!=="number")return A.bG(c9)
if(c7-c9<0.001)break
c7=a0
if(typeof c7!=="number")return c7.ap()
a0=c7+1}a2=c
b=d9.V(p,a2,!0).J()
a3=0
for(c7=n,c9=A.k(c7),d1=new A.Y(c7,c7.r,c9.j("Y<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
a4=c7==null?c9.a(c7):c7
c7=d9.c.a.i(0,a4)
c7.toString
a5=c7
a6=b.c.i(0,a4)
if(a6==null)continue
for(c7=a5.f,d2=c7.length,c3=0;c3<c7.length;c7.length===d2||(0,A.j)(c7),++c3){a7=c7[c3]
d3=a3
d4=a7.c
d5=a6.a
d6=a5
d7=d6.Q
d6=d7==null?d6.c-d6.e:d7
d6=d4.af(Math.max(d5-(d6+a7.x),0))
d5=a7.d
if(typeof d3!=="number")return d3.ap()
a3=d3+d6*d5}}a8=0
c7=d9.c.r.i(0,p)
if(c7==null)c7=A.K(b8)
c9=A.k(c7)
d1=new A.Y(c7,c7.r,c9.j("Y<1>"))
d1.c=c7.e
c9=c9.c
while(d1.l()){c7=d1.d
a9=c7==null?c9.a(c7):c7
c7=d9.c.ao(a9)
c7.toString
b0=c7
if(b0.y==null)continue
b1=b.d.i(0,a9)
if(b1!=null){c7=a8
d2=b1.a
d3=d9.aA(b0)
a8=Math.max(A.mb(c7),Math.abs(d2)/(3.141592653589793*d3*d3/4))}}b2=c2.a9(o.e)
c7=b2
d8=c7==null?null:c7.r.b7(a3)
b3=d8==null?0:d8
c7=d9.c.a.i(0,g)
c7.toString
b4=c7
c7=d9.c.a.i(0,h)
c7.toString
b5=c7
c7=o.f
c9=a3
d1=a2
d2=b3
if(typeof d1!=="number")return d1.ap()
if(typeof d2!=="number")return A.bG(d2)
d3=b4
d4=d3.Q
d3=d4==null?d3.c-d3.e:d4
d4=b5
d5=d4.Q
d4=d5==null?d4.c-d4.e:d5
B.a.k(e0,new A.cp(p,c7,c9,a2,d1+d2+(d3-d4),l,e.$1(b),a8,c5,b.a))}}finally{for(b7=s,b8=b7.length,c3=0;c3<b7.length;b7.length===b8||(0,A.j)(b7),++c3){b6=b7[c3]
c0=J.dc(r,b6.a)
c0.toString
b6.y=c0}d9.c=q}return e0},
dP(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=this.d,b2=b1.x
B.a.W(b2)
s=this.a
r=s.b
if(!r.k2)return b2
q=A.l(t.N,t.ft)
p=new A.iu(q)
for(o=b1.c,n=A.k(o).j("M<2>"),m=new A.M(o,o.r,o.e,n);m.l();){l=m.d
for(k=l.at,j=k.length,l=l.b,i=0;i<k.length;k.length===j||(0,A.j)(k),++i)p.$2(k[i],l)}for(m=b1.e,l=m.length,i=0;i<m.length;m.length===l||(0,A.j)(m),++i){h=m[i]
for(k=h.f,j=k.length,g=h.b,f=0;f<k.length;k.length===j||(0,A.j)(k),++f)p.$2(k[f],g)}for(l=new A.J(q,q.$ti.j("J<1,2>")).gq(0),e=r.k3,r=t.Q,k=s.c,b1=b1.f;l.l();){d=l.d
c=d.b
b=c.a
a=k.R(b.y)
if(a==null)continue
j=d.a
a0=s.ad(j)
a1=r.b(a0)?a0.gn(a0):b.w
g=a.f
a2=Math.max(a.z,0.5)
a3=Math.sqrt(2203967.1408535363/(1+22e8*(g/1000)/(a.r.c*(a2/1000))))
a2=b.as
a4=a3*a2/9.80665
a5=2*Math.max(a1,1)/a3
a6=e<=0||e<a5?a4:a4*a5/e
a7=Math.max(b.ax,b.ay)
for(g=new A.M(o,o.r,o.e,n);g.l();)for(a8=g.d.at,a9=a8.length,i=0;i<a9;++i){b0=a8[i]
if(b0.b===j)a7=Math.max(a7,Math.max(b0.ax,b0.ay))}for(g=m.length,i=0;i<g;++i)for(a8=m[i].f,a9=a8.length,f=0;f<a9;++f){b0=a8[f]
if(b0.b===j)a7=Math.max(a7,Math.max(b0.ax,b0.ay))}g=a.b
a8=a.y
B.a.k(b2,new A.bQ(j,c.b,g,a2,a3,a6,a7,a8,e,a5))
if(a8>0&&a7+a6>a8+0.000001)B.a.k(b1,"surge_rating_exceeded:"+j)}return b2},
dV(){var s,r,q,p,o,n,m=A.d([],t.ey)
for(s=this.bD(),r=s.length,q=0;q<s.length;s.length===r||(0,A.j)(s),++q){p=s[q].c
o=p.cc()
o.B(0,p)
m.push(o)}n=A.qR(this.a,m)
m=this.d
m.z=n
if(n!=null)B.a.B(m.f,n.c)
return n},
dM(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9=this,c0=null,c1="bom.pipes",c2="bom.outlets",c3="un",c4="bom.pivots",c5="bom.electrical",c6=t.N,c7=A.l(c6,t.q),c8=new A.ip(c7)
for(s=b9.c.b,r=s.length,q=b9.a,p=q.c,o=b9.e,n=0;n<s.length;s.length===r||(0,A.j)(s),++n){m=s[n]
if(m.d!==B.e)continue
l=p.ai(m.y)
if(l!=null){c8.$8$code$supplier("bom.tapes",l.b,"m",m.w,l.cx,l.a,l.d,l.c)
continue}k=o.i(0,m.f)
j=p.R(k==null?m.x:k)
if(j!=null)c8.$8$code$supplier(c1,j.b,"m",m.w,j.Q,j.a,j.d,j.c)}for(s=q.e,r=s.length,o=b9.b,i=b9.d,h=i.d,n=0;n<s.length;s.length===r||(0,A.j)(s),++n){g=s[n]
if(b9.c.z.v(0,g.a))continue
A:{f=g instanceof A.b7
e=f?g:c0
if(f){d=p.a1(e.f)
if(d!=null){f=d.b
c=d.aF(e.r)
c=c==null?c0:c.b
if(c==null)c=""
c8.$8$code$supplier(c2,f+" \u2014 "+c,c3,1,d.r,d.a,d.d,d.c)}break A}f=g instanceof A.am
d=f?g:c0
if(f){j=p.a1(d.r)
if(j!=null){f=j.b
c=j.aF(d.w)
c=c==null?c0:c.b
if(c==null)c=""
c8.$8$code$supplier(c2,f+" \u2014 "+c,c3,d.gb8(),j.r,j.a,j.d,j.c)}break A}f=g instanceof A.ao
b=f?g:c0
if(f){d=p.a9(b.e)
if(d!=null)c8.$8$code$supplier("bom.valves",d.b,c3,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.b6
a=f?g:c0
if(f){d=p.a9(a.e)
if(d!=null)c8.$8$code$supplier("bom.devices",d.b,c3,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.bA
a0=f?g:c0
if(f){d=p.av(a0.e)
if(d!=null)c8.$8$code$supplier("bom.pumps",d.b,c3,1,d.Q,d.a,d.d,d.c)
break A}f=g instanceof A.ba
a0=f?g:c0
if(f){a1=h.i(0,a0.a)
f=a1==null
a2=f?c0:a1.as
if(a2==null)a2=a0.er().length
a3=a0.c
c=(a3.length!==0?a3:o.$1("tool.pivot"))+" \u2014 "
a4=A.z(a0.z===B.E?o.$1("pivot.kindPivot"):o.$1("pivot.kindLinear"))
a5=a0.x
c8.$6(c4,c+a4+" "+B.b.a2(a5)+" m, "+a2+" "+A.z(o.$1("pivot.towers")),c3,1,a0.id,c0)
c8.$6(c4,c+A.z(o.$1("pivot.towersItem"))+" ("+B.b.a2(a0.as)+" m)",c3,a2,a0.r,c0)
a6=p.R(a0.at)
if(a6!=null)c8.$8$code$supplier(c1,a6.b,"m",a5,a6.Q,a6.a,a6.d,a6.c)
a7=f?c0:a1.gd_()
if(a7==null){f=a0.d
a7=f>0?B.b.a2(a5/f):0}a8=p.a1(a0.e)
f=a7>0
if(f){a4=a8==null
a5=a4?c0:a8.b
a5=A.z(a5==null?o.$1("pivot.sprinklersItem"):a5)
a9=a4?c0:a8.r
if(a9==null)a9=0
b0=a4?c0:a8.a
b1=a4?c0:a8.d
if(b1==null)b1=""
a4=a4?c0:a8.c
if(a4==null)a4=""
c8.$8$code$supplier(c4,c+a5,c3,a7,a9,b0,b1,a4)}b2=p.a9(a0.f)
if(b2!=null&&f)c8.$8$code$supplier(c4,c+b2.b,c3,a7,b2.y,b2.a,b2.d,b2.c)
if(a0.cx>0)c8.$6(c4,c+A.z(o.$1("pivot.endGunItem")),c3,1,0,c0)
break A}break A}}b3=i.z
if(b3!=null){for(r=b3.d,r=new A.J(r,A.k(r).j("J<1,2>")).gq(0);r.l();){g=r.d
b4=p.eu(g.a)
if(b4!=null&&g.b>0)c8.$8$code$supplier(c5,b4.b,"m",g.b,b4.r,b4.a,b4.d,b4.c)}for(s=B.a.gq(s),r=new A.bo(s,t.jg),p=t.f8;r.l();){h=p.a(s.gp())
f=h.c
c8.$6(c5,A.z(f.length!==0?f:o.$1("tool.controller"))+" ("+h.e+" "+A.z(o.$1("elec.stationsShort"))+")",c3,1,h.r,c0)}s=b3.a
if(s.length!==0)c8.$6(c5,o.$1("elec.splice"),c3,2*s.length,0,c0)}s=i.r
B.a.W(s)
B.a.B(s,new A.av(c7,c7.$ti.j("av<2>")))
r=q.b
if(r.k4){b5=A.rh(q,b9.c,b9.gdC(),o)
B.a.B(s,b5.a)
b6=A.K(c6)
for(c6=b5.b,q=c6.length,p=i.f,n=0;n<c6.length;c6.length===q||(0,A.j)(c6),++n){a=c6[n]
b7=A.nM(a.a,a.b,a.c,o)
if(b6.k(0,b7))B.a.k(p,"fitting_missing:"+b7)}}B.a.ak(s,new A.iq())
c6=A.t(s)
b8=new A.A(s,c6.j("q(1)").a(new A.ir(b9)),c6.j("A<1>")).gn(0)
if(b8>0)B.a.k(i.f,"bom_unpriced:"+b8)
c6=t.i
q=B.a.P(s,0,new A.is(),c6)
i.Q=q
i.as=q*A.fK(r.y,r.z)
i.at=B.a.P(i.e,0,new A.it(),c6)
return s}}
A.i_.prototype={
$2(a,b){return A.W(a)+t.cQ.a(b).gei()},
$S:66}
A.i6.prototype={
$1(a){return t.o.a(a).a},
$S:60}
A.ij.prototype={
$0(){return A.d([],t.I)},
$S:56}
A.ii.prototype={
$2(a,b){return A.W(a)+t.G.a(b).w},
$S:42}
A.ik.prototype={
$1(a){return A.fO(t.p.a(a).f/1000,this.b)<=this.a.aC(this.c)+1e-9},
$S:7}
A.hU.prototype={
$2(a,b){var s,r
A.D(a)
t.x.a(b)
s=this.a
r=J.a5(b)
s.e.h(0,a,r.gu(b).a.a)
s=s.f
if(r.gn(b)>1)s.h(0,a,b)
else s.T(0,a)},
$S:39}
A.i0.prototype={
$0(){return A.d([],t.s)},
$S:32}
A.i5.prototype={
$1(a){var s=this.a.d.i(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:9}
A.i4.prototype={
$0(){return A.l(t.N,t.i)},
$S:31}
A.i7.prototype={
$1(a){return t.j5.a(a).b===this.a},
$S:33}
A.hV.prototype={
$1(a){t.G.a(a)
return a.f===this.a.a&&a.d===B.e},
$S:1}
A.hW.prototype={
$2(a,b){var s=t.G
return B.c.N(s.a(a).r,s.a(b).r)},
$S:35}
A.hX.prototype={
$1(a){return this.a.i(0,A.D(a))},
$S:36}
A.hY.prototype={
$1(a){return A.nl(a)==null},
$S:37}
A.hZ.prototype={
$0(){return"e"+this.a.a.r++},
$S:38}
A.ih.prototype={
$1(a){var s=this.a,r=t.v.a(a).a
if(s.c.d.E(r)){s=s.c
r=s.w.v(0,s.d.i(0,r))
s=r}else s=!1
return s},
$S:13}
A.im.prototype={
$1(a){return t.v.a(a).e},
$S:13}
A.io.prototype={
$1(a){var s,r,q,p,o,n,m,l
for(s=this.b,s=new A.au(s,s.r,s.e,A.k(s).j("au<1>")),r=this.c,q=a.c,p=this.a,o=-1/0;s.l();){n=s.d
m=p.aq(n)
l=q.i(0,m==null?"":m)
if(l==null)continue
n=r.i(0,n)
n.toString
o=Math.max(o,n-l.b)}return isFinite(o)?o:0},
$S:30}
A.i3.prototype={
$1(a){var s=this.a.d.i(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:9}
A.i1.prototype={
$4(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this,a2=a1.a,a3=a2.a.i(0,a4)
if(a3==null)return
s=a1.c.i(0,a3)
s.toString
r=A.l(t.N,t.U)
for(q=a1.b,a2=q.ce(a2.b,a4),p=a2.length,o=a1.r.d,n=a1.d,m=a1.f,l=a1.e,k=0,j=0;j<a2.length;a2.length===p||(0,A.j)(a2),++j){i=a2[j]
h=i.a
g=n.i(0,h)
if(g!=null){f=r.X(g,new A.i2())
for(h=l.i(0,g),e=h.length,d=0;d<h.length;h.length===e||(0,A.j)(h),++d){c=h[d]
b=c.a
a=f.i(0,b)
if(a==null)a=0
f.h(0,b,a+q.c8(i,c,m.$1(i)))}}else if(i.d===B.e)k+=q.c2(i,m.$1(i))
else{h=o.i(0,h)
h=h==null?null:h.c
k+=h==null?0:h}}a0=q.c.a.i(0,a4).gaE()+a7-q.c.a.i(0,a3).gaE()
a2=a1.x.i(0,s.a+"|"+a1.y)
a2.toString
s=a6!=null?a6+a0:null
B.a.k(a1.w,new A.dB(a2,r,k,a5+a0,s))},
$S:41}
A.i2.prototype={
$0(){return A.l(t.N,t.i)},
$S:31}
A.iw.prototype={
$2(a,b){return A.W(a)+t.f.a(b).e},
$S:29}
A.iv.prototype={
$0(){var s,r,q,p,o,n=A.d([],t.k)
for(s=this.b,r=s.length,q=this.a,p=this.c,o=0;o<s.length;s.length===r||(0,A.j)(s),++o)n.push(q.cA(s[o],p))
return n},
$S:43}
A.ix.prototype={
$1(a){var s
t.v.a(a)
s=this.a.c.d.i(0,a.a)
s.toString
return s},
$S:44}
A.iy.prototype={
$1(a){var s
A.D(a)
s=this.a.c.ao(a)
return(s==null?null:s.d)===B.e},
$S:45}
A.iz.prototype={
$1(a){return!t.v.a(a).e},
$S:13}
A.iA.prototype={
$2(a,b){var s=t.nN
s.a(a)
s.a(b)
return a.e-a.d>=b.e-b.d?a:b},
$S:46}
A.ia.prototype={
$0(){var s=this.a,r=this.c,q=this.b?s.cY(r):s.aD(r)
s.d.c.h(0,r,q)
return q},
$S:0}
A.ib.prototype={
$0(){var s=this.a,r=this.b,q=s.cz(r)
s.d.d.h(0,r.a,q)
return q},
$S:0}
A.i8.prototype={
$0(){var s,r,q,p=this.a,o=p.bD(),n=B.a.P(o,0,new A.i9(),t.i),m=p.d.e
B.a.W(m)
s=A.d([],t.k)
for(r=o.length,q=0;q<o.length;o.length===r||(0,A.j)(o),++q)s.push(p.cA(o[q],n))
B.a.B(m,s)},
$S:0}
A.i9.prototype={
$2(a,b){return A.W(a)+t.f.a(b).e},
$S:29}
A.ic.prototype={
$0(){if(this.b)this.a.cX()
else this.c.$0()},
$S:0}
A.id.prototype={
$0(){var s,r,q=this.b,p=q.d7()
this.a.a=p
if(p>0){s=q.d
r=s.y
if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.bq()}r.B(0,q.c.z)
s.c.W(0)}},
$S:0}
A.ie.prototype={
$0(){var s=this.a,r=this.b,q=s.ds(r)
s.d.c.h(0,r,q)
return q},
$S:0}
A.ig.prototype={
$0(){this.a.dJ()},
$S:0}
A.il.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h=1/0
for(q=this.b,p=q.length,o=this.a,n=a.c,m=0;m<q.length;q.length===p||(0,A.j)(q),++m){s=q[m]
r=n.i(0,s)
if(r==null)continue
l=h
k=r.a
j=o.c.a.i(0,s)
i=j.Q
j=i==null?j.c-j.e:i
h=Math.min(A.mb(l),k-j)}return isFinite(h)?h:0},
$S:30}
A.iu.prototype={
$2(a,b){var s=this.a,r=a.b,q=s.i(0,r)
if(q==null||a.as>q.a.as)s.h(0,r,new A.m(a,b))},
$S:47}
A.ip.prototype={
$8$code$supplier(a,b,c,d,e,f,g,h){var s=a+"|"+b,r=this.a,q=r.i(0,s)
if(q!=null)q.d+=d
else r.h(0,s,new A.ah(a,b,c,d,e,f,g,h))},
$6(a,b,c,d,e,f){return this.$8$code$supplier(a,b,c,d,e,f,"","")},
$S:48}
A.iq.prototype={
$2(a,b){var s,r=t.q
r.a(a)
r.a(b)
r=a.a
s=b.a
return r===s?B.d.N(a.b,b.b):B.d.N(r,s)},
$S:49}
A.ir.prototype={
$1(a){var s,r
t.q.a(a)
s=a.f
r=!1
if(s!=null)if(a.d>0)if(!(a.e>0)){s=this.a.a.c.a1(s)
s=(s==null?null:s.e)!==B.av}else s=r
else s=r
else s=r
return s},
$S:50}
A.is.prototype={
$2(a,b){A.W(a)
t.q.a(b)
return a+b.d*b.e},
$S:51}
A.it.prototype={
$2(a,b){return A.W(a)+t.ju.a(b).z},
$S:52}
A.cD.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"valve",r.a)
q.h(0,"zone",r.b)
q.h(0,"ctrl",r.c)
q.h(0,"st",r.d)
q.h(0,"route",r.e)
q.h(0,"wire",r.f)
s=r.r
if(s!=null)q.h(0,"sw",s)
s=r.w
if(s!=null)q.h(0,"cw",s)
q.h(0,"v",r.x)
q.h(0,"ok",r.y)
q.h(0,"n",r.z)
return q}}
A.c1.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"ctrl",r.a)
q.h(0,"name",r.b)
q.h(0,"stations",r.c)
q.h(0,"used",r.d)
s=r.e
if(s!=null)q.h(0,"cw",s)
q.h(0,"route",r.f)
q.h(0,"wire",r.r)
q.h(0,"open",r.w)
q.h(0,"amps",r.x)
return q}}
A.dk.prototype={
m(){var s,r=this,q=r.a,p=A.t(q),o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.iC()),o),o.j("w.E"))
p=r.b
o=A.t(p)
s=o.j("u<1,i<c,@>>")
p=A.p(new A.u(p,o.j("i<c,@>(1)").a(new A.iD()),s),s.j("w.E"))
return A.X(["runs",q,"ctrls",p,"warn",r.c,"meters",r.d],t.N,t.z)}}
A.iC.prototype={
$1(a){return t.ct.a(a).m()},
$S:53}
A.iD.prototype={
$1(a){return t.l0.a(a).m()},
$S:54}
A.dV.prototype={
gn(a){return this.c}}
A.k4.prototype={
bh(a){var s=this.a
return new A.m(B.b.I(a.a/s),B.b.I(a.b/s))},
bF(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.bh(a),d=e.a,c=e.b,b=f.a
for(s=f.b,r=a.a,q=a.b,p=f.d,o=null,n=-1;n<=1;++n)for(m=d+n,l=-1;l<=1;++l){k=p.i(0,new A.m(m,c+l))
k=J.a0(k==null?B.bo:k)
while(k.l()){j=k.gp()
if(j>>>0!==j||j>=s.length)return A.b(s,j)
i=s[j]
h=i.a-r
i=i.b-q
g=Math.sqrt(h*h+i*i)
if(g<=b){b=g
o=j}}}return o},
cJ(a){var s,r=this,q=r.bF(a)
if(q!=null)return q
s=r.b
B.a.k(s,a)
J.b3(r.d.X(r.bh(a),new A.k8()),s.length-1)
return s.length-1},
bz(a,b,c){var s,r,q
if(a===b)return
s=this.b
r=s.length
if(!(a>=0&&a<r))return A.b(s,a)
q=s[a]
if(!(b>=0&&b<r))return A.b(s,b)
B.a.k(this.c,new A.dV(a,b,q.U(0,s[b]).gn(0),c))},
gbC(){return new A.bF(this.dX(),t.mN)},
dX(){var s=this
return function(){var r=0,q=1,p=[],o,n,m
return function $async$gbC(a,b,c){if(b===1){p.push(c)
r=q}for(;;)switch(r){case 0:o=s.c,n=0
case 2:if(!(n<o.length)){r=4
break}m=o[n]
r=m!=null?5:6
break
case 5:r=7
return a.b=new A.m(n,m),1
case 7:case 6:case 3:++n
r=2
break
case 4:return 0
case 1:return a.c=p.at(-1),3}}}},
cC(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this,d=e.bF(a)
if(d!=null)return d
s=e.a
for(r=e.gbC(),q=r.$ti,r=new A.br(r.a(),q.j("br<1>")),p=e.b,o=a.a,n=a.b,q=q.c,m=null;r.l();){l=r.b
if(l==null)l=q.a(l)
k=l.a
j=l.b
l=j.a
i=p.length
if(!(l>=0&&l<i))return A.b(p,l)
l=p[l]
h=j.b
if(!(h>=0&&h<i))return A.b(p,h)
h=A.kU(a,l,p[h]).a
l=o-h.a
h=n-h.b
g=Math.sqrt(l*l+h*h)
if(g<=s){s=g
m=k}}if(m==null)return null
r=e.c
if(m>>>0!==m||m>=r.length)return A.b(r,m)
q=r[m]
q.toString
B.a.h(r,m,null)
B.a.k(p,a)
J.b3(e.d.X(e.bh(a),new A.k7()),p.length-1)
f=p.length-1
p=q.d
e.bz(q.a,f,p)
e.bz(f,q.b,p)
return f},
dI(){var s,r,q,p,o,n=A.l(t.S,t.L)
for(s=this.gbC(),r=s.$ti,s=new A.br(s.a(),r.j("br<1>")),r=r.c;s.l();){q=s.b
if(q==null)q=r.a(q)
p=q.a
o=q.b
J.b3(n.X(o.a,new A.k5()),p)
J.b3(n.X(o.b,new A.k6()),p)}return n},
cW(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f
t.l3.a(b)
s=t.S
r=A.X([a,0],s,t.i)
q=A.l(s,s)
p=A.pi(new A.k9(),null,t.R)
s=p.$ti.c
p.aH(s.a(new A.m(0,a)))
for(o=this.c;n=p.d,m=n==null,!m;){if(m)A.bs(A.ak())
n=p.d=p.bv(n)
l=n.a
k=l.a
j=l.b
n=p.bv(n)
p.d=n
p.T(0,n.a)
n=r.i(0,j)
if(k>(n==null?1/0:n))continue
n=b.i(0,j)
n=J.a0(n==null?B.bo:n)
while(n.l()){m=n.gp()
if(m>>>0!==m||m>=o.length)return A.b(o,m)
i=o[m]
h=i.a
if(j===h)h=i.b
g=k+i.c
f=r.i(0,h)
if(g<(f==null?1/0:f)-1e-12){r.h(0,h,g)
q.h(0,h,m)
p.aH(s.a(new A.m(g,h)))}}}return new A.m(r,q)}}
A.k8.prototype={
$0(){return A.d([],t.t)},
$S:5}
A.k7.prototype={
$0(){return A.d([],t.t)},
$S:5}
A.k5.prototype={
$0(){return A.d([],t.t)},
$S:5}
A.k6.prototype={
$0(){return A.d([],t.t)},
$S:5}
A.k9.prototype={
$2(a,b){var s,r=t.R
r.a(a)
r.a(b)
r=a.a
s=b.a
return r!==s?B.b.N(r,s):B.c.N(a.b,b.b)},
$S:26}
A.jD.prototype={}
A.kW.prototype={
$1(a){return t.hB.a(a).d.length>=2},
$S:57}
A.kX.prototype={
$2(a,b){var s,r=t.kU
r.a(a)
r.a(b)
r=this.a
s=r.i(0,a.a)
s.toString
r=r.i(0,b.a)
r.toString
return B.b.N(s,r)},
$S:58}
A.kY.prototype={
$2(a,b){var s
A.W(a)
A.aI(b)
s=this.a.c
if(!(b>=0&&b<s.length))return A.b(s,b)
return a+s[b].c},
$S:59}
A.kZ.prototype={
$1(a){return t.C.a(a).v(0,this.a.a)},
$S:12}
A.l_.prototype={
$2(a,b){A.aI(a)
t.C.a(b)
return Math.max(a,b.gn(b))},
$S:61}
A.l4.prototype={
$2(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
t.C.a(b)
for(s=e.a,r=s.i(0,a),q=r.length,p=e.c.c,o=e.d,n=e.b,m=n.b,n=n.a,l=0,k=0;k<r.length;r.length===q||(0,A.j)(r),++k){j=r[k]
for(i=b.gq(b),h=0;i.l();){g=i.gp()
f=s.i(0,g)
f.toString
if(B.a.v(f,j))h+=g===a?n:m}if(!(j>=0&&j<p.length))return A.b(p,j)
l+=h*p[j].c*o/1000}return l},
$S:62}
A.l0.prototype={
$1(a){return t.C.a(a).v(0,this.a.a)},
$S:12}
A.l1.prototype={
$1(a){return this.a.$2(this.b.a,t.C.a(a))},
$S:63}
A.l2.prototype={
$1(a){return t.C.a(a).v(0,this.a.a)},
$S:12}
A.l3.prototype={
$1(a){t.C.a(a)
return a.gn(a)},
$S:64}
A.l5.prototype={
$3(a,b,c){var s,r=this,q=r.c.i(0,a)
q.toString
s=r.e.i(0,a)
s.toString
return r.a.f-r.b.a*b.f*q*r.d/1000-s*c.f},
$S:65}
A.dp.prototype={
gcI(){return this.a.b+"|"+B.b.a4(this.b,1)+"|"+B.b.a4(this.c,1)}}
A.iI.prototype={}
A.l9.prototype={
$1(a){return a===B.b.b9(a)?""+B.b.a2(a):B.b.a4(a,1)},
$S:11}
A.lC.prototype={
$4$qty$size2(a,b,c,d){var s=new A.dp(a,b,d),r=this.a,q=r.i(0,s.gcI()),p=s.gcI(),o=q==null?null:q.b
r.h(0,p,new A.m(s,(o==null?0:o)+c))},
$2(a,b){return this.$4$qty$size2(a,b,1,0)},
$3$qty(a,b,c){return this.$4$qty$size2(a,b,c,0)},
$3$size2(a,b,c){return this.$4$qty$size2(a,b,1,c)},
$S:67}
A.lE.prototype={
$1(a){var s,r
t.G.a(a)
s=this.a.ai(a.y)
if(s!=null)return s.e
r=this.b.$1(a)
r=r==null?null:r.e
return r==null?0:r},
$S:9}
A.lB.prototype={
$2(a,b){var s=a.cx,r=a.cy
return a.b===b?r.U(0,s).gcK():s.U(0,r).gcK()},
$S:68}
A.lt.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.e){s=this.a.$1(a)
if(typeof s!=="number")return s.cV()
s=s>0}else s=!1
return s},
$S:1}
A.lu.prototype={
$1(a){return!this.a.v(0,t.G.a(a).f)},
$S:1}
A.lv.prototype={
$1(a){return this.a.v(0,t.G.a(a).f)},
$S:1}
A.lw.prototype={
$1(a){return t.G.a(a).d!==B.e},
$S:1}
A.lD.prototype={
$2(a,b){return this.a.i(0,B.b.a4(a.a,3)+"|"+B.b.a4(a.b,3)+"|"+b.b)},
$S:69}
A.lz.prototype={
$2(a,b){return a!=null&&B.a.Z(a.w,new A.lA(b,this.a))},
$S:70}
A.lA.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.e){s=a.f
s=s!==this.a&&!this.b.v(0,s)}else s=!1
return s},
$S:1}
A.lx.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.ly.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.ls.prototype={
$1(a){var s
A:{if(B.w===a||B.L===a){s="bom.takeoffs"
break A}if(B.n===a){s="bom.risers"
break A}s="bom.fittings"
break A}return s},
$S:71}
A.cw.prototype={
H(){return"LpSense."+this.b}}
A.cv.prototype={}
A.iW.prototype={}
A.cR.prototype={}
A.bN.prototype={
H(){return"LpStatus."+this.b}}
A.lF.prototype={
$2(a,b){var s,r
A.aI(a)
A.W(b)
if(a>=0&&a<this.a){s=this.b
if(!(a>=0&&a<s.length))return A.b(s,a)
r=s[a]
s.$flags&2&&A.ag(s)
s[a]=r+b*this.c}},
$S:72}
A.lH.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=g.a,e=new Float64Array(f)
for(s=g.c,r=g.d,q=r.length,p=a.length,o=g.e,n=o.length,m=g.b,l=0;l<f;++l){if(l<m){if(!(l<p))return A.b(a,l)
k=-a[l]}else k=0
for(j=0;j<s;++j){if(!(j<q))return A.b(r,j)
i=r[j]
if(!(i>=0&&i<p))return A.b(a,i)
i=a[i]
if(!(j<n))return A.b(o,j)
h=o[j]
if(!(l<h.length))return A.b(h,l)
k+=i*h[l]}if(!(l<f))return A.b(e,l)
e[l]=k}return e},
$S:73}
A.lG.prototype={
$2(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a,d=e.length
if(!(a>=0&&a<d))return A.b(e,a)
s=e[a]
r=s.length
if(!(b>=0&&b<r))return A.b(s,b)
q=s[b]
for(p=f.b,o=s.$flags|0,n=0;n<p;++n){if(!(n<r))return A.b(s,n)
m=s[n]
o&2&&A.ag(s)
s[n]=m/q}for(o=f.c,l=0;l<o;++l){if(l===a)continue
if(!(l<d))return A.b(e,l)
m=e[l]
k=m.length
if(!(b<k))return A.b(m,b)
j=m[b]
if(j===0)continue
for(i=m.$flags|0,n=0;n<p;++n){if(!(n<k))return A.b(m,n)
h=m[n]
if(!(n<r))return A.b(s,n)
g=s[n]
i&2&&A.ag(m)
m[n]=h-j*g}}B.a.h(f.d,a,b)},
$S:10}
A.lI.prototype={
$2(b0,b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this
t.nO.a(b1)
s=a9.b
r=s.$1(b0)
for(q=a9.a,p=a9.c,o=a9.f,n=a9.w,m=n.length,l=b0.length,k=a9.r,j=a9.e,i=a9.x,h=a9.d,g=0,f=1/0,e=!1;q.a<p;f=a8){for(d=r.length,c=h,b=-1,a=0;a<j;++a){if(b1.v(0,a))continue
if(!(a<d))return A.b(r,a)
a0=r[a]
if(a0>c){if(e){b=a
break}c=a0
b=a}}if(b<0)return B.N
for(d=k.length,a1=-1,a2=1/0,a3=0;a3<o;++a3){if(!(a3<d))return A.b(k,a3)
a4=k[a3]
a5=a4.length
if(!(b<a5))return A.b(a4,b)
a6=a4[b]
if(a6<=h)continue
if(!(j<a5))return A.b(a4,j)
a7=a4[j]/a6
if(!(a7<a2-1e-12)){a4=!1
if(a7<=a2+1e-12)if(a1>=0){if(!(a3<m))return A.b(n,a3)
a4=n[a3]
if(!(a1<m))return A.b(n,a1)
a4=a4<n[a1]}}else a4=!0
if(a4){a2=a7
a1=a3}}if(a1<0)return B.fr
i.$2(a1,b);++q.a
r=s.$1(b0)
for(d=k.length,a8=0,a3=0;a3<o;++a3){if(!(a3<m))return A.b(n,a3)
a4=n[a3]
if(!(a4>=0&&a4<l))return A.b(b0,a4)
a4=b0[a4]
if(!(a3<d))return A.b(k,a3)
a5=k[a3]
if(!(j<a5.length))return A.b(a5,j)
a8+=a4*a5[j]}if(a8>f-1e-12){++g
if(g>30)e=!0}else{g=0
e=!1}}return B.bu},
$S:75}
A.dC.prototype={}
A.dB.prototype={}
A.eO.prototype={}
A.dA.prototype={}
A.lj.prototype={
$2(a,b){var s
A.D(a)
t.U.a(b)
s=this.a.i(0,a)
if(s==null)return
b.a_(0,new A.li(s,this.b))},
$S:76}
A.li.prototype={
$2(a,b){var s,r,q
A.D(a)
A.W(b)
s=this.a.i(0,a)
if(s!=null){r=this.b
q=r.i(0,s)
r.h(0,s,(q==null?0:q)-b)}},
$S:77}
A.lk.prototype={
$2(a,b){var s=t.ca
s.a(a)
return B.b.N(s.a(b).a.f,a.a.f)},
$S:78}
A.kM.prototype={
$2(a,b){return A.W(a)+t.ca.a(b).b},
$S:79}
A.c4.prototype={
H(){return"GLinkKind."+this.b}}
A.bi.prototype={
gei(){return this.c.af(this.e)*this.d}}
A.b5.prototype={
gaE(){var s=this.Q
return s==null?this.c-this.e:s}}
A.I.prototype={
gn(a){return this.w}}
A.jb.prototype={
ao(a){var s,r,q,p
for(s=this.b,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null}}
A.iZ.prototype={
gba(){var s=this.c
return s===$?this.c=this.a.b.x:s},
gcO(){var s,r=this,q=r.d
if(q===$){s=r.a.dN()
r.d!==$&&A.rn()
r.d=s
q=s}return q},
c6(a){var s=this.gba()*4
return(B.b.I(a.a/s)*73856093^B.b.I(a.b/s)*19349663)>>>0},
aJ(a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=a0.a,e=g.gba(),d=e*4,c=B.b.I(f/d),b=a0.b,a=B.b.I(b/d)
for(d=g.f,s=null,r=1/0,q=-1;q<=1;++q)for(p=(c+q)*73856093,o=-1;o<=1;++o){n=d.i(0,(p^(a+o)*19349663)>>>0)
if(n==null)continue
for(m=J.a0(n);m.l();){l=m.gp()
if(l.d!==a1)continue
k=l.b
j=k.a-f
k=k.b-b
i=Math.sqrt(j*j+k*k)
if(i<=e&&i<r){r=i
s=l}}}f=s==null
if(!f||!a2)return f?$.o5():s
f=g.r++
h=A.lP(g.gcO().b4(a0),"n"+f,a0,a1)
g.e.a.h(0,h.a,h)
J.b3(d.X(g.c6(a0),new A.j0()),h)
return h},
au(a,b){return this.aJ(a,b,!0)},
bA(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8="outlet_spec_missing:",f9=f6.e
f9.Q=f6.gcO()
s=f6.a
r=s.c
s=s.e
q=A.t(s)
p=q.j("A<1>")
o=A.p(new A.A(s,q.j("q(1)").a(new A.j1()),p),p.j("h.E"))
q=t.K
n=A.d([],q)
p=t.N
m=A.l(p,t.V)
for(l=o.length,k=0;k<o.length;o.length===l||(0,A.j)(o),++k)m.h(0,o[k].a,A.d([],q))
j=new A.j7()
i=new A.j9()
h=new A.j8(f6,o,i,j,m)
for(l=s.length,g=t.dr,k=0;k<s.length;s.length===l||(0,A.j)(s),++k){f=s[k]
e=f instanceof A.b7
d=e?f:f7
if(e){h.$2(d.d,A.d([d.e],g))
continue}e=f instanceof A.ct
c=e?f:f7
if(e){h.$2(c.d,A.d([c.e],g))
continue}e=f instanceof A.ao
b=e?f:f7
if(e){h.$2(b.d,B.D)
continue}e=f instanceof A.bA
a=e?f:f7
if(e){h.$2(a.d,A.d([a.w],g))
continue}e=f instanceof A.b6
a0=e?f:f7
if(e){h.$2(a0.d,A.d([a0.f],g))
continue}e=f instanceof A.aH
a1=e?f:f7
if(e){h.$2(a1.d,A.d([B.i],g))
continue}e=f instanceof A.ba
a=e?f:f7
if(e){h.$2(a.w,A.d([B.i],g))
continue}continue}for(l=o.length,k=0;e=o.length,k<e;o.length===l||(0,A.j)(o),++k){f=o[k]
a2=j.$1(f)
e=J.ae(a2)
if(e.gn(a2)<2)continue
a3=f.a
h.$3$exclude(e.gu(a2),A.d([i.$1(f)],g),a3)
h.$3$exclude(e.gF(a2),A.d([i.$1(f)],g),a3)}for(l=t.g,g=t.n,a3=t.i,a4=t.cQ,a5=f9.y,a6=f9.z,k=0;k<o.length;o.length===e||(0,A.j)(o),++k){f=o[k]
a7=i.$1(f)
a8=j.$1(f)
if(J.at(a8)<2){a6.k(0,f.a)
continue}a9=f.a
b0=m.i(0,a9)
b0.toString
a2=A.eN(a8,!0,l)
if(b0.length!==0){b1=A.d([],g)
for(b2=b0.length,b3=0;b3<b0.length;b0.length===b2||(0,A.j)(b0),++b3){a1=b0[b3]
for(b4=a1.a,b5=a1.b,b6=0,b7=1/0,b8=0,b9=1;b9<a2.length;++b9){c0=b9-1
c1=A.kU(a1,a2[c0],a2[b9])
c2=c1.a
c3=c2.a-b4
c4=c2.b-b5
c5=Math.sqrt(c3*c3+c4*c4)
if(c5<b7){c3=a2.length
if(!(c0<c3))return A.b(a2,c0)
c4=a2[c0]
if(!(b9<c3))return A.b(a2,b9)
c3=a2[b9]
c6=c4.a-c3.a
c3=c4.b-c3.b
b8=b6+c1.b*Math.sqrt(c6*c6+c3*c3)
b7=c5}c3=a2.length
if(!(c0<c3))return A.b(a2,c0)
c0=a2[c0]
if(!(b9<c3))return A.b(a2,b9)
c3=a2[b9]
c4=c0.a-c3.a
c3=c0.b-c3.b
b6+=Math.sqrt(c4*c4+c3*c3)}B.a.k(b1,b8)}c7=A.o0(a2,b1)
a2=A.d([J.bZ(B.a.gu(c7))],q)
for(b0=c7.length,b3=0;b3<c7.length;c7.length===b0||(0,A.j)(c7),++b3)B.a.B(a2,J.mp(c7[b3],1))}B.a.B(n,a2)
A:{b0=f instanceof A.aM
a=b0?f:f7
if(b0){c8=r.R(a.f)
c9=a7===B.h?B.j:B.k
b0=c8==null
b2=b0?f7:c8.a
b0=a.r||b0
f6.d6(a9,a2,a7,b0,a.w,b2,c9)
break A}b0=f instanceof A.am
a1=b0?f:f7
if(b0){d0=r.a1(a1.r)
b0=d0==null
d1=b0?f7:d0.aF(a1.w)
if(b0||d1==null){B.a.k(a5,f8+a9)
a6.k(0,a9)
continue}c8=r.R(a1.e)
d2=A.b2(a2)
d3=a1.gb8()
d4=a1.z
d4=d4>0?d4:a1.y
b0=a1.x
d5=f6.cw(d1,b0)
d6=d5.a
d7=d5.b
b2=A.d([],g)
for(b4=a1.y,b9=0;b9<d3;++b9)b2.push(d4+b9*b4)
d8=f6.ca(b2,d2)
d9=A.l(a3,a4)
for(b2=d8.length,b4=d1.c,b5=d1.w,c0=a1.as,c3=d0.x,c4=a1.at,c3=c0+c3+c4,c0=d1.b,b3=0;b3<d8.length;d8.length===b2||(0,A.j)(d8),++b3){c6=d8[b3]
d9.h(0,c6.a,new A.bi(a9,c6.c,b4,c6.b,b0,d6,d7,b5,c3,c0))}b0=c8==null
b2=b0?f7:c8.a
f6.d5(a9,a2,a7,d9,a1.f||b0,c4,0,b2,B.q)
break A}b0=f instanceof A.aG
e0=b0?f:f7
if(b0){c8=r.ai(e0.e)
if(c8==null){B.a.k(a5,"tape_spec_missing:"+a9)
a6.k(0,a9)
continue}d2=A.b2(a2)
b0=c8.r
d3=b0>0?B.b.I(d2/b0):0
b2=A.d([],g)
for(b9=1;b9<=d3;++b9)b2.push(b9*b0)
d8=f6.ca(b2,d2)
b0=c8.z
b2=e0.f
d6=Math.max(b0,b2*(1-c8.at/100))
d7=Math.min(c8.Q,b2*(1+c8.ax/100))
d9=A.l(a3,a4)
for(b0=d8.length,b4=c8.w,b5=c8.y,c0=e0.x,c3=c8.b,b3=0;b3<d8.length;d8.length===b0||(0,A.j)(d8),++b3){c4=d8[b3]
d9.h(0,c4.a,new A.bi(a9,c4.c,b4,c4.b,b2,d6,d7,b5,c0,c3))}b0=c8.a
b2=c8.x
f6.bW(a9,a2,a7,d9,!1,c0,e0.y,b2,f7,b0,B.q)
break A}break A}}for(q=[0,1],m=f9.c,l=f9.d,g=f9.e,k=0;k<2;++k){e1=q[k]
for(e=s.length,a3=e1===0,b3=0;b3<s.length;s.length===e||(0,A.j)(s),++b3){f=s[b3]
a4=f instanceof A.bA
if(a3===(a4||f instanceof A.b6))continue
B:{a9=f instanceof A.b7
d=a9?f:f7
if(a9){d0=r.a1(d.f)
a4=d0==null
d1=a4?f7:d0.aF(d.r)
if(a4||d1==null){B.a.k(a5,f8+f.a)
continue}d3=f6.aJ(d.d,d.e,!1)
if(d3.a.length===0){a6.k(0,f.a)
continue}a4=d.w
e2=f6.cw(d1,a4)
a9=f.a
d3.r.k(0,a9)
B.a.k(d3.f,new A.bi(a9,-1,d1.c,1,a4,e2.a,e2.b,d1.w,d.z+d0.x,d1.b))
break B}a9=f instanceof A.ct
c=a9?f:f7
if(a9){d3=f6.au(c.d,c.e)
d3.r.k(0,f.a)
a4=c.f
if(a4!=null)d3.Q=a4
break B}a9=f instanceof A.ba
a=a9?f:f7
if(a9){d3=f6.aJ(a.w,B.i,!1)
a4=d3.a
if(a4.length===0){a6.k(0,f.a)
continue}a9=f.a
d3.r.k(0,a9)
g.h(0,a9,a4)
break B}a9=f instanceof A.aH
a1=a9?f:f7
if(a9){d3=f6.au(a1.d,B.i)
a4=f.a
d3.r.k(0,a4)
d3.y=!0
d3.z=a4
l.h(0,a4,d3.a)
if(d3.w.length===0)a6.k(0,a4)
break B}a9=f instanceof A.ao
b=a9?f:f7
if(a9){a4=b.d
e3=f6.au(a4,B.i)
e4=f6.au(a4,B.h)
a9=f.a
e3.r.k(0,a9)
e4.r.k(0,a9)
b0=e3.a
b2=e4.a
b4=b.e
f6.aW(new A.I("cv_"+a9,b0,b2,B.X,B.i,a9,0,0,f7,f7,!1,B.j,0,b.x,0,b4,f7,1,a4,a4,0))
m.h(0,a9,new A.m(b0,b2))
if(e4.w.length<=1)B.a.k(a5,"valve_no_zone_pipes:"+a9)
break B}a9={}
a9.a=null
if(a4){a9.a=f
b0=f}else b0=f7
if(a4){c8=r.av(b0.e)
if(c8==null){B.a.k(a5,"pump_spec_missing:"+f.a)
continue}f6.c5(f.a,b0.d,b0.w,new A.j2(a9,f,c8))
break B}a4={}
a4.a=null
a9=f instanceof A.b6
if(a9){a4.a=f
b0=f}else b0=f7
if(a9){c8=r.a9(b0.e)
if(c8==null){B.a.k(a5,"valve_spec_missing:"+f.a)
continue}a9=c8.e
f6.c5(f.a,b0.d,b0.f,new A.j3(a4,f,a9===B.S,c8))
break B}break B}}}for(q=f9.a,e=new A.M(q,q.r,q.e,A.k(q).j("M<2>"));e.l();){a3=e.d
for(a4=a3.w,a9=a4.length,c5=0,k=0;k<a9;++k)c5=Math.max(c5,a4[k].at)
a3.e=c5}for(e=new A.J(m,A.k(m).j("J<1,2>")).gq(0),a3=f9.f,a4=f9.r,a9=t.s;e.l();){e5=e.d
e6=e5.a
e7=e5.b.b
e8=A.K(p)
e9=A.K(p)
f0=A.d([e7],a9)
e8.k(0,e7)
while(b0=f0.length,b0!==0){if(0>=b0)return A.b(f0,-1)
f1=f0.pop()
d3=q.i(0,f1)
b0=d3.x
if(b0!=null&&b0!==e6){f2=A.d([e6,b0],a9)
B.a.a5(f2)
f3="zone_overlap:"+f2[0]+":"+f2[1]
if(!B.a.v(a5,f3))B.a.k(a5,f3)}d3.x=e6
for(b0=d3.w,b2=b0.length,k=0;k<b0.length;b0.length===b2||(0,A.j)(b0),++k){f4=b0[k]
if(f4.d===B.X)continue
if(f4.e!==B.h)continue
e9.k(0,f4.a)
f4.dx=e6
d=f4.b
if(f1===d)d=f4.c
if(e8.k(0,d))B.a.k(f0,d)}}a3.h(0,e6,e8)
a4.h(0,e6,e9)}p=A.p(new A.av(l,A.k(l).j("av<2>")),p)
l=f9.w
l.B(0,p)
for(e=f9.x;a3=p.length,a3!==0;){if(0>=a3)return A.b(p,-1)
f1=p.pop()
for(a3=q.i(0,f1).w,a4=a3.length,k=0;k<a3.length;a3.length===a4||(0,A.j)(a3),++k){f4=a3[k]
if(f4.e!==B.i||f4.d===B.X)continue
e.k(0,f4.a)
d=f4.b
if(f1===d)d=f4.c
if(l.k(0,d))B.a.k(p,d)}}f6.dk()
for(q=s.length,k=0;k<s.length;s.length===q||(0,A.j)(s),++k){f=s[k]
if(!A.oM(f))continue
p=f.a
if(a6.v(0,p))continue
C:{if(f instanceof A.ao){f5=m.i(0,p)
if(!l.v(0,(f5==null?B.hh:f5).a))a6.k(0,p)
break C}e=f instanceof A.aM
if(e)a3=f.e===B.i
else a3=!1
if(a3){if(!f6.bJ(p).Z(0,new A.j4(f6)))a6.k(0,p)
break C}if(e||f instanceof A.am||f instanceof A.aG){if(!f6.bJ(p).Z(0,new A.j5()))a6.k(0,p)
break C}e=f instanceof A.b7
d=e?f:f7
if(e){e=d.d
a3=d.e
d3=f6.aJ(e,a3,!1)
e=d3.a
if(e.length===0)a6.k(0,p)
else if(a3===B.h?d3.x==null:!l.v(0,e))a6.k(0,p)
break C}if(f instanceof A.bA||f instanceof A.b6){if(!f6.bJ(p).Z(0,new A.j6(f6)))a6.k(0,p)
break C}if(f instanceof A.ba){d3=g.i(0,p)
if(d3==null||!l.v(0,d3))a6.k(0,p)
break C}break C}}return f9},
bJ(a){var s=this.e.b,r=A.t(s)
return new A.A(s,r.j("q(1)").a(new A.ja(a)),r.j("A<1>"))},
cw(a,b){var s=a.c.e6(b,a.y,a.x)
return new A.m(Math.max(s.a,a.e),Math.min(s.b,a.f))},
ca(a,b){var s,r,q,p,o,n,m,l,k,j
t.bd.a(a)
s=a.length
if(s===0)return A.d([],t.nV)
r=this.b
q=B.b.an(s/(r===$?this.b=Math.max(2,this.a.b.go):r))
p=A.d([],t.nV)
for(o=0;s=a.length,o<s;o=n){n=o+q
m=Math.min(n,s)
l=m-o
for(k=o,j=0;k<m;++k){if(!(k>=0&&k<s))return A.b(a,k)
j+=a[k]}B.a.k(p,new A.a(Math.min(j/l,b),l,o))}return p},
aW(a){var s=this.e
B.a.k(s.b,a)
s=s.a
B.a.k(s.i(0,a.b).w,a)
B.a.k(s.i(0,a.c).w,a)},
d6(a,b,c,d,e,f,g){var s,r,q,p,o,n,m,l,k,j,i
t.V.a(b)
for(s=a+"_",r=1;r<b.length;++r){q=r-1
p=this.au(b[q],c)
if(!(r<b.length))return A.b(b,r)
o=this.au(b[r],c)
p.r.k(0,a)
o.r.k(0,a)
n=p.a
m=o.a
if(n===m)continue
l=b.length
if(!(q<l))return A.b(b,q)
k=b[q]
if(!(r<l))return A.b(b,r)
l=b[r]
j=k.a-l.a
l=k.b-l.b
i=Math.sqrt(j*j+l*l)
l=b.length
if(!(q<l))return A.b(b,q)
j=b[q]
if(!(r<l))return A.b(b,r)
this.aW(new A.I(s+q,n,m,B.e,c,a,q,i,f,null,d,g,0,e,0,null,null,1,j,b[r],0))}},
bW(a,b,a0,a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.V.a(b)
t.nh.a(a1)
s=A.al([0,A.b2(b)],t.i)
for(r=0,q=1;q<b.length;++q){p=b[q-1]
o=b[q]
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)
s.k(0,r)}s.B(0,new A.aa(a1,A.k(a1).j("aa<1>")))
m=A.p(s,s.$ti.c)
B.a.a5(m)
for(p=m.length,o=a+"_",l=null,k=0,j=0,i=0,h=0;h<m.length;m.length===p||(0,A.j)(m),++h,k=g,l=e){g=m[h]
f=A.lo(b,g)
n=l!=null
e=n&&g-k<this.gba()?l:this.au(f,a0)
e.r.k(0,a)
d=a1.i(0,g)
if(d!=null){B.a.k(e.f,d)
i+=d.d}if(n&&l.a!==e.a){c=j+1
this.aW(new A.I(o+j,l.a,e.a,B.e,a0,a,c-1,g-k,a6,a7,a2,a8,a5*i,a3,0,null,null,1,A.lo(b,k),f,i))
j=c
i=0}}if(a4>0&&l!=null)B.a.k(l.f,new A.bi(a,-2,new A.c3(a4,0,0,0),1,1,0,1/0,0,0,"flush"))},
d5(a,b,c,d,e,f,g,h,i){return this.bW(a,b,c,d,e,f,0,g,h,null,i)},
dk(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=t.N,a=A.l(b,t.i)
for(s=this.a,r=s.e,q=r.length,p=this.e,o=p.a,n=p.d,m=0;m<r.length;r.length===q||(0,A.j)(r),++m){l=r[m]
if(!(l instanceof A.aH))continue
k=n.i(0,l.a)
j=o.i(0,k==null?"":k)
if(j==null)continue
i=j.c+l.y
j.Q=i
a.h(0,j.a,i)}r=A.d([],t.I)
for(q=p.b,n=q.length,p=p.x,s=s.c,m=0;m<q.length;q.length===n||(0,A.j)(q),++m){h=q[m]
k=!1
if(h.d===B.Y)if(p.v(0,h.a)){k=s.av(h.ch)
k=k==null?null:k.f
k=k===!0}if(k)r.push(h)}if(r.length===0||a.a===0)return
s=A.l(b,b)
for(q=a.$ti,n=new A.au(a,a.r,a.e,q.j("au<1>"));n.l();){k=n.d
s.h(0,k,k)}b=A.p(new A.aa(a,q.j("aa<1>")),b)
for(g=0;g<b.length;++g){f=b[g]
for(q=o.i(0,f).w,n=q.length,m=0;m<q.length;q.length===n||(0,A.j)(q),++m){h=q[m]
if(!p.v(0,h.a))continue
e=h.b
if(f===e)e=h.c
if(s.E(e))continue
k=s.i(0,f)
k.toString
s.h(0,e,k)
B.a.k(b,e)}}for(b=r.length,m=0;m<r.length;r.length===b||(0,A.j)(r),++m){h=r[m]
q=h.b
d=s.i(0,q)
if(d==null)continue
for(q=[q,h.c],c=0;c<2;++c){j=o.i(0,q[c])
if(!j.y)j.Q=a.i(0,d)}}},
c5(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this
t.fC.a(a7)
s=a3.aJ(a5,a6,!1)
r=s.a
if(r.length===0){a3.e.z.k(0,a4)
return}s.r.k(0,a4)
q=s.w
p=A.eN(q,!0,t.G)
o=p.length
n=null
if(o>=2){m=a3.dh(a6)
for(l=1/0,k=0;k<p.length;p.length===o||(0,A.j)(p),++k){j=p[k]
i=j.b
h=m.i(0,r===i?j.c:i)
if(h==null)h=1/0
if(h<l){l=h
n=j}}}else if(o===1)n=s.y?null:B.a.gu(p)
g=A.lP(s.c,"n"+a3.r++,a5,a6)
o=a3.e
i=o.a
f=g.a
i.h(0,f,g)
J.b3(a3.f.X(a3.c6(a5),new A.j_()),g)
g.r.k(0,a4)
for(e=p.length,d=g.w,o=o.b,k=0;k<p.length;p.length===e||(0,A.j)(p),++k){j=p[k]
if(j===n)continue
c=B.a.cH(o,j)
b=j.b
a=b===r?f:b
a0=j.c
a1=a0===r?f:a0
a2=new A.I(j.a,a,a1,j.d,j.e,j.f,j.r,j.w,j.x,j.y,j.z,j.Q,j.as,j.at,j.ax,j.ay,j.ch,j.CW,j.cx,j.cy,j.db)
B.a.h(o,c,a2)
B.a.T(q,j)
b=i.i(0,r===b?a0:b).w
B.a.T(b,j)
B.a.k(b,a2)
B.a.k(d,a2)}a3.aW(a7.$2(r,f))},
dh(a){var s,r,q,p,o,n,m,l,k,j,i=A.l(t.N,t.i),h=A.d([],t.s)
if(a===B.i){for(s=this.e,r=s.d,r=new A.M(r,r.r,r.e,A.k(r).j("M<2>"));r.l();){q=r.d
i.h(0,q,0)
B.a.k(h,q)}for(s=s.a,s=new A.M(s,s.r,s.e,A.k(s).j("M<2>"));s.l();){r=s.d
if(r.y&&!i.E(r.a)){r=r.a
i.h(0,r,0)
B.a.k(h,r)}}}else for(s=this.e.c,s=new A.M(s,s.r,s.e,A.k(s).j("M<2>"));s.l();){r=s.d.b
i.h(0,r,0)
B.a.k(h,r)}for(s=this.e.a,p=0;p<h.length;p=o){o=p+1
n=h[p]
for(r=s.i(0,n).w,q=r.length,m=0;m<r.length;r.length===q||(0,A.j)(r),++m){l=r[m]
if(l.d===B.X)continue
k=l.b
if(n===k)k=l.c
if(!i.E(k)){j=i.i(0,n)
j.toString
i.h(0,k,j+1)
B.a.k(h,k)}}}return i}}
A.j0.prototype={
$0(){return A.d([],t.go)},
$S:27}
A.j1.prototype={
$1(a){t.h.a(a)
return a instanceof A.aM||a instanceof A.am||a instanceof A.aG},
$S:81}
A.j7.prototype={
$1(a){return t.Q.a(a).gO()},
$S:82}
A.j9.prototype={
$1(a){var s=A.oL(a)
return s==null?B.h:s},
$S:83}
A.j8.prototype={
$3$exclude(a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this
t.lv.a(a3)
for(s=a1.b,r=s.length,q=a2.a,p=a2.b,o=a1.a,n=a1.e,m=a1.d,l=a1.c,k=0;k<s.length;s.length===r||(0,A.j)(s),++k){j=s[k]
i=j.a
if(i===a4)continue
if(!B.a.v(a3,l.$1(j)))continue
h=m.$1(j)
for(g=J.ae(h),f=1;f<g.gn(h);++f){e=f-1
d=A.kU(a2,g.i(h,e),g.i(h,f))
c=d.a
b=d.b
a=c.a-q
a0=c.b-p
a0=Math.sqrt(a*a+a0*a0)
a=o.gba()
if(a0<=a&&b>1e-9&&b<0.999999999){e=g.i(h,e)
a0=e.a-q
e=e.b-p
if(Math.sqrt(a0*a0+e*e)>a){e=g.i(h,f)
a0=e.a-q
e=e.b-p
a=Math.sqrt(a0*a0+e*e)>a
e=a}else e=!1
if(e){e=n.i(0,i)
e.toString
B.a.k(e,c)}}}}},
$2(a,b){return this.$3$exclude(a,b,null)},
$S:169}
A.j2.prototype={
$2(a,b){var s=this.b.a,r=this.a.a,q=r.d
return A.mD(q,q,!1,0,0,s,a,"pump_"+s,B.Y,0,0,null,this.c.a,r.w,0,0,r.f,null,b,B.j,null)},
$S:24}
A.j3.prototype={
$2(a,b){var s,r=this,q=r.b.a,p=r.c,o=p?B.eQ:B.eP,n=r.a.a,m=r.d
if(p){p=n.r
p=p>0?p:m.z}else p=0
s=n.d
return A.mD(s,s,!1,0,0,q,a,"dev_"+q,o,0,0,null,null,n.f,0,p,1,null,b,B.j,m.a)},
$S:24}
A.j4.prototype={
$1(a){return this.a.e.x.v(0,t.G.a(a).a)},
$S:1}
A.j5.prototype={
$1(a){return t.G.a(a).dx!=null},
$S:1}
A.j6.prototype={
$1(a){t.G.a(a)
return this.a.e.x.v(0,a.a)||a.dx!=null},
$S:1}
A.ja.prototype={
$1(a){return t.G.a(a).f===this.a},
$S:1}
A.j_.prototype={
$0(){return A.d([],t.go)},
$S:27}
A.cx.prototype={
H(){return"PivotKind."+this.b}}
A.jo.prototype={
gcB(){var s=this,r=s.c+s.ax
return s.a===B.E?3.141592653589793*r*r*(B.b.a7(s.db,1,360)/360):r*Math.max(s.d,0)},
gbR(){var s=this.ch
return s<=0?0:this.gcB()*this.ay/1000/(s*3600)},
gcR(){var s=this.e
return s<=0?0:Math.max(1,B.b.I(this.c/s))}}
A.cy.prototype={
m(){var s=this
return A.X(["i",s.a,"d",s.b,"q",s.c,"h",s.d,"dz",s.e],t.N,t.z)}}
A.bO.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"i",r.a)
q.h(0,"r0",r.b)
q.h(0,"r1",r.c)
q.h(0,"n",r.d)
q.h(0,"q",r.e)
q.h(0,"h",r.f)
s=r.r
if(s.length!==0)q.h(0,"noz",s)
return q}}
A.cW.prototype={
gd_(){return B.a.P(this.b,0,new A.jl(),t.S)},
m(){var s,r,q,p=this,o=A.l(t.N,t.z)
o.h(0,"id",p.a)
o.h(0,"name",p.c)
o.h(0,"kind",p.d.b)
o.h(0,"q",p.e)
o.h(0,"qg",p.f)
o.h(0,"hin",p.r)
o.h(0,"hf",p.w)
o.h(0,"dz",p.x)
o.h(0,"hend",p.y)
o.h(0,"hp",p.z)
o.h(0,"hm",p.Q)
o.h(0,"n",p.as)
s=p.at
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.jm()),q),q.j("w.E"))
o.h(0,"towers",s)
o.h(0,"area",p.ax)
o.h(0,"depth",p.ay)
o.h(0,"hours",p.ch)
o.h(0,"iavg",p.CW)
o.h(0,"ipeak",p.cx)
o.h(0,"v",p.cy)
o.h(0,"warn",p.db)
s=p.dx
if(s!=null)o.h(0,"havail",s)
s=p.b
if(s.length!==0){r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.jn()),q),q.j("w.E"))
o.h(0,"spans",s)}return o}}
A.jl.prototype={
$2(a,b){return A.aI(a)+t.fR.a(b).d},
$S:86}
A.jm.prototype={
$1(a){return t.oz.a(a).m()},
$S:87}
A.jn.prototype={
$1(a){return t.fR.a(a).m()},
$S:88}
A.kR.prototype={
$1(a){return 0},
$S:23}
A.ld.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=B.b.a2(a2*10),a0=b.a,a1=a0.i(0,a)
if(a1!=null)return a1
s=b.b
r=-1/0
if(s.a===B.E){q=B.b.a7(s.db,1,360)*3.141592653589793/180
p=Math.max(8,B.b.a2(b.c*q/6.283185307179586))
for(s=b.e,o=b.f,n=o.a,o=o.b,m=b.r,l=q/2,k=q>=6.283185306179586,j=b.d,i=0;i<=p;++i){h=k?0:l
g=j+q*i/p-h
h=s.$1(new A.C(n+a2*Math.cos(g),o+a2*Math.sin(g)))
if(typeof h!=="number")return h.U()
r=Math.max(r,h-m)}}else{o=b.d
n=Math.cos(o)
o=Math.sin(o)
m=-o
s=s.d
p=Math.max(4,B.b.a2(s/25))
for(l=b.f,k=l.a,j=k+n*a2,l=l.b,o=l+o*a2,h=b.e,i=0;i<=p;++i){f=s*i/p
e=m*f
f=n*f
d=h.$1(new A.C(j+e,o+f))
f=h.$1(new A.C(k+e,l+f))
if(typeof d!=="number")return d.U()
if(typeof f!=="number")return A.bG(f)
r=Math.max(r,d-f)}}c=isFinite(r)?Math.max(r,0):0
a0.h(0,a,c)
return c},
$S:23}
A.bl.prototype={
m(){var s,r,q=this,p=A.l(t.N,t.z)
p.h(0,"link",q.a)
p.h(0,"ent",q.b)
p.h(0,"seg",q.c)
s=q.d
r=t.n
p.h(0,"a",A.d([s.a,s.b],r))
s=q.e
p.h(0,"b",A.d([s.a,s.b],r))
p.h(0,"za",q.f)
p.h(0,"zb",q.r)
p.h(0,"len",q.w)
p.h(0,"d",q.x)
s=q.y
if(s!=null)p.h(0,"spec",s)
p.h(0,"name",q.z)
p.h(0,"q",q.Q)
p.h(0,"v",q.as)
p.h(0,"hf",q.at)
p.h(0,"p0",q.ax)
p.h(0,"p1",q.ay)
p.h(0,"pn",q.ch)
s=q.CW
if(s!=null)p.h(0,"zone",s)
if(q.cx)p.h(0,"ov",!0)
return p},
gn(a){return this.w}}
A.aA.prototype={
m(){var s=this,r=s.c
return A.X(["ent",s.a,"i",s.b,"p",A.d([r.a,r.b],t.n),"z",s.d,"h",s.e,"q",s.f,"qn",s.r,"n",s.w,"lo",s.x,"hi",s.y,"label",s.z],t.N,t.z)}}
A.c2.prototype={
m(){var s=this
return A.X(["ent",s.a,"link",s.b,"q",s.c,"hf",s.d,"hp",s.e,"pu",s.f,"pd",s.r,"st",s.w,"z",s.x],t.N,t.z)}}
A.d2.prototype={
gev(){var s=this
return s.w>=s.y-0.000001&&s.x<=s.z+0.000001},
gbK(){var s=this.ax
return s.length===0?null:B.a.M(s,new A.kb())},
geh(){var s=this.ax
return s.length===0?null:B.a.M(s,new A.ka())},
cD(a){var s=this
t.fm.a(a)
return A.m0(s.z,s.y,s.dx,s.c,s.ay,s.e,s.cy,s.fr,s.x,s.w,s.Q,s.ax,s.dy,s.db,s.at,s.r,s.d,s.as,s.CW,s.a,s.f,s.cx,a,s.b)},
m(){var s,r,q=this,p=q.as.m(),o=q.at,n=A.t(o),m=n.j("u<1,i<c,@>>")
o=A.p(new A.u(o,n.j("i<c,@>(1)").a(new A.kc()),m),m.j("w.E"))
n=q.ax
m=A.t(n)
s=m.j("u<1,i<c,@>>")
n=A.p(new A.u(n,m.j("i<c,@>(1)").a(new A.kd()),s),s.j("w.E"))
m=q.ay
s=A.t(m)
r=s.j("u<1,i<c,@>>")
m=A.p(new A.u(m,s.j("i<c,@>(1)").a(new A.ke()),r),r.j("w.E"))
return A.X(["valve",q.a,"name",q.b,"conv",q.c,"q",q.d,"hd",q.e,"hv",q.f,"hreq",q.r,"pmin",q.w,"pmax",q.x,"lo",q.y,"hi",q.z,"pn",q.Q,"uni",p,"pipes",o,"outlets",n,"devices",m,"warn",q.ch,"zv",q.CW,"valveName",q.cx,"n",q.cy,"cost",q.db,"energy",q.dx,"ocu",q.dy,"epp",q.fr],t.N,t.z)}}
A.kb.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e<=b.e?a:b},
$S:22}
A.ka.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e>=b.e?a:b},
$S:22}
A.kc.prototype={
$1(a){return t.h4.a(a).m()},
$S:20}
A.kd.prototype={
$1(a){return t.o.a(a).m()},
$S:92}
A.ke.prototype={
$1(a){return t.n6.a(a).m()},
$S:17}
A.cA.prototype={
m(){var s=this
return A.X(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"z",s.f,"calc",s.r,"dh",s.w,"mh",s.x,"dq",s.y,"mq",s.z],t.N,t.z)}}
A.b_.prototype={
m(){var s=this,r=s.f
return A.X(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"p",A.d([r.a,r.b],t.n)],t.N,t.z)}}
A.bd.prototype={
m(){var s,r,q,p=this,o=p.d,n=A.t(o),m=n.j("u<1,i<c,@>>")
o=A.p(new A.u(o,n.j("i<c,@>(1)").a(new A.jK()),m),m.j("w.E"))
n=p.e
m=A.t(n)
s=m.j("u<1,i<c,@>>")
n=A.p(new A.u(n,m.j("i<c,@>(1)").a(new A.jL()),s),s.j("w.E"))
m=p.f
s=A.t(m)
r=s.j("u<1,i<c,@>>")
m=A.p(new A.u(m,s.j("i<c,@>(1)").a(new A.jM()),r),r.j("w.E"))
s=p.r
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.jN()),q),q.j("w.E"))
return A.X(["id",p.a,"name",p.b,"conv",p.c,"supplies",o,"valves",n,"pipes",m,"devices",s,"warn",p.w,"q",p.x,"dur",p.y,"energy",p.z],t.N,t.z)}}
A.jK.prototype={
$1(a){return t.ep.a(a).m()},
$S:94}
A.jL.prototype={
$1(a){return t.nN.a(a).m()},
$S:95}
A.jM.prototype={
$1(a){return t.h4.a(a).m()},
$S:20}
A.jN.prototype={
$1(a){return t.n6.a(a).m()},
$S:17}
A.ah.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"cat",r.a)
q.h(0,"desc",r.b)
q.h(0,"unit",r.c)
q.h(0,"qty",r.d)
q.h(0,"cost",r.e)
s=r.f
if(s!=null)q.h(0,"spec",s)
s=r.r
if(s.length!==0)q.h(0,"code",s)
s=r.w
if(s.length!==0)q.h(0,"sup",s)
return q}}
A.cp.prototype={
m(){var s=this
return A.X(["valve",s.a,"name",s.b,"q",s.c,"hd",s.d,"hreq",s.e,"n",s.f,"hend",s.r,"vmax",s.w,"vf",s.x,"conv",s.y],t.N,t.z)}}
A.bQ.prototype={
m(){var s=this
return A.X(["ent",s.a,"ctx",s.b,"name",s.c,"v",s.d,"a",s.e,"dh",s.f,"hs",s.r,"pn",s.w,"tc",s.x,"tcrit",s.y],t.N,t.z)}}
A.eq.prototype={
m(){var s,r,q,p=this,o=A.l(t.N,t.z)
o.h(0,"timestamp",p.a.bN())
o.h(0,"method",p.b)
s=p.c
r=A.k(s).j("av<2>")
q=t.P
r=A.lT(new A.av(s,r),r.j("i<c,@>(h.E)").a(new A.hO()),r.j("h.E"),q)
s=A.p(r,A.k(r).j("h.E"))
o.h(0,"zones",s)
s=p.d
if(s.a!==0){r=A.k(s).j("av<2>")
q=A.lT(new A.av(s,r),r.j("i<c,@>(h.E)").a(new A.hP()),r.j("h.E"),q)
s=A.p(q,A.k(q).j("h.E"))
o.h(0,"pivots",s)}s=p.e
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.hQ()),q),q.j("w.E"))
o.h(0,"systemFlows",s)
o.h(0,"messages",p.f)
s=p.r
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.hR()),q),q.j("w.E"))
o.h(0,"bom",s)
s=p.w
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.hS()),q),q.j("w.E"))
o.h(0,"flushing",s)
s=p.x
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.hT()),q),q.j("w.E"))
o.h(0,"surge",s)
s=p.y
s=A.p(s,A.k(s).c)
o.h(0,"unconnected",s)
s=p.z
if(s!=null)o.h(0,"electrical",s.m())
o.h(0,"capital",p.Q)
o.h(0,"annualCapital",p.as)
o.h(0,"annualEnergy",p.at)
return o}}
A.hO.prototype={
$1(a){return t.kV.a(a).m()},
$S:96}
A.hP.prototype={
$1(a){return t.oY.a(a).m()},
$S:97}
A.hQ.prototype={
$1(a){return t.ju.a(a).m()},
$S:98}
A.hR.prototype={
$1(a){return t.q.a(a).m()},
$S:99}
A.hS.prototype={
$1(a){return t.lG.a(a).m()},
$S:100}
A.hT.prototype={
$1(a){return t.eu.a(a).m()},
$S:101}
A.c3.prototype={
af(a){if(a<=0)return 0
return this.a*Math.pow(a,this.b)},
cL(a){if(a<=0||this.c===0)return 0
return this.c*Math.pow(a,this.d)},
ar(a){var s=Math.max(a,0.000001),r=this.b
if(r===0)return 1e-9
return this.a*r*Math.pow(s,r-1)},
e6(a,b,c){var s=this.b
if(s<=0.01)return B.hP
s=1/s
return new A.m(a*Math.pow(1-c,s),a*Math.pow(1+b,s))},
m(){var s=this
return A.X(["k",s.a,"x",s.b,"ra",s.c,"rb",s.d],t.N,t.z)}}
A.lb.prototype={
$2(a,b){return A.W(a)+A.W(b)},
$S:3}
A.lc.prototype={
$2(a,b){return A.W(a)+Math.abs(A.W(b)-this.a)},
$S:3}
A.cq.prototype={
H(){return"FrictionMethod."+this.b}}
A.aK.prototype={
b7(a){var s
if(a===0)return 0
s=this.a*Math.pow(Math.abs(a),this.b)+this.c
return a<0?-s:s},
ar(a){var s=this.b
return Math.max(s*this.a*Math.pow(Math.max(Math.abs(a),1e-9),s-1),1e-9)},
m(){return A.X(["k",this.a,"n",this.b,"c",this.c],t.N,t.z)}}
A.ds.prototype={
H(){return"HNodeKind."+this.b}}
A.by.prototype={}
A.c5.prototype={
H(){return"HLinkKind."+this.b}}
A.cP.prototype={
H(){return"LinkStatus."+this.b}}
A.dr.prototype={
gn(a){return this.f}}
A.jc.prototype={}
A.eY.prototype={}
A.eL.prototype={}
A.cU.prototype={}
A.ew.prototype={
J(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7,f8=this,f9=A.d([],t.s),g0=f8.b,g1=A.k(g0).j("av<2>"),g2=A.p(new A.av(g0,g1),g1.j("h.E"))
g1=t.N
s=A.l(g1,t.S)
for(r=g2.length,q=0,p=0;p<g2.length;g2.length===r||(0,A.j)(g2),++p){o=g2[p]
if(o.b===B.Z){n=q+1
s.h(0,o.a,q)
q=n}}r=A.t(g2)
if(!new A.A(g2,r.j("q(1)").a(new A.iK()),r.j("A<1>")).gq(0).l())B.a.k(f9,"no_fixed_head_node")
r=t.i
m=A.l(g1,r)
for(l=g2.length,p=0;p<g2.length;g2.length===l||(0,A.j)(g2),++p){o=g2[p]
if(o.b===B.a_){k=o.e
if(k==null)k=o.c}else k=o.c+10
m.h(0,o.a,k)}j=A.d([],t.n)
for(l=f8.c,k=l.length,p=0;p<l.length;l.length===k||(0,A.j)(l),++p){i=l[p]
switch(i.d.a){case 0:case 3:case 2:h=i.e
B.a.k(j,3.141592653589793*h*h/4)
break
case 1:h=i.z
if(h!=null){h=isFinite(h.gbM())?h.gbM()/2:0.01
h=Math.max(h,0.0001)}else h=0.01
B.a.k(j,h)
break
case 4:B.a.k(j,0)
break}h=i.d
g=h===B.M
if(g)i.ay=B.x
h=h===B.eR
if(h)i.ay=B.l
if(!h&&!g)i.ay=B.o}k=A.l(g1,r)
for(h=g2.length,p=0;p<g2.length;g2.length===h||(0,A.j)(g2),++p)k.h(0,g2[p].a,0)
f=A.l(g1,t.y)
h=l.length
e=A.bj(h,1,!1,r)
g=l.length
d=A.bj(g,0,!1,r)
r=f8.a.a
b=r===B.bj
r=r===B.ap
a=1
a0=1/0
a1=1
for(;;){if(!(a<=200)){c=!1
break}for(a2=0;a2<l.length;++a2){i=l[a2]
if(!(a2<j.length))return A.b(j,a2)
a3=j[a2]
a4=1e8
switch(i.d.a){case 4:a5=1e8*a3
break
case 0:if(i.ay===B.l)a5=1e8*a3
else{a6=f8.cg(i,a3)
o=r?1.852:2
a7=Math.max(Math.abs(a3),1e-7)
a8=i.x
if(a8>0){a9=i.e
b0=3.141592653589793*a9*a9/4
b1=a8/(19.6133*b0*b0)}else b1=0
b2=o*a6*Math.pow(a7,o-1)+2*b1*a7
if(b&&a7>0.000001)b2+=(f8.cg(i,a7*1.01)-a6)/(a7*0.01)*Math.pow(a7,o)
b3=a6*Math.pow(a7,o)+b1*a7*a7
a4=Math.max(b2,1e-12)
a5=a3<0?-b3:b3}break
case 3:b4=i.Q
if(b4==null)b4=B.I
if(i.ay===B.l)a5=1e8*a3
else{a4=Math.max(b4.ar(a3),1e-9)
a5=b4.b7(a3)}break
case 2:b4=i.Q
a8=i.ay
if(a8===B.l)a5=1e8*a3
else if(a8===B.o){a8=b4!=null
a4=a8?Math.max(b4.ar(a3),1e-9):0.01
a5=a8?b4.b7(a3):0.01*a3}else{a4=1/0
a5=0}break
case 1:b5=i.z
if(b5==null||i.ay===B.l)a5=1e8*a3
else if(a3<=0)a5=1e8*a3
else{b6=b5.gbM()
if(isFinite(b6)&&a3>b6){b7=Math.max(-b5.ar(b6),0.000001)
a5=-b5.bG(b6)+(a3-b6)*b7
a4=b7}else{a4=Math.max(-b5.ar(a3),0.000001)
a5=-b5.bG(a3)}}break
default:a4=null
a5=null}B.a.h(e,a2,a4)
B.a.h(d,a2,a5)}b8=A.ph(q)
for(a8=g2.length,a9=b8.c,b9=a9.length,c0=b8.b,c1=!1,p=0;p<g2.length;g2.length===a8||(0,A.j)(g2),++p){o=g2[p]
c2=o.a
c3=s.i(0,c2)
if(c3==null)continue
c4=o.d
c5=o.f
if(c5!=null&&o.r>0){c6=o.c+o.w
c7=m.i(0,c2)
c7.toString
c8=c7-c6
c9=c8>0
d0=f.i(0,c2)
if(d0!=null&&d0!==c9)c1=!0
f.h(0,c2,c9)
if(!c9){if(c3>>>0!==c3||c3>=c0.length)return A.b(c0,c3)
c7=c0[c3]
d1=c7.i(0,c3)
c7.h(0,c3,(d1==null?0:d1)+1e-12)
if(c3>>>0!==c3||c3>=b9)return A.b(a9,c3)
B.a.h(a9,c3,a9[c3]+1e-12*c6)
k.h(0,c2,0)}else{b5=Math.max(c8,0.000001)
d2=c5.af(b5)*o.r
d3=1/Math.max(c5.ar(b5)*o.r,1e-9)
if(c3>>>0!==c3||c3>=c0.length)return A.b(c0,c3)
c7=c0[c3]
d1=c7.i(0,c3)
if(d1==null)d1=0
c7.h(0,c3,d1+1/d3)
if(c3>>>0!==c3||c3>=b9)return A.b(a9,c3)
B.a.h(a9,c3,a9[c3]+(-d2+b5/d3+c6/d3))
k.h(0,c2,d2)}}if(c3>>>0!==c3||c3>=b9)return A.b(a9,c3)
B.a.h(a9,c3,a9[c3]-c4)}for(a2=0;a2<l.length;++a2){i=l[a2]
a8=i.b
d4=s.i(0,a8)
c2=i.c
d5=s.i(0,c2)
if(i.d===B.M&&i.ay===B.x){a8=g0.i(0,c2).c
if(d5!=null){if(d5>>>0!==d5||d5>=c0.length)return A.b(c0,d5)
c2=c0[d5]
c7=c2.i(0,d5)
c2.h(0,d5,(c7==null?0:c7)+1e8)
if(d5>>>0!==d5||d5>=b9)return A.b(a9,d5)
B.a.h(a9,d5,a9[d5]+1e8*(a8+i.as))
a8=a9[d5]
if(!(a2<j.length))return A.b(j,a2)
B.a.h(a9,d5,a8+j[a2])}if(d4!=null){if(d4>>>0!==d4||d4>=b9)return A.b(a9,d4)
a8=a9[d4]
if(!(a2<j.length))return A.b(j,a2)
B.a.h(a9,d4,a8+-j[a2])}continue}if(!(a2<h))return A.b(e,a2)
d6=1/e[a2]
if(!(a2<j.length))return A.b(j,a2)
a3=j[a2]
if(!(a2<g))return A.b(d,a2)
a5=d[a2]
c7=d4==null
d1=!c7
if(d1){if(d4>>>0!==d4||d4>=c0.length)return A.b(c0,d4)
d7=c0[d4]
d8=d7.i(0,d4)
d7.h(0,d4,(d8==null?0:d8)+d6)
if(d4>>>0!==d4||d4>=b9)return A.b(a9,d4)
B.a.h(a9,d4,a9[d4]+(-a3+a5*d6))
if(d5==null){d7=a9[d4]
c2=m.i(0,c2)
c2.toString
B.a.h(a9,d4,d7+c2*d6)}}c2=d5!=null
if(c2){if(d5>>>0!==d5||d5>=c0.length)return A.b(c0,d5)
d7=c0[d5]
d8=d7.i(0,d5)
d7.h(0,d5,(d8==null?0:d8)+d6)
if(d5>>>0!==d5||d5>=b9)return A.b(a9,d5)
B.a.h(a9,d5,a9[d5]+(a3-a5*d6))
if(c7){c7=a9[d5]
a8=m.i(0,a8)
a8.toString
B.a.h(a9,d5,c7+a8*d6)}}if(d1&&c2){a8=-d6
if(d4>>>0!==d4||d4>=c0.length)return A.b(c0,d4)
c2=c0[d4]
c7=c2.i(0,d5)
c2.h(0,d5,(c7==null?0:c7)+a8)
if(d4!==d5){if(d5>>>0!==d5||d5>=c0.length)return A.b(c0,d5)
c2=c0[d5]
c7=c2.i(0,d4)
c2.h(0,d4,(c7==null?0:c7)+a8)}}}d9=b8.J()
for(a8=g2.length,a9=d9.length,p=0;p<g2.length;g2.length===a8||(0,A.j)(g2),++p){b9=g2[p].a
c3=s.i(0,b9)
if(c3!=null){if(c3>>>0!==c3||c3>=a9)return A.b(d9,c3)
e0=d9[c3]
if(isFinite(e0))m.h(0,b9,e0)}}for(e1=0,e2=0,a2=0;a2<l.length;++a2){i=l[a2]
a8=m.i(0,i.b)
a8.toString
a9=i.c
b9=m.i(0,a9)
b9.toString
if(i.d===B.M&&i.ay===B.x){a8=g0.i(0,a9).d
b9=k.i(0,a9)
b9.toString
e3=a8+b9
for(a8=l.length,b9=j.length,e4=0;e4<a8;++e4){if(e4===a2)continue
e5=l[e4]
if(e5.b===a9){if(!(e4<b9))return A.b(j,e4)
e3+=j[e4]}if(e5.c===a9){if(!(e4<b9))return A.b(j,e4)
e3-=j[e4]}}e6=e3}else{if(!(a2<j.length))return A.b(j,a2)
a9=j[a2]
if(!(a2<g))return A.b(d,a2)
c0=d[a2]
if(!(a2<h))return A.b(e,a2)
e6=a9-a1*(c0-(a8-b9))/e[a2]}if(!isFinite(e6))e6=0
if(!(a2<j.length))return A.b(j,a2)
e1+=Math.abs(e6-j[a2])
e2+=Math.abs(e6)
B.a.h(j,a2,e6)}e7=e2>0?e1/e2:0
if(e1<1e-9)e7=0
for(e8=c1,a2=0;a2<l.length;++a2){i=l[a2]
a8=i.d
if(a8===B.aq&&i.y){a9=m.i(0,i.b)
a9.toString
b9=m.i(0,i.c)
b9.toString
e9=a9-b9
f0=i.ay===B.l
f1=!0
if(!f0){if(!(a2<j.length))return A.b(j,a2)
a9=j[a2]<-0.000001||e9<-0.0001}else a9=!1
if(a9){i.ay=B.l
e8=f1}else if(f0&&e9>0.0001){i.ay=B.o
B.a.h(j,a2,1e-7)
e8=f1}}if(a8===B.M){a8=i.c
f2=g0.i(0,a8).c+i.as
a9=m.i(0,i.b)
a9.toString
a8=m.i(0,a8)
a8.toString
f3=i.ay
switch(f3.a){case 2:if(!(a2<j.length))return A.b(j,a2)
if(j[a2]<-0.000001){i.ay=B.l
a8=B.l}else if(a9<f2-0.0001){i.ay=B.o
a8=B.o}else a8=f3
break
case 0:if(!(a2<j.length))return A.b(j,a2)
if(j[a2]<-0.000001){i.ay=B.l
a8=B.l}else if(a9>f2+0.0001){i.ay=B.x
a8=B.x}else a8=f3
break
case 1:b9=a9>a8+0.0001
if(b9&&a9<f2-0.0001){i.ay=B.o
a8=B.o}else if(b9&&a8<f2-0.0001){i.ay=B.x
a8=B.x}else a8=f3
break
default:a8=f3}if(a8!==f3)e8=!0
if(a8===B.l)B.a.h(j,a2,0)}}if(e7<0.00001&&!e8&&a>1){c=!0
break}if(e7>a0*1.5&&a>3)a1=Math.max(0.3,a1*0.7)
else if(a1<1)a1=Math.min(1,a1*1.2);++a
a0=e7}if(!c)B.a.k(f9,"not_converged")
f4=A.l(g1,t.oX)
for(g0=g2.length,p=0;p<g2.length;g2.length===g0||(0,A.j)(g2),++p){o=g2[p]
r=o.a
k=m.i(0,r)
k.toString
h=o.f
if(h!=null&&o.r>0)h.af(Math.max(k-o.c-o.w,0))
f4.h(0,r,new A.eY(k,k-o.c))}f5=A.l(g1,t.g_)
for(a2=0;a2<l.length;++a2){i=l[a2]
if(!(a2<j.length))return A.b(j,a2)
f6=j[a2]
g0=m.i(0,i.b)
g0.toString
g1=m.i(0,i.c)
g1.toString
f7=i.d===B.bk&&i.z!=null&&f6>0?i.z.bG(f6):0
f5.h(0,i.a,new A.eL(f6,g0-g1,i.ay,f7))}return new A.cU(c,f4,f5)},
cg(a,b){var s,r,q=this.a
switch(q.a.a){case 0:return 10.67*a.f/(Math.pow(a.r,1.852)*Math.pow(a.e,4.871))
case 1:s=a.e
r=3.141592653589793*s*s/4
return A.nI(a.w/s,A.fO(s,Math.max(Math.abs(b),1e-7))*s/q.b)*a.f/(s*2*9.80665*r*r)}}}
A.iK.prototype={
$1(a){return t.b.a(a).b===B.a_},
$S:103}
A.cY.prototype={
bG(a){var s=this,r=s.d,q=a/r
return r*r*(s.a*q*q+s.b*q+s.c)},
ar(a){var s=this.d
return s*(2*this.a*(a/s)+this.b)},
gbM(){var s,r,q,p,o=this,n=o.a
if(n===0){n=o.b
return n<0?-o.c/n*o.d:1/0}s=o.b
r=s*s-4*n*o.c
if(r<0)return 1/0
s=-s
n=2*n
q=t.ee
p=A.p(new A.A(A.d([(s-Math.sqrt(r))/n,(s+Math.sqrt(r))/n],t.n),t.eq.a(new A.jz()),q),q.j("h.E"))
B.a.a5(p)
return p.length===0?1/0:B.a.gu(p)*o.d},
m(){var s=this
return A.X(["a",s.a,"b",s.b,"c",s.c,"w",s.d],t.N,t.z)}}
A.jz.prototype={
$1(a){return A.W(a)>0},
$S:6}
A.jy.prototype={
$1(a){t.aL.a(a)
return a.a>=0&&a.b>=0},
$S:105}
A.jE.prototype={
J(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5={},b6=b4.a
if(b6===0)return B.bp
s=b4.b
r=A.t(s)
q=r.j("u<1,i<f,e>>")
p=A.p(new A.u(s,r.j("i<f,e>(1)").a(new A.jF()),q),q.j("w.E"))
s=t.i
o=A.eN(b4.c,!0,s)
n=A.bj(b6,!1,!1,t.y)
r=t.t
m=A.d([],r)
l=A.d([],t.iT)
q=t.S
k=J.eC(b6,q)
for(j=0;j<b6;++j){if(!(j<p.length))return A.b(p,j)
i=p[j]
i=i.gn(i)
if(!(j<p.length))return A.b(p,j)
k[j]=i-(p[j].E(j)?1:0)}h=A.l(q,t.nO)
for(j=0;j<b6;++j){if(!(j<k.length))return A.b(k,j)
h.X(k[j],new A.jG()).k(0,j)}b5.a=0
g=new A.jH(b5,b4,h,n)
f=new A.jI(b5,h,k)
for(i=t.n,e=0;e<b6;++e){d=g.$0()
if(d<0)break
B.a.h(n,d,!0)
if(d>>>0!==d||d>=p.length)return A.b(p,d)
c=p[d]
b=c.i(0,d)
if(Math.abs(b==null?0:b)<1e-300)c.h(0,d,1e-30)
a=c.i(0,d)
a.toString
a0=A.d([],r)
a1=A.d([],i)
for(a2=c.gaL(),a2=a2.gq(a2);a2.l();){a3=a2.gp()
a4=a3.a
if(a4!==d){if(!(a4>=0&&a4<b6))return A.b(n,a4)
a5=!n[a4]}else a5=!1
if(a5){B.a.k(a0,a4)
B.a.k(a1,a3.b)}}for(a6=0;a6<a0.length;++a6){j=a0[a6]
if(!(a6<a1.length))return A.b(a1,a6)
a7=a1[a6]/a
a2=o.length
if(!(j>=0&&j<a2))return A.b(o,j)
a3=o[j]
if(d>>>0!==d||d>=a2)return A.b(o,d)
B.a.h(o,j,a3-a7*o[d])
if(!(j<p.length))return A.b(p,j)
a8=p[j]
a8.T(0,d)
for(a2=-a7,a9=0;a9<a0.length;++a9){b0=a0[a9]
if(!(a9<a1.length))return A.b(a1,a9)
a3=a1[a9]
a4=a8.i(0,b0)
if(a4==null)a4=0
a8.h(0,b0,a4+a2*a3)}a2=a8.gn(a8)
f.$2(j,a2-(a8.E(j)?1:0))}B.a.k(m,d)
a2=A.l(q,s)
for(a6=0;a6<a0.length;++a6){a3=a0[a6]
if(!(a6<a1.length))return A.b(a1,a6)
a2.h(0,a3,a1[a6])}a2.h(0,d,a)
B.a.k(l,a2)}a6=A.bj(b6,0,!1,s)
for(b1=m.length-1;b1>=0;--b1){if(!(b1<m.length))return A.b(m,b1)
d=m[b1]
if(!(b1<l.length))return A.b(l,b1)
c=l[b1]
if(!(d>=0&&d<o.length))return A.b(o,d)
b2=o[d]
for(s=new A.ap(c,c.r,c.e,A.k(c).j("ap<1,2>"));s.l();){b3=s.d
r=b3.a
if(r!==d){q=b3.b
if(!(r>=0&&r<b6))return A.b(a6,r)
b2-=q*a6[r]}}s=c.i(0,d)
s.toString
B.a.h(a6,d,b2/s)}return a6}}
A.jF.prototype={
$1(a){return A.p0(t.jq.a(a),t.S,t.i)},
$S:106}
A.jG.prototype={
$0(){return A.K(t.S)},
$S:16}
A.jH.prototype={
$0(){var s,r,q,p,o,n,m,l=this
for(s=l.a,r=l.b.a,q=r+1,p=l.c;;){o=p.i(0,s.a)
if(o!=null&&o.ga0(o)){n=o.gu(o)
o.T(0,n)
return n}if(++s.a>q){for(s=l.d,q=s.length,m=0;m<r;++m){if(!(m<q))return A.b(s,m)
if(!s[m])return m}return-1}}},
$S:108}
A.jI.prototype={
$2(a,b){var s,r=this.b,q=this.c
if(!(a>=0&&a<q.length))return A.b(q,a)
s=r.i(0,q[a])
if(s!=null)s.T(0,a)
B.a.h(q,a,b)
r.X(b,new A.jJ()).k(0,a)
r=this.a
if(b<r.a)r.a=b},
$S:10}
A.jJ.prototype={
$0(){return A.K(t.S)},
$S:16}
A.dS.prototype={
m(){var s=this
return A.X(["count",s.a,"mean",s.b,"min",s.c,"max",s.d,"cu",s.e,"du",s.f,"eu",s.r,"us",s.w,"qvar",s.x,"cv",s.y],t.N,t.z)}}
A.k_.prototype={
$1(a){return isFinite(A.W(a))},
$S:6}
A.k0.prototype={
$2(a,b){return A.W(a)+A.W(b)},
$S:3}
A.k1.prototype={
$2(a,b){return A.W(a)+Math.abs(A.W(b)-this.a)},
$S:3}
A.k2.prototype={
$2(a,b){return A.W(a)+A.W(b)},
$S:3}
A.k3.prototype={
$2(a,b){var s
A.W(a)
s=A.W(b)-this.a
return a+s*s},
$S:3}
A.b8.prototype={
H(){return"PipeMaterial."+this.b}}
A.eJ.prototype={
m(){return A.X(["strings",this.a,"tutorial",B.as,"catalog",B.as],t.N,t.z)}}
A.iJ.prototype={
m(){var s=this
return A.X(["zone",s.a,"north",s.b,"e0",s.c,"n0",s.d],t.N,t.z)}}
A.b9.prototype={
H(){return"PipeUsage."+this.b}}
A.L.prototype={
m(){var s,r,q,p=this,o=A.l(t.N,t.z)
o.h(0,"id",p.a)
o.h(0,"name",p.b)
o.h(0,"nominalMm",p.e)
o.h(0,"idMm",p.f)
o.h(0,"material",p.r.b)
o.h(0,"c",p.w)
o.h(0,"roughMm",p.x)
o.h(0,"ratingM",p.y)
o.h(0,"wallMm",p.z)
o.h(0,"cost",p.Q)
s=p.as
r=A.k(s)
q=r.j("co<1,c>")
s=A.p(new A.co(s,r.j("c(1)").a(new A.jk()),q),q.j("h.E"))
o.h(0,"usage",s)
o.h(0,"enabled",p.at)
s=p.c
if(s.length!==0)o.h(0,"sup",s)
s=p.d
if(s.length!==0)o.h(0,"code",s)
return o}}
A.jk.prototype={
$1(a){return t.W.a(a).b},
$S:109}
A.jj.prototype={
$1(a){return A.aj(B.f0,A.D(a),t.W)},
$S:110}
A.bk.prototype={
H(){return"OutletKind."+this.b}}
A.G.prototype={
m(){var s=this
return A.X(["id",s.a,"name",s.b,"curve",s.c.m(),"arc",s.d,"minH",s.e,"maxH",s.f,"defH",s.r,"cv",s.w,"tolB",s.x,"tolA",s.y],t.N,t.z)}}
A.a8.prototype={
aF(a){var s=this.f
if(s.length===0)return null
return B.a.ae(s,new A.jf(a),new A.jg(this))},
m(){var s,r,q,p=this,o=A.l(t.N,t.z)
o.h(0,"id",p.a)
o.h(0,"name",p.b)
o.h(0,"kind",p.e.b)
s=p.f
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.jh()),q),q.j("w.E"))
o.h(0,"nozzles",s)
o.h(0,"cost",p.r)
o.h(0,"inletMm",p.w)
o.h(0,"riser",p.x)
o.h(0,"enabled",p.y)
s=p.c
if(s.length!==0)o.h(0,"sup",s)
s=p.d
if(s.length!==0)o.h(0,"code",s)
return o}}
A.jf.prototype={
$1(a){return t.mP.a(a).a===this.a},
$S:111}
A.jg.prototype={
$0(){return B.a.gu(this.a.f)},
$S:141}
A.jh.prototype={
$1(a){return t.mP.a(a).m()},
$S:113}
A.je.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j=null,i=t.P
i.a(a)
s=A.D(a.i(0,"id"))
r=A.D(a.i(0,"name"))
i=A.mC(i.a(a.i(0,"curve")))
q=A.y(a.i(0,"arc"))
if(q==null)q=j
if(q==null)q=360
p=A.y(a.i(0,"minH"))
if(p==null)p=j
if(p==null)p=5
o=A.y(a.i(0,"maxH"))
if(o==null)o=j
if(o==null)o=60
n=A.y(a.i(0,"defH"))
if(n==null)n=j
if(n==null)n=20
m=A.y(a.i(0,"cv"))
if(m==null)m=j
if(m==null)m=0.03
l=A.y(a.i(0,"tolB"))
if(l==null)l=j
if(l==null)l=0.05
k=A.y(a.i(0,"tolA"))
if(k==null)k=j
return new A.G(s,r,i,q,p,o,n,m,l,k==null?0.05:k)},
$S:114}
A.aZ.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"id",r.a)
q.h(0,"name",r.b)
q.h(0,"nominalMm",r.e)
q.h(0,"idMm",r.f)
q.h(0,"spacing",r.r)
q.h(0,"emitter",r.w.m())
q.h(0,"barbK",r.x)
q.h(0,"cv",r.y)
q.h(0,"minH",r.z)
q.h(0,"maxH",r.Q)
q.h(0,"inletH",r.as)
q.h(0,"tolB",r.at)
q.h(0,"tolA",r.ax)
q.h(0,"ratingM",r.ay)
q.h(0,"roughMm",r.ch)
q.h(0,"c",r.CW)
q.h(0,"cost",r.cx)
q.h(0,"enabled",r.cy)
s=r.c
if(s.length!==0)q.h(0,"sup",s)
s=r.d
if(s.length!==0)q.h(0,"code",s)
return q}}
A.aO.prototype={
H(){return"ValveKind."+this.b}}
A.F.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"id",r.a)
q.h(0,"name",r.b)
q.h(0,"kind",r.e.b)
q.h(0,"sizeMm",r.f)
q.h(0,"loss",r.r.m())
q.h(0,"minQ",r.w)
q.h(0,"maxQ",r.x)
q.h(0,"cost",r.y)
q.h(0,"setting",r.z)
q.h(0,"enabled",r.Q)
s=r.c
if(s.length!==0)q.h(0,"sup",s)
s=r.d
if(s.length!==0)q.h(0,"code",s)
return q}}
A.aX.prototype={
m(){var s,r,q,p=this,o=A.l(t.N,t.z)
o.h(0,"id",p.a)
o.h(0,"name",p.b)
s=p.r
r=A.t(s)
q=r.j("u<1,r<e>>")
s=A.p(new A.u(s,r.j("r<e>(1)").a(new A.jB()),q),q.j("w.E"))
o.h(0,"points",s)
o.h(0,"eff",p.x)
o.h(0,"minQ",p.y)
o.h(0,"maxQ",p.z)
o.h(0,"cost",p.Q)
o.h(0,"enabled",p.as)
s=p.c
if(s.length!==0)o.h(0,"sup",s)
s=p.d
if(s.length!==0)o.h(0,"code",s)
s=p.e
if(s>0)o.h(0,"kw",s)
o.h(0,"sub",p.f)
return o}}
A.jB.prototype={
$1(a){t.aL.a(a)
return A.d([a.a,a.b],t.n)},
$S:115}
A.jA.prototype={
$1(a){var s=J.ae(a)
return new A.m(A.az(s.i(a,0)),A.az(s.i(a,1)))},
$S:116}
A.ac.prototype={
H(){return"FittingKind."+this.b}}
A.a1.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"id",r.a)
q.h(0,"name",r.b)
q.h(0,"kind",r.e.b)
q.h(0,"sizeMm",r.f)
s=r.r
if(s>0)q.h(0,"size2Mm",s)
q.h(0,"cost",r.w)
q.h(0,"enabled",r.x)
s=r.c
if(s.length!==0)q.h(0,"sup",s)
s=r.d
if(s.length!==0)q.h(0,"code",s)
s=r.y
if(s.length!==0)q.h(0,"mat",s)
return q}}
A.Z.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"id",r.a)
q.h(0,"name",r.b)
q.h(0,"mm2",r.e)
q.h(0,"ohm",r.f)
q.h(0,"cost",r.r)
q.h(0,"enabled",r.w)
s=r.c
if(s.length!==0)q.h(0,"sup",s)
s=r.d
if(s.length!==0)q.h(0,"code",s)
return q}}
A.fU.prototype={
eu(a){var s=this.r
s=new A.a9(s,A.t(s).j("a9<1,Z?>"))
s=s.ae(s,new A.hE(a),new A.hF())
return s},
gdZ(){var s=this.r,r=A.t(s),q=r.j("A<1>")
s=A.p(new A.A(s,r.j("q(1)").a(new A.h5()),q),q.j("h.E"))
B.a.ak(s,new A.h6())
return s},
e3(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
for(s=this.f,r=s.length,q=c>0,p=null,o=1/0,n=0;n<r;++n){m=s[n]
if(!m.x||m.e!==a)continue
l=m.f
k=l-b
if(k<-0.5)continue
j=Math.abs(k)
if(q){i=m.r
h=(i>0?i:l)-c
if(h<-0.5)continue
j+=Math.abs(h)}else{g=m.r
if(g>0&&Math.abs(g-l)>0.5)continue}if(j<o){o=j
p=m}}return p},
R(a){var s
if(a==null)s=null
else{s=this.a
s=new A.a9(s,A.t(s).j("a9<1,L?>"))
s=s.ae(s,new A.hg(a),new A.hh())}return s},
a1(a){var s
if(a==null)s=null
else{s=this.b
s=new A.a9(s,A.t(s).j("a9<1,a8?>"))
s=s.ae(s,new A.he(a),new A.hf())}return s},
ai(a){var s
if(a==null)s=null
else{s=this.c
s=new A.a9(s,A.t(s).j("a9<1,aZ?>"))
s=s.ae(s,new A.ht(a),new A.hu())}return s},
a9(a){var s
if(a==null)s=null
else{s=this.d
s=new A.a9(s,A.t(s).j("a9<1,F?>"))
s=s.ae(s,new A.hC(a),new A.hD())}return s},
av(a){var s
if(a==null)s=null
else{s=this.e
s=new A.a9(s,A.t(s).j("a9<1,aX?>"))
s=s.ae(s,new A.hk(a),new A.hl())}return s},
ah(a){var s=this.a,r=A.t(s),q=r.j("A<1>")
s=A.p(new A.A(s,r.j("q(1)").a(new A.hi(a)),q),q.j("h.E"))
B.a.ak(s,new A.hj())
return s},
m(){var s=this,r=A.l(t.N,t.z),q=s.a,p=A.t(q),o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hv()),o),o.j("w.E"))
r.h(0,"pipes",q)
q=s.b
p=A.t(q)
o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hw()),o),o.j("w.E"))
r.h(0,"outlets",q)
q=s.c
p=A.t(q)
o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hx()),o),o.j("w.E"))
r.h(0,"tapes",q)
q=s.d
p=A.t(q)
o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hy()),o),o.j("w.E"))
r.h(0,"valves",q)
q=s.e
p=A.t(q)
o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hz()),o),o.j("w.E"))
r.h(0,"pumps",q)
q=s.f
p=A.t(q)
o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hA()),o),o.j("w.E"))
r.h(0,"fittings",q)
q=s.r
if(q.length!==0){p=A.t(q)
o=p.j("u<1,i<c,@>>")
q=A.p(new A.u(q,p.j("i<c,@>(1)").a(new A.hB()),o),o.j("w.E"))
r.h(0,"wires",q)}return r},
cZ(){var s,r,q,p,o,n,m,l,k,j=new A.hs(),i=new A.hq(),h=this.a,g=A.t(h),f=g.j("A<1>"),e=A.p(new A.A(h,g.j("q(1)").a(new A.hm()),f),f.j("h.E"))
g=A.t(e)
f=g.j("e(1)")
s=i.$1(new A.u(e,f.a(new A.hn(j)),g.j("u<1,e>")))
r=A.l(t.N,t.i)
for(q=h.length,p=g.j("q(1)"),o=g.j("A<1>"),g=g.j("aF<1,e>"),n=0;n<h.length;h.length===q||(0,A.j)(h),++n){m=h[n]
l=m.Q
if(l>0){r.h(0,m.a,l)
continue}l=i.$1(new A.aF(new A.A(e,p.a(new A.ho(m)),o),f.a(new A.hp(j)),g))
k=l==null?s:l
if(k==null)k=0.0001
l=j.$1(m)
if(typeof l!=="number")return A.bG(l)
r.h(0,m.a,k*l)}return r}}
A.hE.prototype={
$1(a){return t.f4.a(a).a===this.a},
$S:117}
A.hF.prototype={
$0(){return null},
$S:2}
A.h5.prototype={
$1(a){t.e.a(a)
return a.w&&a.f>0},
$S:118}
A.h6.prototype={
$2(a,b){var s=t.e
s.a(a)
return B.b.N(s.a(b).f,a.f)},
$S:119}
A.hg.prototype={
$1(a){return t.cV.a(a).a===this.a},
$S:120}
A.hh.prototype={
$0(){return null},
$S:2}
A.he.prototype={
$1(a){return t.h2.a(a).a===this.a},
$S:121}
A.hf.prototype={
$0(){return null},
$S:2}
A.ht.prototype={
$1(a){return t.mv.a(a).a===this.a},
$S:122}
A.hu.prototype={
$0(){return null},
$S:2}
A.hC.prototype={
$1(a){return t.kf.a(a).a===this.a},
$S:123}
A.hD.prototype={
$0(){return null},
$S:2}
A.hk.prototype={
$1(a){return t.gL.a(a).a===this.a},
$S:124}
A.hl.prototype={
$0(){return null},
$S:2}
A.hi.prototype={
$1(a){t.p.a(a)
return a.at&&a.as.v(0,this.a)},
$S:7}
A.hj.prototype={
$2(a,b){var s=t.p
return B.b.N(s.a(a).f,s.a(b).f)},
$S:125}
A.hv.prototype={
$1(a){return t.p.a(a).m()},
$S:126}
A.hw.prototype={
$1(a){return t.fa.a(a).m()},
$S:127}
A.hx.prototype={
$1(a){return t.gs.a(a).m()},
$S:128}
A.hy.prototype={
$1(a){return t.e4.a(a).m()},
$S:129}
A.hz.prototype={
$1(a){return t.dz.a(a).m()},
$S:130}
A.hA.prototype={
$1(a){return t.kN.a(a).m()},
$S:131}
A.hB.prototype={
$1(a){return t.e.a(a).m()},
$S:132}
A.h7.prototype={
$1(a){return A.p6(t.P.a(a))},
$S:133}
A.h8.prototype={
$1(a){return A.p4(t.P.a(a))},
$S:134}
A.h9.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=null,a1=t.P
a1.a(a2)
s=A.D(a2.i(0,"id"))
r=A.D(a2.i(0,"name"))
q=A.x(a2.i(0,"sup"))
if(q==null)q=""
p=A.x(a2.i(0,"code"))
if(p==null)p=""
o=A.y(a2.i(0,"nominalMm"))
if(o==null)o=a0
if(o==null)o=16
n=A.az(a2.i(0,"idMm"))
m=A.az(a2.i(0,"spacing"))
a1=A.mC(a1.a(a2.i(0,"emitter")))
l=A.y(a2.i(0,"barbK"))
if(l==null)l=a0
if(l==null)l=0.4
k=A.y(a2.i(0,"cv"))
if(k==null)k=a0
if(k==null)k=0.03
j=A.y(a2.i(0,"minH"))
if(j==null)j=a0
if(j==null)j=4
i=A.y(a2.i(0,"maxH"))
if(i==null)i=a0
if(i==null)i=15
h=A.y(a2.i(0,"inletH"))
if(h==null)h=a0
if(h==null)h=10
g=A.y(a2.i(0,"tolB"))
if(g==null)g=a0
if(g==null)g=30
f=A.y(a2.i(0,"tolA"))
if(f==null)f=a0
if(f==null)f=20
e=A.y(a2.i(0,"ratingM"))
if(e==null)e=a0
if(e==null)e=25
d=A.y(a2.i(0,"roughMm"))
if(d==null)d=a0
if(d==null)d=0.002
c=A.y(a2.i(0,"c"))
if(c==null)c=a0
if(c==null)c=140
b=A.y(a2.i(0,"cost"))
if(b==null)b=a0
if(b==null)b=0
a=A.V(a2.i(0,"enabled"))
return A.d1(l,p,b,k,h,a1,m,a!==!1,c,s,n,i,j,r,o,e,d,q,f,g)},
$S:135}
A.ha.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e=t.P
e.a(a)
s=A.D(a.i(0,"id"))
r=A.D(a.i(0,"name"))
q=A.x(a.i(0,"sup"))
if(q==null)q=""
p=A.x(a.i(0,"code"))
if(p==null)p=""
o=A.aj(B.fa,A.D(a.i(0,"kind")),t.bn)
n=A.az(a.i(0,"sizeMm"))
e=e.a(a.i(0,"loss"))
m=A.az(e.i(0,"k"))
l=A.y(e.i(0,"n"))
if(l==null)l=f
if(l==null)l=2
e=A.y(e.i(0,"c"))
if(e==null)e=f
if(e==null)e=0
k=A.y(a.i(0,"minQ"))
if(k==null)k=f
if(k==null)k=0
j=A.y(a.i(0,"maxQ"))
if(j==null)j=f
if(j==null)j=1
i=A.y(a.i(0,"cost"))
if(i==null)i=f
if(i==null)i=0
h=A.y(a.i(0,"setting"))
if(h==null)h=f
if(h==null)h=0
g=A.V(a.i(0,"enabled"))
return new A.F(s,r,q,p,o,n,new A.aK(m,l,e),k,j,i,h,g!==!1)},
$S:136}
A.hb.prototype={
$1(a){return A.pe(t.P.a(a))},
$S:137}
A.hc.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j
t.P.a(a)
s=A.D(a.i(0,"id"))
r=A.D(a.i(0,"name"))
q=A.aj(B.fn,A.D(a.i(0,"kind")),t.na)
p=A.az(a.i(0,"sizeMm"))
o=A.y(a.i(0,"size2Mm"))
if(o==null)o=null
if(o==null)o=0
n=A.y(a.i(0,"cost"))
if(n==null)n=null
if(n==null)n=0
m=A.V(a.i(0,"enabled"))
l=A.x(a.i(0,"sup"))
if(l==null)l=""
k=A.x(a.i(0,"code"))
if(k==null)k=""
j=A.x(a.i(0,"mat"))
if(j==null)j=""
return new A.a1(s,r,l,k,q,p,o,n,m!==!1,j)},
$S:138}
A.hd.prototype={
$1(a){var s,r,q,p,o,n,m,l,k=null
t.P.a(a)
s=A.D(a.i(0,"id"))
r=A.D(a.i(0,"name"))
q=A.y(a.i(0,"mm2"))
if(q==null)q=k
if(q==null)q=1.5
p=A.y(a.i(0,"ohm"))
if(p==null)p=k
if(p==null){p=A.y(a.i(0,"mm2"))
if(p==null)p=k
if(p==null)p=1.5
p=p>0?18.1/p:1/0}o=A.y(a.i(0,"cost"))
if(o==null)o=k
if(o==null)o=0
n=A.V(a.i(0,"enabled"))
m=A.x(a.i(0,"sup"))
if(m==null)m=""
l=A.x(a.i(0,"code"))
if(l==null)l=""
return new A.Z(s,r,m,l,q,p,o,n!==!1)},
$S:139}
A.hs.prototype={
$1(a){var s,r=a.f,q=a.z
q=q>0?q:Math.max(0,(a.e-r)/2)
s=r+2*Math.max(q,0.1)
return 0.7853981633974483*(s*s-r*r)},
$S:4}
A.hq.prototype={
$1(a){var s,r,q=t.kk.a(a).bP(0,new A.hr()),p=A.p(q,q.$ti.j("h.E"))
B.a.a5(p)
q=p.length
if(q===0)return null
s=q/2|0
if((q&1)===1){if(!(s<q))return A.b(p,s)
q=p[s]}else{r=s-1
if(!(r>=0&&r<q))return A.b(p,r)
r=p[r]
if(!(s<q))return A.b(p,s)
s=(r+p[s])/2
q=s}return q},
$S:140}
A.hr.prototype={
$1(a){A.W(a)
return isFinite(a)&&a>0},
$S:6}
A.hm.prototype={
$1(a){return t.p.a(a).Q>0},
$S:7}
A.hn.prototype={
$1(a){var s,r
t.p.a(a)
s=a.Q
r=this.a.$1(a)
if(typeof r!=="number")return A.bG(r)
return s/r},
$S:4}
A.ho.prototype={
$1(a){return t.p.a(a).r===this.a.r},
$S:7}
A.hp.prototype={
$1(a){var s,r
t.p.a(a)
s=a.Q
r=this.a.$1(a)
if(typeof r!=="number")return A.bG(r)
return s/r},
$S:4}
A.fW.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.mi(r,b)
s=b
break A}return s},
$S:8}
A.fX.prototype={
$4$radiusM(a,b,c,d){var s=d>0,r=s?0.35:0,q=Math.pow(b,c),p=s?d/Math.pow(b,r):0
s=s?r:0
return new A.c3(a*27777777777777776e-23/q,c,p,s)},
$3(a,b,c){return this.$4$radiusM(a,b,c,0)},
$S:142}
A.fV.prototype={
$2(a,b){return new A.aK(A.rc(b/1000,a),2,0)},
$S:143}
A.h4.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.mi(r,b)
s=b
break A}return s},
$S:8}
A.h3.prototype={
$1(a){return a===B.b.b9(a)?""+B.b.a2(a):A.z(a)},
$S:11}
A.h1.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.mi(r,b)
s=b
break A}return s},
$S:8}
A.fY.prototype={
$1(a){return t.p.a(a).e},
$S:4}
A.h0.prototype={
$1(a){return a===B.b.b9(a)?""+B.b.a2(a):B.b.a4(a,1)},
$S:11}
A.h2.prototype={
$2(a,b){return B.b.b9(a*(0.25+b/40))},
$S:3}
A.fZ.prototype={
$1(a){t.p.a(a)
return a.as.v(0,B.q)||a.e<=50},
$S:7}
A.h_.prototype={
$1(a){return t.p.a(a).e},
$S:4}
A.v.prototype={}
A.aL.prototype={
H(){return"HydraulicScope."+this.b}}
A.O.prototype={
H(){return"EntityType."+this.b}}
A.E.prototype={
D(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"type",r.gC().b)
q.h(0,"id",r.a)
q.h(0,"layer",r.b)
s=r.c
if(s.length!==0)q.h(0,"name",s)
return q}}
A.iG.prototype={
$0(){var s=t.O.a(this.a.i(0,"pts"))
if(s==null)s=[]
s=J.aC(s,new A.iH(),t.g)
s=A.p(s,s.$ti.j("w.E"))
return s},
$S:144}
A.iH.prototype={
$1(a){return A.bm(t.j.a(a))},
$S:145}
A.iF.prototype={
$0(){return A.bm(t.j.a(this.a.i(0,"p")))},
$S:146}
A.iE.prototype={
$2(a,b){var s=A.y(this.a.i(0,a))
if(s==null)s=null
return s==null?b:s},
$1(a){return this.$2(a,0)},
$S:147}
A.bb.prototype={}
A.a4.prototype={
gn(a){return A.b2(this.gO())},
dW(a){var s,r,q,p,o,n,m=this
for(s=a.a,r=a.b,q=1/0,p=1;p<J.at(m.gO());++p){o=A.kU(a,J.dc(m.gO(),p-1),J.dc(m.gO(),p)).a
n=s-o.a
o=r-o.b
q=Math.min(q,Math.sqrt(n*n+o*o))}return J.at(m.gO())===1?J.ml(J.bZ(m.gO()),a).gn(0):q}}
A.kO.prototype={
$1(a){t.g.a(a)
return A.d([a.a,a.b],t.n)},
$S:148}
A.cu.prototype={
gC(){return B.b_},
gn(a){return this.d.U(0,this.e).gn(0)},
m(){var s=A.U(this.D(),t.N,t.z),r=this.d,q=t.n
s.h(0,"a",A.d([r.a,r.b],q))
r=this.e
s.h(0,"b",A.d([r.a,r.b],q))
return s}}
A.cX.prototype={
gn(a){var s,r=this.d,q=A.b2(r)
if(this.e&&J.at(r)>2){s=J.a5(r)
r=J.ml(s.gF(r),t.g.a(s.gu(r))).gn(0)}else r=0
return q+r},
gC(){return B.b0},
m(){var s=A.U(this.D(),t.N,t.z)
s.h(0,"pts",A.bW(this.d))
s.h(0,"closed",this.e)
return s},
gO(){return this.d}}
A.el.prototype={
gC(){return B.b6},
m(){var s=A.U(this.D(),t.N,t.z),r=this.d
s.h(0,"p",A.d([r.a,r.b],t.n))
s.h(0,"r",this.e)
return s}}
A.de.prototype={
gC(){return B.bb},
gn(a){return this.e*Math.abs(this.r)},
ek(){var s,r,q,p,o,n,m=this,l=m.r,k=Math.max(2,B.b.an(32*Math.abs(l)/6.283185307179586)),j=A.d([],t.K)
for(s=m.d,r=m.e,q=m.f,p=s.a,s=s.b,o=0;o<=k;++o){n=q+l*o/k
j.push(new A.C(p+r*Math.cos(n),s+r*Math.sin(n)))}return j},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"r",s.e)
r.h(0,"s",s.f)
r.h(0,"w",s.r)
return r}}
A.d_.prototype={
gC(){return B.bc},
gn(a){return A.b2(A.qL(this.d,this.e,8))},
m(){var s=A.U(this.D(),t.N,t.z)
s.h(0,"pts",A.bW(this.d))
s.h(0,"closed",this.e)
return s},
gO(){return this.d}}
A.ev.prototype={
gC(){return B.bd},
m(){var s=this,r=A.U(s.D(),t.N,t.z)
r.h(0,"pts",A.bW(s.d))
r.h(0,"ang",s.e)
r.h(0,"sp",s.f)
r.h(0,"solid",s.r)
return r},
gO(){return this.d}}
A.aN.prototype={
H(){return"SymbolKind."+this.b}}
A.f7.prototype={
gC(){return B.be},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"kind",s.e.b)
r.h(0,"size",s.f)
r.h(0,"rot",s.r)
return r}}
A.fa.prototype={
gC(){return B.bf},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"text",s.e)
r.h(0,"h",s.f)
r.h(0,"rot",s.r)
return r}}
A.es.prototype={
gC(){return B.bg},
gn(a){return this.d.U(0,this.e).gn(0)},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d,p=t.n
r.h(0,"a",A.d([q.a,q.b],p))
q=s.e
r.h(0,"b",A.d([q.a,q.b],p))
r.h(0,"off",s.f)
return r}}
A.eg.prototype={
gC(){return B.bh},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d,p=t.n
r.h(0,"v",A.d([q.a,q.b],p))
q=s.e
r.h(0,"a",A.d([q.a,q.b],p))
q=s.f
r.h(0,"b",A.d([q.a,q.b],p))
r.h(0,"r",s.r)
return r}}
A.f4.prototype={
gC(){return B.b1},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d,p=t.n
r.h(0,"c",A.d([q.a,q.b],p))
q=s.e
r.h(0,"p",A.d([q.a,q.b],p))
if(s.f)r.h(0,"dia",!0)
return r}}
A.cO.prototype={
gC(){return B.b2},
m(){var s=this,r=A.U(s.D(),t.N,t.z)
r.h(0,"pts",A.bW(s.d))
r.h(0,"text",s.e)
r.h(0,"h",s.f)
return r},
gO(){return this.d}}
A.ex.prototype={
gC(){return B.b3},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"w",s.e)
r.h(0,"h",s.f)
r.h(0,"rot",s.r)
r.h(0,"op",s.w)
r.h(0,"mime",s.x)
q=s.y
if(q!=null){t.fn.j("c_.S").a(q)
r.h(0,"data",B.de.gbE().bB(q))}q=s.z
if(q.length!==0)r.h(0,"src",q)
return r}}
A.cj.prototype={
gC(){return B.b4},
m(){var s=this,r=A.U(s.D(),t.N,t.z)
r.h(0,"pts",A.bW(s.d))
r.h(0,"z",s.e)
if(s.f)r.h(0,"gen",!0)
return r},
gO(){return this.d}}
A.dO.prototype={
gC(){return B.b5},
m(){var s=A.U(this.D(),t.N,t.z),r=this.d
s.h(0,"p",A.d([r.a,r.b],t.n))
s.h(0,"z",this.e)
return s}}
A.aM.prototype={
gC(){return B.ab},
m(){var s,r=this,q=A.U(r.D(),t.N,t.z)
q.h(0,"pts",A.bW(r.d))
q.h(0,"scope",r.e.b)
s=r.f
if(s!=null)q.h(0,"spec",s)
q.h(0,"auto",r.r)
q.h(0,"depth",r.w)
return q},
gO(){return this.d}}
A.am.prototype={
gC(){return B.ac},
gb8(){var s,r=this,q=A.b2(r.d),p=r.z
p=p>0?p:r.y
if(!isFinite(p)||p<0||q<p-1e-9)return 0
s=r.y
if(!(s>0)||!isFinite(s))return 1
return B.b.I((q-p)/s+1e-9)+1},
m(){var s,r=this,q=A.U(r.D(),t.N,t.z)
q.h(0,"pts",A.bW(r.d))
s=r.e
if(s!=null)q.h(0,"spec",s)
q.h(0,"auto",r.f)
q.h(0,"outlet",r.r)
s=r.w
if(s!=null)q.h(0,"nozzle",s)
q.h(0,"head",r.x)
q.h(0,"sp",r.y)
q.h(0,"off",r.z)
q.h(0,"arc",r.Q)
q.h(0,"riser",r.as)
q.h(0,"depth",r.at)
return q},
sO(a){this.d=t.V.a(a)},
gO(){return this.d}}
A.aG.prototype={
gC(){return B.ad},
m(){var s=this,r=A.U(s.D(),t.N,t.z)
r.h(0,"pts",A.bW(s.d))
r.h(0,"spec",s.e)
r.h(0,"inlet",s.f)
r.h(0,"reg",s.r)
r.h(0,"submin",s.w)
r.h(0,"depth",s.x)
r.h(0,"flush",s.y)
return r},
gO(){return this.d}}
A.b7.prototype={
gC(){return B.ae},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"scope",s.e.b)
r.h(0,"outlet",s.f)
q=s.r
if(q!=null)r.h(0,"nozzle",q)
r.h(0,"head",s.w)
r.h(0,"arc",s.x)
r.h(0,"rot",s.y)
r.h(0,"riser",s.z)
q=s.Q
if(q.length!==0)r.h(0,"zone",q)
return r}}
A.ao.prototype={
gC(){return B.af},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.h(0,"spec",q)
r.h(0,"zone",s.f)
r.h(0,"rot",s.r)
q=s.w
if(q!=null)r.h(0,"fixed",q)
r.h(0,"depth",s.x)
return r}}
A.aH.prototype={
gC(){return B.ag},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"calc",s.e)
r.h(0,"dh",s.f)
r.h(0,"mh",s.r)
r.h(0,"dq",s.w)
r.h(0,"mq",s.x)
r.h(0,"wl",s.y)
return r}}
A.bA.prototype={
gC(){return B.ah},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.h(0,"spec",q)
r.h(0,"speed",s.f)
r.h(0,"rot",s.r)
r.h(0,"scope",s.w.b)
return r}}
A.b6.prototype={
gC(){return B.ai},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.h(0,"spec",q)
r.h(0,"scope",s.f.b)
r.h(0,"set",s.r)
r.h(0,"rot",s.w)
return r}}
A.ct.prototype={
gC(){return B.aj},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"scope",s.e.b)
q=s.f
if(q!=null)r.h(0,"z",q)
return r}}
A.ba.prototype={
er(){var s,r,q,p,o,n,m,l=this,k=l.as
if(k<=0)return B.fd
s=Math.max(1,B.b.I(l.x/k))
r=A.d([],t.K)
for(q=l.w,p=l.y*3.141592653589793/180,o=q.a,q=q.b,n=1;n<=s;++n){m=n*k
r.push(new A.C(o+Math.cos(p)*m,q+Math.sin(p)*m))}return r},
gC(){return B.ak},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.w
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"r",s.x)
r.h(0,"ang",s.y)
r.h(0,"kind",s.z.b)
q=s.Q
if(q>0)r.h(0,"travel",q)
r.h(0,"span",s.as)
q=s.at
if(q!=null)r.h(0,"spec",q)
r.h(0,"idmm",s.ax)
r.h(0,"c",s.ay)
r.h(0,"hp",s.ch)
r.h(0,"hend",s.CW)
q=s.cx
if(q>0)r.h(0,"qg",q)
q=s.cy
if(q>0)r.h(0,"hg",q)
r.h(0,"throw",s.db)
r.h(0,"depth",s.dx)
r.h(0,"hours",s.dy)
r.h(0,"ww",s.fr)
r.h(0,"hm",s.fx)
q=s.fy
if(q>0)r.h(0,"imax",q)
q=s.go
if(q!==360)r.h(0,"sector",q)
q=s.id
if(q>0)r.h(0,"cost",q)
q=s.k1
if(q.length!==0)r.h(0,"zone",q)
r.h(0,"ssp",s.d)
q=s.e
if(q!=null)r.h(0,"sspec",q)
q=s.f
if(q!=null)r.h(0,"rspec",q)
q=s.r
if(q>0)r.h(0,"tcost",q)
return r}}
A.cM.prototype={
gC(){return B.b7},
m(){var s,r=this,q=A.U(r.D(),t.N,t.z)
q.h(0,"pts",A.bW(r.d))
q.h(0,"depth",r.e)
q.h(0,"eff",r.f)
q.h(0,"crop",r.r)
s=r.w
if(s>0)q.h(0,"epp",s)
if(r.x)q.h(0,"wb",!0)
q.h(0,"eto",r.y)
q.h(0,"kc",r.z)
q.h(0,"awc",r.Q)
q.h(0,"root",r.as)
q.h(0,"mad",r.at)
s=r.ax
if(s>0)q.h(0,"psp",s)
s=r.ay
if(s>0)q.h(0,"rsp",s)
s=r.ch
if(s!==1)q.h(0,"wf",s)
return q},
gO(){return this.d}}
A.ck.prototype={
gC(){return B.b8},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d
r.h(0,"p",A.d([q.a,q.b],t.n))
r.h(0,"st",s.e)
r.h(0,"v",s.f)
q=s.r
if(q>0)r.h(0,"cost",q)
q=s.w
if(q>0)r.h(0,"sim",q)
return r}}
A.cb.prototype={
gC(){return B.b9},
m(){var s=A.U(this.D(),t.N,t.z)
s.h(0,"pts",A.bW(this.d))
return s},
gO(){return this.d}}
A.eZ.prototype={
gC(){return B.ba},
m(){var s=this,r=A.U(s.D(),t.N,t.z),q=s.d,p=t.n
r.h(0,"p",A.d([q.a,q.b],p))
q=s.e
r.h(0,"e",A.d([q.a,q.b],p))
q=s.f
if(!q.Y(0,B.O))r.h(0,"o",A.d([q.a,q.b],p))
r.h(0,"x",s.r)
return r}}
A.fe.prototype={}
A.fh.prototype={}
A.fi.prototype={}
A.fj.prototype={}
A.fn.prototype={}
A.fq.prototype={}
A.fr.prototype={}
A.ft.prototype={}
A.fu.prototype={}
A.fv.prototype={}
A.fw.prototype={}
A.fx.prototype={}
A.fz.prototype={}
A.fA.prototype={}
A.fB.prototype={}
A.fE.prototype={}
A.fF.prototype={}
A.fG.prototype={}
A.fH.prototype={}
A.fI.prototype={}
A.C.prototype={
ap(a,b){return new A.C(this.a+b.a,this.b+b.b)},
U(a,b){return new A.C(this.a-b.a,this.b-b.b)},
aj(a,b){return new A.C(this.a*b,this.b*b)},
gn(a){var s=this.a,r=this.b
return Math.sqrt(s*s+r*r)},
gcK(){var s=this.gn(0)
return s===0?B.O:new A.C(this.a/s,this.b/s)},
cE(a){return this.a*a.a+this.b*a.b},
m(){return A.X(["x",this.a,"y",this.b],t.N,t.z)},
Y(a,b){if(b==null)return!1
return b instanceof A.C&&b.a===this.a&&b.b===this.b},
gL(a){return A.cV(this.a,this.b,B.f,B.f)},
t(a){return"Pt("+B.b.a4(this.a,3)+", "+B.b.a4(this.b,3)+")"}}
A.ek.prototype={}
A.lK.prototype={
$1(a){A.W(a)
return a>1e-9&&a<A.b2(this.a)-1e-9},
$S:6}
A.lL.prototype={
$1(a){return A.b2(t.V.a(a))>1e-9},
$S:149}
A.kS.prototype={
$1(a){var s,r,q,p=this
if(p.a){s=p.c
return J.dc(p.b,B.c.bc(B.c.bc(a,s)+s,s))}if(a<0){s=p.b
r=J.ae(s)
return r.i(s,0).aj(0,2).U(0,r.i(s,1))}s=p.c
if(a>=s){r=p.b
q=J.ae(r)
return q.i(r,s-1).aj(0,2).U(0,q.i(r,s-2))}return J.dc(p.b,a)},
$S:150}
A.kT.prototype={
$3(a,b,c){return a+Math.pow(b.U(0,c).gn(0),0.5)},
$S:151}
A.aE.prototype={
m(){var s=this
return A.X(["name",s.a,"color",s.b,"visible",s.c,"locked",s.d],t.N,t.z)}}
A.cz.prototype={
H(){return"SizingMethod."+this.b}}
A.hJ.prototype={
m(){var s=this
return A.X(["units",s.a.m(),"method",s.b.b,"temp",s.c,"vZone",s.d,"vMain",s.e,"vLat",s.f,"minorPct",s.r,"minor",s.w,"tol",s.x,"interest",s.y,"term",s.z,"kwh",s.Q,"eff",s.as,"hours",s.at,"zoneHours",s.ax,"trade",s.ay,"latSizes",s.ch,"subSizes",s.CW,"cScale",s.cx,"cOffset",s.cy,"densify",s.db,"currency",s.dx,"currencyCode",s.dy,"sizing",s.fr.b,"mainSizes",s.fx,"epp",s.fy,"maxNodes",s.go,"flushV",s.id,"flushH",s.k1,"surge",s.k2,"closure",s.k3,"fittings",s.k4,"stick",s.ok,"zoneVar",s.p1,"terrain",s.p2.b,"inrushA",s.p3,"holdA",s.p4,"minV",s.R8,"slack",s.RG],t.N,t.z)}}
A.hK.prototype={
$2(a,b){var s=A.y(this.a.i(0,a))
if(s==null)s=null
return s==null?b:s},
$S:152}
A.bc.prototype={
m(){var s=this,r=s.c
r=A.p(r,A.k(r).c)
return A.X(["id",s.a,"name",s.b,"valves",r,"start",s.d,"dur",s.e],t.N,t.z)}}
A.jq.prototype={
m(){var s,r=this,q=A.l(t.N,t.z)
q.h(0,"uid",r.a)
q.h(0,"created",r.b.bN())
s=r.c
if(s!=null)q.h(0,"modified",s.bN())
q.h(0,"name",r.d)
q.h(0,"client",r.e)
q.h(0,"site",r.f)
q.h(0,"designer",r.r)
q.h(0,"notes",r.w)
s=r.x
if(s!=null)q.h(0,"georef",s.m())
return q}}
A.jp.prototype={
ad(a){var s,r,q,p
for(s=this.e,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null},
dN(){var s,r,q,p=this.b,o=A.d([],t.pn),n=new A.f9(p.db,p.p2,o,A.l(t.S,t.L))
for(p=this.e,s=p.length,r=0;r<p.length;p.length===s||(0,A.j)(p),++r){q=p[r]
if(q instanceof A.cj&&!q.f)n.dH(q.d,q.e)
if(q instanceof A.dO){B.a.k(o,new A.bS(q.d,q.e))
n.f=!0}}return n},
m(){var s,r,q,p=this,o=A.l(t.N,t.z)
o.h(0,"format","opencadirrigation")
o.h(0,"version",1)
o.h(0,"meta",p.a.m())
o.h(0,"params",p.b.m())
o.h(0,"catalog",p.c.m())
s=J.aC(p.d,new A.jv(),t.P)
s=A.p(s,s.$ti.j("w.E"))
o.h(0,"layers",s)
s=p.e
r=A.t(s)
q=r.j("i<c,@>(1)").a(new A.jw())
r=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,q,r),r.j("w.E"))
o.h(0,"entities",s)
s=p.f
r=A.t(s)
q=r.j("u<1,i<c,@>>")
s=A.p(new A.u(s,r.j("i<c,@>(1)").a(new A.jx()),q),q.j("w.E"))
o.h(0,"systemFlows",s)
o.h(0,"nextId",p.r)
s=p.w
if(s!=="DRAWING")o.h(0,"currentLayer",s)
return o}}
A.jv.prototype={
$1(a){return t.df.a(a).m()},
$S:153}
A.jw.prototype={
$1(a){return t.h.a(a).m()},
$S:21}
A.jx.prototype={
$1(a){return t.f.a(a).m()},
$S:154}
A.jr.prototype={
$1(a){return A.oO(t.P.a(a))},
$S:155}
A.js.prototype={
$1(a){var s,r,q,p
t.P.a(a)
s=A.D(a.i(0,"name"))
r=A.y(a.i(0,"color"))
r=r==null?null:B.b.a3(r)
if(r==null)r=B.bv.i(0,s)
if(r==null)r=4289773253
q=A.V(a.i(0,"visible"))
p=A.V(a.i(0,"locked"))
return new A.aE(s,r,q!==!1,p===!0)},
$S:156}
A.jt.prototype={
$1(a){t.er.a(a)
return a.length===0?A.mW():a},
$S:157}
A.ju.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.D(a.i(0,"id"))
r=A.D(a.i(0,"name"))
q=t.O.a(a.i(0,"valves"))
if(q==null)q=[]
q=J.ok(q,t.N)
q=q.aw(q)
p=A.y(a.i(0,"start"))
if(p==null)p=null
if(p==null)p=0
o=A.y(a.i(0,"dur"))
if(o==null)o=null
return A.n3(o==null?1:o,s,r,p,q)},
$S:158}
A.lJ.prototype={
$1(a){A.W(a)
return a>0.000001&&a<this.a-0.000001},
$S:6}
A.cB.prototype={
H(){return"TerrainMethod."+this.b}}
A.bS.prototype={}
A.f9.prototype={
gep(){var s,r,q,p,o,n,m,l=this,k=l.r
if(k==null||l.f){s=l.c
r=s.length
q=r>12e3?B.b.an(r/12e3):1
p=A.d([],t.kb)
for(o=0;o<r;o+=q){if(!(o>=0&&o<s.length))return A.b(s,o)
n=s[o]
m=n.a
p.push(new A.a(m.a,m.b,n.b))}k=l.r=A.pq(p)
if(l.f)l.ck()}return k},
dH(a,b){var s,r,q,p,o=this
t.V.a(a)
s=J.ae(a)
if(s.gG(a))return
if(s.gn(a)===1){B.a.k(o.c,new A.bS(t.g.a(s.gu(a)),b))
o.f=!0
return}r=A.b2(a)
q=Math.max(1,B.b.an(r/o.a))
for(s=o.c,p=0;p<=q;++p){B.a.k(s,new A.bS(A.lo(a,r*p/q),b))
o.f=!0}o.f=!0},
ck(){var s,r,q,p,o=this,n=o.d
n.W(0)
s=o.c
if(s.length===0){o.f=!1
return}r=A.t(s)
q=A.ot(new A.u(s,r.j("C(1)").a(new A.jP()),r.j("u<1,C>")))
o.e=Math.max(0.001,Math.max(q.c-q.a,q.d-q.b)/Math.max(1,Math.sqrt(s.length)))
for(p=0;p<s.length;++p){r=s[p].a
J.b3(n.X((B.b.I(r.a/o.e)*73856093^B.b.I(r.b/o.e)*19349663)>>>0,new A.jQ()),p)}o.f=!1},
cF(a,b,c){var s,r=this
if(r.c.length===0)return b
if(r.b===B.aR){s=r.gep().b4(a)
if(s!=null)return s}return r.e7(a,b,c)},
b4(a){return this.cF(a,0,8)},
e7(a8,a9,b0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this,a7=a6.c
if(a7.length===0)return a9
if(a6.f)a6.ck()
s=A.d([],t.ip)
r=a8.a
q=B.b.I(r/a6.e)
p=a8.b
o=B.b.I(p/a6.e)
for(n=a6.d,m=0;m<=64;){for(l=-m,k=m>0,j=l;j<=m;++j)for(i=(q+j)*73856093,h=Math.abs(j)!==m,g=l;g<=m;++g){if(k&&h&&Math.abs(g)!==m)continue
f=n.i(0,(i^(o+g)*19349663)>>>0)
if(f==null)continue
for(e=J.a0(f);e.l();){d=e.gp()
if(d>>>0!==d||d>=a7.length)return A.b(a7,d)
c=a7[d].a
b=c.a-r
c=c.b-p
B.a.k(s,new A.m(Math.sqrt(b*b+c*c),d))}}if(s.length>=b0&&m>=1)break;++m}if(s.length===0)for(a=0;a<a7.length;++a){n=a7[a].a
k=n.a-r
n=n.b-p
B.a.k(s,new A.m(Math.sqrt(k*k+n*n),a))}B.a.ak(s,new A.jR())
a0=A.c9(s,0,A.cI(b0,"count",t.S),t.R).cQ(0)
if(B.a.gu(a0).a<1e-9){r=B.a.gu(a0).b
if(!(r>=0&&r<a7.length))return A.b(a7,r)
return a7[r].b}for(r=a0.length,p=a7.length,a1=0,a2=0,a3=0;a3<r;++a3){n=a0[a3]
a4=n.a
a=n.b
a5=1/(a4*a4)
if(!(a>=0&&a<p))return A.b(a7,a)
a1+=a5*a7[a].b
a2+=a5}return a2===0?a9:a1/a2}}
A.jP.prototype={
$1(a){return t.jH.a(a).a},
$S:160}
A.jQ.prototype={
$0(){return A.d([],t.t)},
$S:5}
A.jR.prototype={
$2(a,b){var s=t.R
return B.b.N(s.a(a).a,s.a(b).a)},
$S:26}
A.ca.prototype={}
A.jS.prototype={
dj(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=b.e
a.W(0)
s=b.d
if(s.length===0)return
r=b.a
b.r=B.a.M(r,B.H)
q=b.b
b.w=B.a.M(q,B.H)
b.f=Math.max(0.000001,Math.max(B.a.M(r,B.m)-b.r,B.a.M(q,B.m)-b.w)/Math.max(4,Math.sqrt(s.length)))
for(p=0;p<s.length;++p){o=s[p]
n=o.a
m=r.length
if(!(n>=0&&n<m))return A.b(r,n)
l=r[n]
k=o.b
if(!(k>=0&&k<m))return A.b(r,k)
j=r[k]
i=o.c
if(!(i>=0&&i<m))return A.b(r,i)
m=r[i]
h=Math.min(l,Math.min(j,m))
g=Math.max(l,Math.max(j,m))
m=q.length
if(!(n<m))return A.b(q,n)
n=q[n]
if(!(k<m))return A.b(q,k)
k=q[k]
if(!(i<m))return A.b(q,i)
i=q[i]
f=Math.min(n,Math.min(k,i))
e=Math.max(n,Math.max(k,i))
for(d=B.b.I((h-b.r)/b.f);d<=B.b.I((g-b.r)/b.f);++d)for(c=B.b.I((f-b.w)/b.f),n=d*73856093;c<=B.b.I((e-b.w)/b.f);++c)J.b3(a.X((n^c*19349663)>>>0,new A.jT()),p)}},
ef(a){var s,r,q,p=this,o=p.d
if(o.length===0)return-1
s=p.e.i(0,(B.b.I((a.a-p.r)/p.f)*73856093^B.b.I((a.b-p.w)/p.f)*19349663)>>>0)
if(s==null)return-1
for(r=J.a0(s);r.l();){q=r.gp()
if(q>>>0!==q||q>=o.length)return A.b(o,q)
if(p.c_(o[q],a)!=null)return q}return-1},
c_(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g=this.a,f=a.a,e=g.length
if(!(f>=0&&f<e))return A.b(g,f)
s=g[f]
r=this.b
q=r.length
if(!(f<q))return A.b(r,f)
p=r[f]
f=a.b
if(!(f>=0&&f<e))return A.b(g,f)
o=g[f]
if(!(f<q))return A.b(r,f)
n=r[f]
f=a.c
if(!(f>=0&&f<e))return A.b(g,f)
m=g[f]
if(!(f<q))return A.b(r,f)
l=r[f]
f=n-l
r=s-m
q=m-o
k=f*r+q*(p-l)
if(Math.abs(k)<1e-18)return null
g=b.a-m
e=b.b-l
j=(f*g+q*e)/k
i=((l-p)*g+r*e)/k
h=1-j-i
if(j<-1e-9||i<-1e-9||h<-1e-9)return null
return new A.a(j,i,h)},
b4(a){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.ef(a)
if(h<0)return null
s=i.d
if(!(h<s.length))return A.b(s,h)
r=s[h]
q=i.c_(r,a)
p=q.a
o=q.b
n=q.c
s=i.c
m=r.a
l=s.length
if(!(m>=0&&m<l))return A.b(s,m)
m=s[m]
k=r.b
if(!(k>=0&&k<l))return A.b(s,k)
k=s[k]
j=r.c
if(!(j>=0&&j<l))return A.b(s,j)
return p*m+o*k+n*s[j]}}
A.jV.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g=this.a,f=a.a,e=g.length
if(!(f>=0&&f<e))return A.b(g,f)
s=g[f]
r=this.b
q=r.length
if(!(f<q))return A.b(r,f)
p=r[f]
f=a.b
if(!(f>=0&&f<e))return A.b(g,f)
o=g[f]
if(!(f<q))return A.b(r,f)
n=r[f]
f=a.c
if(!(f>=0&&f<e))return A.b(g,f)
m=g[f]
if(!(f<q))return A.b(r,f)
l=r[f]
f=n-l
r=l-p
q=p-n
k=2*(s*f+o*r+m*q)
if(Math.abs(k)<1e-18){a.d=s
a.e=p
a.f=1/0
return}j=s*s+p*p
i=o*o+n*n
h=m*m+l*l
g=(j*f+i*r+h*q)/k
a.d=g
f=(j*(m-o)+i*(s-m)+h*(o-s))/k
a.e=f
g=s-g
f=p-f
a.f=g*g+f*f},
$S:161}
A.jU.prototype={
$1(a){var s,r,q,p,o,n=this,m=n.a
if(!(a>=0&&a<m.length))return A.b(m,a)
s=n.c
r=n.d
q=r-1
p=B.c.a7(B.b.I((m[a]-n.b)/s*r),0,q)
m=n.e
if(!(a<m.length))return A.b(m,a)
o=B.c.a7(B.b.I((m[a]-n.f)/s*r),0,q)
m=o*r
return(o&1)===0?m+p:m+(q-p)},
$S:162}
A.jW.prototype={
$2(a,b){var s
A.aI(a)
A.aI(b)
s=this.a
return J.mn(s.$1(a),s.$1(b))},
$S:163}
A.jX.prototype={
$2(a,b){var s=a<b?a*4194304+b:b*4194304+a,r=this.a,q=r.i(0,s)
if(q==null){r.h(0,s,1)
B.a.k(this.b,new A.m(a,b))}else r.h(0,s,q+1)},
$S:10}
A.jT.prototype={
$0(){return A.d([],t.t)},
$S:5}
A.bz.prototype={
H(){return"LengthUnit."+this.b}}
A.bw.prototype={
H(){return"FlowUnit."+this.b}}
A.bP.prototype={
H(){return"PressureUnit."+this.b}}
A.cm.prototype={
H(){return"DiameterUnit."+this.b}}
A.fc.prototype={
m(){var s=this
return A.X(["length",s.a.b,"flow",s.b.b,"pressure",s.c.b,"diameter",s.d.b],t.N,t.z)},
gn(a){return this.a}}
A.lm.prototype={
$1(a){var s=A.nm(a).data
if(s==null||!(typeof s==="string"))return
A.lp(t.P.a(B.aW.dQ(A.D(s),null)),new A.ll(this.a))},
$S:164}
A.ll.prototype={
$1(a){return this.a.postMessage(B.aW.e_(t.P.a(a),null))},
$S:165};(function aliases(){var s=J.c7.prototype
s.d2=s.t
s=A.h.prototype
s.d1=s.bP})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._static_0,p=hunkHelpers._instance_1i,o=hunkHelpers._instance_1u,n=hunkHelpers._instance_0u,m=hunkHelpers.installInstanceTearOff,l=hunkHelpers.installStaticTearOff
s(J,"qf","oX",166)
r(A,"qI","px",14)
r(A,"qJ","py",14)
r(A,"qK","pz",14)
q(A,"nG","qC",0)
p(A.be.prototype,"gaK","v",107)
r(A,"qN","q5",28)
q(A,"qS","qt",168)
var k
o(k=A.er.prototype,"gdC","b_",85)
o(k,"gcf","al",4)
n(k,"gdO","dP",84)
n(k,"gdU","dV",80)
n(k,"gdL","dM",74)
m(A.f9.prototype,"gdY",0,1,null,["$3$fallback$neighbours","$1"],["cF","b4"],159,0,0)
l(A,"rb",2,null,["$1$2","$2"],["nU",function(a,b){return A.nU(a,b,t.H)}],15,0)
l(A,"nS",2,null,["$1$2","$2"],["nT",function(a,b){return A.nT(a,b,t.H)}],15,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.N,null)
q(A.N,[A.lQ,J.eA,A.dK,J.ch,A.h,A.dh,A.T,A.jC,A.aV,A.dD,A.dU,A.dM,A.dm,A.bo,A.a_,A.bf,A.di,A.cF,A.bC,A.aD,A.jY,A.jd,A.dn,A.e6,A.a7,A.iT,A.au,A.M,A.ap,A.eF,A.kA,A.bn,A.fm,A.kF,A.kD,A.ff,A.br,A.bh,A.cE,A.an,A.fg,A.fC,A.eb,A.fs,A.Y,A.H,A.cd,A.bp,A.bE,A.c_,A.ep,A.kk,A.kj,A.ky,A.bH,A.cn,A.fk,A.f_,A.dP,A.kl,A.dq,A.aq,A.aw,A.fD,A.d0,A.iL,A.hL,A.hM,A.cl,A.er,A.cD,A.c1,A.dk,A.dV,A.k4,A.jD,A.dp,A.iI,A.cv,A.iW,A.cR,A.dC,A.dB,A.eO,A.dA,A.bi,A.b5,A.I,A.jb,A.iZ,A.jo,A.cy,A.bO,A.cW,A.bl,A.aA,A.c2,A.d2,A.cA,A.b_,A.bd,A.ah,A.cp,A.bQ,A.eq,A.c3,A.aK,A.by,A.dr,A.jc,A.eY,A.eL,A.cU,A.ew,A.cY,A.jE,A.dS,A.eJ,A.iJ,A.L,A.G,A.a8,A.aZ,A.F,A.aX,A.a1,A.Z,A.fU,A.v,A.E,A.bb,A.a4,A.C,A.ek,A.aE,A.hJ,A.bc,A.jq,A.jp,A.bS,A.f9,A.ca,A.jS,A.fc])
q(J.eA,[J.eD,J.du,J.dw,J.dv,J.dx,J.cr,J.cs])
q(J.dw,[J.c7,J.o,A.cS,A.dG])
q(J.c7,[J.f0,J.cC,J.c6])
r(J.eB,A.dK)
r(J.iP,J.o)
q(J.cr,[J.dt,J.eE])
q(A.h,[A.cc,A.B,A.aF,A.A,A.dL,A.b0,A.dY,A.bF])
q(A.cc,[A.ci,A.ec])
r(A.dX,A.ci)
r(A.dW,A.ec)
r(A.a9,A.dW)
q(A.T,[A.eK,A.bT,A.eG,A.fd,A.f5,A.fl,A.dy,A.ei,A.bu,A.dT,A.fb,A.dQ,A.eo])
q(A.B,[A.w,A.dl,A.aa,A.av,A.J])
q(A.w,[A.dR,A.u,A.bB,A.fp])
r(A.co,A.aF)
r(A.iB,A.dL)
q(A.bf,[A.d4,A.d5,A.cH])
r(A.m,A.d4)
r(A.a,A.d5)
q(A.cH,[A.d6,A.aP])
r(A.aT,A.di)
q(A.bC,[A.dj,A.e2])
r(A.c0,A.dj)
q(A.aD,[A.ez,A.em,A.en,A.f8,A.le,A.lg,A.kg,A.kf,A.kI,A.ku,A.iX,A.hH,A.hI,A.hN,A.lq,A.lr,A.i6,A.ik,A.i5,A.i7,A.hV,A.hX,A.hY,A.ih,A.im,A.io,A.i3,A.i1,A.ix,A.iy,A.iz,A.il,A.ip,A.ir,A.iC,A.iD,A.kW,A.kZ,A.l0,A.l1,A.l2,A.l3,A.l5,A.l9,A.lC,A.lE,A.lt,A.lu,A.lv,A.lw,A.lA,A.lx,A.ly,A.ls,A.lH,A.j1,A.j7,A.j9,A.j8,A.j4,A.j5,A.j6,A.ja,A.jm,A.jn,A.kR,A.ld,A.kc,A.kd,A.ke,A.jK,A.jL,A.jM,A.jN,A.hO,A.hP,A.hQ,A.hR,A.hS,A.hT,A.iK,A.jz,A.jy,A.jF,A.k_,A.jk,A.jj,A.jf,A.jh,A.je,A.jB,A.jA,A.hE,A.h5,A.hg,A.he,A.ht,A.hC,A.hk,A.hi,A.hv,A.hw,A.hx,A.hy,A.hz,A.hA,A.hB,A.h7,A.h8,A.h9,A.ha,A.hb,A.hc,A.hd,A.hs,A.hq,A.hr,A.hm,A.hn,A.ho,A.hp,A.fW,A.fX,A.h4,A.h3,A.h1,A.fY,A.h0,A.fZ,A.h_,A.iH,A.iE,A.kO,A.lK,A.lL,A.kS,A.kT,A.jv,A.jw,A.jx,A.jr,A.js,A.jt,A.ju,A.lJ,A.jP,A.jV,A.jU,A.lm,A.ll])
r(A.bL,A.ez)
r(A.dI,A.bT)
q(A.f8,[A.f6,A.cN])
q(A.a7,[A.bM,A.fo])
q(A.en,[A.iQ,A.lf,A.kJ,A.kQ,A.kv,A.iV,A.iY,A.kz,A.iM,A.i_,A.ii,A.hU,A.hW,A.iw,A.iA,A.i9,A.iu,A.iq,A.is,A.it,A.k9,A.kX,A.kY,A.l_,A.l4,A.lB,A.lD,A.lz,A.lF,A.lG,A.lI,A.lj,A.li,A.lk,A.kM,A.j2,A.j3,A.jl,A.kb,A.ka,A.lb,A.lc,A.jI,A.k0,A.k1,A.k2,A.k3,A.h6,A.hj,A.fV,A.h2,A.hK,A.jR,A.jW,A.jX])
q(A.dG,[A.eP,A.cT])
q(A.cT,[A.dZ,A.e0])
r(A.e_,A.dZ)
r(A.dE,A.e_)
r(A.e1,A.e0)
r(A.dF,A.e1)
q(A.dE,[A.eQ,A.eR])
q(A.dF,[A.eS,A.eT,A.eU,A.eV,A.eW,A.dH,A.eX])
r(A.d7,A.fl)
q(A.em,[A.kh,A.ki,A.kE,A.km,A.kq,A.kp,A.ko,A.kn,A.kt,A.ks,A.kr,A.kC,A.kP,A.ij,A.i0,A.i4,A.hZ,A.i2,A.iv,A.ia,A.ib,A.i8,A.ic,A.id,A.ie,A.ig,A.k8,A.k7,A.k5,A.k6,A.j0,A.j_,A.jG,A.jH,A.jJ,A.jg,A.hF,A.hh,A.hf,A.hu,A.hD,A.hl,A.iG,A.iF,A.jQ,A.jT])
r(A.fy,A.eb)
r(A.be,A.e2)
r(A.bq,A.cd)
r(A.e3,A.bE)
r(A.e4,A.bp)
r(A.e5,A.e4)
r(A.dN,A.e5)
q(A.c_,[A.dg,A.eH])
q(A.ep,[A.fT,A.fS,A.iS,A.iR])
r(A.eI,A.dy)
r(A.kx,A.ky)
q(A.bu,[A.dJ,A.ey])
q(A.fk,[A.bv,A.cw,A.bN,A.c4,A.cx,A.cq,A.ds,A.c5,A.cP,A.b8,A.b9,A.bk,A.aO,A.ac,A.aL,A.O,A.aN,A.cz,A.cB,A.bz,A.bw,A.bP,A.cm])
q(A.E,[A.cu,A.fw,A.el,A.de,A.fz,A.fn,A.fE,A.fG,A.es,A.eg,A.f4,A.fr,A.ex,A.fh,A.fA,A.fv,A.fB,A.fF,A.fu,A.fi,A.fH,A.fx,A.ft,A.fq,A.ba,A.fe,A.fj,A.fI,A.eZ])
r(A.cX,A.fw)
r(A.d_,A.fz)
r(A.ev,A.fn)
r(A.f7,A.fE)
r(A.fa,A.fG)
r(A.cO,A.fr)
r(A.cj,A.fh)
r(A.dO,A.fA)
r(A.aM,A.fv)
r(A.am,A.fB)
r(A.aG,A.fF)
r(A.b7,A.fu)
r(A.ao,A.fi)
r(A.aH,A.fH)
r(A.bA,A.fx)
r(A.b6,A.ft)
r(A.ct,A.fq)
r(A.cM,A.fe)
r(A.ck,A.fj)
r(A.cb,A.fI)
s(A.ec,A.H)
s(A.dZ,A.H)
s(A.e_,A.a_)
s(A.e0,A.H)
s(A.e1,A.a_)
s(A.e4,A.h)
s(A.e5,A.bC)
s(A.fe,A.a4)
s(A.fh,A.a4)
s(A.fi,A.bb)
s(A.fj,A.bb)
s(A.fn,A.a4)
s(A.fq,A.bb)
s(A.fr,A.a4)
s(A.ft,A.bb)
s(A.fu,A.bb)
s(A.fv,A.a4)
s(A.fw,A.a4)
s(A.fx,A.bb)
s(A.fz,A.a4)
s(A.fA,A.bb)
s(A.fB,A.a4)
s(A.fE,A.bb)
s(A.fF,A.a4)
s(A.fG,A.bb)
s(A.fH,A.bb)
s(A.fI,A.a4)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{f:"int",e:"double",aB:"num",c:"String",q:"bool",aw:"Null",r:"List",N:"Object",i:"Map",a3:"JSObject"},mangledNames:{},types:["~()","q(I)","aw()","e(e,e)","e(L)","r<f>()","q(e)","q(L)","c(c,c,c)","e(I)","~(f,f)","c(e)","q(P<c>)","q(aH)","~(~())","0^(0^,0^)<aB>","P<f>()","i<c,@>(c2)","~(N?,N?)","f(c?)","i<c,@>(bl)","i<c,@>(E)","aA(aA,aA)","e(e)","I(c,c)","aw(@)","f(+(e,f),+(e,f))","r<b5>()","@(@)","e(e,bc)","e(cU)","i<c,e>()","r<c>()","q(aq<c,I?>)","@(@,c)","f(I,I)","f?(c)","q(f?)","c()","~(c,r<+(L,e)>)","aw(~())","~(c,e,e?,e)","e(e,I)","r<bd>()","c(aH)","q(c)","b_(b_,b_)","~(bl,c)","~(c,c,c,e,e,c?{code:c,supplier:c})","f(ah,ah)","q(ah)","e(e,ah)","e(e,bd)","i<c,@>(cD)","i<c,@>(c1)","@(c)","r<I>()","q(cb)","f(ao,ao)","e(e,f)","c(aA)","f(f,P<c>)","e(c,P<c>)","e(P<c>)","f(P<c>)","e(c,Z,Z)","e(e,bi)","~(ac,e{qty:e,size2:e})","C(I,c)","b5?(C,aL)","q(b5?,c)","c(ac)","~(f,e)","bJ(bJ)","r<ah>()","bN(bJ,P<f>)","~(c,i<c,e>)","~(c,e)","f(+(L,e),+(L,e))","e(e,+(L,e))","dk?()","q(E)","r<C>(E)","aL(E)","r<bQ>()","L?(I)","f(f,bO)","i<c,@>(cy)","i<c,@>(bO)","~(cl)","c(c)","~(c,c)","i<c,@>(aA)","~(@,@)","i<c,@>(cA)","i<c,@>(b_)","i<c,@>(d2)","i<c,@>(cW)","i<c,@>(bd)","i<c,@>(ah)","i<c,@>(cp)","i<c,@>(bQ)","~(@)","q(by)","aw(@,c8)","q(+(e,e))","i<f,e>(i<f,e>)","q(N?)","f()","c(b9)","b9(@)","q(G)","aw(N,c8)","i<c,@>(G)","G(@)","r<e>(+(e,e))","+(e,e)(@)","q(Z?)","q(Z)","f(Z,Z)","q(L?)","q(a8?)","q(aZ?)","q(F?)","q(aX?)","f(L,L)","i<c,@>(L)","i<c,@>(a8)","i<c,@>(aZ)","i<c,@>(F)","i<c,@>(aX)","i<c,@>(a1)","i<c,@>(Z)","L(@)","a8(@)","aZ(@)","F(@)","aX(@)","a1(@)","Z(@)","e?(h<e>)","G()","c3(e,e,e{radiusM:e})","aK(e,e)","r<C>()","C(@)","C()","e(c[e])","r<e>(C)","q(r<C>)","C(f)","e(e,C,C)","e(c,e)","i<c,@>(aE)","i<c,@>(bc)","E(@)","aE(@)","r<aE>(r<aE>)","bc(@)","e(C{fallback:e,neighbours:f})","C(bS)","~(ca)","f(f)","f(f,f)","aw(a3)","~(i<c,@>)","f(@,@)","~(f,@)","bx<~>()","~(C,h<aL>{exclude:c?})"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.m&&a.b(c.a)&&b.b(c.b),"3;":(a,b,c)=>d=>d instanceof A.a&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;":a=>b=>b instanceof A.d6&&A.nX(a,b.a),"4;run,stage,zoneId,zoneIndex":a=>b=>b instanceof A.aP&&A.nX(a,b.a)}}
A.pX(v.typeUniverse,JSON.parse('{"f0":"c7","cC":"c7","c6":"c7","ru":"cS","eD":{"q":[],"Q":[]},"du":{"Q":[]},"dw":{"a3":[]},"c7":{"a3":[]},"o":{"r":["1"],"B":["1"],"a3":[],"h":["1"],"h.E":"1"},"eB":{"dK":[]},"iP":{"o":["1"],"r":["1"],"B":["1"],"a3":[],"h":["1"],"h.E":"1"},"ch":{"R":["1"]},"cr":{"e":[],"aB":[],"aS":["aB"]},"dt":{"e":[],"f":[],"aB":[],"aS":["aB"],"Q":[]},"eE":{"e":[],"aB":[],"aS":["aB"],"Q":[]},"cs":{"c":[],"aS":["c"],"ji":[],"Q":[]},"cc":{"h":["2"]},"dh":{"R":["2"]},"ci":{"cc":["1","2"],"h":["2"],"h.E":"2"},"dX":{"ci":["1","2"],"cc":["1","2"],"B":["2"],"h":["2"],"h.E":"2"},"dW":{"H":["2"],"r":["2"],"cc":["1","2"],"B":["2"],"h":["2"]},"a9":{"dW":["1","2"],"H":["2"],"r":["2"],"cc":["1","2"],"B":["2"],"h":["2"],"H.E":"2","h.E":"2"},"eK":{"T":[]},"B":{"h":["1"]},"w":{"B":["1"],"h":["1"]},"dR":{"w":["1"],"B":["1"],"h":["1"],"h.E":"1","w.E":"1"},"aV":{"R":["1"]},"aF":{"h":["2"],"h.E":"2"},"co":{"aF":["1","2"],"B":["2"],"h":["2"],"h.E":"2"},"dD":{"R":["2"]},"u":{"w":["2"],"B":["2"],"h":["2"],"h.E":"2","w.E":"2"},"A":{"h":["1"],"h.E":"1"},"dU":{"R":["1"]},"dL":{"h":["1"],"h.E":"1"},"iB":{"dL":["1"],"B":["1"],"h":["1"],"h.E":"1"},"dM":{"R":["1"]},"dl":{"B":["1"],"h":["1"],"h.E":"1"},"dm":{"R":["1"]},"b0":{"h":["1"],"h.E":"1"},"bo":{"R":["1"]},"bB":{"w":["1"],"B":["1"],"h":["1"],"h.E":"1","w.E":"1"},"m":{"d4":[],"bf":[]},"a":{"d5":[],"bf":[]},"d6":{"cH":[],"bf":[]},"aP":{"cH":[],"bf":[]},"di":{"i":["1","2"]},"aT":{"di":["1","2"],"i":["1","2"]},"dY":{"h":["1"],"h.E":"1"},"cF":{"R":["1"]},"dj":{"bC":["1"],"P":["1"],"B":["1"],"h":["1"]},"c0":{"dj":["1"],"bC":["1"],"P":["1"],"B":["1"],"h":["1"],"h.E":"1"},"ez":{"aD":[],"bK":[]},"bL":{"aD":[],"bK":[]},"dI":{"bT":[],"T":[]},"eG":{"T":[]},"fd":{"T":[]},"e6":{"c8":[]},"aD":{"bK":[]},"em":{"aD":[],"bK":[]},"en":{"aD":[],"bK":[]},"f8":{"aD":[],"bK":[]},"f6":{"aD":[],"bK":[]},"cN":{"aD":[],"bK":[]},"f5":{"T":[]},"bM":{"a7":["1","2"],"mJ":["1","2"],"i":["1","2"],"a7.K":"1","a7.V":"2"},"aa":{"B":["1"],"h":["1"],"h.E":"1"},"au":{"R":["1"]},"av":{"B":["1"],"h":["1"],"h.E":"1"},"M":{"R":["1"]},"J":{"B":["aq<1,2>"],"h":["aq<1,2>"],"h.E":"aq<1,2>"},"ap":{"R":["aq<1,2>"]},"d4":{"bf":[]},"d5":{"bf":[]},"cH":{"bf":[]},"eF":{"pf":[],"ji":[]},"cS":{"a3":[],"Q":[]},"dG":{"a3":[]},"eP":{"a3":[],"Q":[]},"cT":{"aU":["1"],"a3":[]},"dE":{"H":["e"],"r":["e"],"aU":["e"],"B":["e"],"a3":[],"h":["e"],"a_":["e"]},"dF":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"]},"eQ":{"H":["e"],"r":["e"],"aU":["e"],"B":["e"],"a3":[],"h":["e"],"a_":["e"],"Q":[],"H.E":"e","h.E":"e","a_.E":"e"},"eR":{"bJ":[],"H":["e"],"r":["e"],"aU":["e"],"B":["e"],"a3":[],"h":["e"],"a_":["e"],"Q":[],"H.E":"e","h.E":"e","a_.E":"e"},"eS":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"eT":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"eU":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"eV":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"eW":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"dH":{"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"eX":{"m_":[],"H":["f"],"r":["f"],"aU":["f"],"B":["f"],"a3":[],"h":["f"],"a_":["f"],"Q":[],"H.E":"f","h.E":"f","a_.E":"f"},"fl":{"T":[]},"d7":{"bT":[],"T":[]},"br":{"R":["1"]},"bF":{"h":["1"],"h.E":"1"},"bh":{"T":[]},"an":{"bx":["1"]},"eb":{"n6":[]},"fy":{"eb":[],"n6":[]},"bq":{"cd":["1","bq<1>"],"cd.1":"bq<1>","cd.K":"1"},"be":{"bC":["1"],"mK":["1"],"P":["1"],"B":["1"],"h":["1"],"h.E":"1"},"Y":{"R":["1"]},"a7":{"i":["1","2"]},"bC":{"P":["1"],"B":["1"],"h":["1"]},"e2":{"bC":["1"],"P":["1"],"B":["1"],"h":["1"]},"bE":{"R":["3"]},"e3":{"bE":["1","2","1"],"R":["1"],"bE.K":"1","bE.T":"1","bE.1":"2"},"dN":{"bC":["1"],"P":["1"],"B":["1"],"bp":["1","bq<1>"],"h":["1"],"h.E":"1","bp.K":"1","bp.1":"bq<1>"},"fo":{"a7":["c","@"],"i":["c","@"],"a7.K":"c","a7.V":"@"},"fp":{"w":["c"],"B":["c"],"h":["c"],"h.E":"c","w.E":"c"},"dg":{"c_":["r<f>","c"],"c_.S":"r<f>"},"dy":{"T":[]},"eI":{"T":[]},"eH":{"c_":["N?","c"],"c_.S":"N?"},"bH":{"aS":["bH"]},"e":{"aB":[],"aS":["aB"]},"cn":{"aS":["cn"]},"f":{"aB":[],"aS":["aB"]},"r":{"B":["1"],"h":["1"]},"aB":{"aS":["aB"]},"P":{"B":["1"],"h":["1"]},"c":{"aS":["c"],"ji":[]},"fk":{"a2":[]},"ei":{"T":[]},"bT":{"T":[]},"bu":{"T":[]},"dJ":{"T":[]},"ey":{"T":[]},"dT":{"T":[]},"fb":{"T":[]},"dQ":{"T":[]},"eo":{"T":[]},"f_":{"T":[]},"dP":{"T":[]},"fD":{"c8":[]},"d0":{"pl":[]},"bv":{"a2":[]},"cw":{"a2":[]},"bN":{"a2":[]},"c4":{"a2":[]},"cx":{"a2":[]},"cq":{"a2":[]},"ds":{"a2":[]},"c5":{"a2":[]},"cP":{"a2":[]},"b8":{"a2":[]},"b9":{"a2":[]},"bk":{"a2":[]},"aO":{"a2":[]},"ac":{"a2":[]},"aL":{"a2":[]},"O":{"a2":[]},"aN":{"a2":[]},"am":{"a4":[],"E":[]},"aG":{"a4":[],"E":[]},"b7":{"E":[]},"ao":{"E":[]},"aH":{"E":[]},"ba":{"E":[]},"cM":{"a4":[],"E":[]},"ck":{"E":[]},"cb":{"a4":[],"E":[]},"cu":{"E":[]},"cX":{"a4":[],"E":[]},"el":{"E":[]},"de":{"E":[]},"d_":{"a4":[],"E":[]},"ev":{"a4":[],"E":[]},"f7":{"E":[]},"fa":{"E":[]},"es":{"E":[]},"eg":{"E":[]},"f4":{"E":[]},"cO":{"a4":[],"E":[]},"ex":{"E":[]},"cj":{"a4":[],"E":[]},"dO":{"E":[]},"aM":{"a4":[],"E":[]},"bA":{"E":[]},"b6":{"E":[]},"ct":{"E":[]},"eZ":{"E":[]},"cz":{"a2":[]},"cB":{"a2":[]},"bz":{"a2":[]},"bw":{"a2":[]},"bP":{"a2":[]},"cm":{"a2":[]},"oU":{"r":["f"],"B":["f"],"h":["f"]},"m_":{"r":["f"],"B":["f"],"h":["f"]},"pt":{"r":["f"],"B":["f"],"h":["f"]},"oS":{"r":["f"],"B":["f"],"h":["f"]},"pr":{"r":["f"],"B":["f"],"h":["f"]},"oT":{"r":["f"],"B":["f"],"h":["f"]},"ps":{"r":["f"],"B":["f"],"h":["f"]},"oR":{"r":["e"],"B":["e"],"h":["e"]},"bJ":{"r":["e"],"B":["e"],"h":["e"]}}'))
A.pW(v.typeUniverse,JSON.parse('{"ec":2,"cT":1,"e2":1,"e4":1,"e5":1,"ep":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",h:"SHP: {r} registros, {n} entidades ({crs})",n:"{k}: {p} marcadores, {n} entidades ({crs})"}
var t=(function rtii(){var s=A.S
return{mu:s("cM"),u:s("bh"),fn:s("dg"),q:s("ah"),bP:s("aS<@>"),lq:s("c0<c>"),kU:s("ao"),l0:s("c1"),f8:s("ck"),cs:s("bH"),nJ:s("eq"),n6:s("c2"),ks:s("cm"),jS:s("cn"),Y:s("B<@>"),cQ:s("bi"),h:s("E"),od:s("O"),fz:s("T"),na:s("ac"),kN:s("a1"),kI:s("bJ"),mf:s("bw"),lG:s("cp"),m1:s("cq"),Z:s("bK"),G:s("I"),fC:s("I(c,c)"),cr:s("b5"),b:s("by"),E:s("aL"),id:s("bL<e>"),lv:s("h<aL>"),bq:s("h<c>"),kk:s("h<e>"),e7:s("h<@>"),o6:s("o<ah>"),l1:s("o<ao>"),ou:s("o<c1>"),c:s("o<c2>"),hz:s("o<bi>"),w:s("o<E>"),e0:s("o<dp>"),eK:s("o<a1>"),p4:s("o<cp>"),I:s("o<I>"),go:s("o<b5>"),lp:s("o<dr>"),dr:s("o<aL>"),j8:s("o<aE>"),gv:s("o<r<C>>"),iA:s("o<r<e>>"),nx:s("o<cv>"),nE:s("o<dB>"),jv:s("o<dC>"),ot:s("o<cw>"),gN:s("o<i<c,e>>"),iT:s("o<i<f,e>>"),lH:s("o<cU>"),nB:s("o<G>"),iv:s("o<b7>"),A:s("o<aA>"),dO:s("o<a8>"),dI:s("o<bl>"),nD:s("o<L>"),eN:s("o<bO>"),i5:s("o<cy>"),K:s("o<C>"),fH:s("o<aX>"),an:s("o<+(L,e)>"),dD:s("o<+(c,c3)>"),fU:s("o<+(e,e)>"),ip:s("o<+(e,f)>"),hD:s("o<+(f,f)>"),kb:s("o<+(e,e,e)>"),nV:s("o<+(e,f,f)>"),ey:s("o<P<c>>"),h0:s("o<am>"),s:s("o<c>"),iF:s("o<cA>"),cu:s("o<bQ>"),cD:s("o<bc>"),k:s("o<bd>"),ik:s("o<aZ>"),pn:s("o<bS>"),ae:s("o<ca>"),eZ:s("o<b_>"),bD:s("o<F>"),kD:s("o<cD>"),lS:s("o<Z>"),n:s("o<e>"),dG:s("o<@>"),t:s("o<f>"),oA:s("o<dV?>"),T:s("du"),m:s("a3"),dY:s("c6"),dX:s("aU<@>"),df:s("aE"),hu:s("bz"),g_:s("eL"),e5:s("r<I>"),g2:s("r<b5>"),er:s("r<aE>"),ms:s("r<aA>"),d:s("r<L>"),V:s("r<C>"),x:s("r<+(L,e)>"),bF:s("r<c>"),k6:s("r<bc>"),bd:s("r<e>"),j:s("r<@>"),L:s("r<f>"),j5:s("aq<c,I?>"),U:s("i<c,e>"),P:s("i<c,@>"),dV:s("i<c,f>"),nh:s("i<e,bi>"),av:s("i<@,@>"),jq:s("i<f,e>"),J:s("i<c,r<I>>"),c8:s("i<c,I?>"),l3:s("i<f,r<f>>"),pj:s("aF<P<c>,e>"),oi:s("aF<P<c>,f>"),pa:s("u<c,f?>"),oX:s("eY"),mP:s("G"),a:s("aw"),D:s("N"),hF:s("bk"),o:s("aA"),fa:s("a8"),f7:s("b8"),h4:s("bl"),p:s("L"),W:s("b9"),m9:s("ba"),n7:s("cx"),oY:s("cW"),fR:s("bO"),oz:s("cy"),Q:s("a4"),c4:s("bP"),g:s("C"),dz:s("aX"),lZ:s("rx"),aK:s("+()"),kh:s("+(dp,e)"),lJ:s("+(i<f,e>,i<f,f>)"),ft:s("+(bl,c)"),ca:s("+(L,e)"),kM:s("+(c,c)"),aL:s("+(e,e)"),R:s("+(e,f)"),gn:s("+(f,f)"),g9:s("bB<I>"),hZ:s("P<I>"),C:s("P<c>"),nO:s("P<f>"),fA:s("cz"),l:s("c8"),N:s("c"),ep:s("cA"),eu:s("bQ"),ai:s("aN"),f:s("bc"),ju:s("bd"),gs:s("aZ"),oW:s("cB"),jH:s("bS"),aJ:s("Q"),do:s("bT"),cx:s("cC"),nN:s("b_"),bn:s("aO"),e4:s("F"),v:s("aH"),ji:s("A<r<C>>"),fG:s("A<P<c>>"),ee:s("A<e>"),cA:s("b0<ao>"),iC:s("b0<ck>"),hP:s("b0<aG>"),lF:s("b0<aH>"),mt:s("b0<cb>"),jc:s("bo<cM>"),jg:s("bo<ck>"),bo:s("bo<ba>"),hB:s("cb"),ct:s("cD"),e:s("Z"),kV:s("d2"),_:s("an<@>"),cU:s("an<~>"),mN:s("bF<+(f,dV)>"),iG:s("bF<+run,stage,zoneId,zoneIndex(~(),bv,c?,f)>"),y:s("q"),eV:s("q(r<C>)"),iW:s("q(N)"),pf:s("q(P<c>)"),eq:s("q(e)"),i:s("e"),bC:s("e(P<c>)"),z:s("@"),mY:s("@()"),mq:s("@(N)"),ng:s("@(N,c8)"),S:s("f"),iJ:s("f(P<c>)"),cH:s("ao?"),gK:s("bx<aw>?"),ga:s("bx<~>()?"),B:s("I?"),mU:s("a3?"),fm:s("r<c>?"),O:s("r<@>?"),md:s("i<c,c>?"),dZ:s("i<c,@>?"),iD:s("N?"),h2:s("a8?"),cV:s("L?"),gL:s("aX?"),bl:s("c?"),mv:s("aZ?"),kf:s("F?"),f4:s("Z?"),F:s("cE<@,@>?"),X:s("fs?"),o9:s("q?"),jX:s("e?"),aV:s("f?"),bw:s("f?(c)"),jh:s("aB?"),dn:s("~(cl)?"),H:s("aB"),r:s("~"),M:s("~()"),lc:s("~(c,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.eS=J.eA.prototype
B.a=J.o.prototype
B.c=J.dt.prototype
B.b=J.cr.prototype
B.d=J.cs.prototype
B.eT=J.c6.prototype
B.eU=J.dw.prototype
B.bA=J.f0.prototype
B.aS=J.cC.prototype
B.dc=new A.ek(1/0,1/0,-1/0,-1/0)
B.m=new A.bL(A.nS(),t.id)
B.dd=new A.bL(A.nS(),A.S("bL<f>"))
B.H=new A.bL(A.rb(),t.id)
B.dg=new A.fT()
B.de=new A.dg()
B.df=new A.fS()
B.dh=new A.cn()
B.di=new A.dm(A.S("dm<0&>"))
B.aU=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.dj=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.dp=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.dk=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.dn=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.dm=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.dl=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.aV=function(hooks) { return hooks; }

B.aW=new A.eH()
B.dq=new A.f_()
B.f=new A.jC()
B.u=new A.fy()
B.dr=new A.fD()
B.aX=new A.bv(0,"zones")
B.eG=new A.bv(1,"mainline")
B.V=new A.bv(2,"splits")
B.eH=new A.bv(3,"flushing")
B.eI=new A.bv(4,"surge")
B.aa=new A.bv(5,"bom")
B.I=new A.aK(0,2,0)
B.aY=new A.aK(0.001,2,0)
B.b_=new A.O(0,"line")
B.b0=new A.O(1,"polyline")
B.b1=new A.O(10,"radialDimension")
B.b2=new A.O(11,"leader")
B.b3=new A.O(12,"image")
B.b4=new A.O(13,"contour")
B.b5=new A.O(14,"spotHeight")
B.ab=new A.O(15,"pipe")
B.ac=new A.O(16,"sprayline")
B.ad=new A.O(17,"tape")
B.ae=new A.O(18,"outlet")
B.af=new A.O(19,"controlValve")
B.b6=new A.O(2,"circle")
B.ag=new A.O(20,"waterSupply")
B.ah=new A.O(21,"pump")
B.ai=new A.O(22,"misc")
B.aj=new A.O(23,"junction")
B.b7=new A.O(24,"area")
B.ak=new A.O(25,"pivot")
B.b8=new A.O(26,"controller")
B.b9=new A.O(27,"wire")
B.ba=new A.O(28,"ordinateDimension")
B.bb=new A.O(3,"arc")
B.bc=new A.O(4,"spline")
B.bd=new A.O(5,"hatch")
B.be=new A.O(6,"symbol")
B.bf=new A.O(7,"text")
B.bg=new A.O(8,"dimension")
B.bh=new A.O(9,"angularDimension")
B.W=new A.ac(0,"coupler")
B.al=new A.ac(1,"elbow90")
B.n=new A.ac(10,"riser")
B.am=new A.ac(2,"elbow45")
B.J=new A.ac(3,"tee")
B.an=new A.ac(4,"cross")
B.v=new A.ac(5,"reducer")
B.K=new A.ac(6,"endCap")
B.ao=new A.ac(7,"adapter")
B.w=new A.ac(8,"takeOff")
B.L=new A.ac(9,"tapeEnd")
B.eO=new A.dq("Not an OpenCADIrrigation project",null,null)
B.ap=new A.cq(0,"hazenWilliams")
B.bj=new A.cq(1,"darcyWeisbach")
B.e=new A.c4(0,"pipe")
B.X=new A.c4(1,"controlValve")
B.Y=new A.c4(2,"pump")
B.eP=new A.c4(3,"device")
B.eQ=new A.c4(4,"prv")
B.aq=new A.c5(0,"pipe")
B.bk=new A.c5(1,"pump")
B.M=new A.c5(2,"prv")
B.bl=new A.c5(3,"device")
B.eR=new A.c5(4,"closed")
B.Z=new A.ds(0,"junction")
B.a_=new A.ds(1,"reservoir")
B.h=new A.aL(0,"zone")
B.i=new A.aL(1,"mainline")
B.eV=new A.iR(null)
B.eW=new A.iS(null)
B.o=new A.cP(0,"open")
B.l=new A.cP(1,"closed")
B.x=new A.cP(2,"active")
B.dD=new A.v("BRL","R$")
B.en=new A.v("USD","US$")
B.eA=new A.v("EUR","\u20ac")
B.e3=new A.v("MXN","MX$")
B.er=new A.v("INR","\u20b9")
B.eD=new A.v("CNY","CN\xa5")
B.dC=new A.v("JPY","\xa5")
B.dU=new A.v("IDR","Rp")
B.eF=new A.v("NGN","\u20a6")
B.el=new A.v("TZS","TSh")
B.dY=new A.v("KES","KSh")
B.dP=new A.v("VND","\u20ab")
B.ey=new A.v("TRY","\u20ba")
B.e_=new A.v("RUB","\u20bd")
B.ez=new A.v("EGP","E\xa3")
B.eg=new A.v("SAR","SAR")
B.ec=new A.v("PKR","Rs")
B.ev=new A.v("BDT","\u09f3")
B.dF=new A.v("GBP","\xa3")
B.dx=new A.v("ARS","AR$")
B.dJ=new A.v("COP","CO$")
B.dI=new A.v("CLP","CL$")
B.e9=new A.v("PEN","S/")
B.eo=new A.v("UYU","$U")
B.dz=new A.v("PYG","\u20b2")
B.dB=new A.v("BOB","Bs")
B.dQ=new A.v("GTQ","Q")
B.ew=new A.v("CRC","\u20a1")
B.dM=new A.v("DOP","RD$")
B.dG=new A.v("CAD","CA$")
B.dy=new A.v("AUD","A$")
B.e8=new A.v("NZD","NZ$")
B.et=new A.v("ZAR","R")
B.dH=new A.v("CHF","CHF")
B.eh=new A.v("SEK","kr")
B.e6=new A.v("NOK","kr")
B.dL=new A.v("DKK","kr")
B.dR=new A.v("PLN","z\u0142")
B.ee=new A.v("CZK","K\u010d")
B.dT=new A.v("HUF","Ft")
B.ef=new A.v("RON","lei")
B.du=new A.v("UAH","\u20b4")
B.ex=new A.v("KZT","\u20b8")
B.dE=new A.v("BYN","Br")
B.eC=new A.v("ILS","\u20aa")
B.dv=new A.v("AED","AED")
B.ed=new A.v("QAR","QAR")
B.dZ=new A.v("KWD","KWD")
B.ea=new A.v("OMR","OMR")
B.dA=new A.v("BHD","BHD")
B.dX=new A.v("JOD","JOD")
B.dV=new A.v("IQD","IQD")
B.e0=new A.v("LBP","LBP")
B.e2=new A.v("MAD","MAD")
B.dN=new A.v("DZD","DZD")
B.ej=new A.v("TND","TND")
B.dW=new A.v("IRR","IRR")
B.eu=new A.v("AFN","\u060b")
B.dt=new A.v("KRW","\u20a9")
B.ek=new A.v("TWD","NT$")
B.dS=new A.v("HKD","HK$")
B.ei=new A.v("SGD","S$")
B.e4=new A.v("MYR","RM")
B.es=new A.v("THB","\u0e3f")
B.eB=new A.v("PHP","\u20b1")
B.e7=new A.v("NPR","NRs")
B.e1=new A.v("LKR","LKR")
B.ds=new A.v("UZS","so\u02bbm")
B.eb=new A.v("AZN","\u20bc")
B.em=new A.v("UGX","USh")
B.dO=new A.v("ETB","Br")
B.eE=new A.v("GHS","GH\u20b5")
B.eq=new A.v("XOF","CFA")
B.ep=new A.v("XAF","FCFA")
B.dw=new A.v("AOA","Kz")
B.e5=new A.v("MZN","MT")
B.dK=new A.v("CVE","Esc")
B.bn=s([B.dD,B.en,B.eA,B.e3,B.er,B.eD,B.dC,B.dU,B.eF,B.el,B.dY,B.dP,B.ey,B.e_,B.ez,B.eg,B.ec,B.ev,B.dF,B.dx,B.dJ,B.dI,B.e9,B.eo,B.dz,B.dB,B.dQ,B.ew,B.dM,B.dG,B.dy,B.e8,B.et,B.dH,B.eh,B.e6,B.dL,B.dR,B.ee,B.dT,B.ef,B.du,B.ex,B.dE,B.eC,B.dv,B.ed,B.dZ,B.ea,B.dA,B.dX,B.dV,B.e0,B.e2,B.dN,B.ej,B.dW,B.eu,B.dt,B.ek,B.dS,B.ei,B.e4,B.es,B.eB,B.e7,B.e1,B.ds,B.eb,B.em,B.dO,B.eE,B.eq,B.ep,B.dw,B.e5,B.dK],A.S("o<v>"))
B.q=new A.b9(0,"lateral")
B.j=new A.b9(1,"zone")
B.k=new A.b9(2,"mainline")
B.f0=s([B.q,B.j,B.k],A.S("o<b9>"))
B.a2=new A.bk(0,"sprinkler")
B.at=new A.bk(1,"microSprinkler")
B.au=new A.bk(2,"dripper")
B.fx=new A.bk(3,"bubbler")
B.by=new A.bk(4,"gun")
B.av=new A.bk(5,"demandPoint")
B.f1=s([B.a2,B.at,B.au,B.fx,B.by,B.av],A.S("o<bk>"))
B.aZ=new A.cm(0,"mm")
B.eJ=new A.cm(1,"inch")
B.f2=s([B.aZ,B.eJ],A.S("o<cm>"))
B.p=new A.b8(3e9,0,"pvc")
B.y=new A.b8(9e8,1,"pehd")
B.aw=new A.b8(3e8,2,"peld")
B.bz=new A.b8(2e11,3,"steel")
B.fy=new A.b8(17e10,4,"ductileIron")
B.fA=new A.b8(7e10,5,"aluminium")
B.fz=new A.b8(3e10,6,"concrete")
B.f3=s([B.p,B.y,B.aw,B.bz,B.fy,B.fA,B.fz],A.S("o<b8>"))
B.f4=s([B.ap,B.bj],A.S("o<cq>"))
B.D=s([B.h,B.i],t.dr)
B.f5=s(["IMAGES","DRAWING","HATCHES","SYMBOLS","TEXT","DIMENSIONS","CONTOURS","SPOT_HEIGHTS","DEM","ZONE_PIPES","MAINLINE_PIPES","SPRAYLINES","TAPES","OUTLETS","WETTED_RADII","CONTROL_VALVES","WATER_SUPPLY","PUMPS","MISC_HYDRAULIC","JUNCTIONS","PIVOTS","WIRES","CONTROLLERS","AREAS","LABELS"],t.s)
B.E=new A.cx(0,"pivot")
B.fB=new A.cx(1,"linear")
B.f6=s([B.E,B.fB],A.S("o<cx>"))
B.a7=new A.cz(0,"lp")
B.FN=new A.cz(1,"greedy")
B.f7=s([B.a7,B.FN],A.S("o<cz>"))
B.aR=new A.cB(0,"tin")
B.FX=new A.cB(1,"idw")
B.f8=s([B.aR,B.FX],A.S("o<cB>"))
B.f9=s(["id","de","en","es","fr","ha","sw","pt","vi","tr","ru","ar","ur","hi","mr","bn","pa","te","zh","ja"],t.s)
B.B=new A.aO(0,"control")
B.S=new A.aO(1,"prv")
B.T=new A.aO(2,"isolation")
B.U=new A.aO(3,"check")
B.aT=new A.aO(4,"backflow")
B.C=new A.aO(5,"filter")
B.a8=new A.aO(6,"meter")
B.a9=new A.aO(7,"airRelease")
B.G9=new A.aO(8,"other")
B.fa=s([B.B,B.S,B.T,B.U,B.aT,B.C,B.a8,B.a9,B.G9],A.S("o<aO>"))
B.h4=new A.m(1,1.3)
B.hn=new A.m(1.5,1.7)
B.ha=new A.m(2.5,2.6)
B.fX=new A.m(4,4)
B.hu=new A.m(6,5.9)
B.ho=new A.m(10,9.6)
B.fb=s([B.h4,B.hn,B.ha,B.fX,B.hu,B.ho],t.fU)
B.FO=new A.aN(0,"northArrow")
B.FP=new A.aN(1,"tree")
B.FQ=new A.aN(2,"building")
B.FR=new A.aN(3,"tank")
B.FS=new A.aN(4,"well")
B.FT=new A.aN(5,"valveBox")
B.FU=new A.aN(6,"pumpHouse")
B.FV=new A.aN(7,"gate")
B.FW=new A.aN(8,"filterStation")
B.fc=s([B.FO,B.FP,B.FQ,B.FR,B.FS,B.FT,B.FU,B.FV,B.FW],A.S("o<aN>"))
B.bq=s([],t.c)
B.fe=s([],t.I)
B.fg=s([],t.nB)
B.ff=s([],t.A)
B.br=s([],t.dI)
B.bs=s([],t.nD)
B.fd=s([],t.K)
B.Ga=s([],t.ey)
B.fh=s([],t.iF)
B.fi=s([],t.eZ)
B.bp=s([],t.n)
B.bo=s([],t.t)
B.Gb=s([],t.dD)
B.h8=new A.m(18,1.2)
B.hw=new A.m(16,1.6)
B.h7=new A.m(14,2.4)
B.h6=new A.m(12,3.7)
B.fY=new A.m(10,5.7)
B.hE=new A.m(8,8.9)
B.fj=s([B.h8,B.hw,B.h7,B.h6,B.fY,B.hE],A.S("o<+(f,e)>"))
B.bm=new A.bz(0,"m")
B.eX=new A.bz(1,"mm")
B.eY=new A.bz(2,"cm")
B.eZ=new A.bz(3,"ft")
B.f_=new A.bz(4,"inch")
B.fk=s([B.bm,B.eX,B.eY,B.eZ,B.f_],A.S("o<bz>"))
B.bB=new A.bP(0,"mH2O")
B.fC=new A.bP(1,"kPa")
B.fD=new A.bP(2,"bar")
B.fE=new A.bP(3,"psi")
B.fl=s([B.bB,B.fC,B.fD,B.fE],A.S("o<bP>"))
B.bi=new A.bw(0,"lph")
B.eK=new A.bw(1,"lpm")
B.eL=new A.bw(2,"lps")
B.eM=new A.bw(3,"m3h")
B.eN=new A.bw(4,"gpm")
B.fm=s([B.bi,B.eK,B.eL,B.eM,B.eN],A.S("o<bw>"))
B.fn=s([B.W,B.al,B.am,B.J,B.an,B.v,B.K,B.ao,B.w,B.L,B.n],A.S("o<ac>"))
B.fo=s(["no_water_supply"],t.s)
B.fp=s([B.b_,B.b0,B.b6,B.bb,B.bc,B.bd,B.be,B.bf,B.bg,B.bh,B.b1,B.b2,B.b3,B.b4,B.b5,B.ab,B.ac,B.ad,B.ae,B.af,B.ag,B.ah,B.ai,B.aj,B.b7,B.ak,B.b8,B.b9,B.ba],A.S("o<O>"))
B.a0=new A.cw(0,"le")
B.ar=new A.cw(1,"eq")
B.bt=new A.cw(2,"ge")
B.N=new A.bN(0,"optimal")
B.fq=new A.bN(1,"infeasible")
B.fr=new A.bN(2,"unbounded")
B.bu=new A.bN(3,"iterationLimit")
B.fu={DRAWING:0,TEXT:1,DIMENSIONS:2,CONTOURS:3,SPOT_HEIGHTS:4,DEM:5,ZONE_PIPES:6,MAINLINE_PIPES:7,SPRAYLINES:8,TAPES:9,OUTLETS:10,WETTED_RADII:11,CONTROL_VALVES:12,WATER_SUPPLY:13,PUMPS:14,MISC_HYDRAULIC:15,JUNCTIONS:16,AREAS:17,LABELS:18,IMAGES:19,HATCHES:20,SYMBOLS:21,PIVOTS:22,CONTROLLERS:23,WIRES:24}
B.bv=new A.aT(B.fu,[4289773253,4293718001,4287669422,4287458915,4288776319,4286483095,4282557941,4280191205,4280731354,4284922730,4280923894,1428797174,4294944550,4286470082,4293874512,4294953512,4286091420,867095937,4291811548,4294967295,4286091420,4289773253,4283283116,4294930499,4294962776],A.S("aT<c,f>"))
B.ft={BRL:0,USD:1,EUR:2,GBP:3,JPY:4,CNY:5,INR:6,IDR:7,NGN:8,KES:9,TZS:10,UGX:11,VND:12,TRY:13,RUB:14,EGP:15,SAR:16,AED:17,MAD:18,DZD:19,TND:20,IQD:21,JOD:22,QAR:23,KWD:24,OMR:25,BHD:26,LBP:27,PKR:28,BDT:29,MXN:30,ARS:31,COP:32,CLP:33,PEN:34,UYU:35,PYG:36,BOB:37,GTQ:38,CRC:39,DOP:40,CAD:41,AUD:42,NZD:43,ZAR:44,CHF:45,SEK:46,NOK:47,DKK:48,PLN:49,CZK:50,HUF:51,RON:52,UAH:53,KZT:54,BYN:55,ILS:56,KRW:57,TWD:58,HKD:59,SGD:60,MYR:61,THB:62,PHP:63,XOF:64,XAF:65,AOA:66,MZN:67,ETB:68,GHS:69,NPR:70,LKR:71,IRR:72,AFN:73,UZS:74,AZN:75,CVE:76}
B.bw=new A.aT(B.ft,[1,0.194498,0.169492,0.14543,30.6062,1.3088,18.6598,3451.74,262.864,25.2459,516.716,745.134,5050.14,9.48874,16.495,10.1227,0.729374,0.7143,1.85499,26.0744,0.569235,254.226,0.1379,0.707979,0.060022,0.074785,0.073132,17407.7,54.0161,23.9342,3.34495,294.148,617.19,187.238,0.657038,7.83241,1160.73,2.19297,1.48678,87.1606,11.4422,0.272264,0.27313,0.34017,3.16636,0.1602,1.91301,1.83189,1.26869,0.739874,4.12219,61.7788,0.8934,8.7116,86.927,0.58924,0.589802,269.659,6.1751,1.52685,0.248332,0.793666,6.48381,12.216,111.137,111.137,183.852,12.4413,31.3447,2.22843,29.8503,64.2754,267526,12.6304,2299.29,0.331254,18.6819],A.S("aT<c,e>"))
B.fw={"app.title":0,ok:1,cancel:2,apply:3,close:4,auto:5,clear:6,"menu.file":7,"menu.edit":8,"menu.view":9,"menu.draw":10,"menu.zone":11,"menu.mainline":12,"menu.design":13,"menu.reports":14,"menu.tools":15,"menu.help":16,"file.new":17,"file.open":18,"file.save":19,"file.exportDxf":20,"file.exportDrawing":21,"file.exportReport":22,"file.georef":23,"file.newTab":24,"file.closeTab":25,"tab.new":26,"tab.close":27,"edit.clipCopy":28,"edit.clipCut":29,"edit.paste":30,"msg.copied":31,"msg.cut":32,"msg.pipeCut":33,"msg.pasted":34,"msg.nothingSelected":35,"msg.clipboardEmpty":36,"msg.unknownCommand":37,"status.command":38,"help.shortcuts":39,"sc.title":40,"sc.intro":41,"sc.file":42,"sc.edit":43,"sc.view":44,"sc.commands":45,"sc.hydraulic":46,"sc.switchTab":47,"sc.cancel":48,"sc.finish":49,"sc.undoPoint":50,"sc.repeat":51,"sc.zoom":52,"sc.pan":53,"sc.panHold":54,"sc.reports":55,"sc.gridDisplay":56,"sc.angleLock":57,"sc.autoRun":58,"sc.toggles":59,"sc.designCmds":60,"exp.dxf":61,"exp.dwg":62,"exp.pdf":63,"exp.svg":64,"exp.kml":65,"exp.kmz":66,"exp.geojson":67,"exp.csv":68,"exp.txt":69,"exp.xlsx":70,"exp.reportPdf":71,"msg.exported":72,"msg.needResults":73,"msg.nothingToExport":74,"msg.georefSet":75,"geo.title":76,"geo.explain":77,"geo.modeLatLon":78,"geo.modeUtm":79,"geo.lat":80,"geo.lon":81,"geo.zone":82,"geo.north":83,"geo.easting":84,"geo.northing":85,"geo.current":86,"geo.none":87,"geo.remove":88,"geo.invalid":89,"plot.title":90,"plot.page":91,"plot.orientation":92,"plot.landscape":93,"plot.portrait":94,"plot.scale":95,"plot.scaleAuto":96,"plot.wetted":97,"plot.labels":98,"plot.legend":99,"plot.reports":100,"plot.export":101,"plot.fits":102,"pdf.date":103,"pdf.scale":104,"pdf.sheet":105,"pdf.origin":106,"pdf.summary":107,"pdf.crs":108,"pdf.local":109,"pdf.legend":110,"pdf.subtitle":111,"pdf.reportTitle":112,"pdf.generated":113,"pdf.page":114,"pdf.cont":115,"pdf.noResults":116,"pdf.params":117,"layer.DRAWING":118,"layer.TEXT":119,"layer.DIMENSIONS":120,"layer.CONTOURS":121,"layer.SPOT_HEIGHTS":122,"layer.DEM":123,"layer.ZONE_PIPES":124,"layer.MAINLINE_PIPES":125,"layer.SPRAYLINES":126,"layer.TAPES":127,"layer.OUTLETS":128,"layer.WETTED_RADII":129,"layer.CONTROL_VALVES":130,"layer.WATER_SUPPLY":131,"layer.PUMPS":132,"layer.MISC_HYDRAULIC":133,"layer.JUNCTIONS":134,"layer.AREAS":135,"layer.LABELS":136,"file.details":137,"edit.undo":138,"edit.redo":139,"edit.delete":140,"edit.selectAll":141,"edit.copy":142,"view.zoomAll":143,"view.zoomIn":144,"view.zoomOut":145,"view.grid":146,"view.labels":147,"view.wetted":148,"view.overlay.none":149,"view.overlay.velocity":150,"view.overlay.pressure":151,"view.overlay.sizes":152,"view.layers":153,"view.language":154,"lang.pt":155,"lang.en":156,"lang.es":157,"design.params":158,"design.management":159,"design.check":160,"design.zone":161,"design.analyze":162,"design.mainline":163,"design.all":164,"design.clear":165,"design.progress.title":166,"design.progress.start":167,"design.progress.zones":168,"design.progress.mainline":169,"design.progress.splits":170,"design.progress.flushing":171,"design.progress.surge":172,"design.progress.bom":173,"design.progress.bg":174,"design.progress.hint":175,"design.catalog":176,"design.block":177,"design.autohead":178,"reports.zone":179,"reports.pipes":180,"reports.outlets":181,"reports.mainline":182,"reports.devices":183,"reports.bom":184,"reports.water":185,"reports.hgl":186,"reports.messages":187,"tools.lateral":188,"tools.pump":189,"tools.hammer":190,"tools.units":191,"help.about":192,"help.tutorial":193,"tool.select":194,"tool.pan":195,"tool.line":196,"tool.polyline":197,"tool.rect":198,"tool.circle":199,"tool.text":200,"tool.dimension":201,"tool.contour":202,"tool.spot":203,"tool.area":204,"tool.zonePipe":205,"tool.mainPipe":206,"tool.sprayline":207,"tool.tape":208,"tool.outlet":209,"tool.valve":210,"tool.supply":211,"tool.pump":212,"tool.misc":213,"tool.junction":214,"tool.block":215,"tool.autohead":216,"tool.measure":217,"hint.select":218,"hint.pan":219,"hint.line":220,"hint.polyline":221,"hint.rect":222,"hint.circle":223,"hint.text":224,"hint.dimension":225,"hint.contour":226,"hint.spot":227,"hint.area":228,"hint.pipe":229,"hint.point":230,"hint.block":231,"hint.measure":232,"status.ready":233,"status.snap":234,"status.grid":235,"status.ortho":236,"status.keepLinks":237,"status.keepLinksTip":238,"status.entities":239,"props.title":240,"props.none":241,"props.multi":242,"props.layer":243,"props.name":244,"props.pipe":245,"props.auto":246,"props.depth":247,"props.outlet":248,"props.nozzle":249,"props.head":250,"props.spacing":251,"props.offset":252,"props.arc":253,"props.riser":254,"props.tape":255,"props.inlet":256,"props.regulated":257,"props.submainMin":258,"props.valve":259,"props.zone":260,"props.fixedHead":261,"props.calc":262,"props.designHead":263,"props.maxHead":264,"props.designFlow":265,"props.maxFlow":266,"props.waterLevel":267,"props.pump":268,"props.speed":269,"props.misc":270,"props.setting":271,"props.elevation":272,"props.elevationDem":273,"props.text":274,"props.textHeight":275,"props.radius":276,"props.closed":277,"props.netDepth":278,"props.efficiency":279,"props.crop":280,"props.length":281,"props.area":282,"props.outlets":283,"props.scope":284,"props.results":285,"props.orientation":286,"props.rotation":287,"props.dimOffset":288,"props.zoomTo":289,"props.halfSpacing":290,"props.downstream":291,"props.required":292,"props.valveLoss":293,"props.emitterMinMax":294,"props.allowed":295,"props.uniformity":296,"props.defaults":297,"scope.zone":298,"scope.mainline":299,"result.flow":300,"result.velocity":301,"result.loss":302,"result.pressure":303,"result.pStart":304,"result.pEnd":305,"result.min":306,"result.max":307,"msg.saved":308,"msg.loaded":309,"msg.designDone":310,"msg.unconnected":311,"msg.allConnected":312,"msg.designBusy":313,"msg.designStale":314,"msg.noValves":315,"msg.deleted":316,"msg.imported":317,"msg.error":318,"msg.unsavedConfirm":319,"msg.noResults":320,"msg.noAreas":321,"msg.selectForHgl":322,"msg.noMessages":323,"msg.unconnectedItem":324,"imp.dwg":325,"imp.skipped":326,"imp.kml":327,"imp.dxf":328,"dwg.notDwg":329,"dwg.corrupt":330,"kmz.noKml":331,"rep.zone":332,"rep.valve":333,"rep.emitters":334,"rep.flow":335,"rep.pDown":336,"rep.valveLoss":337,"rep.pRequired":338,"rep.pMin":339,"rep.pMax":340,"rep.allowMin":341,"rep.allowMax":342,"rep.varAllow":343,"rep.varActual":344,"rep.pipeCost":345,"rep.warnings":346,"rep.context":347,"rep.entity":348,"rep.segment":349,"rep.pipe":350,"rep.innerDiam":351,"rep.length":352,"rep.q":353,"rep.velocity":354,"rep.hf":355,"rep.pStart":356,"rep.pEnd":357,"rep.zStart":358,"rep.zEnd":359,"rep.pn":360,"rep.emitter":361,"rep.n":362,"rep.qTotal":363,"rep.qMean":364,"rep.flowName":365,"rep.item":366,"rep.pAvailable":367,"rep.status":368,"rep.energyYear":369,"rep.supply":370,"rep.pump":371,"rep.device":372,"rep.calculated":373,"rep.surplus":374,"rep.fixed":375,"rep.deficit":376,"rep.ok":377,"rep.pumpHead":378,"rep.pIn":379,"rep.pOut":380,"rep.loss":381,"rep.st.running":382,"rep.st.stopped":383,"rep.st.open":384,"rep.st.closed":385,"rep.st.active":386,"rep.suction":387,"rep.submersible":388,"rep.outOfRange":389,"rep.category":390,"rep.description":391,"rep.unit":392,"rep.quantity":393,"rep.unitCost":394,"rep.total":395,"rep.totalRow":396,"rep.annualCapital":397,"rep.annualEnergy":398,"rep.annualTotal":399,"rep.area":400,"rep.grossDepth":401,"rep.volume":402,"rep.rate":403,"rep.hoursDay":404,"hgl.legend":405,"csv.zones":406,"csv.flows":407,"csv.bom":408,"bom.pipes":409,"bom.tapes":410,"bom.outlets":411,"bom.valves":412,"bom.devices":413,"bom.pumps":414,"name.zone":415,"name.supply":416,"name.allZones":417,"name.submain":418,"name.stub":419,"name.lateral":420,"name.area":421,"name.newProject":422,"name.text":423,"name.flow":424,"name.report":425,"ex.name":426,"ex.client":427,"ex.site":428,"ex.boundary":429,"ex.title":430,"ex.zoneA":431,"ex.zoneB":432,"ex.blockA":433,"ex.blockB":434,"ex.citrus":435,"ex.grape":436,"ex.riser":437,"ex.branchA":438,"ex.branchB":439,"ex.well":440,"ex.flow1":441,"ex.flow2":442,"dlg.project":443,"dlg.client":444,"dlg.site":445,"dlg.designer":446,"dlg.notes":447,"dlg.hydraulics":448,"dlg.frictionFormula":449,"dlg.hw":450,"dlg.dw":451,"dlg.waterTemp":452,"dlg.vLateral":453,"dlg.vZone":454,"dlg.vMain":455,"dlg.minorPct":456,"dlg.connectTol":457,"dlg.applyMinor":458,"dlg.cScale":459,"dlg.cOffset":460,"dlg.sizing":461,"dlg.maxSubmainSizes":462,"dlg.densify":463,"dlg.economics":464,"dlg.tradeCapital":465,"dlg.interest":466,"dlg.term":467,"dlg.energyCost":468,"dlg.pumpEff":469,"dlg.hoursMain":470,"dlg.hoursZone":471,"dlg.currency":472,"dlg.currencySymbol":473,"dlg.currencyNote":474,"dlg.convertPricesTitle":475,"dlg.convertPricesBody":476,"dlg.rate":477,"dlg.rateSource":478,"dlg.rateUnknown":479,"dlg.onlyCurrency":480,"dlg.convert":481,"msg.pricesConverted":482,"hist.currency":483,"cat.packPriced":484,"cat.packUnpriced":485,"cat.packSources":486,"cat.packConverted":487,"cat.packNoCurrency":488,"warn.bom_unpriced":489,"adv.bom_unpriced.why":490,"adv.bom_unpriced.how":491,"dlg.metric":492,"dlg.us":493,"dlg.length":494,"dlg.flow":495,"dlg.pressure":496,"dlg.diameter":497,"dlg.allTogether":498,"dlg.oneAtATime":499,"dlg.addFlow":500,"dlg.name":501,"dlg.startHour":502,"dlg.durationHours":503,"dlg.noFlows":504,"dlg.sprayBlock":505,"dlg.dripBlock":506,"dlg.laterals":507,"dlg.emitterSpacing":508,"dlg.lateralPipe":509,"dlg.lateralSpacing":510,"dlg.lateralDirection":511,"dlg.submainValve":512,"dlg.submainPosition":513,"dlg.submainStart":514,"dlg.submainCentre":515,"dlg.submainEnd":516,"dlg.submainPipe":517,"dlg.valvePosition":518,"dlg.posStart":519,"dlg.posCentre":520,"dlg.posEnd":521,"dlg.stub":522,"dlg.spacingPct":523,"dlg.direction":524,"dlg.square":525,"dlg.triangular":526,"dlg.gridSummary":527,"dlg.tapeLateral":528,"dlg.emitterLateral":529,"dlg.slope":530,"dlg.tolBelow":531,"dlg.tolAbove":532,"dlg.results":533,"dlg.emittersCount":534,"dlg.inletFlow":535,"dlg.totalLoss":536,"dlg.endPressure":537,"dlg.pMinMax":538,"dlg.pVariation":539,"dlg.maxVelocity":540,"dlg.uniformity4":541,"dlg.qvar":542,"dlg.maxLength":543,"dlg.staticHead":544,"dlg.speed":545,"dlg.mainPipe":546,"dlg.hoursYear":547,"dlg.operatingPoint":548,"dlg.pumpCannot":549,"dlg.head":550,"dlg.velocityMain":551,"dlg.hydraulicPower":552,"dlg.shaftPower":553,"dlg.annualEnergy":554,"dlg.shutoffRunout":555,"dlg.velocity":556,"dlg.closureTime":557,"dlg.staticPressure":558,"dlg.resultJoukowsky":559,"dlg.celerity":560,"dlg.maxSurge":561,"dlg.criticalTime":562,"dlg.estSurge":563,"dlg.totalPressure":564,"dlg.pipeClass":565,"cat.pipes":566,"cat.outlets":567,"cat.tapes":568,"cat.valves":569,"cat.pumps":570,"cat.use":571,"cat.name":572,"cat.dn":573,"cat.idmm":574,"cat.c":575,"cat.pn":576,"cat.costM":577,"cat.outlet":578,"cat.nozzle":579,"cat.k":580,"cat.x":581,"cat.pMin":582,"cat.pMax":583,"cat.pDefault":584,"cat.cv":585,"cat.tol":586,"cat.cost":587,"cat.spacing":588,"cat.qNom":589,"cat.kd":590,"cat.type":591,"cat.kLoss":592,"cat.n":593,"cat.qMax":594,"cat.points":595,"cat.eff":596,"cat.submersible":597,"cat.hint":598,"mat.pvc":599,"mat.pehd":600,"mat.peld":601,"mat.steel":602,"mat.ductileIron":603,"mat.aluminium":604,"mat.concrete":605,"warn.not_converged":606,"warn.cannot_meet_pressure_window":607,"warn.mainline_cannot_meet_pressure":608,"warn.no_water_supply":609,"warn.outlet_over_pressure":610,"warn.outlet_under_pressure":611,"warn.pressure_rating_exceeded":612,"warn.pump_out_of_range":613,"warn.pump_suction_lift":614,"warn.supply_flow_exceeded":615,"warn.supply_head_exceeded":616,"warn.valve_flow_out_of_range":617,"warn.valve_missing":618,"warn.valve_pressure_deficit":619,"warn.valve_unreachable":620,"warn.velocity_exceeded":621,"warn.zone_empty":622,"warn.zone_overlap":623,"warn.valve_no_zone_pipes":624,"warn.outlet_spec_missing":625,"warn.tape_spec_missing":626,"warn.pump_spec_missing":627,"warn.valve_spec_missing":628,"warn.no_fixed_head_node":629,"warn.page_missing":630,"about.text":631,"about.version":632,"about.site":633,"tool.arc":634,"tool.spline":635,"tool.hatch":636,"tool.symbol":637,"tool.dimAngular":638,"tool.dimRadial":639,"tool.leader":640,"tool.rotate":641,"tool.mirror":642,"tool.scale":643,"tool.offset":644,"tool.trim":645,"tool.extend":646,"tool.cutPipe":647,"tool.profile":648,"hint.arc":649,"hint.spline":650,"hint.hatch":651,"hint.symbol":652,"hint.dimAngular":653,"hint.dimRadial":654,"hint.leader":655,"hint.rotate":656,"hint.mirror":657,"hint.scale":658,"hint.offset":659,"hint.trim":660,"hint.extend":661,"hint.cutPipe":662,"hint.profile":663,"edit.transform":664,"edit.array":665,"edit.feed":666,"arr.title":667,"arr.rect":668,"arr.polar":669,"arr.rows":670,"arr.cols":671,"arr.dx":672,"arr.dy":673,"arr.angle":674,"arr.count":675,"arr.center":676,"arr.total":677,"arr.rotateItems":678,"arr.selection":679,"msg.layerLocked":680,"msg.noIntersection":681,"msg.selectLateral":682,"msg.feedComputed":683,"msg.arrayDone":684,"view.overlay.minMax":685,"view.baseMap":686,"view.baseMap.none":687,"view.baseMap.streets":688,"view.baseMap.satellite":689,"view.baseMap.topo":690,"view.baseMap.carto":691,"view.baseMap.esriStreets":692,"view.baseMap.esriTopo":693,"view.baseMap.googleRoads":694,"view.baseMap.googleSatellite":695,"view.baseMap.googleHybrid":696,"view.baseMap.googleTerrain":697,"view.baseMap.custom":698,"view.baseMap.googleKey":699,"view.baseMap.customUrl":700,"basemap.googleKey.title":701,"basemap.googleKey.explain":702,"basemap.googleKey.steps":703,"basemap.googleKey.console":704,"basemap.googleKey.docs":705,"basemap.googleKey.field":706,"basemap.googleKey.privacy":707,"basemap.googleKey.remove":708,"basemap.googleKeyMissing":709,"basemap.googleError":710,"basemap.custom.title":711,"basemap.custom.explain":712,"basemap.custom.field":713,"basemap.custom.placeholders":714,"basemap.customInvalid":715,"view.baseMapNeedsGeo":716,"view.grips":717,"zone.feedEnvelope":718,"layer.current":719,"layer.lock":720,"layer.add":721,"layer.rename":722,"layer.delete":723,"layer.color":724,"layer.name":725,"layer.exists":726,"layer.hint":727,"props.batch":728,"props.mixed":729,"props.symbolKind":730,"props.symbolSize":731,"props.hatchAngle":732,"props.hatchSpacing":733,"props.hatchSolid":734,"props.opacity":735,"props.imageWidth":736,"props.imageHeight":737,"props.source":738,"props.emittersPerPlant":739,"props.waterBalance":740,"props.eto":741,"props.kc":742,"props.kcPreset":743,"props.awc":744,"props.rootDepth":745,"props.mad":746,"props.wettedFraction":747,"props.plantSpacing":748,"props.rowSpacing":749,"props.etc":750,"props.interval":751,"props.offsetDistance":752,"props.copyOnTransform":753,"props.mirrorKeep":754,"props.splitOnInsert":755,"props.splineClosed":756,"props.angle":757,"props.leaderText":758,"props.dimRadius":759,"props.locked":760,"props.flushingFlow":761,"props.envelope":762,"props.envelopeBest":763,"props.envelopeRange":764,"props.envelopeNone":765,"sym.northArrow":766,"sym.tree":767,"sym.building":768,"sym.tank":769,"sym.well":770,"sym.valveBox":771,"sym.pumpHouse":772,"sym.gate":773,"sym.filterStation":774,"crop.citrus":775,"crop.grape":776,"crop.coffee":777,"crop.banana":778,"crop.mango":779,"crop.apple":780,"crop.tomato":781,"crop.maize":782,"crop.sugarcane":783,"crop.vegetables":784,"crop.turf":785,"crop.pasture":786,"crop.custom":787,"reports.flushing":788,"reports.surge":789,"reports.crop":790,"reports.schedule":791,"reports.profile":792,"rep.code":793,"rep.tapes":794,"rep.vFlush":795,"rep.celerity":796,"rep.surge":797,"rep.pStatic":798,"rep.pTotal":799,"rep.tCritical":800,"rep.raw":801,"rep.interval":802,"rep.netEvent":803,"rep.grossEvent":804,"rep.hoursEvent":805,"rep.overlapCu":806,"sch.date":807,"sch.flow":808,"sch.zones":809,"sch.start":810,"sch.end":811,"sch.duration":812,"prof.distance":813,"prof.elevation":814,"prof.hint":815,"prof.slope":816,"fit.coupler":817,"fit.elbow90":818,"fit.elbow45":819,"fit.tee":820,"fit.cross":821,"fit.reducer":822,"fit.endCap":823,"fit.adapter":824,"fit.takeOff":825,"fit.tapeEnd":826,"fit.riser":827,"bom.fittings":828,"bom.takeoffs":829,"bom.risers":830,"cat.fittings":831,"cat.kind":832,"cat.size2":833,"cat.supplier":834,"cat.code":835,"cat.add":836,"cat.duplicate":837,"cat.remove":838,"cat.import":839,"cat.export":840,"cat.exportCsv":841,"cat.reset":842,"cat.setDefault":843,"cat.importHint":844,"cat.removeConfirm":845,"cat.inUse":846,"msg.catalogImported":847,"msg.catalogDefaultSaved":848,"msg.catalogReset":849,"msg.lateralNeedsCatalog":850,"warn.lp_infeasible":851,"warn.fitting_missing":852,"warn.surge_rating_exceeded":853,"warn.schedule_no_area":854,"warn.schedule_over_24h":855,"file.importDrawing":856,"imp.points":857,"imp.shp":858,"imp.image":859,"imp.imageGeo":860,"imp.err.dem_bad_response":861,"imp.err.dem_bad_tile":862,"imp.err.dem_count_mismatch":863,"imp.err.points_empty":864,"imp.err.points_no_columns":865,"imp.err.shp_bad_header":866,"imp.err.shp_zip_no_shp":867,"imp.err.image_zip_no_image":868,"imp.err.image_unreadable":869,"imp.err.file_corrupt":870,"imp.err.image_too_large":871,"file.georefImage":872,"gimg.title":873,"gimg.explain":874,"gimg.keepAspect":875,"dlg.sizingMethod":876,"dlg.lp":877,"dlg.greedy":878,"dlg.maxLateralSizes":879,"dlg.maxMainlineSizes":880,"dlg.epp":881,"dlg.maxNodes":882,"dlg.zoneVar":883,"dlg.flushing":884,"dlg.flushV":885,"dlg.flushH":886,"dlg.checkSurge":887,"dlg.closure":888,"dlg.bom":889,"dlg.fittings":890,"dlg.stick":891,"design.pumpSelect":892,"design.dem3d":893,"pump.title":894,"pump.duty":895,"pump.supply":896,"pump.candidates":897,"pump.hAtDuty":898,"pump.margin":899,"pump.opPoint":900,"pump.power":901,"pump.parallel":902,"pump.energy":903,"pump.insert":904,"pump.replace":905,"pump.noSupply":906,"pump.unsuitable":907,"pump.suction":908,"msg.pumpApplied":909,"dem.title":910,"dem.exaggeration":911,"dem.hint":912,"dem.noData":913,"dem.range":914,"file.recent":915,"file.noRecent":916,"file.versions":917,"file.autosave":918,"rec.title":919,"rec.text":920,"rec.restore":921,"rec.discard":922,"rec.later":923,"rec.item":924,"msg.recovered":925,"ver.title":926,"ver.none":927,"ver.restore":928,"ver.item":929,"msg.versionRestored":930,"mgmt.flows":931,"mgmt.schedule":932,"mgmt.apply":933,"mgmt.export":934,"mgmt.days":935,"mgmt.dayStart":936,"mgmt.keepStart":937,"mgmt.maxDaily":938,"mgmt.needResults":939,"mgmt.perFlow":940,"sc.editCmds":941,"sc.gripRemove":942,"sc.gripInsert":943,"sc.touch":944,"tool.pivot":945,"hint.pivot":946,"tool.alignImage":947,"hint.alignImage":948,"align.step1":949,"align.step2":950,"align.step3":951,"align.step4":952,"align.keepScale":953,"msg.alignDone":954,"msg.alignSelectFirst":955,"msg.profileCleared":956,"elev.title":957,"elev.contourTitle":958,"elev.spotTitle":959,"elev.value":960,"elev.interval":961,"elev.autoIncrement":962,"elev.ask":963,"elev.explainContour":964,"elev.explainSpot":965,"menu.terrain":966,"terrain.onlineDem":967,"terrain.generateContours":968,"terrain.method":969,"terrain.tin":970,"terrain.idw":971,"terrain.clearProfile":972,"terrain.stats":973,"terrain.none":974,"dlg.terrainMethod":975,"dem.online.title":976,"dem.online.explain":977,"dem.online.source":978,"dem.online.spacing":979,"dem.online.extent":980,"dem.online.replace":981,"dem.online.existing":982,"dem.online.replaceExisting":983,"dem.online.keepWarn":984,"dem.online.mismatchTitle":985,"dem.online.mismatch":986,"dem.online.mismatchRemove":987,"dem.online.mismatchKeep":988,"dem.online.wait":989,"dem.online.estimate":990,"dem.online.limitHint":991,"dem.online.cancelled":992,"dem.online.noData":993,"dem.online.layerHint":994,"dem.online.useView":995,"dem.online.run":996,"dem.online.progress":997,"dem.online.done":998,"dem.online.needGeo":999,"dem.online.error":1000,"dem.online.empty":1001,"cgen.title":1002,"cgen.explain":1003,"cgen.interval":1004,"cgen.replace":1005,"cgen.preview":1006,"cgen.done":1007,"cgen.run":1008,"prof.clear":1009,"prof.ground":1010,"prof.pipe":1011,"prof.hgl":1012,"prof.lowest":1013,"prof.highest":1014,"prof.howTo":1015,"prof.noTerrain":1016,"prof.station":1017,"prof.pressure":1018,"prof.pathLabel":1019,"reports.pivots":1020,"rep.pivot":1021,"rep.type":1022,"rep.towers":1023,"rep.pAvail":1024,"rep.rise":1025,"rep.depthCycle":1026,"rep.hoursCycle":1027,"rep.appRatePeak":1028,"pivot.kindPivot":1029,"pivot.kindLinear":1030,"pivot.towers":1031,"bom.pivots":1032,"warn.pivot_pressure_deficit":1033,"warn.pivot_app_rate":1034,"warn.pivot_no_flow":1035,"warn.pivot_no_end_pressure":1036,"props.pivotKind":1037,"props.pivotRadius":1038,"props.pivotSpan":1039,"props.pivotTravel":1040,"props.pivotPipe":1041,"props.pivotPipeId":1042,"props.pivotC":1043,"props.pivotHeight":1044,"props.pivotEndP":1045,"props.pivotGunQ":1046,"props.pivotGunP":1047,"props.pivotThrow":1048,"props.pivotDepth":1049,"props.pivotHours":1050,"props.pivotWidth":1051,"props.pivotLoss":1052,"props.pivotMaxRate":1053,"props.pivotSector":1054,"props.pivotCost":1055,"props.pivotAngle":1056,"props.pivotResults":1057,"props.pivotArea":1058,"props.pivotInlet":1059,"props.contourInterval":1060,"props.derived":1061,"check.title":1062,"check.explain":1063,"check.summary":1064,"check.ok":1065,"check.run":1066,"check.sev.error":1067,"check.sev.warning":1068,"check.sev.info":1069,"check.no_hydraulics":1070,"check.no_supply":1071,"check.no_valves":1072,"check.unconnected":1073,"check.zone_no_emitters":1074,"check.duplicate_zone_name":1075,"check.mainline_dead_end":1076,"check.zone_dead_end":1077,"check.zero_length":1078,"check.tiny_segment":1079,"check.duplicate_item":1080,"check.pipes_cross":1081,"check.spec_missing":1082,"check.supply_no_head":1083,"check.pivot_unconnected":1084,"check.no_terrain":1085,"check.looped_mainline":1086,"check.area_no_emitters":1087,"adv.why":1088,"adv.how":1089,"adv.locate":1090,"adv.fixAll":1091,"adv.fixAllHint":1092,"adv.optimize":1093,"adv.level.error":1094,"adv.level.warning":1095,"adv.level.info":1096,"adv.none":1097,"adv.noneYet":1098,"adv.runHint":1099,"adv.designing":1100,"adv.working":1101,"adv.fixed":1102,"adv.fixFailed":1103,"adv.summaryTitle":1104,"adv.summaryNone":1105,"adv.summaryApplied":1106,"adv.remaining":1107,"adv.allClear":1108,"adv.undoHint":1109,"adv.undoAll":1110,"adv.problemsAfterDesign":1111,"adv.use.lateral":1112,"adv.use.zone":1113,"adv.use.mainline":1114,"opt.title":1115,"opt.explain":1116,"opt.pumps":1117,"opt.valves":1118,"opt.resizeAll":1119,"opt.run":1120,"opt.working":1121,"opt.before":1122,"opt.after":1123,"opt.capital":1124,"opt.energy":1125,"opt.annual":1126,"opt.problems":1127,"opt.kept":1128,"opt.reverted":1129,"opt.undo":1130,"opt.note":1131,"hist.fix":1132,"hist.autofix":1133,"hist.optimize":1134,"check.set_velocity":1135,"check.set_hours":1136,"check.set_economy":1137,"check.set_tolerance":1138,"check.set_variation":1139,"check.set_temperature":1140,"check.no_pipes_for_usage":1141,"check.supply_limits":1142,"check.valve_not_in_flow":1143,"check.flow_empty":1144,"check.flow_duration":1145,"check.emitter_head_range":1146,"check.pump_speed":1147,"fix.connect":1148,"fix.deleteItem":1149,"fix.cleanSegments":1150,"fix.removeDuplicates":1151,"fix.renameZone":1152,"fix.calculateSupply":1153,"fix.choosePump":1154,"fix.submersiblePump":1155,"fix.autoSizePipes":1156,"fix.raisePipeClass":1157,"fix.resizeValve":1158,"fix.assignModel":1159,"fix.splitFlows":1160,"fix.addFittings":1161,"fix.joinCrossing":1162,"fix.addSupply":1163,"fix.resetSettings":1164,"fix.addMissingFlow":1165,"fix.removeEmptyFlows":1166,"fix.fixFlowDurations":1167,"fix.nominalEmitterHead":1168,"fix.resetPumpSpeed":1169,"fix.fixSupplyLimits":1170,"fix.enablePipes":1171,"fixed.connect":1172,"fixed.deleteItem":1173,"fixed.cleanSegments":1174,"fixed.removeDuplicates":1175,"fixed.renameZone":1176,"fixed.calculateSupply":1177,"fixed.choosePump":1178,"fixed.insertPump":1179,"fixed.autoSizePipes":1180,"fixed.raisePipeClass":1181,"fixed.resizeValve":1182,"fixed.assignModel":1183,"fixed.splitFlows":1184,"fixed.addFittings":1185,"fixed.joinCrossing":1186,"fixed.addSupply":1187,"fixed.resetSettings":1188,"fixed.enablePipes":1189,"fixed.fixSupplyLimits":1190,"fixed.addMissingFlow":1191,"fixed.removeEmptyFlows":1192,"fixed.fixFlowDurations":1193,"fixed.nominalEmitterHead":1194,"fixed.resetPumpSpeed":1195,"fixed.lpSizing":1196,"fixfail.notFound":1197,"fixfail.nothingNear":1198,"fixfail.needsResults":1199,"fixfail.noSupply":1200,"fixfail.noDuty":1201,"fixfail.noPump":1202,"fixfail.alreadyBest":1203,"fixfail.noPipeAtSupply":1204,"fixfail.noChange":1205,"fixfail.noOption":1206,"adv.no_supply.why":1207,"adv.no_supply.how":1208,"adv.no_valves.why":1209,"adv.no_valves.how":1210,"adv.no_hydraulics.why":1211,"adv.no_hydraulics.how":1212,"adv.unconnected.why":1213,"adv.unconnected.how":1214,"adv.zero_length.why":1215,"adv.zero_length.how":1216,"adv.tiny_segment.why":1217,"adv.tiny_segment.how":1218,"adv.duplicate_item.why":1219,"adv.duplicate_item.how":1220,"adv.duplicate_zone_name.why":1221,"adv.duplicate_zone_name.how":1222,"adv.pipes_cross.why":1223,"adv.pipes_cross.how":1224,"adv.mainline_dead_end.why":1225,"adv.mainline_dead_end.how":1226,"adv.zone_dead_end.why":1227,"adv.zone_dead_end.how":1228,"adv.zone_no_emitters.why":1229,"adv.zone_no_emitters.how":1230,"adv.area_no_emitters.why":1231,"adv.area_no_emitters.how":1232,"adv.spec_missing.why":1233,"adv.spec_missing.how":1234,"adv.supply_no_head.why":1235,"adv.supply_no_head.how":1236,"adv.looped_mainline.why":1237,"adv.looped_mainline.how":1238,"adv.no_terrain.why":1239,"adv.no_terrain.how":1240,"adv.not_converged.why":1241,"adv.not_converged.how":1242,"adv.cannot_meet_pressure_window.why":1243,"adv.cannot_meet_pressure_window.how":1244,"adv.outlet_over_pressure.why":1245,"adv.outlet_over_pressure.how":1246,"adv.velocity_exceeded.why":1247,"adv.velocity_exceeded.how":1248,"adv.pressure_rating_exceeded.why":1249,"adv.pressure_rating_exceeded.how":1250,"adv.surge_rating_exceeded.why":1251,"adv.surge_rating_exceeded.how":1252,"adv.valve_flow_out_of_range.why":1253,"adv.valve_flow_out_of_range.how":1254,"adv.valve_pressure_deficit.why":1255,"adv.valve_pressure_deficit.how":1256,"adv.pivot_pressure_deficit.why":1257,"adv.pivot_pressure_deficit.how":1258,"adv.supply_flow_exceeded.why":1259,"adv.supply_flow_exceeded.how":1260,"adv.supply_head_exceeded.why":1261,"adv.supply_head_exceeded.how":1262,"adv.pump_out_of_range.why":1263,"adv.pump_out_of_range.how":1264,"adv.pump_suction_lift.why":1265,"adv.pump_suction_lift.how":1266,"adv.zone_overlap.why":1267,"adv.zone_overlap.how":1268,"adv.lp_infeasible.why":1269,"adv.lp_infeasible.how":1270,"adv.fitting_missing.why":1271,"adv.fitting_missing.how":1272,"adv.pivot_no_flow.why":1273,"adv.pivot_no_flow.how":1274,"adv.pivot_no_end_pressure.why":1275,"adv.pivot_no_end_pressure.how":1276,"adv.pivot_app_rate.why":1277,"adv.pivot_app_rate.how":1278,"adv.valve_missing.why":1279,"adv.valve_missing.how":1280,"adv.set_velocity.why":1281,"adv.set_velocity.how":1282,"adv.set_hours.why":1283,"adv.set_hours.how":1284,"adv.set_economy.why":1285,"adv.set_economy.how":1286,"adv.set_tolerance.why":1287,"adv.set_tolerance.how":1288,"adv.set_variation.why":1289,"adv.set_variation.how":1290,"adv.set_temperature.why":1291,"adv.set_temperature.how":1292,"adv.no_pipes_for_usage.why":1293,"adv.no_pipes_for_usage.how":1294,"adv.supply_limits.why":1295,"adv.supply_limits.how":1296,"adv.valve_not_in_flow.why":1297,"adv.valve_not_in_flow.how":1298,"adv.flow_empty.why":1299,"adv.flow_empty.how":1300,"adv.flow_duration.why":1301,"adv.flow_duration.how":1302,"adv.emitter_head_range.why":1303,"adv.emitter_head_range.how":1304,"adv.pump_speed.why":1305,"adv.pump_speed.how":1306,"design.checkFull":1307,"cat.packs":1308,"cat.packsExplain":1309,"cat.packAdd":1310,"cat.packAdded":1311,"cat.packItems":1312,"cat.exportXlsx":1313,"cat.importAny":1314,"mob.menu":1315,"mob.done":1316,"mob.cancel":1317,"mob.props":1318,"mob.tools":1319,"mob.hint":1320,"mob.group.nav":1321,"mob.group.draw":1322,"mob.group.edit":1323,"mob.group.terrain":1324,"mob.group.zone":1325,"mob.group.main":1326,"mob.selection":1327,"mob.project":1328,"mob.file":1329,"mob.view":1330,"mob.help":1331,"sc.mobile":1332,"dlg.followGuide":1333,"hist.title":1334,"hist.hint":1335,"hist.start":1336,"hist.edit":1337,"hist.add":1338,"hist.addMany":1339,"hist.delete":1340,"hist.move":1341,"hist.rotate":1342,"hist.scale":1343,"hist.mirror":1344,"hist.transform":1345,"hist.copy":1346,"hist.array":1347,"hist.block":1348,"hist.grid":1349,"hist.props":1350,"hist.import":1351,"hist.design":1352,"hist.contours":1353,"hist.dem":1354,"hist.demClear":1355,"hist.paste":1356,"hist.elevation":1357,"hist.align":1358,"hist.layer":1359,"plot.bomOnSheet":1360,"pdf.bom":1361,"pdf.qty":1362,"pdf.bomMore":1363,"imp.demTiff":1364,"reports.pivotSpans":1365,"rep.span":1366,"rep.rFrom":1367,"rep.rTo":1368,"rep.sprinklers":1369,"rep.qSprinkler":1370,"rep.pMid":1371,"rep.nozzleSuggested":1372,"props.pivotSprSpacing":1373,"props.pivotSprinkler":1374,"props.pivotRegulator":1375,"props.pivotTowerCost":1376,"pivot.towersItem":1377,"pivot.sprinklersItem":1378,"pivot.endGunItem":1379,"props.contourSmooth":1380,"dem.online.maxPoints":1381,"pump.motor":1382,"warn.lp_loops_approx":1383,"cat.packsBundled":1384,"cat.packsLoaded":1385,"cat.packImport":1386,"cat.packUrl":1387,"cat.packLoad":1388,"cat.packLoading":1389,"cat.packLoaded":1390,"cat.packLoadError":1391,"cat.packExport":1392,"cat.packExportTitle":1393,"cat.packExportExplain":1394,"cat.packBrand":1395,"cat.packName":1396,"cat.packDescription":1397,"cat.packSource":1398,"cat.packExported":1399,"cat.packFormat":1400,"cat.packFrom":1401,"imp.err.catalog_json_unknown":1402,"imp.err.catalog_index_not_pack":1403,"imp.err.catalog_index_unknown":1404,"imp.err.catalog_pack_version":1405,"dem.online.coord":1406,"dem.online.coordHint":1407,"dem.online.coordExplain":1408,"dem.online.useCoord":1409,"dem.online.areaSize":1410,"dem.online.coordInvalid":1411,"dem.online.contours":1412,"dem.online.contourInterval":1413,"dem.online.doneContours":1414,"msg.georefAt":1415,"file.examples":1416,"help.welcome":1417,"welcome.title":1418,"welcome.body":1419,"welcome.examples":1420,"welcome.examplesHint":1421,"welcome.tutorial":1422,"welcome.skip":1423,"exg.orchard.title":1424,"exg.orchard.sub":1425,"exg.orchard.tags":1426,"exg.garden.title":1427,"exg.garden.sub":1428,"exg.garden.tags":1429,"exg.sportsField.title":1430,"exg.sportsField.sub":1431,"exg.sportsField.tags":1432,"exg.rowCrop.title":1433,"exg.rowCrop.sub":1434,"exg.rowCrop.tags":1435,"exg.pivot.title":1436,"exg.pivot.sub":1437,"exg.pivot.tags":1438,"ex.shift":1439,"ex.g.name":1440,"ex.g.client":1441,"ex.g.site":1442,"ex.g.title":1443,"ex.g.lot":1444,"ex.g.house":1445,"ex.g.front":1446,"ex.g.back":1447,"ex.g.bed":1448,"ex.g.zone1":1449,"ex.g.zone2":1450,"ex.g.zone3":1451,"ex.g.supply":1452,"ex.g.grass":1453,"ex.g.shrubs":1454,"ex.g.main":1455,"ex.g.street":1456,"ex.f.name":1457,"ex.f.client":1458,"ex.f.site":1459,"ex.f.title":1460,"ex.f.pitch":1461,"ex.f.row":1462,"ex.f.tank":1463,"ex.f.pumpHouse":1464,"ex.f.grass":1465,"ex.f.main":1466,"ex.c.name":1467,"ex.c.client":1468,"ex.c.site":1469,"ex.c.title":1470,"ex.c.block":1471,"ex.c.tomato":1472,"ex.c.reservoir":1473,"ex.c.trunk":1474,"ex.c.west":1475,"ex.c.east":1476,"ex.c.road":1477,"ex.c.field":1478,"ex.p.name":1479,"ex.p.client":1480,"ex.p.site":1481,"ex.p.title":1482,"ex.p.pivot":1483,"ex.p.well":1484,"ex.p.maize":1485,"ex.p.adductor":1486,"ex.p.field":1487,"ex.p.boundary":1488,"exg.greenhouse.title":1489,"exg.greenhouse.sub":1490,"exg.greenhouse.tags":1491,"exg.nursery.title":1492,"exg.nursery.sub":1493,"exg.nursery.tags":1494,"exg.coffee.title":1495,"exg.coffee.sub":1496,"exg.coffee.tags":1497,"exg.bananas.title":1498,"exg.bananas.sub":1499,"exg.bananas.tags":1500,"exg.sugarcane.title":1501,"exg.sugarcane.sub":1502,"exg.sugarcane.tags":1503,"exg.gravity.title":1504,"exg.gravity.sub":1505,"exg.gravity.tags":1506,"exg.pasture.title":1507,"exg.pasture.sub":1508,"exg.pasture.tags":1509,"exg.golf.title":1510,"exg.golf.sub":1511,"exg.golf.tags":1512,"exg.sectorPivot.title":1513,"exg.sectorPivot.sub":1514,"exg.sectorPivot.tags":1515,"exg.linear.title":1516,"exg.linear.sub":1517,"exg.linear.tags":1518,"ex.gh.name":1519,"ex.gh.client":1520,"ex.gh.site":1521,"ex.gh.title":1522,"ex.gh.lot":1523,"ex.gh.tunnel":1524,"ex.gh.crop":1525,"ex.gh.tank":1526,"ex.gh.main":1527,"ex.nu.name":1528,"ex.nu.client":1529,"ex.nu.site":1530,"ex.nu.title":1531,"ex.nu.lot":1532,"ex.nu.bed":1533,"ex.nu.crop":1534,"ex.nu.tank":1535,"ex.nu.main":1536,"ex.cf.name":1537,"ex.cf.client":1538,"ex.cf.site":1539,"ex.cf.title":1540,"ex.cf.block":1541,"ex.cf.coffee":1542,"ex.cf.well":1543,"ex.cf.main":1544,"ex.cf.boundary":1545,"ex.ba.name":1546,"ex.ba.client":1547,"ex.ba.site":1548,"ex.ba.title":1549,"ex.ba.block":1550,"ex.ba.banana":1551,"ex.ba.well":1552,"ex.ba.field":1553,"ex.ba.road":1554,"ex.ba.main":1555,"ex.sc.name":1556,"ex.sc.client":1557,"ex.sc.site":1558,"ex.sc.title":1559,"ex.sc.block":1560,"ex.sc.cane":1561,"ex.sc.field":1562,"ex.sc.road":1563,"ex.sc.reservoir":1564,"ex.sc.trunk":1565,"ex.sc.west":1566,"ex.sc.east":1567,"ex.gr.name":1568,"ex.gr.client":1569,"ex.gr.site":1570,"ex.gr.title":1571,"ex.gr.block":1572,"ex.gr.crop":1573,"ex.gr.reservoir":1574,"ex.gr.prv":1575,"ex.gr.field":1576,"ex.gr.main":1577,"ex.gr.west":1578,"ex.gr.east":1579,"ex.pa.name":1580,"ex.pa.client":1581,"ex.pa.site":1582,"ex.pa.title":1583,"ex.pa.paddock":1584,"ex.pa.grass":1585,"ex.pa.fence":1586,"ex.pa.road":1587,"ex.pa.reservoir":1588,"ex.pa.main":1589,"ex.go.name":1590,"ex.go.client":1591,"ex.go.site":1592,"ex.go.title":1593,"ex.go.tee":1594,"ex.go.fairway":1595,"ex.go.fairwayZone":1596,"ex.go.green":1597,"ex.go.bunker":1598,"ex.go.pond":1599,"ex.go.turf":1600,"ex.go.pumpHouse":1601,"ex.go.main":1602,"ex.sp.name":1603,"ex.sp.client":1604,"ex.sp.site":1605,"ex.sp.title":1606,"ex.sp.pivot":1607,"ex.sp.soy":1608,"ex.sp.pond":1609,"ex.sp.farm":1610,"ex.sp.field":1611,"ex.sp.boundary":1612,"ex.sp.road":1613,"ex.sp.adductor":1614,"ex.li.name":1615,"ex.li.client":1616,"ex.li.site":1617,"ex.li.title":1618,"ex.li.machine":1619,"ex.li.wheat":1620,"ex.li.canal":1621,"ex.li.intake":1622,"ex.li.field":1623,"ex.li.boundary":1624,"ex.li.main":1625,"view.overlay.densogram":1626,"dens.menu":1627,"dens.title":1628,"dens.hint":1629,"dens.profile":1630,"dens.profile.triangular":1631,"dens.profile.elliptical":1632,"dens.profile.uniform":1633,"dens.cell":1634,"dens.useResults":1635,"dens.noResults":1636,"dens.zones":1637,"dens.results":1638,"dens.none":1639,"dens.sources":1640,"dens.target":1641,"dens.targetAreas":1642,"dens.targetWetted":1643,"dens.area":1644,"dens.cellUsed":1645,"dens.basis":1646,"dens.fromResults":1647,"dens.nominal":1648,"dens.mean":1649,"dens.minMax":1650,"dens.lowQuarter":1651,"dens.sc":1652,"dens.dry":1653,"dens.scHint":1654,"dens.exportCsv":1655,"dens.show":1656,"dens.legend":1657,"tool.controller":1658,"tool.wire":1659,"tool.dimOrdinate":1660,"hint.controller":1661,"hint.wire":1662,"hint.dimOrdinate":1663,"name.controller":1664,"mob.group.elec":1665,"layer.CONTROLLERS":1666,"layer.WIRES":1667,"layer.IMAGES":1668,"layer.HATCHES":1669,"layer.SYMBOLS":1670,"layer.PIVOTS":1671,"bom.electrical":1672,"elec.stationsShort":1673,"elec.splice":1674,"elec.stationTag":1675,"elec.used":1676,"elec.common":1677,"elec.maxOpen":1678,"elec.peak":1679,"elec.station":1680,"elec.stationWire":1681,"elec.volts":1682,"elec.commonRow":1683,"reports.electrical":1684,"msg.noElectrical":1685,"rep.controller":1686,"rep.station":1687,"rep.route":1688,"rep.wireLength":1689,"rep.stationWire":1690,"rep.commonWire":1691,"rep.openTogether":1692,"rep.solenoidV":1693,"props.diameter":1694,"props.dimDiameter":1695,"props.ordinateX":1696,"props.ordinateOrigin":1697,"props.stations":1698,"props.outputVolts":1699,"props.maxSimultaneous":1700,"cat.wires":1701,"cat.wire":1702,"cat.mm2":1703,"cat.ohmKm":1704,"dlg.electrical":1705,"dlg.inrushA":1706,"dlg.holdingA":1707,"dlg.minVolts":1708,"dlg.wireSlack":1709,"warn.elec_no_controller":1710,"warn.elec_unwired":1711,"warn.elec_wire_orphan":1712,"warn.elec_ctrl_unwired":1713,"warn.elec_no_wires":1714,"warn.elec_stations":1715,"warn.elec_voltage":1716,"warn.elec_simultaneous":1717,"adv.elec_no_controller.why":1718,"adv.elec_no_controller.how":1719,"adv.elec_unwired.why":1720,"adv.elec_unwired.how":1721,"adv.elec_wire_orphan.why":1722,"adv.elec_wire_orphan.how":1723,"adv.elec_ctrl_unwired.why":1724,"adv.elec_ctrl_unwired.how":1725,"adv.elec_no_wires.why":1726,"adv.elec_no_wires.how":1727,"adv.elec_stations.why":1728,"adv.elec_stations.how":1729,"adv.elec_voltage.why":1730,"adv.elec_voltage.how":1731,"adv.elec_simultaneous.why":1732,"adv.elec_simultaneous.how":1733,"fix.enableWires":1734,"fix.controllerStations":1735,"fixed.enableWires":1736,"fixed.controllerStations":1737,"hist.settings":1738,"hist.details":1739,"hist.params":1740,"hist.units":1741,"hist.catalog":1742,"hist.flows":1743,"mgmt.auto":1744,"mgmt.autoHint":1745,"mgmt.autoMaxFlow":1746,"mgmt.autoMaxValves":1747,"mgmt.autoCap":1748,"mgmt.autoNoCap":1749,"mgmt.autoRun":1750,"mgmt.autoResult":1751,"mgmt.autoOversized":1752,"mgmt.demand":1753}
B.oe=new A.a("OpenCADIrrigation","OpenCADIrrigation","OpenCADIrrigation")
B.r9=new A.a("OK","OK","Aceptar")
B.bW=new A.a("Cancelar","Cancel","Cancelar")
B.lD=new A.a("Aplicar","Apply","Aplicar")
B.nS=new A.a("Fechar","Close","Cerrar")
B.Ez=new A.a("Autom\xe1tico","Automatic","Autom\xe1tico")
B.ci=new A.a("Limpar","Clear","Limpiar")
B.ay=new A.a("Arquivo","File","Archivo")
B.c2=new A.a("Editar","Edit","Editar")
B.cH=new A.a("Ver","View","Ver")
B.c0=new A.a("Desenhar","Draw","Dibujar")
B.F=new A.a("Zona","Zone","Zona")
B.t=new A.a("Linha principal","Mainline","L\xednea principal")
B.cV=new A.a("Projeto","Design","Dise\xf1o")
B.oz=new A.a("Relat\xf3rios","Reports","Informes")
B.c6=new A.a("Ferramentas","Tools","Herramientas")
B.bP=new A.a("Ajuda","Help","Ayuda")
B.bJ=new A.a("Novo projeto","New project","Nuevo proyecto")
B.iF=new A.a("Abrir projeto\u2026","Open project\u2026","Abrir proyecto\u2026")
B.r2=new A.a("Salvar projeto","Save project","Guardar proyecto")
B.jy=new A.a("Exportar DXF","Export DXF","Exportar DXF")
B.ka=new A.a("Exportar desenho","Export drawing","Exportar dibujo")
B.jR=new A.a("Exportar relat\xf3rio","Export report","Exportar informe")
B.xn=new A.a("Georrefer\xeancia\u2026","Georeference\u2026","Georreferencia\u2026")
B.jO=new A.a("Nova aba de projeto","New project tab","Nueva pesta\xf1a de proyecto")
B.iq=new A.a("Fechar aba","Close tab","Cerrar pesta\xf1a")
B.CU=new A.a("Nova aba (Ctrl+Alt+N)","New tab (Ctrl+Alt+N)","Nueva pesta\xf1a (Ctrl+Alt+N)")
B.xW=new A.a("Fechar aba (Ctrl+Alt+W)","Close tab (Ctrl+Alt+W)","Cerrar pesta\xf1a (Ctrl+Alt+W)")
B.mu=new A.a("Copiar","Copy","Copiar")
B.tC=new A.a("Recortar","Cut","Cortar")
B.bX=new A.a("Colar","Paste","Pegar")
B.Da=new A.a("{n} itens copiados","{n} items copied","{n} elementos copiados")
B.Eb=new A.a("{n} itens recortados","{n} items cut","{n} elementos cortados")
B.xb=new A.a("Tubo cortado em 2 trechos","Pipe cut into 2 pieces","Tuber\xeda cortada en 2 tramos")
B.rN=new A.a("{n} itens colados","{n} items pasted","{n} elementos pegados")
B.c1=new A.a("Nada selecionado","Nothing selected","Nada seleccionado")
B.ke=new A.a("\xc1rea de transfer\xeancia vazia","Clipboard is empty","Portapapeles vac\xedo")
B.B9=new A.a("Comando desconhecido: {cmd} (veja Ajuda \u2192 Atalhos de teclado)","Unknown command: {cmd} (see Help \u2192 Keyboard shortcuts)","Comando desconocido: {cmd} (vea Ayuda \u2192 Atajos de teclado)")
B.mr=new A.a("Comando","Command","Comando")
B.jw=new A.a("Atalhos de teclado\u2026","Keyboard shortcuts\u2026","Atajos de teclado\u2026")
B.j1=new A.a("Atalhos de teclado","Keyboard shortcuts","Atajos de teclado")
B.pt=new A.a("Com o desenho em foco, digite o alias do comando e pressione Enter ou Espa\xe7o, como no AutoCAD (ex.: L \u23ce linha, PL \u23ce polilinha, ZE \u23ce enquadrar, E \u23ce apagar). Esc limpa o comando digitado. As combina\xe7\xf5es com Ctrl e as teclas F funcionam em qualquer parte da tela.","With the drawing focused, type the command alias and press Enter or Space, as in AutoCAD (e.g. L \u23ce line, PL \u23ce polyline, ZE \u23ce zoom extents, E \u23ce erase). Esc clears the typed command. Ctrl combinations and F keys work anywhere.","Con el dibujo enfocado, escriba el alias del comando y pulse Enter o Espacio, como en AutoCAD (p. ej. L \u23ce l\xednea, PL \u23ce polil\xednea, ZE \u23ce encuadrar, E \u23ce borrar). Esc limpia el comando. Las combinaciones con Ctrl y las teclas F funcionan en toda la pantalla.")
B.ra=new A.a("Arquivo e abas","File and tabs","Archivo y pesta\xf1as")
B.mH=new A.a("Edi\xe7\xe3o","Editing","Edici\xf3n")
B.xU=new A.a("Vista e desenho","View and drawing","Vista y dibujo")
B.k4=new A.a("Comandos (alias \u23ce)","Commands (alias \u23ce)","Comandos (alias \u23ce)")
B.lx=new A.a("Ferramentas hidr\xe1ulicas (alias \u23ce)","Hydraulic tools (alias \u23ce)","Herramientas hidr\xe1ulicas (alias \u23ce)")
B.yw=new A.a("Alternar aba de projeto","Switch project tab","Cambiar pesta\xf1a de proyecto")
B.qo=new A.a("Cancelar / voltar a selecionar","Cancel / back to select","Cancelar / volver a seleccionar")
B.nI=new A.a("Concluir polilinha / executar comando","Finish polyline / run command","Terminar polil\xednea / ejecutar comando")
B.w1=new A.a("Remover \xfaltimo ponto / apagar letra do comando","Remove last point / delete command letter","Quitar \xfaltimo punto / borrar letra del comando")
B.vY=new A.a("Repetir \xfaltima ferramenta (Enter ao selecionar)","Repeat last tool (Enter while selecting)","Repetir \xfaltima herramienta (Enter al seleccionar)")
B.li=new A.a("Aproximar / afastar","Zoom in / out","Acercar / alejar")
B.vA=new A.a("Deslocar vista","Pan view","Desplazar vista")
B.pO=new A.a("Mover vista (segurar; ou bot\xe3o do meio do mouse)","Pan (hold; or middle mouse button)","Mover vista (mantener; o bot\xf3n central del rat\xf3n)")
B.zv=new A.a("Mostrar/ocultar relat\xf3rios","Show/hide reports","Mostrar/ocultar informes")
B.vM=new A.a("Mostrar/ocultar grade","Show/hide grid","Mostrar/ocultar cuadr\xedcula")
B.vh=new A.a("Travar a linha em 0\xb0/45\xb0/90\xb0 enquanto desenha (segurar)","Lock the line to 0\xb0/45\xb0/90\xb0 while drawing (hold)","Bloquear la l\xednea en 0\xb0/45\xb0/90\xb0 mientras dibuja (mantener)")
B.l2=new A.a("Alias digitado executa sozinho ap\xf3s uma pausa (ou Enter/Espa\xe7o)","A typed alias runs by itself after a pause (or Enter/Space)","El alias escrito se ejecuta solo tras una pausa (o Intro/Espacio)")
B.yC=new A.a("Snap / orto / grade vis\xedvel / snap \xe0 grade","Snap / ortho / grid display / grid snap","Snap / orto / cuadr\xedcula visible / snap a cuadr\xedcula")
B.n3=new A.a("Projetar tudo / verificar conex\xf5es / relat\xf3rios","Design all / check connectivity / reports","Dise\xf1ar todo / verificar conexiones / informes")
B.j8=new A.a("DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)")
B.mX=new A.a("DWG (AutoCAD 2000, bin\xe1rio)","DWG (AutoCAD 2000, binary)","DWG (AutoCAD 2000, binario)")
B.uE=new A.a("PDF (prancha para impress\xe3o)\u2026","PDF (plot sheet)\u2026","PDF (l\xe1mina para impresi\xf3n)\u2026")
B.tS=new A.a("SVG (figura vetorial: web, Inkscape)","SVG (vector figure: web, Inkscape)","SVG (figura vectorial: web, Inkscape)")
B.u4=new A.a("KML (Google Earth)","KML (Google Earth)","KML (Google Earth)")
B.t1=new A.a("KMZ (Google Earth, compactado)","KMZ (Google Earth, zipped)","KMZ (Google Earth, comprimido)")
B.yA=new A.a("GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)")
B.tj=new A.a("CSV (planilha)","CSV (spreadsheet)","CSV (hoja de c\xe1lculo)")
B.iS=new A.a("TXT (texto)","TXT (plain text)","TXT (texto)")
B.D6=new A.a("XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)")
B.vW=new A.a("PDF (documento)","PDF (document)","PDF (documento)")
B.An=new A.a("Exportado: {f}","Exported: {f}","Exportado: {f}")
B.oV=new A.a("Execute o projeto (F5) antes de exportar o relat\xf3rio","Run the design (F5) before exporting the report","Ejecute el dise\xf1o (F5) antes de exportar el informe")
B.rg=new A.a("O desenho est\xe1 vazio","The drawing is empty","El dibujo est\xe1 vac\xedo")
B.ru=new A.a("Georrefer\xeancia definida: {crs}","Georeference set: {crs}","Georreferencia definida: {crs}")
B.z5=new A.a("Georrefer\xeancia do projeto","Project georeference","Georreferencia del proyecto")
B.vc=new A.a("Para exportar em KML, KMZ ou GeoJSON o desenho precisa de uma posi\xe7\xe3o no mundo. Informe a coordenada da origem do desenho (x = 0, y = 0). Projetos importados de KML/KMZ j\xe1 v\xeam georreferenciados.","To export KML, KMZ or GeoJSON the drawing needs a position on Earth. Enter the coordinate of the drawing origin (x = 0, y = 0). Projects imported from KML/KMZ are already georeferenced.","Para exportar en KML, KMZ o GeoJSON el dibujo necesita una posici\xf3n en el mundo. Indique la coordenada del origen del dibujo (x = 0, y = 0). Los proyectos importados de KML/KMZ ya vienen georreferenciados.")
B.x0=new A.a("Latitude / longitude (WGS84)","Latitude / longitude (WGS84)","Latitud / longitud (WGS84)")
B.B3=new A.a("UTM (WGS84)","UTM (WGS84)","UTM (WGS84)")
B.ql=new A.a("Latitude (\xb0)","Latitude (\xb0)","Latitud (\xb0)")
B.zH=new A.a("Longitude (\xb0)","Longitude (\xb0)","Longitud (\xb0)")
B.Am=new A.a("Fuso UTM (1\u201360)","UTM zone (1\u201360)","Huso UTM (1\u201360)")
B.nO=new A.a("Hemisf\xe9rio norte","Northern hemisphere","Hemisferio norte")
B.vm=new A.a("Este (m)","Easting (m)","Este (m)")
B.nj=new A.a("Norte (m)","Northing (m)","Norte (m)")
B.lz=new A.a("Atual: {crs} \xb7 origem E {e} m, N {n} m","Current: {crs} \xb7 origin E {e} m, N {n} m","Actual: {crs} \xb7 origen E {e} m, N {n} m")
B.l8=new A.a("Projeto ainda sem georrefer\xeancia","Project not georeferenced yet","Proyecto a\xfan sin georreferencia")
B.aH=new A.a("Remover","Remove","Quitar")
B.tJ=new A.a("Coordenadas inv\xe1lidas","Invalid coordinates","Coordenadas no v\xe1lidas")
B.nY=new A.a("Exportar PDF (prancha)","Export PDF (plot sheet)","Exportar PDF (l\xe1mina)")
B.u_=new A.a("Formato do papel","Paper size","Tama\xf1o de papel")
B.yW=new A.a("Orienta\xe7\xe3o","Orientation","Orientaci\xf3n")
B.rI=new A.a("Paisagem","Landscape","Horizontal")
B.tI=new A.a("Retrato","Portrait","Vertical")
B.xw=new A.a("Escala 1 :","Scale 1 :","Escala 1 :")
B.iO=new A.a("Ajustar \xe0 folha","Fit to sheet","Ajustar a la hoja")
B.aQ=new A.a("Raios molhados","Wetted radii","Radios mojados")
B.Bi=new A.a("R\xf3tulos e resultados","Labels and results","Etiquetas y resultados")
B.zq=new A.a("Legenda de camadas","Layer legend","Leyenda de capas")
B.rL=new A.a("Anexar p\xe1ginas de relat\xf3rio","Append report pages","Adjuntar p\xe1ginas de informe")
B.nC=new A.a("Exportar","Export","Exportar")
B.FF=new A.a("Escala autom\xe1tica: 1:{n}","Automatic scale: 1:{n}","Escala autom\xe1tica: 1:{n}")
B.c_=new A.a("Data","Date","Fecha")
B.nw=new A.a("Escala","Scale","Escala")
B.o_=new A.a("Folha","Sheet","Hoja")
B.cn=new A.a("Origem","Origin","Origen")
B.rw=new A.a("Zonas / emissores","Zones / outlets","Zonas / emisores")
B.ve=new A.a("Coordenadas","Coordinates","Coordenadas")
B.DH=new A.a("Locais (m)","Local (m)","Locales (m)")
B.q7=new A.a("Legenda","Legend","Leyenda")
B.zw=new A.a("Projeto de irriga\xe7\xe3o pressurizada","Pressurised irrigation design","Dise\xf1o de riego presurizado")
B.uX=new A.a("Relat\xf3rio de dimensionamento hidr\xe1ulico","Hydraulic design report","Informe de dise\xf1o hidr\xe1ulico")
B.y3=new A.a("Gerado por OpenCADIrrigation em {d}","Generated by OpenCADIrrigation on {d}","Generado por OpenCADIrrigation el {d}")
B.Fi=new A.a("P\xe1gina {i} de {n}","Page {i} of {n}","P\xe1gina {i} de {n}")
B.uu=new A.a("(continua\xe7\xe3o)","(continued)","(continuaci\xf3n)")
B.i3=new A.a("Sem resultados de dimensionamento: execute o projeto para incluir as tabelas hidr\xe1ulicas.","No design results: run the design to include the hydraulic tables.","Sin resultados de dise\xf1o: ejecute el dise\xf1o para incluir las tablas hidr\xe1ulicas.")
B.zr=new A.a("Par\xe2metros de projeto","Design parameters","Par\xe1metros de dise\xf1o")
B.n1=new A.a("Desenho","Drawing","Dibujo")
B.a4=new A.a("Texto","Text","Texto")
B.mx=new A.a("Cotas","Dimensions","Cotas")
B.yx=new A.a("Curvas de n\xedvel","Contours","Curvas de nivel")
B.vQ=new A.a("Pontos cotados","Spot heights","Puntos acotados")
B.BF=new A.a("MDT baixado","Downloaded DEM","MDT descargado")
B.nd=new A.a("Tubos de zona","Zone pipes","Tuber\xedas de zona")
B.m3=new A.a("Linha principal","Mainline pipes","L\xednea principal")
B.ns=new A.a("Laterais com emissores","Spraylines","Laterales con emisores")
B.Dq=new A.a("Fitas gotejadoras","Drip tapes","Cintas de goteo")
B.A=new A.a("Emissores","Outlets","Emisores")
B.Cq=new A.a("V\xe1lvulas de controle","Control valves","V\xe1lvulas de control")
B.zA=new A.a("Fontes de \xe1gua","Water supplies","Fuentes de agua")
B.aA=new A.a("Bombas","Pumps","Bombas")
B.cG=new A.a("Acess\xf3rios hidr\xe1ulicos","Hydraulic devices","Accesorios hidr\xe1ulicos")
B.jC=new A.a("N\xf3s","Junctions","Nudos")
B.lm=new A.a("\xc1reas irrigadas","Irrigated areas","\xc1reas regadas")
B.d8=new A.a("R\xf3tulos","Labels","Etiquetas")
B.yD=new A.a("Detalhes do projeto\u2026","Project details\u2026","Detalles del proyecto\u2026")
B.n2=new A.a("Desfazer","Undo","Deshacer")
B.tE=new A.a("Refazer","Redo","Rehacer")
B.oC=new A.a("Excluir sele\xe7\xe3o","Delete selection","Eliminar selecci\xf3n")
B.CT=new A.a("Selecionar tudo","Select all","Seleccionar todo")
B.ne=new A.a("Duplicar sele\xe7\xe3o","Duplicate selection","Duplicar selecci\xf3n")
B.m5=new A.a("Enquadrar tudo","Zoom all","Encuadrar todo")
B.BC=new A.a("Aproximar","Zoom in","Acercar")
B.r4=new A.a("Afastar","Zoom out","Alejar")
B.cd=new A.a("Grade","Grid","Cuadr\xedcula")
B.tM=new A.a("Sem resultados","No results overlay","Sin resultados")
B.we=new A.a("Colorir por velocidade","Colour by velocity","Colorear por velocidad")
B.FE=new A.a("Colorir por press\xe3o","Colour by pressure","Colorear por presi\xf3n")
B.jv=new A.a("Mostrar di\xe2metros","Show diameters","Mostrar di\xe1metros")
B.bV=new A.a("Camadas","Layers","Capas")
B.p1=new A.a("Idioma","Language","Idioma")
B.wm=new A.a("Portugu\xeas","Portuguese","Portugu\xe9s")
B.qR=new A.a("Ingl\xeas","English","Ingl\xe9s")
B.EI=new A.a("Espanhol","Spanish","Espa\xf1ol")
B.Fo=new A.a("Par\xe2metros de projeto\u2026","Design parameters\u2026","Par\xe1metros de dise\xf1o\u2026")
B.Bg=new A.a("Turnos de opera\xe7\xe3o (management)\u2026","System flows (management)\u2026","Turnos de operaci\xf3n\u2026")
B.xM=new A.a("Verifica\xe7\xe3o do projeto (Design Check)\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o (Design Check)\u2026")
B.w4=new A.a("Dimensionar zonas (LP/velocidade)","Size zones (LP/velocity)","Dimensionar zonas (LP/velocidad)")
B.ww=new A.a("Analisar (tamanhos atuais)","Analyse (existing sizes)","Analizar (tama\xf1os actuales)")
B.vr=new A.a("Dimensionar linha principal","Size mainline","Dimensionar l\xednea principal")
B.kH=new A.a("Projetar tudo","Design all","Dise\xf1ar todo")
B.r7=new A.a("Limpar resultados","Clear results","Limpiar resultados")
B.lh=new A.a("Calculando o projeto\u2026","Designing the system\u2026","Calculando el dise\xf1o\u2026")
B.of=new A.a("Montando a rede hidr\xe1ulica","Building the hydraulic network","Armando la red hidr\xe1ulica")
B.oR=new A.a("Zona {i} de {n}","Zone {i} of {n}","Zona {i} de {n}")
B.qe=new A.a("Linha principal e turnos de opera\xe7\xe3o","Mainline and system flows","L\xednea principal y turnos de operaci\xf3n")
B.oB=new A.a("Reanalisando trechos telescopados","Re-analysing telescoped pipes","Reanalizando tramos telescopados")
B.x2=new A.a("An\xe1lise de lavagem (flushing)","Flushing analysis","An\xe1lisis de lavado (flushing)")
B.jK=new A.a("Verifica\xe7\xe3o de golpe de ar\xedete","Water hammer check","Verificaci\xf3n de golpe de ariete")
B.a5=new A.a("Lista de materiais","Bill of materials","Lista de materiales")
B.Dl=new A.a("Calculando em segundo plano: navegue \xe0 vontade; edi\xe7\xf5es esperam o fim.","Running in the background: navigate freely; edits wait until it finishes.","Calculando en segundo plano: navega libremente; las ediciones esperan al final.")
B.CZ=new A.a("O navegador pode ficar lento enquanto o c\xe1lculo roda.","The browser may be slow while the calculation runs.","El navegador puede ir lento mientras corre el c\xe1lculo.")
B.Eq=new A.a("Cat\xe1logo de componentes\u2026","Component catalog\u2026","Cat\xe1logo de componentes\u2026")
B.xf=new A.a("Bloco de laterais\u2026","Lateral block\u2026","Bloque de laterales\u2026")
B.ua=new A.a("Aspersores autom\xe1ticos (grade)\u2026","Auto sprinklers (grid)\u2026","Aspersores autom\xe1ticos (malla)\u2026")
B.iJ=new A.a("Resumo das zonas","Zone summary","Resumen de zonas")
B.aC=new A.a("Tubos","Pipes","Tuber\xedas")
B.As=new A.a("Linha principal / duty","Mainline / duty","L\xednea principal / demanda")
B.pM=new A.a("Bombas e acess\xf3rios","Pumps and devices","Bombas y accesorios")
B.ij=new A.a("Requisitos h\xeddricos","Water requirements","Requerimientos h\xeddricos")
B.EL=new A.a("Linha piezom\xe9trica","Hydraulic grade line","L\xednea piezom\xe9trica")
B.qw=new A.a("Mensagens","Messages","Mensajes")
B.pP=new A.a("Calculadora de lateral\u2026","Lateral calculator\u2026","Calculadora de lateral\u2026")
B.AE=new A.a("Bomba e curva do sistema\u2026","Pump & system curve\u2026","Bomba y curva del sistema\u2026")
B.Cs=new A.a("Golpe de ar\xedete\u2026","Water hammer\u2026","Golpe de ariete\u2026")
B.j6=new A.a("Unidades\u2026","Units\u2026","Unidades\u2026")
B.rB=new A.a("Sobre","About","Acerca de")
B.A5=new A.a("Tutorial interativo","Interactive tutorial","Tutorial interactivo")
B.ue=new A.a("Selecionar","Select","Seleccionar")
B.xs=new A.a("Mover vista","Pan","Mover vista")
B.Ad=new A.a("Linha","Line","L\xednea")
B.j7=new A.a("Polilinha","Polyline","Polil\xednea")
B.wc=new A.a("Ret\xe2ngulo","Rectangle","Rect\xe1ngulo")
B.nf=new A.a("C\xedrculo","Circle","C\xedrculo")
B.mw=new A.a("Cota","Dimension","Cota")
B.uz=new A.a("Curva de n\xedvel","Contour","Curva de nivel")
B.ws=new A.a("Cota de ponto","Spot height","Cota de punto")
B.aN=new A.a("\xc1rea irrigada","Irrigated area","\xc1rea regada")
B.m6=new A.a("Tubo de zona","Zone pipe","Tuber\xeda de zona")
B.CV=new A.a("Tubo principal","Mainline pipe","Tuber\xeda principal")
B.jU=new A.a("Lateral (sprayline)","Sprayline (lateral)","Lateral (sprayline)")
B.cf=new A.a("Fita/tubo gotejador","Drip tape / dripline","Cinta/tuber\xeda de goteo")
B.a3=new A.a("Emissor","Outlet","Emisor")
B.mT=new A.a("V\xe1lvula de controle","Control valve","V\xe1lvula de control")
B.ps=new A.a("Fonte de \xe1gua","Water supply","Fuente de agua")
B.az=new A.a("Bomba","Pump","Bomba")
B.B_=new A.a("Acess\xf3rio hidr\xe1ulico","Misc. hydraulic","Accesorio hidr\xe1ulico")
B.rt=new A.a("Jun\xe7\xe3o","Junction","Nudo")
B.cR=new A.a("Bloco de laterais","Lateral block","Bloque de laterales")
B.bI=new A.a("Grade de aspersores","Sprinkler grid","Malla de aspersores")
B.qv=new A.a("Medir","Measure","Medir")
B.is=new A.a("Clique para selecionar, arraste para mover ou janela; Shift adiciona; Del exclui","Click to select, drag to move or window; Shift adds; Del deletes","Clic para seleccionar, arrastre para mover o ventana; Shift a\xf1ade; Supr elimina")
B.z1=new A.a("Arraste para mover a vista; roda do mouse para zoom","Drag to pan; mouse wheel zooms","Arrastre para mover la vista; rueda del rat\xf3n para zoom")
B.zW=new A.a("Clique no primeiro ponto, depois no segundo","Click first point, then second","Clic en el primer punto y luego en el segundo")
B.pT=new A.a("Clique nos v\xe9rtices; Enter/duplo clique termina; Esc cancela","Click vertices; Enter/double-click ends; Esc cancels","Clic en los v\xe9rtices; Intro/doble clic termina; Esc cancela")
B.BM=new A.a("Clique nos dois cantos opostos","Click two opposite corners","Clic en dos esquinas opuestas")
B.j3=new A.a("Clique no centro, depois no raio","Click centre, then radius","Clic en el centro y luego en el radio")
B.Ao=new A.a("Clique na posi\xe7\xe3o do texto","Click text position","Clic en la posici\xf3n del texto")
B.A0=new A.a("Clique nos dois pontos e depois na posi\xe7\xe3o da linha de cota","Click two points, then the dimension line position","Clic en dos puntos y luego en la posici\xf3n de la l\xednea de cota")
B.w5=new A.a("Clique os v\xe9rtices da curva de n\xedvel; Enter (ou Concluir) termina e pede a eleva\xe7\xe3o; Esc cancela","Click the contour vertices; Enter (or Done) finishes and asks for the elevation; Esc cancels","Clic en los v\xe9rtices de la curva de nivel; Intro (o Terminar) termina y pide la elevaci\xf3n; Esc cancela")
B.pV=new A.a("Clique onde fica a cota; a eleva\xe7\xe3o \xe9 pedida a cada ponto","Click where the spot height goes; the elevation is asked for each point","Clic donde va la cota; la elevaci\xf3n se pide en cada punto")
B.DI=new A.a("Clique nos v\xe9rtices do pol\xedgono; Enter fecha","Click polygon vertices; Enter closes","Clic en los v\xe9rtices del pol\xedgono; Intro cierra")
B.qi=new A.a("Clique nos v\xe9rtices do tubo; Enter/duplo clique termina; conecta automaticamente","Click pipe vertices; Enter/double-click ends; connects automatically","Clic en los v\xe9rtices de la tuber\xeda; Intro/doble clic termina; conecta autom\xe1ticamente")
B.Cg=new A.a("Clique sobre um tubo ou jun\xe7\xe3o para conectar","Click on a pipe or junction to connect","Clic sobre una tuber\xeda o nudo para conectar")
B.iL=new A.a("Clique nos v\xe9rtices do bloco; Enter conclui e abre as op\xe7\xf5es","Click block vertices; Enter finishes and opens options","Clic en los v\xe9rtices del bloque; Intro termina y abre las opciones")
B.qn=new A.a("Clique em dois pontos","Click two points","Clic en dos puntos")
B.rU=new A.a("Pronto","Ready","Listo")
B.uh=new A.a("Snap","Snap","Snap")
B.rl=new A.a("Orto","Ortho","Orto")
B.zQ=new A.a("Conex\xe3o","Linked","Conexi\xf3n")
B.j0=new A.a("Ao arrastar o n\xf3 de um tubo, as pontas de tubos e os itens ligados a ele acompanham o movimento","Dragging the node of a pipe drags along the pipe ends and items joined to it","Al arrastrar el nodo de una tuber\xeda, los extremos de tuber\xeda y los elementos unidos a \xe9l acompa\xf1an el movimiento")
B.uV=new A.a("ent.","ent.","ent.")
B.aO=new A.a("Propriedades","Properties","Propiedades")
B.y1=new A.a("{n} itens selecionados","{n} items selected","{n} elementos seleccionados")
B.me=new A.a("Camada","Layer","Capa")
B.aF=new A.a("Nome","Name","Nombre")
B.cX=new A.a("Tubo","Pipe","Tuber\xeda")
B.Aq=new A.a("Dimensionar automaticamente","Computer sized","Dimensionar autom\xe1ticamente")
B.p8=new A.a("Profundidade (m)","Depth (m)","Profundidad (m)")
B.bU=new A.a("Bocal","Nozzle","Boquilla")
B.Df=new A.a("Press\xe3o nominal","Nominal pressure","Presi\xf3n nominal")
B.B8=new A.a("Espa\xe7amento","Spacing","Espaciamiento")
B.DF=new A.a("Deslocamento do 1\xba emissor","First outlet offset","Desplazamiento del 1.\xba emisor")
B.AD=new A.a("Arco (\xb0)","Arc (\xb0)","Arco (\xb0)")
B.yl=new A.a("Altura da haste (m)","Riser height (m)","Altura del tubo de subida (m)")
B.ys=new A.a("Fita/tubo gotejador","Tape / dripline","Cinta/tuber\xeda de goteo")
B.ya=new A.a("Press\xe3o de entrada","Inlet pressure","Presi\xf3n de entrada")
B.tF=new A.a("Regulada","Regulated","Regulada")
B.xL=new A.a("Press\xe3o m\xedn. no submain","Submain min. pressure","Presi\xf3n m\xedn. en el submain")
B.bK=new A.a("V\xe1lvula","Valve","V\xe1lvula")
B.o7=new A.a("Press\xe3o a jusante fixa (vazio = calcular)","Fixed downstream pressure (blank = calculate)","Presi\xf3n aguas abajo fija (vac\xedo = calcular)")
B.BX=new A.a("Calcular press\xe3o necess\xe1ria","Calculate required pressure","Calcular presi\xf3n necesaria")
B.FB=new A.a("Press\xe3o de projeto","Design pressure","Presi\xf3n de dise\xf1o")
B.FI=new A.a("Press\xe3o m\xe1xima","Maximum pressure","Presi\xf3n m\xe1xima")
B.wP=new A.a("Vaz\xe3o de projeto","Design flow","Caudal de dise\xf1o")
B.nZ=new A.a("Vaz\xe3o m\xe1xima","Maximum flow","Caudal m\xe1ximo")
B.EG=new A.a("N\xedvel de \xe1gua relativo ao solo (m)","Water level relative to ground (m)","Nivel de agua respecto al suelo (m)")
B.co=new A.a("Rota\xe7\xe3o relativa","Relative speed","Velocidad relativa")
B.d5=new A.a("Acess\xf3rio","Device","Accesorio")
B.t2=new A.a("Press\xe3o regulada (PRV)","Regulated pressure (PRV)","Presi\xf3n regulada (PRV)")
B.aP=new A.a("Eleva\xe7\xe3o (m)","Elevation (m)","Elevaci\xf3n (m)")
B.x6=new A.a("Eleva\xe7\xe3o (m; 0 = do terreno)","Elevation (m; 0 = from DEM)","Elevaci\xf3n (m; 0 = del terreno)")
B.j_=new A.a("Altura do texto (m)","Text height (m)","Altura del texto (m)")
B.jA=new A.a("Raio (m)","Radius (m)","Radio (m)")
B.nR=new A.a("Fechado","Closed","Cerrado")
B.jo=new A.a("L\xe2mina l\xedquida (mm/dia)","Net depth (mm/day)","L\xe1mina neta (mm/d\xeda)")
B.kE=new A.a("Efici\xeancia","Efficiency","Eficiencia")
B.mB=new A.a("Cultura","Crop","Cultivo")
B.bY=new A.a("Comprimento","Length","Longitud")
B.aJ=new A.a("\xc1rea","Area","\xc1rea")
B.pi=new A.a("Escopo","Scope","\xc1mbito")
B.ct=new A.a("Resultados","Results","Resultados")
B.Dt=new A.a("Orienta\xe7\xe3o (\xb0)","Orientation (\xb0)","Orientaci\xf3n (\xb0)")
B.pN=new A.a("Rota\xe7\xe3o (\xb0)","Rotation (\xb0)","Rotaci\xf3n (\xb0)")
B.t0=new A.a("Afastamento da cota","Dimension offset","Desplazamiento de la cota")
B.Fs=new A.a("Enquadrar","Zoom to","Encuadrar")
B.DV=new A.a("1\xba emissor a meio espa\xe7amento","First outlet at half spacing","1.\xba emisor a medio espaciamiento")
B.il=new A.a("P a jusante","Downstream P","P aguas abajo")
B.d_=new A.a("P requerida","Required P","P requerida")
B.Fq=new A.a("Perda na v\xe1lvula","Valve loss","P\xe9rdida en la v\xe1lvula")
B.x5=new A.a("Emissor m\xedn/m\xe1x","Outlet min/max","Emisor m\xedn/m\xe1x")
B.FA=new A.a("Admiss\xedvel","Allowable","Admisible")
B.EC=new A.a("CU / DU / EU","CU / DU / EU","CU / DU / EU")
B.z7=new A.a("valores padr\xe3o","defaults","valores predeterminados")
B.aD=new A.a("Vaz\xe3o","Flow","Caudal")
B.vp=new A.a("Velocidade","Velocity","Velocidad")
B.BY=new A.a("Perda de carga","Head loss","P\xe9rdida de carga")
B.aE=new A.a("Press\xe3o","Pressure","Presi\xf3n")
B.lV=new A.a("Press\xe3o in\xedcio","Start pressure","Presi\xf3n inicio")
B.F0=new A.a("Press\xe3o fim","End pressure","Presi\xf3n final")
B.xX=new A.a("M\xedn","Min","M\xedn")
B.oF=new A.a("M\xe1x","Max","M\xe1x")
B.lr=new A.a("Projeto salvo","Project saved","Proyecto guardado")
B.vo=new A.a("Projeto carregado","Project loaded","Proyecto cargado")
B.lG=new A.a("Projeto conclu\xeddo: {z} zonas, {f} turnos","Design finished: {z} zones, {f} system flows","Dise\xf1o terminado: {z} zonas, {f} turnos")
B.zN=new A.a("{n} itens n\xe3o conectados (marcados em vermelho)","{n} unconnected items (marked in red)","{n} elementos sin conectar (marcados en rojo)")
B.lM=new A.a("Todos os itens est\xe3o conectados","All items are connected","Todos los elementos est\xe1n conectados")
B.pS=new A.a("C\xe1lculo em andamento: aguarde para editar o projeto.","Design running: wait for it to finish before editing.","C\xe1lculo en curso: espera a que termine para editar.")
B.zl=new A.a("O projeto mudou durante o c\xe1lculo; resultados descartados. Rode o c\xe1lculo de novo.","The project changed while the design ran; results discarded. Run the design again.","El proyecto cambi\xf3 durante el c\xe1lculo; resultados descartados. Ejecuta el c\xe1lculo de nuevo.")
B.AJ=new A.a("Nenhuma v\xe1lvula de controle no projeto","No control valve in the design","No hay v\xe1lvulas de control en el dise\xf1o")
B.zO=new A.a("{n} itens exclu\xeddos","{n} items deleted","{n} elementos eliminados")
B.p4=new A.a("Importado","Imported","Importado")
B.rn=new A.a("Erro: {e}","Error: {e}","Error: {e}")
B.CM=new A.a("O projeto atual tem altera\xe7\xf5es n\xe3o salvas. Continuar?","The current project has unsaved changes. Continue?","El proyecto actual tiene cambios sin guardar. \xbfContinuar?")
B.oS=new A.a("Execute Projeto \u25b6 para gerar resultados","Run Design \u25b6 to generate results","Ejecute Dise\xf1o \u25b6 para generar resultados")
B.vT=new A.a("Desenhe \xe1reas irrigadas (ferramenta \xc1rea) para calcular tempos de irriga\xe7\xe3o","Draw irrigated areas (Area tool) to compute irrigation times","Dibuje \xe1reas regadas (herramienta \xc1rea) para calcular tiempos de riego")
B.B6=new A.a("Selecione um tubo, lateral ou v\xe1lvula","Select a pipe, lateral or valve","Seleccione una tuber\xeda, lateral o v\xe1lvula")
B.xj=new A.a("Sem mensagens","No messages","Sin mensajes")
B.zf=new A.a("N\xe3o conectado","Not connected","Sin conectar")
B.wM=new A.a("DWG {v}: {n} entidades, {l} camadas","DWG {v}: {n} entities, {l} layers","DWG {v}: {n} entidades, {l} capas")
B.E9=new A.a(", {n} objetos ignorados",", {n} objects skipped",", {n} objetos omitidos")
B.Cu=new A.a(u.n,"{k}: {p} placemarks, {n} entities ({crs})",u.n)
B.xD=new A.a("DXF: {n} entidades","DXF: {n} entities","DXF: {n} entidades")
B.F3=new A.a("N\xe3o \xe9 um arquivo DWG reconhecido","Not a recognised DWG file","No es un archivo DWG reconocido")
B.xr=new A.a("Estrutura do DWG n\xe3o encontrada (arquivo danificado ou variante n\xe3o suportada)","DWG structure not found (damaged file or unsupported variant)","Estructura del DWG no encontrada (archivo da\xf1ado o variante no compatible)")
B.nX=new A.a("KMZ sem arquivo .kml","KMZ without a .kml file","KMZ sin archivo .kml")
B.k3=new A.a("P jusante","Downstream P","P aguas abajo")
B.vd=new A.a("Perda v\xe1lv.","Valve loss","P\xe9rdida v\xe1lv.")
B.d4=new A.a("P m\xedn","Min P","P m\xedn")
B.cw=new A.a("P m\xe1x","Max P","P m\xe1x")
B.EK=new A.a("Adm. m\xedn","Allow. min","Adm. m\xedn")
B.zU=new A.a("Adm. m\xe1x","Allow. max","Adm. m\xe1x")
B.AL=new A.a("Var. adm. %","Allow. var. %","Var. adm. %")
B.F6=new A.a("Var. real %","Actual var. %","Var. real %")
B.Bv=new A.a("Custo tubos","Pipe cost","Costo tuber\xedas")
B.lJ=new A.a("Avisos","Warnings","Avisos")
B.mt=new A.a("Contexto","Context","Contexto")
B.nt=new A.a("Entidade","Entity","Entidad")
B.p2=new A.a("Seg.","Seg.","Seg.")
B.mQ=new A.a("DI","ID","DI")
B.cg=new A.a("L","L","L")
B.t6=new A.a("Q","Q","Q")
B.q_=new A.a("V (m/s)","V (m/s)","V (m/s)")
B.zJ=new A.a("hf","hf","hf")
B.iT=new A.a("P in\xedcio","Start P","P inicio")
B.id=new A.a("P fim","End P","P fin")
B.wU=new A.a("Z in\xedcio","Start Z","Z inicio")
B.oq=new A.a("Z fim","End Z","Z fin")
B.rA=new A.a("PN","PN","PN")
B.qQ=new A.a("N","N","N")
B.Du=new A.a("Q total","Total Q","Q total")
B.Fg=new A.a("Q m\xe9dio","Mean Q","Q medio")
B.aG=new A.a("Turno","System flow","Turno")
B.p7=new A.a("Item","Item","Elemento")
B.kJ=new A.a("P dispon\xedvel","Available P","P disponible")
B.vR=new A.a("Situa\xe7\xe3o","Status","Estado")
B.cK=new A.a("Energia/ano","Energy/year","Energ\xeda/a\xf1o")
B.aB=new A.a("Fonte","Supply","Fuente")
B.xE=new A.a("calculada","calculated","calculada")
B.Dw=new A.a("sobra","surplus","sobra")
B.yR=new A.a("fixa","fixed","fija")
B.Ee=new A.a("d\xe9ficit","deficit","d\xe9ficit")
B.C3=new A.a("ok","ok","ok")
B.kp=new A.a("H bomba","Pump H","H bomba")
B.Ax=new A.a("P entrada","Inlet P","P entrada")
B.l_=new A.a("P sa\xedda","Outlet P","P salida")
B.wg=new A.a("Perda","Loss","P\xe9rdida")
B.tz=new A.a("em opera\xe7\xe3o","running","en operaci\xf3n")
B.Ci=new A.a("parada","stopped","detenida")
B.x_=new A.a("aberto","open","abierto")
B.yN=new A.a("fechado","closed","cerrado")
B.D1=new A.a("regulando","regulating","regulando")
B.mJ=new A.a("suc\xe7\xe3o","suction lift","succi\xf3n")
B.Dy=new A.a("submersa","submersible","sumergible")
B.r8=new A.a("fora da faixa","out of range","fuera de rango")
B.rz=new A.a("Categoria","Category","Categor\xeda")
B.C5=new A.a("Descri\xe7\xe3o","Description","Descripci\xf3n")
B.Ai=new A.a("Un.","Unit","Ud.")
B.tl=new A.a("Quantidade","Quantity","Cantidad")
B.yt=new A.a("Unit\xe1rio","Unit cost","Unitario")
B.uP=new A.a("Total","Total","Total")
B.uC=new A.a("TOTAL","TOTAL","TOTAL")
B.D3=new A.a("Custo anualizado (capital)","Annualised cost (capital)","Costo anualizado (capital)")
B.z6=new A.a("Custo anual de energia","Annual energy cost","Costo anual de energ\xeda")
B.d6=new A.a("Custo anual total","Total annual cost","Costo anual total")
B.xR=new A.a("L\xe2mina bruta (mm/d)","Gross depth (mm/d)","L\xe1mina bruta (mm/d)")
B.ie=new A.a("Volume (m\xb3/d)","Volume (m\xb3/d)","Volumen (m\xb3/d)")
B.iB=new A.a("Taxa (mm/h)","Rate (mm/h)","Tasa (mm/h)")
B.oj=new A.a("Horas/dia","Hours/day","Horas/d\xeda")
B.qP=new A.a("HGL (azul) \xb7 terreno (marrom) \xb7 faixa admiss\xedvel (verde)","HGL (blue) \xb7 ground (brown) \xb7 allowable band (green)","LP (azul) \xb7 terreno (marr\xf3n) \xb7 banda admisible (verde)")
B.wx=new A.a("ZONAS","ZONES","ZONAS")
B.Do=new A.a("TURNOS","SYSTEM FLOWS","TURNOS")
B.Ej=new A.a("LISTA DE MATERIAIS","BILL OF MATERIALS","LISTA DE MATERIALES")
B.oW=new A.a("Fitas/tubos gotejadores","Drip tapes/lines","Cintas/tuber\xedas de goteo")
B.cU=new A.a("V\xe1lvulas","Valves","V\xe1lvulas")
B.xO=new A.a("Todas as zonas","All zones","Todas las zonas")
B.un=new A.a("Submain","Submain","Submain")
B.uQ=new A.a("Trecho","Stub","Tramo")
B.D2=new A.a("relatorio","report","informe")
B.vy=new A.a("Exemplo pomar","Orchard example","Ejemplo huerto")
B.z=new A.a("Fazenda Exemplo","Example Farm","Finca Ejemplo")
B.ko=new A.a("Blocos A e B","Blocks A and B","Bloques A y B")
B.n5=new A.a("Divisa","Boundary","Lindero")
B.zo=new A.a("Pomar \u2014 exemplo OpenCADIrrigation","Orchard \u2014 OpenCADIrrigation example","Huerto \u2014 ejemplo OpenCADIrrigation")
B.qg=new A.a("Zona A","Zone A","Zona A")
B.qh=new A.a("Zona B","Zone B","Zona B")
B.AB=new A.a("Bloco A","Block A","Bloque A")
B.yV=new A.a("Bloco B","Block B","Bloque B")
B.cu=new A.a("Citros","Citrus","C\xedtricos")
B.cE=new A.a("Uva","Grapes","Uva")
B.o3=new A.a("Recalque","Rising main","Impulsi\xf3n")
B.AZ=new A.a("Ramal A","Branch A","Ramal A")
B.Eo=new A.a("Ramal B","Branch B","Ramal B")
B.Q=new A.a("Po\xe7o","Well","Pozo")
B.EW=new A.a("Turno 1 \u2014 Zona A","Flow 1 \u2014 Zone A","Turno 1 \u2014 Zona A")
B.uy=new A.a("Turno 2 \u2014 Zona B","Flow 2 \u2014 Zone B","Turno 2 \u2014 Zona B")
B.rT=new A.a("Projeto","Project","Proyecto")
B.mp=new A.a("Cliente","Client","Cliente")
B.qc=new A.a("Local","Site","Lugar")
B.rS=new A.a("Projetista","Designer","Proyectista")
B.r_=new A.a("Notas","Notes","Notas")
B.wf=new A.a("Hidr\xe1ulica","Hydraulics","Hidr\xe1ulica")
B.p_=new A.a("F\xf3rmula de perda de carga","Head-loss formula","F\xf3rmula de p\xe9rdida de carga")
B.ii=new A.a("Hazen-Williams","Hazen-Williams","Hazen-Williams")
B.yT=new A.a("Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)")
B.i_=new A.a("Temperatura da \xe1gua (\xb0C)","Water temperature (\xb0C)","Temperatura del agua (\xb0C)")
B.hZ=new A.a("Vel. m\xe1x. lateral (m/s)","Max. lateral velocity (m/s)","Vel. m\xe1x. lateral (m/s)")
B.Au=new A.a("Vel. m\xe1x. zona (m/s)","Max. zone velocity (m/s)","Vel. m\xe1x. zona (m/s)")
B.lN=new A.a("Vel. m\xe1x. linha principal (m/s)","Max. mainline velocity (m/s)","Vel. m\xe1x. l\xednea principal (m/s)")
B.ol=new A.a("Perdas localizadas (% do comprimento)","Minor losses (% of length)","P\xe9rdidas localizadas (% de la longitud)")
B.Db=new A.a("Toler\xe2ncia de conex\xe3o (m)","Connection tolerance (m)","Tolerancia de conexi\xf3n (m)")
B.pB=new A.a("Aplicar perdas localizadas","Apply minor losses","Aplicar p\xe9rdidas localizadas")
B.zZ=new A.a("Fator C: escala","C factor: scale","Factor C: escala")
B.q6=new A.a("Fator C: acr\xe9scimo","C factor: offset","Factor C: incremento")
B.v1=new A.a("Dimensionamento","Sizing","Dimensionamiento")
B.rx=new A.a("N\xba m\xe1x. de di\xe2metros no submain","Max. submain sizes","N.\xba m\xe1x. de di\xe1metros en el submain")
B.pH=new A.a("Densifica\xe7\xe3o do DEM (m)","DEM densification (m)","Densificaci\xf3n del MDT (m)")
B.jE=new A.a("Economia","Economics","Econom\xeda")
B.ly=new A.a("Balancear custo de capital vs. custo de energia","Trade capital cost vs. energy cost","Equilibrar costo de capital vs. costo de energ\xeda")
B.Eh=new A.a("Juros (fra\xe7\xe3o/ano)","Interest (fraction/year)","Inter\xe9s (fracci\xf3n/a\xf1o)")
B.Dh=new A.a("Prazo (anos)","Term (years)","Plazo (a\xf1os)")
B.w_=new A.a("Custo da energia ({c}/kWh)","Energy cost ({c}/kWh)","Costo de la energ\xeda ({c}/kWh)")
B.nq=new A.a("Efici\xeancia da bomba (fra\xe7\xe3o)","Pump efficiency (fraction)","Eficiencia de la bomba (fracci\xf3n)")
B.DJ=new A.a("Horas de opera\xe7\xe3o/ano (linha principal)","Operating hours/year (mainline)","Horas de operaci\xf3n/a\xf1o (l\xednea principal)")
B.mY=new A.a("Horas/ano por zona","Hours/year per zone","Horas/a\xf1o por zona")
B.ck=new A.a("Moeda","Currency","Moneda")
B.wG=new A.a("S\xedmbolo da moeda","Currency symbol","S\xedmbolo de la moneda")
B.q8=new A.a("Os pre\xe7os do cat\xe1logo padr\xe3o s\xe3o ilustrativos: uma tabela em reais convertida pelo c\xe2mbio de {d}. Substitua-os pela tabela de pre\xe7os local.","Built-in catalogue prices are illustrative: a price list in reais converted with the exchange rates of {d}. Replace them with your local price list.","Los precios del cat\xe1logo predeterminado son ilustrativos: una lista en reales convertida con el tipo de cambio del {d}. Sustit\xfayalos por la lista de precios local.")
B.C6=new A.a("Converter os pre\xe7os?","Convert the prices?","\xbfConvertir los precios?")
B.xk=new A.a('Converter todos os pre\xe7os do projeto (cat\xe1logo, custo da energia, piv\xf4s) de {from} para {to}? "S\xf3 trocar a moeda" mant\xe9m os n\xfameros como est\xe3o.','Convert every price of the project (catalogue, energy cost, pivots) from {from} to {to}? "Change the currency only" keeps the numbers as they are.','\xbfConvertir todos los precios del proyecto (cat\xe1logo, costo de la energ\xeda, pivotes) de {from} a {to}? "Solo cambiar la moneda" mantiene los n\xfameros como est\xe1n.')
B.iP=new A.a("C\xe2mbio ({to} por 1 {from})","Exchange rate ({to} per 1 {from})","Tipo de cambio ({to} por 1 {from})")
B.yY=new A.a("C\xe2mbio de refer\xeancia de {d} (Banco Central Europeu / exchangerate-api.com). Ajuste para a cota\xe7\xe3o do dia.","Reference rate of {d} (European Central Bank / exchangerate-api.com). Adjust it to the rate of the day.","Tipo de cambio de referencia del {d} (Banco Central Europeo / exchangerate-api.com). Aj\xfastelo a la cotizaci\xf3n del d\xeda.")
B.ip=new A.a("Sem c\xe2mbio de refer\xeancia para esta moeda: informe a taxa.","No reference rate for this currency: enter the rate.","Sin tipo de cambio de referencia para esta moneda: indique la tasa.")
B.lS=new A.a("S\xf3 trocar a moeda","Change the currency only","Solo cambiar la moneda")
B.rZ=new A.a("Converter pre\xe7os","Convert prices","Convertir precios")
B.cO=new A.a("Pre\xe7os convertidos de {from} para {to} (\xd7 {r}).","Prices converted from {from} to {to} (\xd7 {r}).","Precios convertidos de {from} a {to} (\xd7 {r}).")
B.iy=new A.a("Pre\xe7os em {c}","Prices in {c}","Precios en {c}")
B.pW=new A.a("Sem pre\xe7os (preencha com a tabela local)","No prices (fill in your local price list)","Sin precios (complete con la lista local)")
B.o1=new A.a("Fontes","Sources","Fuentes")
B.xK=new A.a("O pacote n\xe3o informa a moeda: pre\xe7os mantidos como est\xe3o.","The pack does not state its currency: prices kept as they are.","El paquete no indica la moneda: precios mantenidos como est\xe1n.")
B.l6=new A.a("Itens do cat\xe1logo sem pre\xe7o","Catalogue items without a price","Elementos del cat\xe1logo sin precio")
B.qb=new A.a("Alguns itens da lista de materiais est\xe3o com pre\xe7o zero, em geral produtos adicionados de um cat\xe1logo de fabricante (que v\xeam sem pre\xe7o). Os totais os deixam de fora e, para tubos sem pre\xe7o, o dimensionamento econ\xf4mico usa uma estimativa proporcional \xe0 parede do tubo.","Some items in the bill of materials have price zero, usually products added from a manufacturer catalogue (they come without prices). The totals leave them out, and for pipes without a price the economic sizing uses an estimate proportional to the pipe wall.","Algunos elementos de la lista de materiales tienen precio cero, en general productos a\xf1adidos desde un cat\xe1logo de fabricante (que vienen sin precio). Los totales los dejan fuera y, para las tuber\xedas sin precio, el dimensionamiento econ\xf3mico usa una estimaci\xf3n proporcional a la pared del tubo.")
B.AC=new A.a("Informe os pre\xe7os no Cat\xe1logo de componentes (ou exporte para Excel, preencha com a sua tabela e importe de volta) e calcule de novo.","Enter the prices in the Component catalog (or export it to Excel, fill in your price list and import it back), then design again.","Indique los precios en el Cat\xe1logo de componentes (o exp\xf3rtelo a Excel, complete con su lista e imp\xf3rtelo de vuelta) y calcule de nuevo.")
B.qp=new A.a("M\xe9trico","Metric","M\xe9trico")
B.rD=new A.a("US","US","EE. UU.")
B.cQ=new A.a("Di\xe2metro","Diameter","Di\xe1metro")
B.jj=new A.a("Todas juntas","All together","Todas juntas")
B.wo=new A.a("Uma por vez","One at a time","Una a la vez")
B.zy=new A.a("+ Turno","+ Flow","+ Turno")
B.yr=new A.a("In\xedcio (h)","Start (h)","Inicio (h)")
B.cZ=new A.a("Dura\xe7\xe3o (h)","Duration (h)","Duraci\xf3n (h)")
B.Cl=new A.a("Sem turnos definidos: todas as zonas ser\xe3o consideradas operando juntas.","No system flows defined: all zones are assumed to run together.","Sin turnos definidos: se considera que todas las zonas funcionan juntas.")
B.CF=new A.a("Aspers\xe3o / microaspers\xe3o","Sprinkler / micro-sprinkler","Aspersi\xf3n / microaspersi\xf3n")
B.EZ=new A.a("Gotejamento (fita/tubo)","Drip (tape/line)","Goteo (cinta/tuber\xeda)")
B.q4=new A.a("Laterais","Laterals","Laterales")
B.mE=new A.a("Espa\xe7amento entre emissores","Outlet spacing","Espaciamiento entre emisores")
B.AF=new A.a("Tubo da lateral","Lateral pipe","Tuber\xeda de la lateral")
B.mC=new A.a("Espa\xe7amento entre laterais","Lateral spacing","Espaciamiento entre laterales")
B.oZ=new A.a("Dire\xe7\xe3o das laterais (\xb0)","Lateral direction (\xb0)","Direcci\xf3n de las laterales (\xb0)")
B.uD=new A.a("Submain e v\xe1lvula","Submain and valve","Submain y v\xe1lvula")
B.m1=new A.a("Posi\xe7\xe3o do submain","Submain position","Posici\xf3n del submain")
B.xt=new A.a("In\xedcio das laterais","Start of laterals","Inicio de las laterales")
B.yL=new A.a("Centro (laterais pareadas)","Centre (paired laterals)","Centro (laterales pareadas)")
B.yI=new A.a("Fim das laterais","End of laterals","Final de las laterales")
B.i9=new A.a("Tubo do submain","Submain pipe","Tuber\xeda del submain")
B.xZ=new A.a("Posi\xe7\xe3o da v\xe1lvula","Valve position","Posici\xf3n de la v\xe1lvula")
B.c4=new A.a("In\xedcio","Start","Inicio")
B.mm=new A.a("Centro","Centre","Centro")
B.nV=new A.a("Fim","End","Final")
B.lO=new A.a("Trecho at\xe9 a v\xe1lvula (stub)","Stub to the valve","Tramo hasta la v\xe1lvula")
B.CP=new A.a("Espa\xe7amento (% do di\xe2metro molhado)","Spacing (% of wetted diameter)","Espaciamiento (% del di\xe1metro mojado)")
B.rE=new A.a("Dire\xe7\xe3o (\xb0)","Direction (\xb0)","Direcci\xf3n (\xb0)")
B.tk=new A.a("Quadrado","Square","Cuadrado")
B.uR=new A.a("Triangular","Triangular","Triangular")
B.xT=new A.a("Raio {r} m \u2192 espa\xe7amento {s} m; taxa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %","Radius {r} m \u2192 spacing {s} m; rate \u2248 {pr} mm/h; theoretical CU \u2248 {cu} %","Radio {r} m \u2192 espaciamiento {s} m; tasa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %")
B.rY=new A.a("Lateral com emissores","Lateral with outlets","Lateral con emisores")
B.oJ=new A.a("Declividade (%; + desce)","Slope (%; + downhill)","Pendiente (%; + baja)")
B.kG=new A.a("Toler\xe2ncia abaixo (%)","Tolerance below (%)","Tolerancia por debajo (%)")
B.va=new A.a("Toler\xe2ncia acima (%)","Tolerance above (%)","Tolerancia por encima (%)")
B.mG=new A.a("Vaz\xe3o de entrada","Inlet flow","Caudal de entrada")
B.n7=new A.a("Perda de carga total","Total head loss","P\xe9rdida de carga total")
B.wi=new A.a("Press\xe3o no fim","End pressure","Presi\xf3n al final")
B.np=new A.a("Press\xe3o m\xedn / m\xe1x","Min / max pressure","Presi\xf3n m\xedn / m\xe1x")
B.zR=new A.a("Varia\xe7\xe3o de press\xe3o","Pressure variation","Variaci\xf3n de presi\xf3n")
B.zE=new A.a("Velocidade m\xe1x.","Max. velocity","Velocidad m\xe1x.")
B.rC=new A.a("CU / DU / EU / Us","CU / DU / EU / Us","CU / DU / EU / Us")
B.CN=new A.a("qvar","qvar","qvar")
B.kR=new A.a("Comprimento m\xe1ximo (janela \xb1)","Maximum length (\xb1 window)","Longitud m\xe1xima (ventana \xb1)")
B.A4=new A.a("Altura est\xe1tica","Static head","Altura est\xe1tica")
B.ot=new A.a("Adutora","Delivery main","Conducci\xf3n")
B.kO=new A.a("Horas/ano","Hours/year","Horas/a\xf1o")
B.cm=new A.a("Ponto de opera\xe7\xe3o","Operating point","Punto de operaci\xf3n")
B.lX=new A.a("A bomba n\xe3o vence a altura est\xe1tica.","The pump cannot overcome the static head.","La bomba no supera la altura est\xe1tica.")
B.zh=new A.a("Altura manom\xe9trica","Total head","Altura manom\xe9trica")
B.pf=new A.a("Velocidade na adutora","Velocity in the main","Velocidad en la conducci\xf3n")
B.CI=new A.a("Pot\xeancia hidr\xe1ulica","Hydraulic power","Potencia hidr\xe1ulica")
B.zK=new A.a("Pot\xeancia no eixo (\u03b7 {e} %)","Shaft power (\u03b7 {e} %)","Potencia en el eje (\u03b7 {e} %)")
B.k0=new A.a("Energia anual","Annual energy","Energ\xeda anual")
B.BD=new A.a("Shutoff / runout","Shutoff / runout","Shutoff / runout")
B.te=new A.a("Velocidade (m/s)","Velocity (m/s)","Velocidad (m/s)")
B.Bf=new A.a("Tempo de fechamento (s)","Closure time (s)","Tiempo de cierre (s)")
B.DX=new A.a("Press\xe3o est\xe1tica","Static pressure","Presi\xf3n est\xe1tica")
B.v2=new A.a("Resultado (Joukowsky)","Result (Joukowsky)","Resultado (Joukowsky)")
B.xx=new A.a("Celeridade","Wave celerity","Celeridad")
B.w2=new A.a("Sobrepress\xe3o m\xe1xima (fechamento instant\xe2neo)","Maximum surge (instantaneous closure)","Sobrepresi\xf3n m\xe1xima (cierre instant\xe1neo)")
B.pZ=new A.a("Tempo cr\xedtico 2L/a","Critical time 2L/a","Tiempo cr\xedtico 2L/a")
B.i2=new A.a("Sobrepress\xe3o estimada (fechamento {s} s)","Estimated surge (closure {s} s)","Sobrepresi\xf3n estimada (cierre {s} s)")
B.wd=new A.a("Press\xe3o total","Total pressure","Presi\xf3n total")
B.nm=new A.a("Classe do tubo","Pipe class","Clase de la tuber\xeda")
B.c8=new A.a("Fitas","Tapes","Cintas")
B.vb=new A.a("Uso","Use","Uso")
B.mS=new A.a("DN","DN","DN")
B.vH=new A.a("DI mm","ID mm","DI mm")
B.md=new A.a("C","C","C")
B.F_=new A.a("PN (m)","PN (m)","PN (m)")
B.iz=new A.a("{c}/m","{c}/m","{c}/m")
B.ir=new A.a("k (L/h\xb7m^-x)","k (L/h\xb7m^-x)","k (L/h\xb7m^-x)")
B.EU=new A.a("x","x","x")
B.CC=new A.a("P padr\xe3o","Default P","P predeterminada")
B.mc=new A.a("CV","CV","CV")
B.zn=new A.a("Tol \xb1%","Tol \xb1%","Tol \xb1%")
B.wX=new A.a("{c}","{c}","{c}")
B.CG=new A.a("Esp. m","Spacing m","Esp. m")
B.ER=new A.a("q nom L/h","q nom L/h","q nom L/h")
B.pK=new A.a("Kd","Kd","Kd")
B.cz=new A.a("Tipo","Type","Tipo")
B.mF=new A.a("K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)")
B.BG=new A.a("n","n","n")
B.k8=new A.a("Q m\xe1x m\xb3/h","Max Q m\xb3/h","Q m\xe1x m\xb3/h")
B.us=new A.a("Pontos (Q m\xb3/h @ H m)","Points (Q m\xb3/h @ H m)","Puntos (Q m\xb3/h @ H m)")
B.rq=new A.a("\u03b7","\u03b7","\u03b7")
B.uo=new A.a("Submersa","Submersible","Sumergible")
B.ul=new A.a("Edite e pressione Enter em cada campo. Valores hidr\xe1ulicos internos em SI; vaz\xf5es em L/h ou m\xb3/h conforme indicado.","Edit and press Enter in each field. Internal hydraulic values are SI; flows in L/h or m\xb3/h as indicated.","Edite y pulse Intro en cada campo. Valores hidr\xe1ulicos internos en SI; caudales en L/h o m\xb3/h seg\xfan se indica.")
B.rH=new A.a("PVC","PVC","PVC")
B.t4=new A.a("PEAD/PE100","HDPE/PE100","PEAD/PE100")
B.ry=new A.a("PEBD","LDPE","PEBD")
B.yv=new A.a("A\xe7o","Steel","Acero")
B.ia=new A.a("Ferro d\xfactil","Ductile iron","Fundici\xf3n d\xfactil")
B.ld=new A.a("Alum\xednio","Aluminium","Aluminio")
B.Bo=new A.a("Concreto","Concrete","Hormig\xf3n")
B.Cz=new A.a("C\xe1lculo n\xe3o convergiu","Calculation did not converge","El c\xe1lculo no convergi\xf3")
B.Fe=new A.a("N\xe3o foi poss\xedvel atender a janela de press\xe3o com os tubos dispon\xedveis","Could not meet the pressure window with the available pipes","No se pudo cumplir la ventana de presi\xf3n con las tuber\xedas disponibles")
B.rs=new A.a("Linha principal n\xe3o consegue atender a press\xe3o das v\xe1lvulas","Mainline cannot meet the valve pressures","La l\xednea principal no puede cumplir la presi\xf3n de las v\xe1lvulas")
B.ku=new A.a("Nenhuma fonte de \xe1gua conectada","No water supply connected","Ninguna fuente de agua conectada")
B.wY=new A.a("Emissor acima da press\xe3o admiss\xedvel","Outlet above allowable pressure","Emisor por encima de la presi\xf3n admisible")
B.EN=new A.a("Emissor abaixo da press\xe3o admiss\xedvel","Outlet below allowable pressure","Emisor por debajo de la presi\xf3n admisible")
B.xY=new A.a("Press\xe3o acima da classe do tubo","Pressure above the pipe rating","Presi\xf3n por encima de la clase de la tuber\xeda")
B.CD=new A.a("Bomba fora da faixa de opera\xe7\xe3o","Pump outside its operating range","Bomba fuera del rango de operaci\xf3n")
B.tZ=new A.a("Suc\xe7\xe3o da bomba acima do limite pr\xe1tico: instale a bomba mais perto do n\xedvel da \xe1gua ou use uma bomba submersa","Pump suction lift above the practical limit: install the pump closer to the water level or use a submersible pump","Succi\xf3n de la bomba por encima del l\xedmite pr\xe1ctico: instale la bomba m\xe1s cerca del nivel del agua o use una bomba sumergible")
B.AX=new A.a("Vaz\xe3o da fonte excedida","Supply flow exceeded","Caudal de la fuente excedido")
B.kv=new A.a("Press\xe3o m\xe1xima da fonte excedida","Supply maximum pressure exceeded","Presi\xf3n m\xe1xima de la fuente excedida")
B.nr=new A.a("Vaz\xe3o fora da faixa da v\xe1lvula","Flow outside the valve range","Caudal fuera del rango de la v\xe1lvula")
B.qx=new A.a("V\xe1lvula n\xe3o encontrada","Valve not found","V\xe1lvula no encontrada")
B.Bt=new A.a("Press\xe3o insuficiente na v\xe1lvula","Insufficient pressure at the valve","Presi\xf3n insuficiente en la v\xe1lvula")
B.um=new A.a("V\xe1lvula n\xe3o alcan\xe7ada pela linha principal","Valve not reached by the mainline","V\xe1lvula no alcanzada por la l\xednea principal")
B.xB=new A.a("Velocidade m\xe1xima excedida","Maximum velocity exceeded","Velocidad m\xe1xima excedida")
B.zM=new A.a("Zona sem tubos ou emissores","Zone without pipes or outlets","Zona sin tuber\xedas ni emisores")
B.z8=new A.a("Zonas conectadas entre si sem v\xe1lvula","Zones connected without a valve","Zonas conectadas entre s\xed sin v\xe1lvula")
B.kb=new A.a("V\xe1lvula sem tubos de zona","Valve without zone pipes","V\xe1lvula sin tuber\xedas de zona")
B.BO=new A.a("Emissor sem modelo no cat\xe1logo","Outlet without a catalog model","Emisor sin modelo en el cat\xe1logo")
B.pe=new A.a("Fita sem modelo no cat\xe1logo","Tape without a catalog model","Cinta sin modelo en el cat\xe1logo")
B.Ba=new A.a("Bomba sem modelo no cat\xe1logo","Pump without a catalog model","Bomba sin modelo en el cat\xe1logo")
B.t7=new A.a("Acess\xf3rio sem modelo no cat\xe1logo","Device without a catalog model","Accesorio sin modelo en el cat\xe1logo")
B.ze=new A.a("Rede sem fonte de carga fixa","Network without a fixed-head source","Red sin fuente de carga fija")
B.iU=new A.a("P\xe1gina de dados ausente no DWG","Missing data page in DWG","P\xe1gina de datos ausente en el DWG")
B.vZ=new A.a("OpenCADIrrigation \u2014 CAD para projeto de irriga\xe7\xe3o pressurizada.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lise de laterais passo a passo, dimensionamento por velocidade e por janela de press\xe3o com crit\xe9rio econ\xf4mico.\nRoda no navegador, sem instala\xe7\xe3o.","OpenCADIrrigation \u2014 CAD for pressurised irrigation design.\nHydraulic engine: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), step-by-step lateral analysis, velocity and pressure-window pipe sizing with economic trade-off.\nRuns in the browser, nothing to install.","OpenCADIrrigation \u2014 CAD para el dise\xf1o de riego presurizado.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lisis de laterales paso a paso, dimensionamiento por velocidad y por ventana de presi\xf3n con criterio econ\xf3mico.\nFunciona en el navegador, sin instalaci\xf3n.")
B.vu=new A.a("Vers\xe3o {v}","Version {v}","Versi\xf3n {v}")
B.D8=new A.a("Site do projeto","Project site","Sitio del proyecto")
B.CY=new A.a("Arco (3 pontos)","Arc (3 points)","Arco (3 puntos)")
B.xN=new A.a("Spline (curva suave)","Spline (smooth curve)","Spline (curva suave)")
B.oD=new A.a("Hachura","Hatch","Sombreado")
B.cj=new A.a("S\xedmbolo","Symbol","S\xedmbolo")
B.oI=new A.a("Cota angular","Angular dimension","Cota angular")
B.EX=new A.a("Cota radial","Radial dimension","Cota radial")
B.iG=new A.a("Chamada (leader)","Leader","Llamada (leader)")
B.cv=new A.a("Rotacionar","Rotate","Rotar")
B.y4=new A.a("Espelhar","Mirror","Simetr\xeda")
B.c3=new A.a("Escalar","Scale","Escalar")
B.vL=new A.a("Deslocar (offset)","Offset","Desfasar (offset)")
B.lC=new A.a("Aparar","Trim","Recortar")
B.ny=new A.a("Estender","Extend","Alargar")
B.F2=new A.a("Cortar tubo","Cut pipe","Cortar tuber\xeda")
B.DA=new A.a("Perfil de eleva\xe7\xe3o","Elevation profile","Perfil de elevaci\xf3n")
B.yB=new A.a("Clique no in\xedcio, em um ponto do arco e no fim","Click start, a point on the arc, then end","Clic en el inicio, un punto del arco y el final")
B.pv=new A.a("Clique nos pontos da curva; Enter termina","Click curve points; Enter ends","Clic en los puntos de la curva; Intro termina")
B.js=new A.a("Clique nos v\xe9rtices da \xe1rea a hachurar; Enter fecha","Click the hatch boundary vertices; Enter closes","Clic en los v\xe9rtices del \xe1rea; Intro cierra")
B.uv=new A.a("Clique para inserir o s\xedmbolo (tipo e tamanho no painel)","Click to insert the symbol (kind and size in the panel)","Clic para insertar el s\xedmbolo (tipo y tama\xf1o en el panel)")
B.i8=new A.a("Clique no v\xe9rtice, nos dois lados e na posi\xe7\xe3o do arco","Click the vertex, both sides, then the arc position","Clic en el v\xe9rtice, los dos lados y la posici\xf3n del arco")
B.oX=new A.a("Clique no c\xedrculo (ou centro) e depois no ponto da cota","Click the circle (or centre) then the dimension point","Clic en el c\xedrculo (o centro) y luego en el punto de la cota")
B.iv=new A.a("Clique na ponta da seta e nos v\xe9rtices; Enter abre o texto","Click the arrow tip and the vertices; Enter opens the text","Clic en la punta de la flecha y los v\xe9rtices; Intro abre el texto")
B.Ep=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (Ctrl = copiar)","Selection: click base point, reference, then target (Ctrl = copy)","Selecci\xf3n: clic en el punto base, la referencia y el destino (Ctrl = copiar)")
B.pF=new A.a("Sele\xe7\xe3o: clique nos dois pontos da linha de espelho","Selection: click the two points of the mirror line","Selecci\xf3n: clic en los dos puntos del eje de simetr\xeda")
B.EH=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (fator = raz\xe3o)","Selection: click base point, reference, then target (factor = ratio)","Selecci\xf3n: clic en el punto base, la referencia y el destino (factor = raz\xf3n)")
B.DL=new A.a("Clique no objeto e depois no lado do deslocamento (dist\xe2ncia no painel)","Click the object then the offset side (distance in the panel)","Clic en el objeto y luego en el lado del desfase (distancia en el panel)")
B.AN=new A.a("Clique na parte a remover; a sele\xe7\xe3o define as arestas de corte","Click the part to remove; the selection defines the cutting edges","Clic en la parte a quitar; la selecci\xf3n define las aristas de corte")
B.vx=new A.a("Clique perto da extremidade a estender at\xe9 a pr\xf3xima aresta","Click near the end to extend to the next edge","Clic cerca del extremo a alargar hasta la siguiente arista")
B.q0=new A.a("Clique no ponto do tubo/lateral onde cortar","Click the point of the pipe/lateral to cut","Clic en el punto de la tuber\xeda/lateral donde cortar")
B.uF=new A.a("Clique os pontos do caminho; Enter (ou Concluir) mostra o perfil na aba Perfil; Esc limpa a linha roxa","Click the path points; Enter (or Done) shows the profile in the Profile tab; Esc clears the purple line","Clic en los puntos del camino; Intro (o Terminar) muestra el perfil en la pesta\xf1a Perfil; Esc borra la l\xednea morada")
B.qC=new A.a("Modificar","Modify","Modificar")
B.CW=new A.a("Matriz (array)\u2026","Array\u2026","Matriz (array)\u2026")
B.Fb=new A.a("Envelope do submain (laterais selecionadas)","Submain envelope (selected laterals)","Envolvente del submain (laterales seleccionadas)")
B.lL=new A.a("Matriz da sele\xe7\xe3o","Array of the selection","Matriz de la selecci\xf3n")
B.uB=new A.a("Retangular","Rectangular","Rectangular")
B.rO=new A.a("Polar","Polar","Polar")
B.qa=new A.a("Linhas","Rows","Filas")
B.mq=new A.a("Colunas","Columns","Columnas")
B.l5=new A.a("Espa\xe7amento em X","Column spacing","Espaciamiento en X")
B.E7=new A.a("Espa\xe7amento em Y","Row spacing","Espaciamiento en Y")
B.xV=new A.a("\xc2ngulo da matriz (\xb0)","Array angle (\xb0)","\xc1ngulo de la matriz (\xb0)")
B.l0=new A.a("N\xfamero de itens","Number of items","N\xfamero de elementos")
B.zi=new A.a("Centro (X, Y)","Centre (X, Y)","Centro (X, Y)")
B.iV=new A.a("\xc2ngulo total (\xb0)","Total angle (\xb0)","\xc1ngulo total (\xb0)")
B.x7=new A.a("Rotacionar itens","Rotate items","Rotar elementos")
B.Cj=new A.a("{n} itens selecionados","{n} selected items","{n} elementos seleccionados")
B.xu=new A.a("A camada est\xe1 bloqueada","The layer is locked","La capa est\xe1 bloqueada")
B.ic=new A.a("Nenhuma interse\xe7\xe3o encontrada","No intersection found","No se encontr\xf3 intersecci\xf3n")
B.EE=new A.a("Selecione uma ou mais laterais (sprayline ou fita)","Select one or more laterals (sprayline or tape)","Seleccione una o m\xe1s laterales (sprayline o cinta)")
B.E3=new A.a("Envelope calculado para {n} laterais (verde = posi\xe7\xe3o admiss\xedvel)","Envelope computed for {n} laterals (green = allowable position)","Envolvente calculada para {n} laterales (verde = posici\xf3n admisible)")
B.yG=new A.a("{n} itens criados","{n} items created","{n} elementos creados")
B.tu=new A.a("Marcar press\xe3o m\xedn/m\xe1x por zona","Mark min/max pressure per zone","Marcar presi\xf3n m\xedn/m\xe1x por zona")
B.j2=new A.a("Mapa base","Base map","Mapa base")
B.qV=new A.a("Nenhum","None","Ninguno")
B.k1=new A.a("Ruas (OpenStreetMap)","Streets (OpenStreetMap)","Calles (OpenStreetMap)")
B.ye=new A.a("Sat\xe9lite (Esri World Imagery)","Satellite (Esri World Imagery)","Sat\xe9lite (Esri World Imagery)")
B.pE=new A.a("Topogr\xe1fico (OpenTopoMap)","Topographic (OpenTopoMap)","Topogr\xe1fico (OpenTopoMap)")
B.Bd=new A.a("Ruas claras (CARTO Voyager)","Light streets (CARTO Voyager)","Calles claras (CARTO Voyager)")
B.BQ=new A.a("Ruas (Esri World Street Map)","Streets (Esri World Street Map)","Calles (Esri World Street Map)")
B.iE=new A.a("Topogr\xe1fico (Esri World Topo Map)","Topographic (Esri World Topo Map)","Topogr\xe1fico (Esri World Topo Map)")
B.qJ=new A.a("Google Maps \u2013 mapa","Google Maps \u2013 roadmap","Google Maps \u2013 mapa")
B.l7=new A.a("Google Maps \u2013 sat\xe9lite","Google Maps \u2013 satellite","Google Maps \u2013 sat\xe9lite")
B.iR=new A.a("Google Maps \u2013 h\xedbrido (sat\xe9lite + vias)","Google Maps \u2013 hybrid (satellite + roads)","Google Maps \u2013 h\xedbrido (sat\xe9lite + v\xedas)")
B.kM=new A.a("Google Maps \u2013 relevo","Google Maps \u2013 terrain","Google Maps \u2013 relieve")
B.oi=new A.a("Personalizado (URL XYZ)","Custom (XYZ URL)","Personalizado (URL XYZ)")
B.Ed=new A.a("Chave da API do Google Maps\u2026","Google Maps API key\u2026","Clave de la API de Google Maps\u2026")
B.Fr=new A.a("URL do mapa personalizado\u2026","Custom map URL\u2026","URL del mapa personalizado\u2026")
B.uN=new A.a("Chave da API do Google Maps","Google Maps API key","Clave de la API de Google Maps")
B.j5=new A.a("Os mapas do Google s\xe3o servidos pela Map Tiles API da Google Maps Platform com a sua pr\xf3pria chave: o uso \xe9 contabilizado (e cobrado al\xe9m da cota gratuita) na sua conta Google Cloud.","Google maps come from the Map Tiles API of the Google Maps Platform with your own key: usage is counted (and billed beyond the free quota) on your Google Cloud account.","Los mapas de Google los sirve la Map Tiles API de Google Maps Platform con su propia clave: el uso se contabiliza (y se cobra m\xe1s all\xe1 de la cuota gratuita) en su cuenta de Google Cloud.")
B.Fu=new A.a('1. No Google Cloud Console, crie um projeto e ative a "Map Tiles API".   2. Em Credenciais, crie uma chave de API.   3. Restrinja a chave aos sites (referenciadores HTTP) em que usa o app.','1. In the Google Cloud Console create a project and enable the "Map Tiles API".   2. Under Credentials create an API key.   3. Restrict the key to the sites (HTTP referrers) where you use the app.','1. En Google Cloud Console cree un proyecto y active la "Map Tiles API".   2. En Credenciales cree una clave de API.   3. Restrinja la clave a los sitios (referentes HTTP) donde usa la app.')
B.xa=new A.a("Abrir Google Cloud Console","Open Google Cloud Console","Abrir Google Cloud Console")
B.vl=new A.a("Como obter a chave","How to get a key","C\xf3mo obtener la clave")
B.r5=new A.a("Chave da API","API key","Clave de la API")
B.lY=new A.a("A chave fica guardada s\xf3 neste navegador e \xe9 enviada apenas ao Google.","The key is kept in this browser only and sent to Google only.","La clave se guarda solo en este navegador y se env\xeda \xfanicamente a Google.")
B.wl=new A.a("Remover chave","Remove key","Quitar clave")
B.u0=new A.a("Google Maps: informe a chave da API em Ver \u2192 Mapa base","Google Maps: enter the API key under View \u2192 Base map","Google Maps: indique la clave de la API en Ver \u2192 Mapa base")
B.BV=new A.a("Google Maps: {e}","Google Maps: {e}","Google Maps: {e}")
B.z9=new A.a("Mapa base personalizado","Custom base map","Mapa base personalizado")
B.Cn=new A.a("Endere\xe7o dos tiles no padr\xe3o XYZ (Web Mercator): um servidor pr\xf3prio, um provedor com chave ou um WMTS.","Address of the tiles in the XYZ pattern (Web Mercator): your own server, a keyed provider or a WMTS.","Direcci\xf3n de los tiles en el patr\xf3n XYZ (Web Mercator): un servidor propio, un proveedor con clave o un WMTS.")
B.Di=new A.a("Modelo de URL","URL template","Plantilla de URL")
B.po=new A.a("Marcadores: {z} zoom, {x} coluna, {y} linha ({-y} para TMS), {s} subdom\xednio a/b/c. A chave do provedor, se houver, vai na pr\xf3pria URL.","Placeholders: {z} zoom, {x} column, {y} row ({-y} for TMS), {s} subdomain a/b/c. The provider key, if any, goes in the URL itself.","Marcadores: {z} zoom, {x} columna, {y} fila ({-y} para TMS), {s} subdominio a/b/c. La clave del proveedor, si la hay, va en la propia URL.")
B.lu=new A.a("A URL precisa come\xe7ar com http(s):// e conter {z}, {x} e {y}","The URL must start with http(s):// and contain {z}, {x} and {y}","La URL debe empezar con http(s):// y contener {z}, {x} e {y}")
B.oU=new A.a("Defina a georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia) para mostrar o mapa base","Set the georeference (File \u2192 Georeference) to show the base map","Defina la georreferencia (Archivo \u2192 Georreferencia) para mostrar el mapa base")
B.tR=new A.a("Al\xe7as de edi\xe7\xe3o","Edit grips","Pinzamientos de edici\xf3n")
B.yb=new A.a("Envelope de posi\xe7\xe3o do submain","Allowable submain position","Posici\xf3n admisible del submain")
B.nA=new A.a("Camada atual","Current layer","Capa actual")
B.m_=new A.a("Bloquear","Lock","Bloquear")
B.Bx=new A.a("Nova camada","New layer","Nueva capa")
B.tG=new A.a("Renomear","Rename","Renombrar")
B.jq=new A.a("Excluir camada (itens v\xe3o para DRAWING)","Delete layer (items move to DRAWING)","Eliminar capa (los elementos van a DRAWING)")
B.mv=new A.a("Cor","Colour","Color")
B.kT=new A.a("Nome da camada","Layer name","Nombre de la capa")
B.Ck=new A.a("J\xe1 existe uma camada com esse nome","A layer with that name already exists","Ya existe una capa con ese nombre")
B.pk=new A.a("Clique no olho para mostrar/ocultar, no cadeado para bloquear, na cor para alterar; duplo clique renomeia; o c\xedrculo marca a camada atual.","Click the eye to show/hide, the padlock to lock, the colour to change it; double-click renames; the dot marks the current layer.","Clic en el ojo para mostrar/ocultar, en el candado para bloquear, en el color para cambiarlo; doble clic renombra; el c\xedrculo marca la capa actual.")
B.mP=new A.a("Edi\xe7\xe3o em lote ({n} {type})","Batch edit ({n} {type})","Edici\xf3n en lote ({n} {type})")
B.yh=new A.a("(valores diferentes)","(mixed values)","(valores distintos)")
B.vO=new A.a("Tamanho (m)","Size (m)","Tama\xf1o (m)")
B.lF=new A.a("\xc2ngulo da hachura (\xb0)","Hatch angle (\xb0)","\xc1ngulo del sombreado (\xb0)")
B.kW=new A.a("Espa\xe7amento da hachura (m)","Hatch spacing (m)","Espaciamiento del sombreado (m)")
B.oL=new A.a("Preenchimento s\xf3lido","Solid fill","Relleno s\xf3lido")
B.rj=new A.a("Opacidade","Opacity","Opacidad")
B.ph=new A.a("Largura (m)","Width (m)","Ancho (m)")
B.nP=new A.a("Altura (m)","Height (m)","Alto (m)")
B.kS=new A.a("Emissores por planta (0 = padr\xe3o do projeto)","Emitters per plant (0 = project default)","Emisores por planta (0 = valor del proyecto)")
B.pc=new A.a("Balan\xe7o h\xeddrico (ETo \xd7 Kc, solo)","Water balance (ETo \xd7 Kc, soil)","Balance h\xeddrico (ETo \xd7 Kc, suelo)")
B.mZ=new A.a("ETo (mm/dia)","ETo (mm/day)","ETo (mm/d\xeda)")
B.pJ=new A.a("Kc","Kc","Kc")
B.wL=new A.a("Kc por cultura (FAO-56)","Kc by crop (FAO-56)","Kc por cultivo (FAO-56)")
B.tA=new A.a("\xc1gua dispon\xedvel (mm/m)","Available water (mm/m)","Agua disponible (mm/m)")
B.zt=new A.a("Profundidade radicular (m)","Root depth (m)","Profundidad radicular (m)")
B.ub=new A.a("Fra\xe7\xe3o de esgotamento (MAD)","Allowed depletion (MAD)","Fracci\xf3n de agotamiento (MAD)")
B.vk=new A.a("Fra\xe7\xe3o molhada","Wetted fraction","Fracci\xf3n mojada")
B.rh=new A.a("Espa\xe7amento entre plantas (m)","Plant spacing (m)","Espaciamiento entre plantas (m)")
B.n_=new A.a("Espa\xe7amento entre linhas (m)","Row spacing (m)","Espaciamiento entre hileras (m)")
B.Dj=new A.a("ETc (mm/dia)","ETc (mm/day)","ETc (mm/d\xeda)")
B.i4=new A.a("Intervalo (dias)","Interval (days)","Intervalo (d\xedas)")
B.zT=new A.a("Dist\xe2ncia do offset","Offset distance","Distancia del desfase")
B.BP=new A.a("Manter original (copiar)","Keep original (copy)","Mantener original (copiar)")
B.D9=new A.a("Manter original","Keep source","Mantener original")
B.CJ=new A.a("Dividir tubo ao inserir sobre ele","Split pipe when inserted on it","Dividir tuber\xeda al insertar sobre ella")
B.AV=new A.a("Curva fechada","Closed curve","Curva cerrada")
B.vf=new A.a("\xc2ngulo (\xb0)","Angle (\xb0)","\xc1ngulo (\xb0)")
B.xz=new A.a("Texto da chamada","Leader text","Texto de la llamada")
B.kd=new A.a("Raio do arco de cota (m)","Dimension arc radius (m)","Radio del arco de cota (m)")
B.jt=new A.a("Camada bloqueada: edi\xe7\xe3o desativada","Locked layer: editing disabled","Capa bloqueada: edici\xf3n desactivada")
B.wp=new A.a("Vaz\xe3o de lavagem no fim (0 = autom\xe1tica)","End flushing flow (0 = automatic)","Caudal de lavado al final (0 = autom\xe1tico)")
B.Em=new A.a("Envelope do submain","Submain envelope","Envolvente del submain")
B.xA=new A.a("Melhor posi\xe7\xe3o: {f} % do in\xedcio (\u0394p {v})","Best position: {f} % from the start (\u0394p {v})","Mejor posici\xf3n: {f} % desde el inicio (\u0394p {v})")
B.ni=new A.a("Admiss\xedvel: {a} % a {b} %","Allowable: {a} % to {b} %","Admisible: {a} % a {b} %")
B.Ae=new A.a("Nenhuma posi\xe7\xe3o atende \xe0 janela de press\xe3o","No position meets the pressure window","Ninguna posici\xf3n cumple la ventana de presi\xf3n")
B.tg=new A.a("Seta norte","North arrow","Flecha norte")
B.kh=new A.a("\xc1rvore","Tree","\xc1rbol")
B.uU=new A.a("Edifica\xe7\xe3o","Building","Edificaci\xf3n")
B.cb=new A.a("Reservat\xf3rio","Tank","Dep\xf3sito")
B.AG=new A.a("Caixa de v\xe1lvula","Valve box","Arqueta de v\xe1lvula")
B.CL=new A.a("Casa de bombas","Pump house","Caseta de bombeo")
B.yg=new A.a("Port\xe3o","Gate","Port\xf3n")
B.DU=new A.a("Esta\xe7\xe3o de filtragem","Filter station","Estaci\xf3n de filtrado")
B.d3=new A.a("Caf\xe9","Coffee","Caf\xe9")
B.bT=new A.a("Banana","Banana","Banano")
B.qq=new A.a("Manga","Mango","Mango")
B.zD=new A.a("Ma\xe7\xe3","Apple","Manzana")
B.cA=new A.a("Tomate","Tomato","Tomate")
B.bF=new A.a("Milho","Maize","Ma\xedz")
B.bS=new A.a("Cana-de-a\xe7\xfacar","Sugarcane","Ca\xf1a de az\xfacar")
B.cc=new A.a("Hortali\xe7as","Vegetables","Hortalizas")
B.bL=new A.a("Grama","Turf","C\xe9sped")
B.rJ=new A.a("Pastagem","Pasture","Pasto")
B.m4=new A.a("Personalizado","Custom","Personalizado")
B.Bz=new A.a("Lavagem (flushing)","Flushing","Lavado (flushing)")
B.wq=new A.a("Golpe de ar\xedete","Water hammer","Golpe de ariete")
B.Ce=new A.a("Agronomia","Agronomy","Agronom\xeda")
B.Fx=new A.a("Programa\xe7\xe3o","Schedule","Programaci\xf3n")
B.cp=new A.a("Perfil","Profile","Perfil")
B.cY=new A.a("C\xf3digo","Code","C\xf3digo")
B.zX=new A.a("V alvo (m/s)","Target V (m/s)","V objetivo (m/s)")
B.ml=new A.a("Celeridade","Celerity","Celeridad")
B.DZ=new A.a("Sobrepress\xe3o","Surge","Sobrepresi\xf3n")
B.pG=new A.a("P m\xe1x regime","Max steady P","P m\xe1x r\xe9gimen")
B.r6=new A.a("P total","Total P","P total")
B.BJ=new A.a("2L/a (s)","2L/a (s)","2L/a (s)")
B.lo=new A.a("AFD","RAW","ARA")
B.E2=new A.a("Intervalo (d)","Interval (d)","Intervalo (d)")
B.Be=new A.a("L\xedquida/evento","Net/event","Neta/evento")
B.yc=new A.a("Bruta/evento","Gross/event","Bruta/evento")
B.qM=new A.a("Horas/evento","Hours/event","Horas/evento")
B.vU=new A.a("CU sobrep. %","Overlap CU %","CU solap. %")
B.cI=new A.a("Zonas","Zones","Zonas")
B.nU=new A.a("Fim","End","Fin")
B.Bp=new A.a("Dist\xe2ncia","Distance","Distancia")
B.it=new A.a("Use a ferramenta Perfil (PR) ou selecione um tubo/lateral para ver o perfil do terreno","Use the Profile tool (PR) or select a pipe/lateral to see the ground profile","Use la herramienta Perfil (PR) o seleccione una tuber\xeda/lateral para ver el perfil del terreno")
B.z2=new A.a("Declividade m\xe9dia {s} %  \xb7  desn\xedvel {d} m  \xb7  comprimento {l}","Mean slope {s} %  \xb7  rise {d} m  \xb7  length {l}","Pendiente media {s} %  \xb7  desnivel {d} m  \xb7  longitud {l}")
B.qf=new A.a("Luva","Coupler","Manguito")
B.Ca=new A.a("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0")
B.wK=new A.a("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0")
B.u9=new A.a("T\xea","Tee","Te")
B.mA=new A.a("Cruzeta","Cross","Cruz")
B.oy=new A.a("Redu\xe7\xe3o","Reducer","Reducci\xf3n")
B.Cm=new A.a("Tamp\xe3o","End cap","Tap\xf3n")
B.lv=new A.a("Adaptador","Adapter","Adaptador")
B.CX=new A.a("Conector inicial de lateral","Lateral take-off","Conector inicial de lateral")
B.jN=new A.a("Final de linha","Line end","Final de l\xednea")
B.kq=new A.a("Haste / tubo de subida","Riser","Tubo de subida")
B.bH=new A.a("Conex\xf5es","Fittings","Conexiones")
B.mK=new A.a("Conectores de lateral","Lateral connectors","Conectores de lateral")
B.pq=new A.a("Hastes e tubos de subida","Risers","Tubos de subida")
B.uO=new A.a("Tipo","Kind","Tipo")
B.BH=new A.a("DN 2","Size 2","DN 2")
B.o2=new A.a("Fornecedor","Supplier","Proveedor")
B.zu=new A.a("+ Adicionar","+ Add","+ A\xf1adir")
B.n8=new A.a("Duplicar","Duplicate","Duplicar")
B.EM=new A.a("Importar (JSON/CSV)\u2026","Import (JSON/CSV)\u2026","Importar (JSON/CSV)\u2026")
B.DE=new A.a("Exportar JSON","Export JSON","Exportar JSON")
B.lP=new A.a("Exportar CSV desta aba","Export CSV of this tab","Exportar CSV de esta pesta\xf1a")
B.iC=new A.a("Restaurar padr\xe3o","Restore default","Restaurar predeterminado")
B.yk=new A.a("Usar como padr\xe3o para novos projetos","Use as default for new projects","Usar como predeterminado en proyectos nuevos")
B.Bl=new A.a("JSON no formato do cat\xe1logo (exportado daqui) ou CSV com cabe\xe7alho; colunas reconhecidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tubos); id, name, kind, sizeMm, size2Mm, cost (conex\xf5es); id, name, idMm, spacing, qLph, headM, x, cost (fitas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emissores).","JSON in the catalog format (exported from here) or CSV with a header; recognised columns: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (pipes); id, name, kind, sizeMm, size2Mm, cost (fittings); id, name, idMm, spacing, qLph, headM, x, cost (tapes); id, name, kind, sizeMm, k, n, maxQm3h, cost (valves); id, name, points (Q@H;\u2026), eff, cost (pumps); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (outlets).","JSON en el formato del cat\xe1logo (exportado desde aqu\xed) o CSV con encabezado; columnas reconocidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tuber\xedas); id, name, kind, sizeMm, size2Mm, cost (conexiones); id, name, idMm, spacing, qLph, headM, x, cost (cintas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emisores).")
B.F4=new A.a('Remover "{n}" do cat\xe1logo? Itens do projeto que o usam ficar\xe3o sem modelo.','Remove "{n}" from the catalog? Project items using it will lose their model.','\xbfQuitar "{n}" del cat\xe1logo? Los elementos del proyecto que lo usan quedar\xe1n sin modelo.')
B.wJ=new A.a("em uso: {n}","in use: {n}","en uso: {n}")
B.kQ=new A.a("Cat\xe1logo: {n} itens importados","Catalog: {n} items imported","Cat\xe1logo: {n} elementos importados")
B.yU=new A.a("Cat\xe1logo salvo como padr\xe3o para novos projetos","Catalog saved as default for new projects","Cat\xe1logo guardado como predeterminado para proyectos nuevos")
B.z4=new A.a("Cat\xe1logo padr\xe3o restaurado","Default catalog restored","Cat\xe1logo predeterminado restaurado")
B.Cx=new A.a("O cat\xe1logo n\xe3o tem fita gotejadora nem emissor com tubo de linha lateral: inclua-os em Projeto \u2192 Cat\xe1logo de componentes","The catalogue has no drip tape and no emitter with a lateral pipe: add them in Design \u2192 Component catalog","El cat\xe1logo no tiene cinta de goteo ni emisor con tubo lateral: agr\xe9guelos en Dise\xf1o \u2192 Cat\xe1logo de componentes")
B.tT=new A.a("LP sem solu\xe7\xe3o com os tubos habilitados (m\xe9todo guloso usado)","LP infeasible with the enabled pipes (greedy method used)","LP sin soluci\xf3n con las tuber\xedas habilitadas (se us\xf3 el m\xe9todo voraz)")
B.Cb=new A.a("Conex\xe3o sem item no cat\xe1logo","Fitting without a catalog item","Conexi\xf3n sin elemento en el cat\xe1logo")
B.B4=new A.a("Golpe de ar\xedete acima da classe do tubo","Water hammer above the pipe class","Golpe de ariete por encima de la clase de la tuber\xeda")
B.BS=new A.a("Turno sem \xe1rea irrigada: dura\xe7\xe3o mantida","System flow without an irrigated area: duration kept","Turno sin \xe1rea regada: duraci\xf3n mantenida")
B.A2=new A.a("Programa\xe7\xe3o excede 24 h no dia","Schedule exceeds 24 h in a day","La programaci\xf3n supera 24 h en el d\xeda")
B.v5=new A.a("Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, imagens)\u2026","Import (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, images)\u2026","Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, im\xe1genes)\u2026")
B.zV=new A.a("Pontos: {n} cotas importadas{geo}","Points: {n} spot heights imported{geo}","Puntos: {n} cotas importadas{geo}")
B.vz=new A.a(u.h,"SHP: {r} records, {n} entities ({crs})",u.h)
B.Ah=new A.a("Imagem {w}\xd7{h} px inserida na vista (ajuste com as al\xe7as ou Georreferenciar imagem)","Image {w}\xd7{h} px placed in the view (adjust with grips or Georeference image)","Imagen {w}\xd7{h} px insertada en la vista (ajuste con las pinzas o Georreferenciar imagen)")
B.AI=new A.a("Imagem georreferenciada {w}\xd7{h} px ({crs})","Georeferenced image {w}\xd7{h} px ({crs})","Imagen georreferenciada {w}\xd7{h} px ({crs})")
B.kt=new A.a("resposta inv\xe1lida do servidor de eleva\xe7\xe3o","invalid answer from the elevation server","respuesta no v\xe1lida del servidor de elevaci\xf3n")
B.F5=new A.a("bloco de eleva\xe7\xe3o inv\xe1lido recebido do servidor","invalid elevation tile received from the server","tesela de elevaci\xf3n no v\xe1lida recibida del servidor")
B.Bc=new A.a("o servidor devolveu um n\xfamero de eleva\xe7\xf5es diferente do pedido","the server returned a different number of elevations than requested","el servidor devolvi\xf3 un n\xfamero de elevaciones distinto del pedido")
B.km=new A.a("Arquivo de pontos vazio","Empty points file","Archivo de puntos vac\xedo")
B.yM=new A.a("N\xe3o foi poss\xedvel identificar as colunas X, Y (e Z)","Could not identify the X, Y (and Z) columns","No se pudieron identificar las columnas X, Y (y Z)")
B.ty=new A.a("Arquivo SHP inv\xe1lido","Invalid SHP file","Archivo SHP no v\xe1lido")
B.t8=new A.a("O ZIP n\xe3o cont\xe9m um arquivo .shp","The ZIP has no .shp file","El ZIP no contiene un archivo .shp")
B.xH=new A.a("O ZIP n\xe3o cont\xe9m imagem","The ZIP has no image","El ZIP no contiene imagen")
B.t5=new A.a("Imagem n\xe3o reconhecida","Image not recognised","Imagen no reconocida")
B.jf=new A.a("O arquivo est\xe1 danificado ou n\xe3o est\xe1 no formato esperado","The file is damaged or not in the expected format","El archivo est\xe1 da\xf1ado o no tiene el formato esperado")
B.ja=new A.a("Imagem grande demais para abrir no navegador (mais de 100 milh\xf5es de pixels)","Image too large to open in the browser (more than 100 million pixels)","Imagen demasiado grande para abrir en el navegador (m\xe1s de 100 millones de p\xedxeles)")
B.tO=new A.a("Georreferenciar imagem selecionada\u2026","Georeference selected image\u2026","Georreferenciar imagen seleccionada\u2026")
B.Cc=new A.a("Georreferenciar imagem","Georeference image","Georreferenciar imagen")
B.CB=new A.a("Informe as coordenadas locais (m) do canto inferior esquerdo, o tamanho real e a rota\xe7\xe3o da imagem.","Enter the local coordinates (m) of the bottom-left corner, the real size and the rotation of the image.","Indique las coordenadas locales (m) de la esquina inferior izquierda, el tama\xf1o real y la rotaci\xf3n de la imagen.")
B.jT=new A.a("Manter propor\xe7\xe3o","Keep aspect ratio","Mantener proporci\xf3n")
B.ju=new A.a("M\xe9todo de dimensionamento","Sizing method","M\xe9todo de dimensionamiento")
B.w9=new A.a("Programa\xe7\xe3o linear (LP: custo de tubo + energia + topografia)","Linear programming (LP: pipe cost + energy + topography)","Programaci\xf3n lineal (LP: costo de tuber\xeda + energ\xeda + topograf\xeda)")
B.Bq=new A.a("Guloso (velocidade \u2192 janela de press\xe3o \u2192 economia)","Greedy (velocity \u2192 pressure window \u2192 economics)","Voraz (velocidad \u2192 ventana de presi\xf3n \u2192 econom\xeda)")
B.yo=new A.a("N\xba m\xe1x. de di\xe2metros por lateral","Max. sizes per lateral","N.\xba m\xe1x. de di\xe1metros por lateral")
B.oM=new A.a("N\xba m\xe1x. de di\xe2metros por tubo principal","Max. sizes per mainline pipe","N.\xba m\xe1x. de di\xe1metros por tuber\xeda principal")
B.y8=new A.a("Emissores por planta (EU)","Emitters per plant (EU)","Emisores por planta (EU)")
B.m9=new A.a("N\xf3s de emissores por lateral (m\xe1x.)","Emitter nodes per lateral (max.)","Nudos de emisores por lateral (m\xe1x.)")
B.z3=new A.a("Varia\xe7\xe3o m\xe1x. de press\xe3o na zona (%; 0 = s\xf3 toler\xe2ncia)","Max. zone pressure variation (%; 0 = tolerance only)","Variaci\xf3n m\xe1x. de presi\xf3n en la zona (%; 0 = solo tolerancia)")
B.ki=new A.a("Lavagem e golpe de ar\xedete","Flushing and water hammer","Lavado y golpe de ariete")
B.Bu=new A.a("Velocidade de lavagem (m/s)","Flushing velocity (m/s)","Velocidad de lavado (m/s)")
B.pQ=new A.a("Press\xe3o m\xedn. no fim da fita (m)","Min. pressure at the tape end (m)","Presi\xf3n m\xedn. al final de la cinta (m)")
B.DS=new A.a("Verificar golpe de ar\xedete (classe do tubo)","Check water hammer (pipe class)","Verificar golpe de ariete (clase de tuber\xeda)")
B.jp=new A.a("Tempo de fechamento de v\xe1lvula (s; 0 = instant\xe2neo)","Valve closure time (s; 0 = instantaneous)","Tiempo de cierre de v\xe1lvula (s; 0 = instant\xe1neo)")
B.kZ=new A.a("Selecionar conex\xf5es automaticamente","Select fittings automatically","Seleccionar conexiones autom\xe1ticamente")
B.r0=new A.a("Comprimento da barra de tubo (m; luvas por barra, 0 = nenhuma)","Pipe stick length (m; couplers per stick, 0 = none)","Longitud de la barra de tuber\xeda (m; manguitos por barra, 0 = ninguno)")
B.xJ=new A.a("Selecionar bomba\u2026","Select pump\u2026","Seleccionar bomba\u2026")
B.lb=new A.a("Vista 3D do terreno\u2026","3D terrain view\u2026","Vista 3D del terreno\u2026")
B.uT=new A.a("Sele\xe7\xe3o autom\xe1tica de bomba","Automatic pump selection","Selecci\xf3n autom\xe1tica de bomba")
B.on=new A.a("Ponto de trabalho: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}","Duty: {q} at {h}  \xb7  static lift \u2248 {s}","Punto de trabajo: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}")
B.jQ=new A.a("Bombas do cat\xe1logo ordenadas por adequa\xe7\xe3o e custo (compra + 5 anos de energia)","Catalog pumps ranked by suitability and cost (purchase + 5 years of energy)","Bombas del cat\xe1logo ordenadas por idoneidad y costo (compra + 5 a\xf1os de energ\xeda)")
B.vE=new A.a("H na vaz\xe3o","H at duty","H al caudal")
B.qs=new A.a("Margem","Margin","Margen")
B.x3=new A.a("Pot\xeancia","Power","Potencia")
B.lU=new A.a("Em paralelo","In parallel","En paralelo")
B.wV=new A.a("Inserir na fonte","Insert at the supply","Insertar en la fuente")
B.DG=new A.a("Aplicar \xe0 bomba existente","Apply to the existing pump","Aplicar a la bomba existente")
B.uJ=new A.a("Execute o projeto com uma fonte de \xe1gua de press\xe3o calculada para obter o ponto de trabalho.","Run the design with a calculated-pressure water supply to get the duty point.","Ejecute el dise\xf1o con una fuente de agua de presi\xf3n calculada para obtener el punto de trabajo.")
B.jn=new A.a("insuficiente","insufficient","insuficiente")
B.B1=new A.a("suc\xe7\xe3o excessiva","suction lift too high","succi\xf3n excesiva")
B.ig=new A.a("Bomba {n} aplicada; execute o projeto novamente","Pump {n} applied; run the design again","Bomba {n} aplicada; vuelva a ejecutar el dise\xf1o")
B.yu=new A.a("Vista 3D do terreno (DEM)","3D terrain view (DEM)","Vista 3D del terreno (MDT)")
B.u8=new A.a("Exagero vertical","Vertical exaggeration","Exageraci\xf3n vertical")
B.u1=new A.a("Arraste para girar; roda do mouse para aproximar. Tubos e laterais s\xe3o drapejados sobre o terreno.","Drag to rotate; mouse wheel zooms. Pipes and laterals are draped on the terrain.","Arrastre para girar; rueda del rat\xf3n para acercar. Las tuber\xedas y laterales se drapean sobre el terreno.")
B.pa=new A.a("Sem dados de eleva\xe7\xe3o: desenhe curvas de n\xedvel ou cotas, ou importe topografia.","No elevation data: draw contours or spot heights, or import a survey.","Sin datos de elevaci\xf3n: dibuje curvas de nivel o cotas, o importe topograf\xeda.")
B.xQ=new A.a("Eleva\xe7\xe3o {a} a {b} m","Elevation {a} to {b} m","Elevaci\xf3n {a} a {b} m")
B.lq=new A.a("Projetos recentes","Recent projects","Proyectos recientes")
B.Ch=new A.a("(nenhum)","(none)","(ninguno)")
B.yQ=new A.a("Hist\xf3rico de vers\xf5es\u2026","Version history\u2026","Historial de versiones\u2026")
B.uc=new A.a("Salvar automaticamente no navegador","Autosave in the browser","Guardar autom\xe1ticamente en el navegador")
B.pb=new A.a("Recuperar projeto","Recover project","Recuperar proyecto")
B.yE=new A.a("Foram encontrados projetos salvos automaticamente que n\xe3o foram salvos em arquivo. Deseja recuper\xe1-los?","Autosaved projects that were never saved to a file were found. Recover them?","Se encontraron proyectos guardados autom\xe1ticamente que no se guardaron en archivo. \xbfDesea recuperarlos?")
B.tD=new A.a("Recuperar","Recover","Recuperar")
B.n0=new A.a("Descartar","Discard","Descartar")
B.pg=new A.a("Depois","Later","Despu\xe9s")
B.ti=new A.a("{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)")
B.DC=new A.a("{n} projetos recuperados","{n} projects recovered","{n} proyectos recuperados")
B.C2=new A.a('Vers\xf5es de "{name}"','Versions of "{name}"','Versiones de "{name}"')
B.D7=new A.a("Nenhuma vers\xe3o guardada ainda: cada Salvar cria uma vers\xe3o (at\xe9 10, no navegador).","No versions kept yet: every Save records a version (up to 10, in the browser).","A\xfan no hay versiones: cada Guardar crea una versi\xf3n (hasta 10, en el navegador).")
B.tH=new A.a("Restaurar","Restore","Restaurar")
B.zp=new A.a("v{v} \u2014 {when}","v{v} \u2014 {when}","v{v} \u2014 {when}")
B.r3=new A.a("Vers\xe3o {v} restaurada","Version {v} restored","Versi\xf3n {v} restaurada")
B.d0=new A.a("Turnos","System flows","Turnos")
B.BT=new A.a("Programa\xe7\xe3o do controlador","Controller programme","Programaci\xf3n del controlador")
B.tr=new A.a("Aplicar dura\xe7\xf5es calculadas aos turnos","Apply computed durations to the flows","Aplicar duraciones calculadas a los turnos")
B.C_=new A.a("Exportar programa\xe7\xe3o (CSV)","Export programme (CSV)","Exportar programaci\xf3n (CSV)")
B.zj=new A.a("Dias","Days","D\xedas")
B.Ey=new A.a("In\xedcio do dia (h)","Day start (h)","Inicio del d\xeda (h)")
B.qA=new A.a("Usar os hor\xe1rios de in\xedcio dos turnos","Use the flows' own start hours","Usar las horas de inicio de los turnos")
B.Ei=new A.a("M\xe1ximo de horas em um dia: {h}","Maximum hours in one day: {h}","M\xe1ximo de horas en un d\xeda: {h}")
B.jJ=new A.a("Execute o projeto para calcular as dura\xe7\xf5es a partir das \xe1reas irrigadas.","Run the design to compute durations from the irrigated areas.","Ejecute el dise\xf1o para calcular las duraciones a partir de las \xe1reas regadas.")
B.F9=new A.a("{name}: {h} h por evento","{name}: {h} h per event","{name}: {h} h por evento")
B.Aw=new A.a("Edi\xe7\xe3o (alias \u23ce)","Editing (alias \u23ce)","Edici\xf3n (alias \u23ce)")
B.ib=new A.a("Remover v\xe9rtice (Ctrl + clique na al\xe7a)","Remove vertex (Ctrl + click on a grip)","Quitar v\xe9rtice (Ctrl + clic en la pinza)")
B.CQ=new A.a("Inserir v\xe9rtice (arrastar a al\xe7a do meio do segmento)","Insert vertex (drag the segment midpoint grip)","Insertar v\xe9rtice (arrastrar la pinza del medio del segmento)")
B.wH=new A.a("Toque: pin\xe7a para zoom, dois dedos para mover, um dedo para desenhar","Touch: pinch to zoom, two fingers to pan, one finger to draw","T\xe1ctil: pellizco para zoom, dos dedos para mover, un dedo para dibujar")
B.FC=new A.a("Piv\xf4 central / lateral m\xf3vel","Centre pivot / linear move","Pivote central / lateral de avance")
B.ji=new A.a("Clique o ponto do piv\xf4 (entrada de \xe1gua, sobre a linha principal) e depois o fim da lateral; Esc cancela","Click the pivot point (water inlet, on the mainline) and then the end of the span; Esc cancels","Clic en el punto del pivote (entrada de agua, sobre la l\xednea principal) y luego el fin de la lateral; Esc cancela")
B.mO=new A.a("Alinhar por 2 pontos","Align by 2 points","Alinear por 2 puntos")
B.px=new A.a("Com a imagem/objetos selecionados: clique o ponto A na origem, onde A deve ficar, o ponto B na origem e onde B deve ficar","With the image/objects selected: click point A on the source, where A must go, point B on the source and where B must go","Con la imagen/objetos seleccionados: clic en el punto A de origen, d\xf3nde debe quedar A, el punto B de origen y d\xf3nde debe quedar B")
B.Ac=new A.a("Ponto A na imagem/desenho a alinhar","Point A on the image/drawing to align","Punto A en la imagen/dibujo a alinear")
B.la=new A.a("Onde o ponto A deve ficar (destino)","Where point A must go (target)","D\xf3nde debe quedar el punto A (destino)")
B.E_=new A.a("Ponto B na imagem/desenho a alinhar","Point B on the image/drawing to align","Punto B en la imagen/dibujo a alinear")
B.FD=new A.a("Onde o ponto B deve ficar (define escala e rota\xe7\xe3o)","Where point B must go (sets scale and rotation)","D\xf3nde debe quedar el punto B (define escala y rotaci\xf3n)")
B.jx=new A.a("Manter a escala (s\xf3 mover e girar)","Keep the scale (move and rotate only)","Mantener la escala (solo mover y girar)")
B.pX=new A.a("Alinhado: escala \xd7{s}, rota\xe7\xe3o {r}\xb0","Aligned: scale \xd7{s}, rotation {r}\xb0","Alineado: escala \xd7{s}, rotaci\xf3n {r}\xb0")
B.D_=new A.a("Selecione antes a imagem ou os objetos a alinhar","Select the image or the objects to align first","Seleccione antes la imagen o los objetos a alinear")
B.iW=new A.a("Caminho do perfil removido do desenho","Profile path removed from the drawing","Camino del perfil quitado del dibujo")
B.ce=new A.a("Eleva\xe7\xe3o","Elevation","Elevaci\xf3n")
B.jF=new A.a("Eleva\xe7\xe3o da curva de n\xedvel","Contour elevation","Elevaci\xf3n de la curva de nivel")
B.kg=new A.a("Eleva\xe7\xe3o da cota","Spot height elevation","Elevaci\xf3n de la cota")
B.cl=new A.a("Intervalo entre curvas (m)","Contour interval (m)","Intervalo entre curvas (m)")
B.Bn=new A.a("Pr\xf3xima curva: somar o intervalo","Next contour: add the interval","Pr\xf3xima curva: sumar el intervalo")
B.oa=new A.a("Perguntar a eleva\xe7\xe3o ao terminar cada curva/cota","Ask for the elevation after each contour/spot","Preguntar la elevaci\xf3n al terminar cada curva/cota")
B.qW=new A.a('Uma curva de n\xedvel liga pontos de mesma altitude. Informe a altitude desta curva. Com "somar o intervalo", a pr\xf3xima curva j\xe1 vem com a eleva\xe7\xe3o seguinte.','A contour joins points of the same altitude. Enter the altitude of this line. With "add the interval", the next contour comes with the following elevation.','Una curva de nivel une puntos de la misma altitud. Indique la altitud de esta curva. Con "sumar el intervalo", la pr\xf3xima curva ya viene con la elevaci\xf3n siguiente.')
B.qX=new A.a("Cota de ponto: altitude do terreno neste lugar (po\xe7o, casa de bombas, canto do talh\xe3o).","Spot height: ground altitude at this place (well, pump house, field corner).","Cota de punto: altitud del terreno en este lugar (pozo, casa de bombas, esquina de la parcela).")
B.cy=new A.a("Terreno","Terrain","Terreno")
B.yF=new A.a("Baixar eleva\xe7\xe3o da internet (MDT)\u2026","Download elevation from the internet (DEM)\u2026","Descargar elevaci\xf3n de internet (MDT)\u2026")
B.wv=new A.a("Gerar curvas de n\xedvel do modelo\u2026","Generate contours from the model\u2026","Generar curvas de nivel del modelo\u2026")
B.u7=new A.a("Interpola\xe7\xe3o do terreno","Terrain interpolation","Interpolaci\xf3n del terreno")
B.Cw=new A.a("Triangula\xe7\xe3o (TIN / MDT)","Triangulation (TIN / DTM)","Triangulaci\xf3n (TIN / MDT)")
B.EQ=new A.a("Inverso da dist\xe2ncia (IDW)","Inverse distance (IDW)","Inverso de la distancia (IDW)")
B.i1=new A.a("Limpar perfil do desenho","Clear profile from the drawing","Limpiar perfil del dibujo")
B.Fl=new A.a("Modelo do terreno: {n} pontos, eleva\xe7\xe3o {a} a {b} m","Terrain model: {n} points, elevation {a} to {b} m","Modelo del terreno: {n} puntos, elevaci\xf3n {a} a {b} m")
B.jb=new A.a("Sem dados de eleva\xe7\xe3o","No elevation data","Sin datos de elevaci\xf3n")
B.q9=new A.a("Interpola\xe7\xe3o do terreno (MDT)","Terrain interpolation (DTM)","Interpolaci\xf3n del terreno (MDT)")
B.tL=new A.a("Eleva\xe7\xe3o da internet (MDT online)","Elevation from the internet (online DEM)","Elevaci\xf3n de internet (MDT en l\xednea)")
B.qz=new A.a("Baixa a altitude de uma grade de pontos sobre o projeto a partir de um modelo digital de eleva\xe7\xe3o p\xfablico e cria cotas de ponto. Precisa de georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia). Resolu\xe7\xe3o de 30\u201390 m: bom para o relevo geral, n\xe3o substitui um levantamento.","Downloads the altitude of a grid of points over the project from a public digital elevation model and creates spot heights. Needs a georeference (File \u2192 Georeference). 30\u201390 m resolution: good for the general relief, not a replacement for a survey.","Descarga la altitud de una malla de puntos sobre el proyecto desde un modelo digital de elevaci\xf3n p\xfablico y crea cotas de punto. Necesita georreferencia (Archivo \u2192 Georreferencia). Resoluci\xf3n de 30\u201390 m: buena para el relieve general, no sustituye un levantamiento.")
B.o0=new A.a("Fonte","Source","Fuente")
B.l3=new A.a("Espa\xe7amento da grade (m)","Grid spacing (m)","Espaciado de la malla (m)")
B.iN=new A.a("\xc1rea {w} \xd7 {h} m \u2192 {n} pontos em {r} requisi\xe7\xf5es","Area {w} \xd7 {h} m \u2192 {n} points in {r} requests","\xc1rea {w} \xd7 {h} m \u2192 {n} puntos en {r} solicitudes")
B.y9=new A.a("Substituir cotas baixadas anteriormente","Replace previously downloaded spot heights","Reemplazar cotas descargadas antes")
B.ur=new A.a("O projeto j\xe1 tem {n} cotas e {m} curvas pr\xf3prias ({a} a {b} m).","The project already has {n} spot heights and {m} contours of its own ({a} to {b} m).","El proyecto ya tiene {n} cotas y {m} curvas propias ({a} a {b} m).")
B.wQ=new A.a("Substituir essas cotas e curvas pelo modelo baixado","Replace them with the downloaded model","Reemplazarlas por el modelo descargado")
B.x1=new A.a("Mantidas, elas entram no mesmo modelo que o MDT. Se estiverem noutro datum (ex.: dados de exemplo a 100 m) o terreno fica cheio de picos.","Kept, they join the same model as the DEM. On another datum (e.g. example data at 100 m) the terrain turns into spikes.","Si se mantienen, entran en el mismo modelo que el MDT. En otro datum (p. ej. datos de ejemplo a 100 m) el terreno se llena de picos.")
B.uM=new A.a("Cotas existentes fora do datum do MDT","Existing heights off the DEM datum","Cotas existentes fuera del datum del MDT")
B.jV=new A.a("As cotas e curvas do projeto ({a} a {b} m) n\xe3o batem com o modelo baixado ({c} a {d} m): o terreno ficaria cheio de picos. Remover as cotas e curvas existentes? (Ctrl+Z desfaz.)","The project's own heights and contours ({a} to {b} m) do not match the downloaded model ({c} to {d} m): the terrain would be full of spikes. Remove the existing heights and contours? (Ctrl+Z undoes it.)","Las cotas y curvas del proyecto ({a} a {b} m) no coinciden con el modelo descargado ({c} a {d} m): el terreno quedar\xeda lleno de picos. \xbfQuitar las cotas y curvas existentes? (Ctrl+Z deshace.)")
B.qr=new A.a("Manter","Keep","Mantener")
B.pL=new A.a("Limite do servidor: aguardando {s} s\u2026","Server limit: waiting {s} s\u2026","L\xedmite del servidor: esperando {s} s\u2026")
B.zz=new A.a("Tempo estimado: {t}","Estimated time: {t}","Tiempo estimado: {t}")
B.yj=new A.a("O Open-Meteo aceita cerca de 600 pontos por minuto; para \xe1reas grandes a fonte Terrain Tiles \xe9 muito mais r\xe1pida (poucas requisi\xe7\xf5es, sem limite).","Open-Meteo takes about 600 points per minute; for large areas the Terrain Tiles source is much faster (a few requests, no limit).","Open-Meteo acepta unos 600 puntos por minuto; para \xe1reas grandes la fuente Terrain Tiles es mucho m\xe1s r\xe1pida (pocas solicitudes, sin l\xedmite).")
B.xe=new A.a("Download cancelado","Download cancelled","Descarga cancelada")
B.Cr=new A.a("{n} pontos sem dados","{n} points without data","{n} puntos sin datos")
B.qO=new A.a('As cotas v\xe3o para a camada "MDT baixado" (pode ser ocultada em Camadas).','The points go to the "Downloaded DEM" layer (it can be hidden in Layers).','Las cotas van a la capa "MDT descargado" (puede ocultarse en Capas).')
B.ta=new A.a("Usar a \xe1rea vis\xedvel em vez dos limites do projeto","Use the visible area instead of the project extent","Usar el \xe1rea visible en lugar de los l\xedmites del proyecto")
B.lR=new A.a("Baixar","Download","Descargar")
B.w8=new A.a("Baixando {i} de {n}\u2026","Downloading {i} of {n}\u2026","Descargando {i} de {n}\u2026")
B.Ev=new A.a("{n} cotas importadas ({s})","{n} spot heights imported ({s})","{n} cotas importadas ({s})")
B.jB=new A.a("Defina antes a georrefer\xeancia do projeto (Arquivo \u2192 Georrefer\xeancia): latitude/longitude de um ponto do desenho.","Set the project georeference first (File \u2192 Georeference): latitude/longitude of a drawing point.","Defina antes la georreferencia del proyecto (Archivo \u2192 Georreferencia): latitud/longitud de un punto del dibujo.")
B.kA=new A.a("Falha ao baixar eleva\xe7\xf5es: {e}","Failed to download elevations: {e}","Error al descargar elevaciones: {e}")
B.l1=new A.a("Desenhe algo (ou use a \xe1rea vis\xedvel) para definir a regi\xe3o.","Draw something (or use the visible area) to define the region.","Dibuje algo (o use el \xe1rea visible) para definir la regi\xf3n.")
B.bN=new A.a("Gerar curvas de n\xedvel","Generate contours","Generar curvas de nivel")
B.nh=new A.a("Cria curvas de n\xedvel a partir do modelo digital do terreno (triangula\xe7\xe3o das cotas e curvas existentes). \xdatil depois de importar pontos ou baixar eleva\xe7\xe3o da internet. As curvas geradas s\xe3o s\xf3 desenho: n\xe3o alteram o modelo.","Creates contours from the digital terrain model (triangulation of the existing spot heights and contours). Useful after importing points or downloading elevation. Generated contours are drawing only: they do not change the model.","Crea curvas de nivel a partir del modelo digital del terreno (triangulaci\xf3n de las cotas y curvas existentes). \xdatil despu\xe9s de importar puntos o descargar elevaci\xf3n. Las curvas generadas son solo dibujo: no cambian el modelo.")
B.Fm=new A.a("Intervalo (m)","Interval (m)","Intervalo (m)")
B.qu=new A.a("Remover curvas geradas anteriormente","Remove previously generated contours","Quitar curvas generadas antes")
B.t_=new A.a("{n} curvas entre {a} e {b} m","{n} contours between {a} and {b} m","{n} curvas entre {a} y {b} m")
B.kj=new A.a("{n} curvas de n\xedvel geradas","{n} contours generated","{n} curvas de nivel generadas")
B.om=new A.a("Gerar","Generate","Generar")
B.uL=new A.a("Terreno","Ground","Terreno")
B.Eu=new A.a("Tubo (com profundidade)","Pipe (with depth)","Tuber\xeda (con profundidad)")
B.BZ=new A.a("Linha piezom\xe9trica (press\xe3o + cota)","Hydraulic grade line (pressure + elevation)","L\xednea piezom\xe9trica (presi\xf3n + cota)")
B.t3=new A.a("Ponto mais baixo","Lowest point","Punto m\xe1s bajo")
B.De=new A.a("Ponto mais alto","Highest point","Punto m\xe1s alto")
B.BE=new A.a("Como usar: Perfil (PR) \u2192 clique os pontos do caminho \u2192 Enter (ou Concluir). Ou selecione um tubo/lateral. A linha roxa no desenho \xe9 o caminho: Limpar (ou Esc com a ferramenta Perfil) a remove.","How to use: Profile (PR) \u2192 click the path points \u2192 Enter (or Done). Or select a pipe/lateral. The purple line on the drawing is the path: Clear (or Esc with the Profile tool) removes it.","C\xf3mo usar: Perfil (PR) \u2192 clic en los puntos del camino \u2192 Intro (o Terminar). O seleccione una tuber\xeda/lateral. La l\xednea morada en el dibujo es el camino: Limpiar (o Esc con la herramienta Perfil) la quita.")
B.no=new A.a("Sem dados de eleva\xe7\xe3o: o perfil sai plano. Desenhe curvas de n\xedvel (CT) ou cotas (SP), importe topografia ou baixe eleva\xe7\xe3o da internet (Projeto \u2192 Terreno).","No elevation data: the profile is flat. Draw contours (CT) or spot heights (SP), import a survey or download elevation from the internet (Design \u2192 Terrain).","Sin datos de elevaci\xf3n: el perfil sale plano. Dibuje curvas de nivel (CT) o cotas (SP), importe topograf\xeda o descargue elevaci\xf3n de internet (Dise\xf1o \u2192 Terreno).")
B.cM=new A.a("Esta\xe7\xe3o","Station","Estaci\xf3n")
B.cS=new A.a("Piv\xf4s","Pivots","Pivotes")
B.n6=new A.a("Piv\xf4","Pivot","Pivote")
B.cB=new A.a("Torres","Towers","Torres")
B.DK=new A.a("P dispon\xedvel","P available","P disponible")
B.nk=new A.a("Desn\xedvel","Rise","Desnivel")
B.mR=new A.a("L\xe2mina/ciclo","Depth/cycle","L\xe1mina/ciclo")
B.E8=new A.a("Horas/ciclo","Hours/cycle","Horas/ciclo")
B.qF=new A.a("Taxa aplic. pico","Peak app. rate","Tasa aplic. pico")
B.aI=new A.a("Piv\xf4 central","Centre pivot","Pivote central")
B.u3=new A.a("Lateral m\xf3vel (linear)","Linear move","Lateral de avance (linear)")
B.DM=new A.a("torres","towers","torres")
B.vG=new A.a("Piv\xf4s e laterais m\xf3veis","Pivots and linear moves","Pivotes y laterales de avance")
B.uI=new A.a("Press\xe3o insuficiente na entrada do piv\xf4","Not enough pressure at the pivot inlet","Presi\xf3n insuficiente en la entrada del pivote")
B.rX=new A.a("Taxa de aplica\xe7\xe3o na ponta acima do limite do solo","Application rate at the end above the soil limit","Tasa de aplicaci\xf3n en la punta por encima del l\xedmite del suelo")
B.AW=new A.a("Piv\xf4 sem vaz\xe3o (l\xe2mina ou horas por ciclo zeradas)","Pivot without flow (depth or hours per cycle are zero)","Pivote sin caudal (l\xe1mina u horas por ciclo en cero)")
B.jS=new A.a("Piv\xf4 sem press\xe3o de ponta definida","Pivot without an end pressure","Pivote sin presi\xf3n de punta definida")
B.og=new A.a("Tipo de m\xe1quina","Machine type","Tipo de m\xe1quina")
B.mN=new A.a("Comprimento da lateral (m)","Span pipe length (m)","Longitud de la lateral (m)")
B.oT=new A.a("V\xe3o entre torres (m)","Span between towers (m)","Vano entre torres (m)")
B.nH=new A.a("Percurso da lateral m\xf3vel (m)","Linear travel length (m)","Recorrido de la lateral (m)")
B.Cy=new A.a("Tubo dos v\xe3os (cat\xe1logo)","Span pipe (catalogue)","Tubo de los vanos (cat\xe1logo)")
B.vI=new A.a("Di\xe2metro interno do tubo (mm)","Pipe inner diameter (mm)","Di\xe1metro interior del tubo (mm)")
B.pd=new A.a("C de Hazen-Williams","Hazen-Williams C","C de Hazen-Williams")
B.F7=new A.a("Altura do tubo (m)","Pipe height (m)","Altura del tubo (m)")
B.lc=new A.a("Press\xe3o na ponta","End pressure","Presi\xf3n en la punta")
B.p9=new A.a("Vaz\xe3o do canh\xe3o final","End gun flow","Caudal del ca\xf1\xf3n final")
B.rp=new A.a("Press\xe3o do canh\xe3o final","End gun pressure","Presi\xf3n del ca\xf1\xf3n final")
B.vX=new A.a("Alcance al\xe9m da ponta (m)","Throw beyond the end (m)","Alcance m\xe1s all\xe1 de la punta (m)")
B.td=new A.a("L\xe2mina bruta por ciclo (mm)","Gross depth per cycle (mm)","L\xe1mina bruta por ciclo (mm)")
B.E4=new A.a("Horas por ciclo (volta/passada)","Hours per cycle (revolution/pass)","Horas por ciclo (vuelta/pasada)")
B.xl=new A.a("Largura molhada na ponta (m)","Wetted width at the end (m)","Ancho mojado en la punta (m)")
B.pu=new A.a("Perdas da m\xe1quina (m)","Machine losses (m)","P\xe9rdidas de la m\xe1quina (m)")
B.mD=new A.a("Taxa m\xe1x. do solo (mm/h; 0 = n\xe3o verificar)","Soil max. rate (mm/h; 0 = no check)","Tasa m\xe1x. del suelo (mm/h; 0 = no verificar)")
B.iY=new A.a("Setor irrigado (\xb0)","Irrigated sector (\xb0)","Sector regado (\xb0)")
B.wO=new A.a("Custo da m\xe1quina","Machine cost","Costo de la m\xe1quina")
B.u6=new A.a("\xc2ngulo de desenho (\xb0)","Drawing angle (\xb0)","\xc1ngulo de dibujo (\xb0)")
B.cs=new A.a("Resultado","Result","Resultado")
B.ma=new A.a("Press\xe3o necess\xe1ria na entrada","Required inlet pressure","Presi\xf3n necesaria en la entrada")
B.zI=new A.a("Gerada do modelo (n\xe3o entra no MDT)","Generated from the model (not used by the DTM)","Generada del modelo (no entra al MDT)")
B.kX=new A.a("Verifica\xe7\xe3o do projeto (Design Check)","Design check","Verificaci\xf3n del dise\xf1o (Design Check)")
B.iw=new A.a("Varre o desenho procurando erros que impedem ou distorcem o c\xe1lculo hidr\xe1ulico: itens desconectados, tubos que se cruzam sem jun\xe7\xe3o, pontas soltas, zonas sem emissores, duplicados e dados de cat\xe1logo faltando. Clique num item para localiz\xe1-lo.","Sweeps the drawing for errors that stop or distort the hydraulic calculation: disconnected items, pipes crossing without a junction, dead ends, zones without emitters, duplicates and missing catalogue data. Click an item to locate it.","Recorre el dibujo buscando errores que impiden o distorsionan el c\xe1lculo hidr\xe1ulico: elementos desconectados, tuber\xedas que se cruzan sin nudo, extremos sueltos, zonas sin emisores, duplicados y datos de cat\xe1logo faltantes. Haga clic en un \xedtem para ubicarlo.")
B.B5=new A.a("{e} erro(s), {w} aviso(s), {i} nota(s)","{e} error(s), {w} warning(s), {i} note(s)","{e} error(es), {w} aviso(s), {i} nota(s)")
B.wz=new A.a("Nenhum erro encontrado: o projeto est\xe1 pronto para o c\xe1lculo (F5).","No errors found: the design is ready to run (F5).","No se encontraron errores: el dise\xf1o est\xe1 listo para calcular (F5).")
B.A6=new A.a("Verificar novamente","Run again","Verificar de nuevo")
B.nv=new A.a("Erro","Error","Error")
B.lI=new A.a("Aviso","Warning","Aviso")
B.qZ=new A.a("Nota","Note","Nota")
B.ob=new A.a("Nenhum item hidr\xe1ulico no desenho","No hydraulic items in the drawing","Ning\xfan elemento hidr\xe1ulico en el dibujo")
B.pI=new A.a("Falta a fonte de \xe1gua (WS)","Water supply missing (WS)","Falta la fuente de agua (WS)")
B.to=new A.a("H\xe1 laterais/emissores mas nenhuma v\xe1lvula de controle (V)","There are laterals/outlets but no control valve (V)","Hay laterales/emisores pero ninguna v\xe1lvula de control (V)")
B.yq=new A.a("Item desconectado da rede","Item not connected to the network","Elemento desconectado de la red")
B.qU=new A.a("Zona sem emissores","Zone without emitters","Zona sin emisores")
B.z_=new A.a("V\xe1lvulas com o mesmo nome de zona","Valves with the same zone name","V\xe1lvulas con el mismo nombre de zona")
B.j4=new A.a("Ponta solta na linha principal (tubo sem sa\xedda)","Dead end on the mainline (pipe with no outlet)","Extremo suelto en la l\xednea principal (tuber\xeda sin salida)")
B.p6=new A.a("Tubo de zona terminando sem lateral","Zone pipe ending without a lateral","Tuber\xeda de zona que termina sin lateral")
B.ok=new A.a("Tubo de comprimento zero","Zero-length pipe","Tuber\xeda de longitud cero")
B.k6=new A.a("Segmento menor que a toler\xe2ncia de conex\xe3o","Segment shorter than the connection tolerance","Segmento menor que la tolerancia de conexi\xf3n")
B.BU=new A.a("Itens duplicados na mesma posi\xe7\xe3o","Duplicated items at the same position","Elementos duplicados en la misma posici\xf3n")
B.jL=new A.a("Tubos se cruzam sem jun\xe7\xe3o (n\xe3o est\xe3o conectados)","Pipes cross without a junction (not connected)","Tuber\xedas se cruzan sin nudo (no est\xe1n conectadas)")
B.rk=new A.a("Modelo do cat\xe1logo n\xe3o encontrado","Catalogue model not found","Modelo del cat\xe1logo no encontrado")
B.F8=new A.a("Fonte com press\xe3o fixa igual a zero","Supply with a fixed pressure of zero","Fuente con presi\xf3n fija igual a cero")
B.xy=new A.a("Piv\xf4 fora da linha principal","Pivot not on the mainline","Pivote fuera de la l\xednea principal")
B.zF=new A.a("Sem dados de eleva\xe7\xe3o: o terreno \xe9 considerado plano","No elevation data: the ground is taken as flat","Sin datos de elevaci\xf3n: el terreno se considera plano")
B.jW=new A.a("Linha principal em anel (rede malhada) \u2014 resolvida pelo solver","Looped mainline (meshed network) \u2014 solved by the solver","L\xednea principal en anillo (red mallada) \u2014 resuelta por el solver")
B.y_=new A.a("\xc1rea sem emissores dentro","Area with no emitters inside","\xc1rea sin emisores dentro")
B.Dx=new A.a("Por qu\xea","Why","Por qu\xe9")
B.ug=new A.a("Como resolver","How to fix","C\xf3mo resolver")
B.cL=new A.a("Mostrar no desenho","Show on the drawing","Mostrar en el dibujo")
B.qB=new A.a("Corrigir automaticamente","Fix automatically","Corregir autom\xe1ticamente")
B.zs=new A.a("Aplica as corre\xe7\xf5es seguras, recalcula e repete at\xe9 n\xe3o restar nada que ele consiga corrigir sozinho. Tudo vira um \xfanico passo: desfa\xe7a com Ctrl+Z.","Applies the safe corrections, runs the design again and repeats until nothing is left that it can fix on its own. It is all one step: undo with Ctrl+Z.","Aplica las correcciones seguras, recalcula y repite hasta que no quede nada que pueda corregir solo. Todo es un \xfanico paso: deshaga con Ctrl+Z.")
B.c5=new A.a("Otimizar projeto","Optimise design","Optimizar dise\xf1o")
B.iQ=new A.a("erro(s)","error(s)","error(es)")
B.C7=new A.a("aviso(s)","warning(s)","aviso(s)")
B.Bb=new A.a("nota(s)","note(s)","nota(s)")
B.wW=new A.a("Nenhum problema: o projeto atende todos os requisitos.","No problems: the design meets every requirement.","Ning\xfan problema: el dise\xf1o cumple todos los requisitos.")
B.kn=new A.a("Nenhum problema no desenho. Calcule o projeto (F5) para conferir press\xf5es e vaz\xf5es.","No problems in the drawing. Run the design (F5) to check pressures and flows.","Ning\xfan problema en el dibujo. Calcule el dise\xf1o (F5) para comprobar presiones y caudales.")
B.kr=new A.a("Estes s\xe3o os problemas do desenho e das configura\xe7\xf5es. Depois de calcular (F5) aparecem tamb\xe9m os de press\xe3o, vaz\xe3o e bomba.","These are the problems of the drawing and the settings. After a design run (F5) the pressure, flow and pump ones show too.","Estos son los problemas del dibujo y de la configuraci\xf3n. Tras calcular (F5) aparecen tambi\xe9n los de presi\xf3n, caudal y bomba.")
B.vK=new A.a("Calculando\u2026","Designing\u2026","Calculando\u2026")
B.kU=new A.a("Corrigindo\u2026 rodada {n}","Fixing\u2026 round {n}","Corrigiendo\u2026 ronda {n}")
B.zP=new A.a("Corrigido: {m}","Fixed: {m}","Corregido: {m}")
B.qL=new A.a("N\xe3o foi poss\xedvel corrigir: {m}","Could not fix: {m}","No se pudo corregir: {m}")
B.cF=new A.a("Corre\xe7\xe3o autom\xe1tica","Automatic correction","Correcci\xf3n autom\xe1tica")
B.wu=new A.a('Nada p\xf4de ser corrigido automaticamente. Siga o "Como resolver" de cada mensagem.','Nothing could be fixed automatically. Follow the "How to fix" of each message.','No se pudo corregir nada autom\xe1ticamente. Siga el "C\xf3mo resolver" de cada mensaje.')
B.Fw=new A.a("{n} corre\xe7\xe3o(\xf5es) aplicada(s):","{n} correction(s) applied:","{n} correcci\xf3n(es) aplicada(s):")
B.vJ=new A.a('Restam {e} erro(s) e {w} aviso(s) que dependem de uma decis\xe3o sua: veja o "Como resolver" de cada um em Mensagens.','{e} error(s) and {w} warning(s) are left that need your decision: see the "How to fix" of each one in Messages.','Quedan {e} error(es) y {w} aviso(s) que dependen de una decisi\xf3n suya: vea el "C\xf3mo resolver" de cada uno en Mensajes.')
B.i0=new A.a("Pronto: nenhum erro ou aviso restante.","Done: no errors or warnings left.","Listo: no quedan errores ni avisos.")
B.oo=new A.a("Tudo foi feito num \xfanico passo do hist\xf3rico: Desfazer (Ctrl+Z) volta ao projeto anterior.","Everything was a single history step: Undo (Ctrl+Z) returns to the previous design.","Todo fue un \xfanico paso del historial: Deshacer (Ctrl+Z) vuelve al dise\xf1o anterior.")
B.AY=new A.a("Desfazer tudo","Undo all","Deshacer todo")
B.rv=new A.a("C\xe1lculo conclu\xeddo com {n} erro(s). A aba Mensagens explica cada um e como resolver.","Design finished with {n} error(s). The Messages tab explains each one and how to fix it.","C\xe1lculo terminado con {n} error(es). La pesta\xf1a Mensajes explica cada uno y c\xf3mo resolverlo.")
B.B0=new A.a("laterais","laterals","laterales")
B.xd=new A.a("tubos de zona","zone pipes","tuber\xedas de zona")
B.Fn=new A.a("linha principal","mainline","l\xednea principal")
B.CO=new A.a("Procura o menor custo anual (investimento anualizado + energia) que ainda atende todas as press\xf5es e velocidades: dimensiona os tubos por programa\xe7\xe3o linear, escolhe a bomba de menor custo de ciclo de vida e a v\xe1lvula certa para cada zona. Se n\xe3o melhorar, nada \xe9 alterado.","Looks for the lowest annual cost (annualised investment + energy) that still meets every pressure and velocity: sizes the pipes by linear programming, picks the pump with the lowest life-cycle cost and the right valve for each zone. If nothing improves, nothing changes.","Busca el menor costo anual (inversi\xf3n anualizada + energ\xeda) que a\xfan cumple todas las presiones y velocidades: dimensiona las tuber\xedas por programaci\xf3n lineal, elige la bomba de menor costo de ciclo de vida y la v\xe1lvula correcta para cada zona. Si no mejora, no se cambia nada.")
B.lW=new A.a("Escolher a bomba de menor custo total (compra + energia)","Choose the pump with the lowest total cost (purchase + energy)","Elegir la bomba de menor costo total (compra + energ\xeda)")
B.D4=new A.a("Ajustar o tamanho de cada v\xe1lvula \xe0 vaz\xe3o da sua zona","Size each valve to the flow of its zone","Ajustar el tama\xf1o de cada v\xe1lvula al caudal de su zona")
B.uW=new A.a("Redimensionar tamb\xe9m os tubos com di\xe2metro fixado por voc\xea","Also resize the pipes whose diameter you fixed","Redimensionar tambi\xe9n las tuber\xedas con di\xe1metro fijado por usted")
B.ro=new A.a("Otimizar","Optimise","Optimizar")
B.pU=new A.a("Otimizando: calculando alternativas\u2026","Optimising: designing alternatives\u2026","Optimizando: calculando alternativas\u2026")
B.lB=new A.a("Antes","Before","Antes")
B.Ft=new A.a("Depois","After","Despu\xe9s")
B.q3=new A.a("Investimento","Investment","Inversi\xf3n")
B.oO=new A.a("Energia por ano","Energy per year","Energ\xeda por a\xf1o")
B.vS=new A.a("Erros / avisos","Errors / warnings","Errores / avisos")
B.q1=new A.a("Otimiza\xe7\xe3o aplicada: o projeto ficou mais barato ou com menos problemas.","Optimisation applied: the design is cheaper or has fewer problems.","Optimizaci\xf3n aplicada: el dise\xf1o es m\xe1s barato o tiene menos problemas.")
B.tf=new A.a("O projeto j\xe1 estava otimizado: nenhuma alternativa melhor foi encontrada e nada foi alterado.","The design was already optimal: no better alternative was found and nothing changed.","El dise\xf1o ya estaba optimizado: no se encontr\xf3 una alternativa mejor y no se cambi\xf3 nada.")
B.jP=new A.a("Desfazer otimiza\xe7\xe3o","Undo optimisation","Deshacer optimizaci\xf3n")
B.rG=new A.a("Custos com os pre\xe7os do cat\xe1logo e os par\xe2metros econ\xf4micos (juros, prazo, tarifa de energia, horas por ano).","Costs use the catalogue prices and the economic parameters (interest, term, energy tariff, hours per year).","Costos con los precios del cat\xe1logo y los par\xe1metros econ\xf3micos (inter\xe9s, plazo, tarifa de energ\xeda, horas por a\xf1o).")
B.up=new A.a("Corre\xe7\xe3o: {n}","Correction: {n}","Correcci\xf3n: {n}")
B.qN=new A.a("Otimiza\xe7\xe3o","Optimisation","Optimizaci\xf3n")
B.Ex=new A.a("Limites de velocidade imposs\xedveis","Impossible velocity limits","L\xedmites de velocidad imposibles")
B.qm=new A.a("Horas de funcionamento por ano imposs\xedveis","Impossible operating hours per year","Horas de funcionamiento por a\xf1o imposibles")
B.xo=new A.a("Par\xe2metros econ\xf4micos imposs\xedveis","Impossible economic parameters","Par\xe1metros econ\xf3micos imposibles")
B.yy=new A.a("Toler\xe2ncia de conex\xe3o fora da faixa","Connection tolerance out of range","Tolerancia de conexi\xf3n fuera de rango")
B.CK=new A.a("Varia\xe7\xe3o de press\xe3o na zona fora da faixa","Zone pressure variation out of range","Variaci\xf3n de presi\xf3n en la zona fuera de rango")
B.v8=new A.a("Temperatura da \xe1gua fora da faixa","Water temperature out of range","Temperatura del agua fuera de rango")
B.yf=new A.a("Nenhum tubo habilitado para este uso","No pipe enabled for this use","Ninguna tuber\xeda habilitada para este uso")
B.v0=new A.a("M\xe1ximo da fonte menor que o valor de projeto","Supply maximum below the design value","M\xe1ximo de la fuente menor que el valor de dise\xf1o")
B.qS=new A.a("Zonas fora de todos os turnos","Zones in no system flow","Zonas fuera de todos los turnos")
B.oQ=new A.a("Turnos vazios","Empty system flows","Turnos vac\xedos")
B.lp=new A.a("Turno com dura\xe7\xe3o zero","System flow with zero duration","Turno con duraci\xf3n cero")
B.nT=new A.a("Press\xe3o do emissor fora da faixa do bocal","Emitter pressure outside the nozzle range","Presi\xf3n del emisor fuera del rango de la boquilla")
B.Dg=new A.a("Rota\xe7\xe3o da bomba fora da faixa","Pump speed out of range","Velocidad de la bomba fuera de rango")
B.iK=new A.a("Conectar ao mais pr\xf3ximo (at\xe9 {d} m)","Connect to the nearest (up to {d} m)","Conectar al m\xe1s cercano (hasta {d} m)")
B.qk=new A.a("Excluir o tubo","Delete the pipe","Eliminar la tuber\xeda")
B.wT=new A.a("Remover v\xe9rtices repetidos","Remove repeated vertices","Quitar v\xe9rtices repetidos")
B.mU=new A.a("Manter s\xf3 um","Keep only one","Dejar solo uno")
B.nD=new A.a("Renomear as zonas repetidas","Rename the repeated zones","Renombrar las zonas repetidas")
B.Cf=new A.a("Calcular a press\xe3o necess\xe1ria na fonte","Calculate the pressure needed at the supply","Calcular la presi\xf3n necesaria en la fuente")
B.mM=new A.a("Escolher a bomba adequada","Choose a suitable pump","Elegir la bomba adecuada")
B.Ek=new A.a("Trocar por bomba submersa","Replace with a submersible pump","Cambiar por bomba sumergible")
B.pn=new A.a("Deixar o c\xe1lculo escolher os di\xe2metros","Let the design choose the diameters","Dejar que el c\xe1lculo elija los di\xe1metros")
B.uk=new A.a("Usar tubo de classe de press\xe3o maior","Use a pipe of a higher pressure class","Usar tuber\xeda de clase de presi\xf3n mayor")
B.od=new A.a("Trocar a v\xe1lvula pelo tamanho certo","Change the valve to the right size","Cambiar la v\xe1lvula por el tama\xf1o correcto")
B.DP=new A.a("Usar um modelo do cat\xe1logo","Use a catalogue model","Usar un modelo del cat\xe1logo")
B.kc=new A.a("Dividir em mais turnos","Split into more system flows","Dividir en m\xe1s turnos")
B.mk=new A.a("Adicionar as conex\xf5es ao cat\xe1logo","Add the fittings to the catalogue","A\xf1adir las conexiones al cat\xe1logo")
B.rd=new A.a("Conectar os tubos no cruzamento","Connect the pipes at the crossing","Conectar las tuber\xedas en el cruce")
B.lH=new A.a("Colocar a fonte na ponta livre","Place the supply at the free end","Colocar la fuente en el extremo libre")
B.tV=new A.a("Voltar aos valores padr\xe3o","Restore the default values","Volver a los valores por defecto")
B.zS=new A.a("Criar um turno para essas zonas","Create a system flow for these zones","Crear un turno para esas zonas")
B.kL=new A.a("Limpar os turnos","Clean up the system flows","Limpiar los turnos")
B.mW=new A.a("Definir 1 h de dura\xe7\xe3o","Set a 1 h duration","Definir 1 h de duraci\xf3n")
B.m8=new A.a("Usar a press\xe3o nominal do emissor","Use the emitter nominal pressure","Usar la presi\xf3n nominal del emisor")
B.op=new A.a("Voltar \xe0 rota\xe7\xe3o nominal","Back to the rated speed","Volver a la velocidad nominal")
B.x4=new A.a("Ajustar os limites da fonte","Adjust the supply limits","Ajustar los l\xedmites de la fuente")
B.xi=new A.a("Habilitar tubos no cat\xe1logo","Enable pipes in the catalogue","Habilitar tuber\xedas en el cat\xe1logo")
B.Bk=new A.a("item conectado (movido {d} m)","item connected (moved {d} m)","elemento conectado (movido {d} m)")
B.tv=new A.a("{n} tubo(s) de comprimento zero exclu\xeddo(s)","{n} zero-length pipe(s) deleted","{n} tuber\xeda(s) de longitud cero eliminada(s)")
B.Dk=new A.a("{n} v\xe9rtice(s) repetido(s) removido(s)","{n} repeated vertex(es) removed","{n} v\xe9rtice(s) repetido(s) quitado(s)")
B.tx=new A.a("{n} item(ns) duplicado(s) removido(s)","{n} duplicated item(s) removed","{n} elemento(s) duplicado(s) quitado(s)")
B.pA=new A.a("{n} zona(s) renomeada(s)","{n} zone(s) renamed","{n} zona(s) renombrada(s)")
B.tn=new A.a("a press\xe3o da fonte agora \xe9 calculada ({n})","the supply pressure is now calculated ({n})","la presi\xf3n de la fuente ahora se calcula ({n})")
B.ll=new A.a("bomba trocada por {n}","pump changed to {n}","bomba cambiada por {n}")
B.AU=new A.a("bomba {n} inserida junto \xe0 fonte","pump {n} inserted next to the supply","bomba {n} insertada junto a la fuente")
B.q2=new A.a("{n} tubo(s) liberado(s) para o c\xe1lculo escolher o di\xe2metro","{n} pipe(s) freed for the design to choose the diameter","{n} tuber\xeda(s) liberada(s) para que el c\xe1lculo elija el di\xe1metro")
B.o5=new A.a("tubo trocado por {n}","pipe changed to {n}","tuber\xeda cambiada por {n}")
B.k2=new A.a("v\xe1lvula trocada por {n}","valve changed to {n}","v\xe1lvula cambiada por {n}")
B.wI=new A.a("modelo definido: {n}","model set: {n}","modelo definido: {n}")
B.xh=new A.a("zonas reagrupadas em {n} turnos","zones regrouped into {n} system flows","zonas reagrupadas en {n} turnos")
B.Dv=new A.a("{n} conex\xe3o(\xf5es) gen\xe9rica(s) adicionada(s) ao cat\xe1logo","{n} generic fitting(s) added to the catalogue","{n} conexi\xf3n(es) gen\xe9rica(s) a\xf1adida(s) al cat\xe1logo")
B.tc=new A.a("tubos conectados no cruzamento","pipes connected at the crossing","tuber\xedas conectadas en el cruce")
B.yi=new A.a("fonte de \xe1gua colocada na ponta livre da linha principal","water supply placed at the free end of the mainline","fuente de agua colocada en el extremo libre de la l\xednea principal")
B.Ak=new A.a("par\xe2metros de projeto restaurados aos valores padr\xe3o","design parameters restored to the defaults","par\xe1metros de dise\xf1o restaurados a los valores por defecto")
B.BA=new A.a("{n} tubo(s) habilitado(s) no cat\xe1logo","{n} pipe(s) enabled in the catalogue","{n} tuber\xeda(s) habilitada(s) en el cat\xe1logo")
B.pr=new A.a("limites da fonte ajustados aos valores de projeto","supply limits set to the design values","l\xedmites de la fuente ajustados a los valores de dise\xf1o")
B.D0=new A.a("{n} zona(s) colocada(s) num novo turno","{n} zone(s) put in a new system flow","{n} zona(s) puesta(s) en un nuevo turno")
B.kP=new A.a("{n} refer\xeancia(s) a turnos vazios ou v\xe1lvulas apagadas removida(s)","{n} reference(s) to empty flows or deleted valves removed","{n} referencia(s) a turnos vac\xedos o v\xe1lvulas borradas quitada(s)")
B.wF=new A.a("dura\xe7\xe3o de {n} turno(s) definida em 1 h","duration of {n} system flow(s) set to 1 h","duraci\xf3n de {n} turno(s) definida en 1 h")
B.vB=new A.a("press\xe3o nominal aplicada a {n} emissor(es) ou linha(s)","nominal pressure applied to {n} emitter(s) or line(s)","presi\xf3n nominal aplicada a {n} emisor(es) o l\xednea(s)")
B.xv=new A.a("rota\xe7\xe3o nominal restaurada em {n} bomba(s)","rated speed restored on {n} pump(s)","velocidad nominal restaurada en {n} bomba(s)")
B.pz=new A.a("dimensionamento por programa\xe7\xe3o linear com o custo da energia","linear-programming sizing with the energy cost","dimensionamiento por programaci\xf3n lineal con el costo de la energ\xeda")
B.jH=new A.a("o item n\xe3o existe mais","the item no longer exists","el elemento ya no existe")
B.xI=new A.a("nenhum tubo ou item compat\xedvel a menos de {d} m","no compatible pipe or item within {d} m","ninguna tuber\xeda o elemento compatible a menos de {d} m")
B.w6=new A.a("calcule o projeto (F5) antes","run the design (F5) first","calcule el dise\xf1o (F5) antes")
B.Av=new A.a("n\xe3o h\xe1 fonte de \xe1gua","there is no water supply","no hay fuente de agua")
B.jz=new A.a("a fonte n\xe3o precisa de bombeamento","the supply needs no pumping","la fuente no necesita bombeo")
B.tX=new A.a("nenhuma bomba do cat\xe1logo atende sozinha a vaz\xe3o e a press\xe3o; adicione uma bomba maior ao cat\xe1logo","no catalogue pump meets the flow and the pressure alone; add a bigger pump to the catalogue","ninguna bomba del cat\xe1logo cumple sola el caudal y la presi\xf3n; a\xf1ada una bomba mayor al cat\xe1logo")
B.jD=new A.a("{n} j\xe1 \xe9 a melhor op\xe7\xe3o do cat\xe1logo","{n} already is the best option in the catalogue","{n} ya es la mejor opci\xf3n del cat\xe1logo")
B.t9=new A.a("nenhum tubo da linha principal sai da fonte","no mainline pipe leaves the supply","ninguna tuber\xeda de la l\xednea principal sale de la fuente")
B.wA=new A.a("n\xe3o havia nada a mudar","there was nothing to change","no hab\xeda nada que cambiar")
B.yZ=new A.a("o cat\xe1logo n\xe3o tem uma op\xe7\xe3o adequada","the catalogue has no suitable option","el cat\xe1logo no tiene una opci\xf3n adecuada")
B.Ff=new A.a("O c\xe1lculo come\xe7a numa fonte de \xe1gua (po\xe7o, reservat\xf3rio, rede p\xfablica ou canal) com n\xedvel e press\xe3o conhecidos. Sem ela a \xe1gua n\xe3o tem de onde vir e nada pode ser calculado.","The design starts at a water supply (well, reservoir, public mains or canal) with a known level and pressure. Without one the water has nowhere to come from and nothing can be calculated.","El c\xe1lculo empieza en una fuente de agua (pozo, reservorio, red p\xfablica o canal) con nivel y presi\xf3n conocidos. Sin ella el agua no tiene de d\xf3nde venir y no se puede calcular nada.")
B.EA=new A.a('Use a ferramenta Fonte de \xe1gua (WS) e clique na ponta da linha principal por onde a \xe1gua entra. Marque "Calcular press\xe3o necess\xe1ria" se ainda n\xe3o souber a press\xe3o dispon\xedvel: o programa diz quanto \xe9 preciso.','Use the Water supply tool (WS) and click the end of the mainline where the water comes in. Tick "Calculate required pressure" if you do not know the available pressure yet: the program tells you how much is needed.','Use la herramienta Fuente de agua (WS) y haga clic en el extremo de la l\xednea principal por donde entra el agua. Marque "Calcular presi\xf3n necesaria" si a\xfan no conoce la presi\xf3n disponible: el programa indica cu\xe1nta se necesita.')
B.mz=new A.a("Cada zona (conjunto de laterais que irrigam juntas) precisa de uma v\xe1lvula de controle que a ligue \xe0 linha principal. \xc9 na v\xe1lvula que o programa separa as zonas e calcula a press\xe3o de cada uma.","Each zone (a set of laterals that irrigate together) needs a control valve that links it to the mainline. The valve is where the program separates the zones and works out the pressure of each one.","Cada zona (conjunto de laterales que riegan juntas) necesita una v\xe1lvula de control que la una a la l\xednea principal. En la v\xe1lvula el programa separa las zonas y calcula la presi\xf3n de cada una.")
B.kI=new A.a("Coloque uma V\xe1lvula de controle (V) onde a linha principal encontra o in\xedcio da zona. O Bloco de laterais (B) desenha laterais, linha de deriva\xe7\xe3o e v\xe1lvula de uma vez.","Place a Control valve (V) where the mainline meets the start of the zone. The Lateral block tool (B) draws laterals, submain and valve in one go.","Coloque una V\xe1lvula de control (V) donde la l\xednea principal se encuentra con el inicio de la zona. El Bloque de laterales (B) dibuja laterales, secundaria y v\xe1lvula de una vez.")
B.jX=new A.a("O desenho ainda n\xe3o tem tubos, emissores nem v\xe1lvulas: s\xf3 h\xe1 o que calcular depois que a rede de irriga\xe7\xe3o \xe9 desenhada.","The drawing has no pipes, emitters or valves yet: there is only something to calculate once the irrigation network is drawn.","El dibujo todav\xeda no tiene tuber\xedas, emisores ni v\xe1lvulas: solo hay algo que calcular cuando la red de riego est\xe1 dibujada.")
B.lk=new A.a("Comece por um exemplo (Arquivo \u2192 Exemplos) ou pelo Tutorial interativo (Ajuda). Num projeto novo: desenhe a \xe1rea, gere um Bloco de laterais (B), ligue as v\xe1lvulas com a linha principal e coloque a fonte de \xe1gua.","Start from an example (File \u2192 Examples) or the Interactive tutorial (Help). For a new design: draw the area, generate a Lateral block (B), link the valves with the mainline and place the water supply.","Empiece por un ejemplo (Archivo \u2192 Ejemplos) o por el Tutorial interactivo (Ayuda). En un dise\xf1o nuevo: dibuje el \xe1rea, genere un Bloque de laterales (B), una las v\xe1lvulas con la l\xednea principal y coloque la fuente de agua.")
B.EP=new A.a("S\xf3 est\xe3o ligados itens que se tocam exatamente (dentro da toler\xe2ncia de conex\xe3o). Um item fora da rede n\xe3o recebe \xe1gua e fica fora do c\xe1lculo; geralmente ele foi solto a poucos cent\xedmetros do tubo.","Only items that touch exactly (within the connection tolerance) are joined. An item off the network gets no water and is left out of the calculation; usually it was dropped a few centimetres from the pipe.","Solo est\xe1n unidos los elementos que se tocan exactamente (dentro de la tolerancia de conexi\xf3n). Un elemento fuera de la red no recibe agua y queda fuera del c\xe1lculo; normalmente se solt\xf3 a pocos cent\xedmetros de la tuber\xeda.")
B.rF=new A.a('Clique em "Mostrar no desenho" e arraste o item at\xe9 o tubo com o Snap ligado, ou use a corre\xe7\xe3o, que o leva ao tubo ou item compat\xedvel mais pr\xf3ximo.','Click "Show on the drawing" and drag the item onto the pipe with Snap on, or use the correction, which moves it to the nearest compatible pipe or item.','Haga clic en "Mostrar en el dibujo" y arrastre el elemento sobre la tuber\xeda con el Snap activado, o use la correcci\xf3n, que lo lleva a la tuber\xeda o elemento compatible m\xe1s cercano.')
B.yz=new A.a("Um tubo sem comprimento (os dois pontos no mesmo lugar) n\xe3o conduz \xe1gua e atrapalha a montagem da rede. Costuma surgir de um clique duplo acidental.","A pipe without length (both points at the same place) carries no water and confuses the network. It usually comes from an accidental double click.","Una tuber\xeda sin longitud (los dos puntos en el mismo lugar) no conduce agua y entorpece el armado de la red. Suele surgir de un doble clic accidental.")
B.lT=new A.a("Exclua o tubo; nada se perde.","Delete the pipe; nothing is lost.","Elimine la tuber\xeda; no se pierde nada.")
B.C8=new A.a("Dois v\xe9rtices mais pr\xf3ximos que a toler\xe2ncia de conex\xe3o viram um s\xf3 n\xf3; o trecho min\xfasculo entre eles pode ligar coisas que n\xe3o deviam se tocar.","Two vertices closer than the connection tolerance become a single node; the tiny piece between them may join things that should not touch.","Dos v\xe9rtices m\xe1s cerca que la tolerancia de conexi\xf3n se vuelven un solo nudo; el tramo diminuto entre ellos puede unir cosas que no deber\xedan tocarse.")
B.yn=new A.a("Remova os v\xe9rtices repetidos (a corre\xe7\xe3o faz isso sem mudar o tra\xe7ado).","Remove the repeated vertices (the correction does it without changing the layout).","Quite los v\xe9rtices repetidos (la correcci\xf3n lo hace sin cambiar el trazado).")
B.mV=new A.a("Dois itens iguais no mesmo ponto (colados duas vezes, por exemplo) dobram a vaz\xe3o e o custo na lista de materiais.","Two identical items at the same point (pasted twice, for instance) double the flow and the cost in the bill of materials.","Dos elementos iguales en el mismo punto (pegados dos veces, por ejemplo) duplican el caudal y el costo en la lista de materiales.")
B.lf=new A.a("Mantenha s\xf3 um deles.","Keep only one of them.","Deje solo uno de ellos.")
B.wD=new A.a("Relat\xf3rios, turnos e programa\xe7\xe3o identificam as zonas pelo nome; nomes repetidos deixam os resultados amb\xedguos.","Reports, system flows and the schedule identify the zones by name; repeated names make the results ambiguous.","Los informes, los turnos y la programaci\xf3n identifican las zonas por el nombre; los nombres repetidos hacen ambiguos los resultados.")
B.DB=new A.a("D\xea um nome diferente a cada zona nas propriedades da v\xe1lvula, ou deixe a corre\xe7\xe3o numer\xe1-las.","Give each zone a different name in the valve properties, or let the correction number them.","D\xe9 un nombre distinto a cada zona en las propiedades de la v\xe1lvula, o deje que la correcci\xf3n las numere.")
B.EY=new A.a("Tubos que se cruzam sem um v\xe9rtice comum n\xe3o est\xe3o ligados, como na obra, onde um passa por cima do outro. Se deviam se conectar, falta a jun\xe7\xe3o.","Pipes that cross without a shared vertex are not joined, as on site, where one passes over the other. If they should connect, the junction is missing.","Las tuber\xedas que se cruzan sin un v\xe9rtice com\xfan no est\xe1n unidas, como en obra, donde una pasa por encima de la otra. Si deb\xedan conectarse, falta el nudo.")
B.w3=new A.a('Se \xe9 uma conex\xe3o (t\xea ou cruzeta), use "Conectar os tubos no cruzamento". Se um s\xf3 passa sobre o outro, est\xe1 certo e o aviso pode ser ignorado.','If it is a connection (a tee or a cross), use "Connect the pipes at the crossing". If one only passes over the other, that is right and the warning can be ignored.','Si es una conexi\xf3n (te o cruz), use "Conectar las tuber\xedas en el cruce". Si una solo pasa sobre la otra, es correcto y el aviso se puede ignorar.')
B.i6=new A.a("Uma ponta da linha principal n\xe3o chega a nenhuma v\xe1lvula, fonte ou emissor: o tubo termina no vazio. Ele n\xe3o leva \xe1gua a lugar nenhum, mas entra no custo.","An end of the mainline reaches no valve, supply or emitter: the pipe ends in the void. It takes water nowhere but adds to the cost.","Un extremo de la l\xednea principal no llega a ninguna v\xe1lvula, fuente ni emisor: la tuber\xeda termina en el vac\xedo. No lleva agua a ninguna parte, pero suma al costo.")
B.vt=new A.a("Ligue a ponta \xe0 v\xe1lvula ou \xe0 fonte que ela devia alcan\xe7ar, ou apague o trecho que sobra. Se o projeto ainda n\xe3o tem fonte, essa ponta costuma ser o lugar dela.","Join the end to the valve or supply it should reach, or delete the leftover piece. If the design has no supply yet, that end is usually where it goes.","Una el extremo a la v\xe1lvula o a la fuente a la que deb\xeda llegar, o borre el tramo sobrante. Si el dise\xf1o a\xfan no tiene fuente, ese extremo suele ser su lugar.")
B.Ab=new A.a("Um tubo da zona termina sem lateral nem emissor na ponta. \xc0s vezes \xe9 proposital (ponto de lavagem), \xe0s vezes \xe9 um trecho esquecido.","A zone pipe ends without a lateral or emitter at its end. Sometimes on purpose (a flushing point), sometimes a forgotten piece.","Una tuber\xeda de la zona termina sin lateral ni emisor en el extremo. A veces es a prop\xf3sito (punto de lavado), a veces es un tramo olvidado.")
B.Aa=new A.a("Se ele n\xe3o serve para nada, encurte ou apague o trecho para economizar tubo.","If it serves no purpose, shorten or delete it to save pipe.","Si no sirve para nada, ac\xf3rtela o b\xf3rrela para ahorrar tuber\xeda.")
B.wR=new A.a("A v\xe1lvula n\xe3o alimenta nenhum emissor: sem vaz\xe3o n\xe3o h\xe1 o que dimensionar, e a zona fica vazia nos resultados.","The valve feeds no emitter: with no flow there is nothing to size, and the zone stays empty in the results.","La v\xe1lvula no alimenta ning\xfan emisor: sin caudal no hay nada que dimensionar y la zona queda vac\xeda en los resultados.")
B.AP=new A.a('Confira se os tubos e laterais da zona tocam a v\xe1lvula (sa\xedda da v\xe1lvula = in\xedcio da linha de deriva\xe7\xe3o). Use "Mostrar no desenho" e ligue-os, ou apague a v\xe1lvula se a zona n\xe3o existe.','Check that the zone pipes and laterals touch the valve (valve outlet = start of the submain). Use "Show on the drawing" and join them, or delete the valve if the zone does not exist.','Compruebe que las tuber\xedas y laterales de la zona tocan la v\xe1lvula (salida de la v\xe1lvula = inicio de la secundaria). Use "Mostrar en el dibujo" y \xfanalos, o borre la v\xe1lvula si la zona no existe.')
B.Ea=new A.a("Uma \xe1rea irrigada foi desenhada, mas n\xe3o tem emissores dentro; ela entra no balan\xe7o h\xeddrico sem ser irrigada.","An irrigated area was drawn but has no emitters inside; it enters the water balance without being irrigated.","Se dibuj\xf3 un \xe1rea regada pero no tiene emisores dentro; entra en el balance h\xeddrico sin ser regada.")
B.l4=new A.a("Gere um Bloco de laterais (B) ou uma Grade de aspersores dentro da \xe1rea, ou apague a \xe1rea se ela \xe9 s\xf3 refer\xeancia.","Generate a Lateral block (B) or a Sprinkler grid inside the area, or delete the area if it is only a reference.","Genere un Bloque de laterales (B) o una Malla de aspersores dentro del \xe1rea, o borre el \xe1rea si es solo referencia.")
B.Az=new A.a("O item aponta para um modelo que n\xe3o est\xe1 no cat\xe1logo do projeto (apagado, ou vindo de outro arquivo). Sem as curvas do modelo n\xe3o \xe9 poss\xedvel calcular.","The item points to a model that is not in the project catalogue (deleted, or coming from another file). Without the model curves it cannot be calculated.","El elemento apunta a un modelo que no est\xe1 en el cat\xe1logo del proyecto (borrado o venido de otro archivo). Sin las curvas del modelo no se puede calcular.")
B.rf=new A.a("Escolha um modelo nas propriedades do item, ou use a corre\xe7\xe3o, que aplica um modelo do cat\xe1logo (nos tubos, o di\xe2metro passa a ser escolhido pelo c\xe1lculo).","Pick a model in the item properties, or use the correction, which applies a catalogue model (for pipes, the design then chooses the diameter).","Elija un modelo en las propiedades del elemento, o use la correcci\xf3n, que aplica un modelo del cat\xe1logo (en las tuber\xedas, el di\xe1metro pasa a elegirlo el c\xe1lculo).")
B.wk=new A.a("A fonte est\xe1 com press\xe3o fixa igual a zero: \xe9 como uma caixa d'\xe1gua no n\xedvel do ch\xe3o, sem bomba. Quase nunca \xe9 o que se quer, e todas as v\xe1lvulas ficar\xe3o sem press\xe3o.","The supply has a fixed pressure of zero: like a tank at ground level with no pump. It is hardly ever what you want, and every valve will lack pressure.","La fuente tiene presi\xf3n fija igual a cero: como un tanque a nivel del suelo, sin bomba. Casi nunca es lo que se quiere, y todas las v\xe1lvulas quedar\xe1n sin presi\xf3n.")
B.Co=new A.a('Informe a press\xe3o real da fonte (rede p\xfablica, por exemplo 25 m.c.a.) ou marque "Calcular press\xe3o necess\xe1ria" para o programa dizer quanto \xe9 preciso.','Enter the real supply pressure (public mains, e.g. 25 m of head) or tick "Calculate required pressure" so the program tells you how much is needed.','Ingrese la presi\xf3n real de la fuente (red p\xfablica, por ejemplo 25 m.c.a.) o marque "Calcular presi\xf3n necesaria" para que el programa diga cu\xe1nta se necesita.')
B.rb=new A.a("A linha principal forma um anel. O solver de rede calcula an\xe9is corretamente; s\xf3 o dimensionamento por programa\xe7\xe3o linear usa uma aproxima\xe7\xe3o em \xe1rvore, conferida depois pela an\xe1lise.","The mainline forms a loop. The network solver handles loops correctly; only the linear-programming sizing uses a tree approximation, checked afterwards by the analysis.","La l\xednea principal forma un anillo. El solver de red calcula anillos correctamente; solo el dimensionamiento por programaci\xf3n lineal usa una aproximaci\xf3n en \xe1rbol, verificada despu\xe9s por el an\xe1lisis.")
B.ym=new A.a("Nada a fazer se o anel \xe9 intencional (ele distribui melhor a press\xe3o). Se n\xe3o \xe9, remova o trecho que fecha o anel.","Nothing to do if the loop is intended (it spreads the pressure better). If it is not, remove the piece that closes the loop.","Nada que hacer si el anillo es intencional (reparte mejor la presi\xf3n). Si no lo es, quite el tramo que cierra el anillo.")
B.zL=new A.a("Sem curvas de n\xedvel nem cotas, o terreno \xe9 considerado plano. Em \xe1reas com desn\xedvel, subidas e descidas mudam muito a press\xe3o nos emissores.","Without contours or spot heights the ground is taken as flat. On sloping land, rises and falls change the emitter pressures a lot.","Sin curvas de nivel ni cotas, el terreno se considera plano. En terrenos con desnivel, las subidas y bajadas cambian mucho la presi\xf3n en los emisores.")
B.zG=new A.a("Baixe a eleva\xe7\xe3o da internet (Projeto \u2192 Terreno), importe um GeoTIFF ou DXF com curvas, ou digite algumas cotas. Em terreno plano de verdade, pode ignorar.","Download the elevation from the internet (Design \u2192 Terrain), import a GeoTIFF or a DXF with contours, or type a few spot heights. On truly flat ground you can ignore it.","Descargue la elevaci\xf3n de internet (Dise\xf1o \u2192 Terreno), importe un GeoTIFF o un DXF con curvas, o escriba algunas cotas. En terreno realmente plano puede ignorarlo.")
B.Al=new A.a("O c\xe1lculo hidr\xe1ulico n\xe3o chegou a uma solu\xe7\xe3o est\xe1vel, geralmente por dados extremos: tubo min\xfasculo com vaz\xe3o enorme, bomba muito fora da faixa ou valores zerados.","The hydraulic calculation did not reach a stable solution, usually because of extreme data: a tiny pipe with a huge flow, a pump far outside its range, or zero values.","El c\xe1lculo hidr\xe1ulico no lleg\xf3 a una soluci\xf3n estable, normalmente por datos extremos: tuber\xeda diminuta con caudal enorme, bomba muy fuera de rango o valores en cero.")
B.nJ=new A.a("Resolva primeiro os outros erros da lista (principalmente itens desconectados e modelos faltando) e calcule de novo. Procure di\xe2metros e press\xf5es absurdos nas propriedades.","First solve the other errors in the list (mainly unconnected items and missing models) and run again. Look for absurd diameters and pressures in the properties.","Resuelva primero los otros errores de la lista (sobre todo elementos desconectados y modelos faltantes) y calcule de nuevo. Busque di\xe1metros y presiones absurdos en las propiedades.")
B.pm=new A.a("Os emissores da zona precisam trabalhar numa faixa de press\xe3o (a janela). Mesmo com os maiores tubos permitidos, a perda de carga ou o desn\xedvel deixam algum emissor fora dela: a zona \xe9 longa ou inclinada demais, ou a press\xe3o pedida est\xe1 fora da faixa do bocal.","The emitters of the zone must work within a pressure range (the window). Even with the largest pipes allowed, friction loss or the slope leave some emitter outside it: the zone is too long or too steep, or the pressure asked is outside the nozzle range.","Los emisores de la zona deben trabajar en un rango de presi\xf3n (la ventana). Incluso con las mayores tuber\xedas permitidas, la p\xe9rdida de carga o el desnivel dejan alg\xfan emisor fuera: la zona es demasiado larga o empinada, o la presi\xf3n pedida est\xe1 fuera del rango de la boquilla.")
B.E6=new A.a("Tente, nesta ordem: deixar o c\xe1lculo escolher os di\xe2metros; dividir a zona em duas v\xe1lvulas; alimentar as laterais pelo meio; usar emissores autocompensantes; habilitar tubos maiores no cat\xe1logo.","Try, in this order: let the design choose the diameters; split the zone into two valves; feed the laterals from the middle; use pressure-compensating emitters; enable larger pipes in the catalogue.","Pruebe, en este orden: dejar que el c\xe1lculo elija los di\xe1metros; dividir la zona en dos v\xe1lvulas; alimentar los laterales por el centro; usar emisores autocompensantes; habilitar tuber\xedas mayores en el cat\xe1logo.")
B.jY=new A.a("Algum emissor recebe mais press\xe3o do que o bocal suporta, o que \xe9 comum em zonas morro abaixo, onde cada metro de descida soma press\xe3o. Isso aumenta a vaz\xe3o, o tamanho das gotas e o desgaste.","Some emitter gets more pressure than the nozzle stands, which is common in downhill zones, where every metre of fall adds pressure. It raises the flow, the droplet size and the wear.","Alg\xfan emisor recibe m\xe1s presi\xf3n de la que soporta la boquilla, algo com\xfan en zonas cuesta abajo, donde cada metro de bajada suma presi\xf3n. Eso aumenta el caudal, el tama\xf1o de gota y el desgaste.")
B.A7=new A.a("Divida a zona por faixas de altitude, use emissores autocompensantes ou reguladores de press\xe3o nas laterais, ou reduza a press\xe3o na v\xe1lvula.","Split the zone by elevation bands, use pressure-compensating emitters or pressure regulators on the laterals, or lower the pressure at the valve.","Divida la zona por franjas de altitud, use emisores autocompensantes o reguladores de presi\xf3n en los laterales, o reduzca la presi\xf3n en la v\xe1lvula.")
B.zB=new A.a("A \xe1gua passa r\xe1pido demais neste tubo (acima do limite dos par\xe2metros, em geral 1,5 a 2 m/s). Velocidade alta gasta press\xe3o, aumenta o golpe de ar\xedete e desgasta o tubo.","Water runs too fast in this pipe (above the limit in the parameters, usually 1.5 to 2 m/s). High velocity wastes pressure, increases water hammer and wears the pipe.","El agua pasa demasiado r\xe1pido por esta tuber\xeda (por encima del l\xedmite de los par\xe1metros, en general 1,5 a 2 m/s). La velocidad alta gasta presi\xf3n, aumenta el golpe de ariete y desgasta la tuber\xeda.")
B.wj=new A.a("Deixe o c\xe1lculo escolher o di\xe2metro (se voc\xea o fixou) ou use um tubo maior. Se j\xe1 \xe9 o maior do cat\xe1logo, divida a vaz\xe3o: mais turnos ou mais uma linha.","Let the design choose the diameter (if you fixed it) or use a bigger pipe. If it is already the largest in the catalogue, split the flow: more system flows or another line.","Deje que el c\xe1lculo elija el di\xe1metro (si usted lo fij\xf3) o use una tuber\xeda mayor. Si ya es la mayor del cat\xe1logo, divida el caudal: m\xe1s turnos u otra l\xednea.")
B.rM=new A.a("A press\xe3o de trabalho passa da classe (PN) do tubo, que pode estourar. Acontece perto de bombas fortes ou no ponto mais baixo do terreno.","The working pressure exceeds the class (PN) of the pipe, which may burst. It happens near strong pumps or at the lowest point of the ground.","La presi\xf3n de trabajo supera la clase (PN) de la tuber\xeda, que puede reventar. Pasa cerca de bombas fuertes o en el punto m\xe1s bajo del terreno.")
B.nL=new A.a("Use um tubo de classe maior no mesmo di\xe2metro (a corre\xe7\xe3o escolhe o mais barato que aguenta), ou reduza a press\xe3o: bomba menor ou v\xe1lvula redutora.","Use a higher-class pipe of the same diameter (the correction picks the cheapest that withstands it), or lower the pressure: a smaller pump or a pressure-reducing valve.","Use una tuber\xeda de clase mayor en el mismo di\xe1metro (la correcci\xf3n elige la m\xe1s barata que resiste), o reduzca la presi\xf3n: bomba menor o v\xe1lvula reductora.")
B.yK=new A.a("Ao fechar uma v\xe1lvula r\xe1pido, a \xe1gua em movimento para de repente e gera um pico de press\xe3o (golpe de ar\xedete). Somado \xe0 press\xe3o normal, ele passa da classe do tubo.","Closing a valve fast stops the moving water suddenly and causes a pressure spike (water hammer). Added to the normal pressure it exceeds the pipe class.","Al cerrar una v\xe1lvula r\xe1pido, el agua en movimiento se detiene de golpe y genera un pico de presi\xf3n (golpe de ariete). Sumado a la presi\xf3n normal, supera la clase de la tuber\xeda.")
B.BI=new A.a("Use tubo de classe maior, feche as v\xe1lvulas mais devagar (tempo de fechamento nos par\xe2metros) ou reduza a velocidade com um tubo mais largo.","Use a higher-class pipe, close the valves more slowly (closure time in the parameters) or lower the velocity with a wider pipe.","Use tuber\xeda de clase mayor, cierre las v\xe1lvulas m\xe1s despacio (tiempo de cierre en los par\xe1metros) o reduzca la velocidad con una tuber\xeda m\xe1s ancha.")
B.oP=new A.a("A vaz\xe3o da zona est\xe1 fora da faixa da v\xe1lvula escolhida: pequena demais, ela perde muita press\xe3o; grande demais, n\xe3o regula bem.","The zone flow is outside the range of the chosen valve: too small a valve loses a lot of pressure; too big a valve does not regulate well.","El caudal de la zona est\xe1 fuera del rango de la v\xe1lvula elegida: si es peque\xf1a pierde mucha presi\xf3n; si es grande no regula bien.")
B.k5=new A.a("Troque a v\xe1lvula por uma do tamanho certo (a corre\xe7\xe3o escolhe a menor que atende).","Change the valve to the right size (the correction picks the smallest that fits).","Cambie la v\xe1lvula por una del tama\xf1o correcto (la correcci\xf3n elige la menor que sirve).")
B.vq=new A.a("A press\xe3o que chega \xe0 v\xe1lvula \xe9 menor que a que a zona precisa: a fonte n\xe3o tem press\xe3o para vencer a perda na linha principal e o desn\xedvel at\xe9 a zona.","The pressure reaching the valve is lower than the zone needs: the supply does not have the pressure to overcome the mainline loss and the rise to the zone.","La presi\xf3n que llega a la v\xe1lvula es menor que la que necesita la zona: la fuente no tiene presi\xf3n para vencer la p\xe9rdida en la l\xednea principal y el desnivel hasta la zona.")
B.nz=new A.a("Coloque ou troque a bomba (a corre\xe7\xe3o escolhe uma para a vaz\xe3o e a press\xe3o), use tubos maiores na linha principal ou divida os turnos. Se a press\xe3o da fonte foi s\xf3 um palpite, deixe o programa calcul\xe1-la.","Add or change the pump (the correction picks one for the flow and the pressure), use larger mainline pipes or split the system flows. If the supply pressure was only a guess, let the program calculate it.","Coloque o cambie la bomba (la correcci\xf3n elige una para el caudal y la presi\xf3n), use tuber\xedas mayores en la l\xednea principal o divida los turnos. Si la presi\xf3n de la fuente era solo una estimaci\xf3n, deje que el programa la calcule.")
B.FH=new A.a("O piv\xf4 precisa de uma press\xe3o na entrada para que o \xfaltimo aspersor funcione; a linha principal entrega menos que isso.","The pivot needs an inlet pressure so that the last sprinkler works; the mainline delivers less than that.","El pivote necesita una presi\xf3n de entrada para que funcione el \xfaltimo aspersor; la l\xednea principal entrega menos.")
B.lZ=new A.a("Escolha uma bomba adequada, aumente o di\xe2metro da adutora ou confira a press\xe3o de ponta pedida nas propriedades do piv\xf4.","Choose a suitable pump, increase the diameter of the supply main or check the end pressure asked in the pivot properties.","Elija una bomba adecuada, aumente el di\xe1metro de la aductora o revise la presi\xf3n de punta pedida en las propiedades del pivote.")
B.EV=new A.a("O turno pede mais vaz\xe3o do que a fonte fornece (a vaz\xe3o de projeto da fonte). Na pr\xe1tica faltaria \xe1gua e as press\xf5es cairiam.","The system flow asks for more flow than the supply gives (its design flow). In practice the water would run short and the pressures would drop.","El turno pide m\xe1s caudal del que da la fuente (su caudal de dise\xf1o). En la pr\xe1ctica faltar\xeda agua y las presiones bajar\xedan.")
B.Dd=new A.a("Divida as zonas em mais turnos (a corre\xe7\xe3o reagrupa para que nenhum passe da vaz\xe3o da fonte), ou aumente a vaz\xe3o da fonte se ela realmente comporta.","Split the zones into more system flows (the correction regroups them so that none exceeds the supply flow), or raise the supply flow if it really allows it.","Divida las zonas en m\xe1s turnos (la correcci\xf3n las reagrupa para que ninguno supere el caudal de la fuente), o aumente el caudal de la fuente si realmente lo permite.")
B.vP=new A.a("Para atender todas as v\xe1lvulas, a fonte precisaria de mais press\xe3o do que o m\xe1ximo informado para ela.","To serve every valve the supply would need more pressure than the maximum entered for it.","Para atender todas las v\xe1lvulas, la fuente necesitar\xeda m\xe1s presi\xf3n que el m\xe1ximo indicado para ella.")
B.uq=new A.a("Coloque uma bomba (booster) depois da fonte, use tubos maiores ou divida os turnos para reduzir a perda de carga.","Add a booster pump after the supply, use larger pipes or split the system flows to reduce the friction loss.","Coloque una bomba (booster) despu\xe9s de la fuente, use tuber\xedas mayores o divida los turnos para reducir la p\xe9rdida de carga.")
B.DD=new A.a("A bomba trabalha fora da faixa de vaz\xe3o da sua curva: pequena demais, n\xe3o entrega a vaz\xe3o; grande demais, trabalha perto do fechamento e desperdi\xe7a energia.","The pump works outside the flow range of its curve: too small, it cannot deliver the flow; too big, it runs near shut-off and wastes energy.","La bomba trabaja fuera del rango de caudal de su curva: si es peque\xf1a, no entrega el caudal; si es grande, trabaja cerca del cierre y desperdicia energ\xeda.")
B.Er=new A.a("Escolha uma bomba adequada: a corre\xe7\xe3o compara as bombas do cat\xe1logo e fica com a de menor custo de compra + energia que atende todos os turnos.","Choose a suitable pump: the correction compares the catalogue pumps and keeps the one with the lowest purchase + energy cost that serves every system flow.","Elija una bomba adecuada: la correcci\xf3n compara las bombas del cat\xe1logo y se queda con la de menor costo de compra + energ\xeda que atiende todos los turnos.")
B.rW=new A.a("Uma bomba de superf\xedcie puxa a \xe1gua por v\xe1cuo, e a press\xe3o atmosf\xe9rica s\xf3 empurra a \xe1gua at\xe9 uns 10 m; na pr\xe1tica, com perdas e o NPSH, o limite \xe9 uns 7 m ao n\xedvel do mar (menos em altitude). Al\xe9m disso a bomba cavita ou perde a escorva.","A surface pump pulls the water through a vacuum, and the atmospheric pressure only pushes water up about 10 m; in practice, with losses and the NPSH, the limit is about 7 m at sea level (less at altitude). Beyond it the pump cavitates or loses its prime.","Una bomba de superficie succiona el agua por vac\xedo, y la presi\xf3n atmosf\xe9rica solo empuja el agua unos 10 m; en la pr\xe1ctica, con p\xe9rdidas y el NPSH, el l\xedmite es unos 7 m a nivel del mar (menos en altitud). M\xe1s all\xe1 la bomba cavita o pierde el cebado.")
B.ut=new A.a("Use uma bomba submersa dentro do po\xe7o, ou instale a bomba de superf\xedcie mais perto do n\xedvel da \xe1gua. A press\xe3o negativa na entrada da bomba \xe9 essa altura de suc\xe7\xe3o.","Use a submersible pump inside the well, or install the surface pump closer to the water level. The negative pressure at the pump inlet is that suction lift.","Use una bomba sumergible dentro del pozo, o instale la bomba de superficie m\xe1s cerca del nivel del agua. La presi\xf3n negativa en la entrada de la bomba es esa altura de succi\xf3n.")
B.kl=new A.a("Duas zonas est\xe3o ligadas por tubo sem v\xe1lvula entre elas: a \xe1gua de uma passa para a outra e o programa n\xe3o consegue separ\xe1-las.","Two zones are joined by pipe without a valve between them: the water of one flows into the other and the program cannot tell them apart.","Dos zonas est\xe1n unidas por tuber\xeda sin v\xe1lvula entre ellas: el agua de una pasa a la otra y el programa no puede separarlas.")
B.w7=new A.a("Corte o tubo que liga as zonas (ferramenta Cortar tubo). Se na verdade s\xe3o uma zona s\xf3, apague uma das v\xe1lvulas.","Cut the pipe that joins the zones (Cut pipe tool). If they really are a single zone, delete one of the valves.","Corte la tuber\xeda que une las zonas (herramienta Cortar tuber\xeda). Si en realidad son una sola zona, borre una de las v\xe1lvulas.")
B.ky=new A.a("Com os tubos habilitados no cat\xe1logo, nenhuma combina\xe7\xe3o atende todas as press\xf5es ao mesmo tempo; o programa usou o m\xe9todo guloso (aumenta os tubos passo a passo), que d\xe1 um bom resultado, mas talvez n\xe3o o mais barato.","With the pipes enabled in the catalogue, no combination meets every pressure at once; the program used the greedy method (upsizing step by step), which gives a good result but perhaps not the cheapest.","Con las tuber\xedas habilitadas en el cat\xe1logo, ninguna combinaci\xf3n cumple todas las presiones a la vez; el programa us\xf3 el m\xe9todo voraz (aumenta las tuber\xedas paso a paso), que da un buen resultado, pero quiz\xe1 no el m\xe1s barato.")
B.wt=new A.a("Habilite di\xe2metros maiores no cat\xe1logo, aumente o n\xfamero de di\xe2metros por linha nos par\xe2metros ou reduza a exig\xeancia de press\xe3o (zonas menores).","Enable larger diameters in the catalogue, raise the number of diameters per line in the parameters or reduce the pressure demand (smaller zones).","Habilite di\xe1metros mayores en el cat\xe1logo, aumente el n\xfamero de di\xe1metros por l\xednea en los par\xe1metros o reduzca la exigencia de presi\xf3n (zonas menores).")
B.xP=new A.a("A lista de materiais precisa de uma conex\xe3o (luva, joelho, t\xea\u2026) de um tamanho que o cat\xe1logo n\xe3o tem; ela fica sem pre\xe7o.","The bill of materials needs a fitting (coupler, elbow, tee\u2026) of a size the catalogue lacks; it stays without a price.","La lista de materiales necesita una conexi\xf3n (manguito, codo, te\u2026) de un tama\xf1o que el cat\xe1logo no tiene; queda sin precio.")
B.o6=new A.a("Adicione as conex\xf5es gen\xe9ricas ao cat\xe1logo (corre\xe7\xe3o) ou cadastre as do seu fornecedor no Cat\xe1logo de componentes.","Add the generic fittings to the catalogue (correction) or enter those of your supplier in the Component catalog.","A\xf1ada las conexiones gen\xe9ricas al cat\xe1logo (correcci\xf3n) o registre las de su proveedor en el Cat\xe1logo de componentes.")
B.my=new A.a("O piv\xf4 est\xe1 com l\xe2mina ou horas por ciclo iguais a zero, ent\xe3o a vaz\xe3o calculada \xe9 zero.","The pivot has a zero depth or zero hours per cycle, so its computed flow is zero.","El pivote tiene l\xe1mina u horas por ciclo en cero, as\xed que el caudal calculado es cero.")
B.vV=new A.a("Informe a l\xe2mina por ciclo (mm) e as horas por volta nas propriedades do piv\xf4.","Enter the depth per cycle (mm) and the hours per turn in the pivot properties.","Ingrese la l\xe1mina por ciclo (mm) y las horas por vuelta en las propiedades del pivote.")
B.xp=new A.a("Sem a press\xe3o na ponta (\xfaltimo aspersor) n\xe3o d\xe1 para calcular a press\xe3o de entrada do piv\xf4.","Without the end pressure (last sprinkler) the inlet pressure of the pivot cannot be calculated.","Sin la presi\xf3n de punta (\xfaltimo aspersor) no se puede calcular la presi\xf3n de entrada del pivote.")
B.D5=new A.a("Informe a press\xe3o de ponta nas propriedades do piv\xf4 (t\xedpico: 10 a 20 m.c.a. com reguladores).","Enter the end pressure in the pivot properties (typical: 10 to 20 m of head with regulators).","Ingrese la presi\xf3n de punta en las propiedades del pivote (t\xedpico: 10 a 20 m.c.a. con reguladores).")
B.AO=new A.a("Na ponta, o piv\xf4 aplica \xe1gua mais r\xe1pido do que o solo consegue infiltrar: a \xe1gua escorre e causa eros\xe3o.","At the end the pivot applies water faster than the soil can take it in: the water runs off and causes erosion.","En la punta el pivote aplica agua m\xe1s r\xe1pido de lo que el suelo puede infiltrar: el agua escurre y causa erosi\xf3n.")
B.Fp=new A.a("Use aspersores de maior raio molhado na ponta, aumente a velocidade de giro (menos l\xe2mina por volta) ou confira o limite do solo.","Use sprinklers with a larger wetted radius at the end, speed up the rotation (less depth per turn) or check the soil limit.","Use aspersores de mayor radio mojado en la punta, aumente la velocidad de giro (menos l\xe1mina por vuelta) o revise el l\xedmite del suelo.")
B.l9=new A.a("Um turno faz refer\xeancia a uma v\xe1lvula que n\xe3o existe mais (foi apagada).","A system flow refers to a valve that no longer exists (it was deleted).","Un turno hace referencia a una v\xe1lvula que ya no existe (fue borrada).")
B.vC=new A.a("Limpe os turnos (corre\xe7\xe3o) ou abra Projeto \u2192 Turnos de opera\xe7\xe3o e retire a v\xe1lvula do turno.","Clean up the system flows (correction) or open Design \u2192 System flows and take the valve out of the flow.","Limpie los turnos (correcci\xf3n) o abra Dise\xf1o \u2192 Turnos de operaci\xf3n y quite la v\xe1lvula del turno.")
B.m0=new A.a("Os limites de velocidade nos par\xe2metros est\xe3o fora da faixa f\xedsica (0,3 a 5 m/s). Zero ou valores enormes tornam o dimensionamento imposs\xedvel ou sem sentido.","The velocity limits in the parameters are outside the physical range (0.3 to 5 m/s). Zero or huge values make the sizing impossible or meaningless.","Los l\xedmites de velocidad de los par\xe1metros est\xe1n fuera del rango f\xedsico (0,3 a 5 m/s). Cero o valores enormes hacen el dimensionamiento imposible o sin sentido.")
B.uf=new A.a("Volte aos valores padr\xe3o (1,5 m/s nas zonas, 2 m/s nas laterais e na linha principal) ou ajuste em Projeto \u2192 Par\xe2metros de projeto.","Restore the defaults (1.5 m/s in zones, 2 m/s in laterals and the mainline) or adjust them in Design \u2192 Design parameters.","Vuelva a los valores por defecto (1,5 m/s en las zonas, 2 m/s en los laterales y en la l\xednea principal) o aj\xfastelos en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.Fh=new A.a("As horas de funcionamento por ano est\xe3o fora de 1 a 8760 (o ano tem 8760 h). O custo de energia e a escolha dos tubos pelo custo total dependem delas.","The operating hours per year are outside 1 to 8760 (a year has 8760 h). The energy cost and the choice of pipes by total cost depend on them.","Las horas de funcionamiento por a\xf1o est\xe1n fuera de 1 a 8760 (el a\xf1o tiene 8760 h). El costo de energ\xeda y la elecci\xf3n de tuber\xedas por costo total dependen de ellas.")
B.CR=new A.a("Volte aos padr\xf5es (2000 h na linha principal, 500 h por zona) ou informe as horas reais em Projeto \u2192 Par\xe2metros de projeto.","Restore the defaults (2000 h for the mainline, 500 h per zone) or enter the real hours in Design \u2192 Design parameters.","Vuelva a los valores por defecto (2000 h en la l\xednea principal, 500 h por zona) o ingrese las horas reales en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.v_=new A.a("Algum par\xe2metro econ\xf4mico \xe9 imposs\xedvel: juros negativos ou acima de 50 % ao ano, prazo fora de 1 a 100 anos, rendimento da bomba fora de 20 a 95 % ou tarifa de energia negativa.","Some economic parameter is impossible: interest negative or above 50 % a year, a term outside 1 to 100 years, a pump efficiency outside 20 to 95 % or a negative energy tariff.","Alg\xfan par\xe1metro econ\xf3mico es imposible: inter\xe9s negativo o mayor que 50 % al a\xf1o, plazo fuera de 1 a 100 a\xf1os, rendimiento de la bomba fuera de 20 a 95 % o tarifa de energ\xeda negativa.")
B.EJ=new A.a("Volte aos valores padr\xe3o ou corrija em Projeto \u2192 Par\xe2metros de projeto.","Restore the defaults or correct them in Design \u2192 Design parameters.","Vuelva a los valores por defecto o corr\xedjalos en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.vw=new A.a("A toler\xe2ncia de conex\xe3o diz a que dist\xe2ncia dois pontos contam como ligados. Zero n\xe3o liga nada; valores grandes (mais de 1 m) ligam coisas que deviam estar separadas.","The connection tolerance says how close two points must be to count as joined. Zero joins nothing; large values (over 1 m) join things that should stay apart.","La tolerancia de conexi\xf3n dice a qu\xe9 distancia dos puntos cuentan como unidos. Cero no une nada; valores grandes (m\xe1s de 1 m) unen cosas que deber\xedan estar separadas.")
B.DY=new A.a("Volte ao padr\xe3o (5 cm) em Projeto \u2192 Par\xe2metros de projeto.","Restore the default (5 cm) in Design \u2192 Design parameters.","Vuelva al valor por defecto (5 cm) en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.oH=new A.a("A varia\xe7\xe3o m\xe1xima de press\xe3o na zona est\xe1 fora de 0 a 60 %. Os crit\xe9rios usuais ficam entre 10 e 20 % (cerca de \xb110 % na vaz\xe3o).","The maximum pressure variation in the zone is outside 0 to 60 %. The usual criteria are 10 to 20 % (about \xb110 % in flow).","La variaci\xf3n m\xe1xima de presi\xf3n en la zona est\xe1 fuera de 0 a 60 %. Los criterios usuales est\xe1n entre 10 y 20 % (cerca de \xb110 % en el caudal).")
B.A1=new A.a("Volte ao padr\xe3o (0 = usa a faixa de press\xe3o do emissor) ou informe 20 %.","Restore the default (0 = use the pressure range of the emitter) or enter 20 %.","Vuelva al valor por defecto (0 = usa el rango de presi\xf3n del emisor) o ingrese 20 %.")
B.v4=new A.a("A temperatura da \xe1gua est\xe1 fora de 0 a 60 \xb0C; ela muda a viscosidade usada na perda de carga (Darcy-Weisbach).","The water temperature is outside 0 to 60 \xb0C; it changes the viscosity used in the friction loss (Darcy-Weisbach).","La temperatura del agua est\xe1 fuera de 0 a 60 \xb0C; cambia la viscosidad usada en la p\xe9rdida de carga (Darcy-Weisbach).")
B.Et=new A.a("Volte ao padr\xe3o (20 \xb0C).","Restore the default (20 \xb0C).","Vuelva al valor por defecto (20 \xb0C).")
B.o4=new A.a("O cat\xe1logo n\xe3o tem nenhum tubo habilitado para este uso (laterais, zona ou linha principal), ent\xe3o o c\xe1lculo n\xe3o tem di\xe2metro para escolher.","The catalogue has no pipe enabled for this use (laterals, zone or mainline), so the design has no diameter to choose.","El cat\xe1logo no tiene ninguna tuber\xeda habilitada para este uso (laterales, zona o l\xednea principal), as\xed que el c\xe1lculo no tiene di\xe1metro que elegir.")
B.kw=new A.a("Habilite tubos no Cat\xe1logo de componentes ou use a corre\xe7\xe3o, que reativa os tubos padr\xe3o desse uso.","Enable pipes in the Component catalog or use the correction, which re-enables the default pipes of that use.","Habilite tuber\xedas en el Cat\xe1logo de componentes o use la correcci\xf3n, que reactiva las tuber\xedas por defecto de ese uso.")
B.nc=new A.a("Na fonte, a press\xe3o ou a vaz\xe3o de projeto \xe9 maior que o m\xe1ximo informado: um dos valores est\xe1 trocado ou foi digitado errado.","At the supply, the design pressure or flow is higher than the maximum entered: one of the values is swapped or mistyped.","En la fuente, la presi\xf3n o el caudal de dise\xf1o es mayor que el m\xe1ximo indicado: uno de los valores est\xe1 cambiado o mal escrito.")
B.nu=new A.a("Confira os valores nas propriedades da fonte; a corre\xe7\xe3o iguala o m\xe1ximo ao valor de projeto.","Check the values in the supply properties; the correction sets the maximum to the design value.","Revise los valores en las propiedades de la fuente; la correcci\xf3n iguala el m\xe1ximo al valor de dise\xf1o.")
B.yS=new A.a("H\xe1 turnos definidos, mas estas zonas n\xe3o est\xe3o em nenhum: elas nunca abrem na simula\xe7\xe3o da linha principal e ficam fora da press\xe3o e da energia calculadas.","System flows are defined, but these zones are in none: they never open in the mainline simulation and are left out of the pressures and energy computed.","Hay turnos definidos, pero estas zonas no est\xe1n en ninguno: nunca abren en la simulaci\xf3n de la l\xednea principal y quedan fuera de la presi\xf3n y la energ\xeda calculadas.")
B.jm=new A.a("Inclua as zonas num turno em Projeto \u2192 Turnos de opera\xe7\xe3o, ou use a corre\xe7\xe3o, que cria um turno novo para elas.","Put the zones in a flow in Design \u2192 System flows, or use the correction, which creates a new flow for them.","Incluya las zonas en un turno en Dise\xf1o \u2192 Turnos de operaci\xf3n, o use la correcci\xf3n, que crea un turno nuevo para ellas.")
B.A3=new A.a("H\xe1 turnos sem nenhuma zona (vazios ou s\xf3 com v\xe1lvulas apagadas): eles n\xe3o fazem nada e confundem a programa\xe7\xe3o.","Some system flows have no zone (empty or with deleted valves only): they do nothing and confuse the schedule.","Hay turnos sin ninguna zona (vac\xedos o solo con v\xe1lvulas borradas): no hacen nada y confunden la programaci\xf3n.")
B.iA=new A.a("Limpe os turnos (corre\xe7\xe3o) ou inclua zonas neles em Projeto \u2192 Turnos de opera\xe7\xe3o.","Clean up the system flows (correction) or put zones in them in Design \u2192 System flows.","Limpie los turnos (correcci\xf3n) o incluya zonas en ellos en Dise\xf1o \u2192 Turnos de operaci\xf3n.")
B.zg=new A.a("Um turno com dura\xe7\xe3o zero ou negativa n\xe3o irriga e zera a energia daquele turno.","A system flow with a zero or negative duration irrigates nothing and zeroes its energy.","Un turno con duraci\xf3n cero o negativa no riega y deja en cero la energ\xeda de ese turno.")
B.ov=new A.a("Informe a dura\xe7\xe3o de cada turno (horas) em Projeto \u2192 Turnos de opera\xe7\xe3o; a corre\xe7\xe3o define 1 h.","Enter the duration of each flow (hours) in Design \u2192 System flows; the correction sets 1 h.","Ingrese la duraci\xf3n de cada turno (horas) en Dise\xf1o \u2192 Turnos de operaci\xf3n; la correcci\xf3n define 1 h.")
B.AH=new A.a("A press\xe3o de trabalho pedida para o emissor est\xe1 fora da faixa do bocal (m\xednima e m\xe1xima do cat\xe1logo). Assim nenhum tubo consegue deixar a zona dentro da janela de press\xe3o: a zona fica imposs\xedvel.","The working pressure asked for the emitter is outside the nozzle range (catalogue minimum and maximum). Then no pipe can keep the zone inside its pressure window: the zone becomes impossible.","La presi\xf3n de trabajo pedida para el emisor est\xe1 fuera del rango de la boquilla (m\xednima y m\xe1xima del cat\xe1logo). As\xed ninguna tuber\xeda puede dejar la zona dentro de la ventana de presi\xf3n: la zona se vuelve imposible.")
B.Dn=new A.a("Use a press\xe3o nominal do bocal (corre\xe7\xe3o) ou escolha outro bocal ou emissor feito para a press\xe3o desejada.","Use the nominal pressure of the nozzle (correction) or choose another nozzle or emitter made for the pressure you want.","Use la presi\xf3n nominal de la boquilla (correcci\xf3n) o elija otra boquilla o emisor hecho para la presi\xf3n deseada.")
B.ng=new A.a("A rota\xe7\xe3o relativa da bomba est\xe1 fora de 40 a 130 % da nominal; pelas leis de afinidade, a curva vira algo que a bomba real n\xe3o faz.","The relative pump speed is outside 40 to 130 % of the rated one; by the affinity laws the curve becomes something the real pump cannot do.","La velocidad relativa de la bomba est\xe1 fuera de 40 a 130 % de la nominal; por las leyes de afinidad, la curva se vuelve algo que la bomba real no hace.")
B.qy=new A.a("Volte \xe0 rota\xe7\xe3o nominal (1,0) ou use o inversor de frequ\xeancia s\xf3 dentro da faixa do fabricante.","Go back to the rated speed (1.0) or use a variable-speed drive only within the range of the manufacturer.","Vuelva a la velocidad nominal (1,0) o use el variador de frecuencia solo dentro del rango del fabricante.")
B.pD=new A.a("Verifica\xe7\xe3o do projeto\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o\u2026")
B.p0=new A.a("Cat\xe1logos de fabricantes\u2026","Manufacturer catalogues\u2026","Cat\xe1logos de fabricantes\u2026")
B.BR=new A.a("Produtos com os dados das tabelas publicadas pelos fabricantes (vaz\xe3o, expoente, raio, faixa de press\xe3o, perda de carga) e os documentos de origem de cada pacote. Os pre\xe7os ficam em zero: exporte para Excel, preencha com a tabela local e importe de volta. Confirme sempre na folha de dados atual.","Products with the data of the manufacturers' published tables (flow, exponent, radius, pressure range, head loss) and the source documents of each pack. Prices are left at zero: export to Excel, fill in the local price list and import it back. Always confirm with the current data sheet.","Productos con los datos de las tablas publicadas por los fabricantes (caudal, exponente, radio, rango de presi\xf3n, p\xe9rdida de carga) y los documentos de origen de cada paquete. Los precios quedan en cero: exporte a Excel, complete con la lista local e importe de vuelta. Confirme siempre con la hoja de datos vigente.")
B.Ef=new A.a("Adicionar","Add","A\xf1adir")
B.Bm=new A.a("{n} itens adicionados de {b}","{n} items added from {b}","{n} \xedtems a\xf1adidos de {b}")
B.vF=new A.a("{n} itens","{n} items","{n} \xedtems")
B.zc=new A.a("Exportar Excel","Export Excel","Exportar Excel")
B.yP=new A.a("Importar (JSON, CSV, Excel)\u2026","Import (JSON, CSV, Excel)\u2026","Importar (JSON, CSV, Excel)\u2026")
B.iu=new A.a("Menu","Menu","Men\xfa")
B.ms=new A.a("Concluir","Done","Terminar")
B.Dm=new A.a("Toque para desenhar \xb7 pin\xe7a para zoom \xb7 dois dedos para mover","Tap to draw \xb7 pinch to zoom \xb7 two fingers to pan","Toque para dibujar \xb7 pellizco para zoom \xb7 dos dedos para mover")
B.qT=new A.a("Navegar","Navigate","Navegar")
B.rR=new A.a("Principal","Mainline","Principal")
B.lg=new A.a("{n} selecionado(s)","{n} selected","{n} seleccionado(s)")
B.jI=new A.a("No celular: bot\xf5es Concluir/Cancelar substituem Enter/Esc; menu \u2630 re\xfane os menus","On a phone: Done/Cancel buttons replace Enter/Esc; the \u2630 menu gathers the menus","En el m\xf3vil: los botones Terminar/Cancelar reemplazan Intro/Esc; el men\xfa \u2630 re\xfane los men\xfas")
B.xm=new A.a("Laterais seguem a linha selecionada ({n}): laterais curvas","Laterals follow the selected line ({n}): curved laterals","Laterales siguen la l\xednea seleccionada ({n}): laterales curvas")
B.za=new A.a("Hist\xf3rico","History","Historial")
B.AS=new A.a("Clique num passo para voltar (ou avan\xe7ar) no tempo; uma nova edi\xe7\xe3o descarta os passos \xe0 frente.","Click a step to go back (or forward) in time; a new edit discards the steps ahead.","Haga clic en un paso para volver (o avanzar) en el tiempo; una nueva edici\xf3n descarta los pasos siguientes.")
B.jr=new A.a("Estado inicial","Initial state","Estado inicial")
B.oc=new A.a("Edi\xe7\xe3o","Edit","Edici\xf3n")
B.CH=new A.a("Adicionar {n}","Add {n}","A\xf1adir {n}")
B.AQ=new A.a("Adicionar {n} itens","Add {n} items","A\xf1adir {n} elementos")
B.uY=new A.a("Excluir {n} item(ns)","Delete {n} item(s)","Eliminar {n} elemento(s)")
B.qE=new A.a("Mover","Move","Mover")
B.nx=new A.a("Espelhar","Mirror","Reflejar")
B.Af=new A.a("Transformar {n} item(ns)","Transform {n} item(s)","Transformar {n} elemento(s)")
B.uA=new A.a("Copiar {n} item(ns)","Copy {n} item(s)","Copiar {n} elemento(s)")
B.qt=new A.a("Matriz","Array","Matriz")
B.p5=new A.a("Importar","Import","Importar")
B.ln=new A.a("Projetar (dimensionar)","Design (size pipes)","Dise\xf1ar (dimensionar)")
B.Es=new A.a("Eleva\xe7\xe3o importada","Elevation imported","Elevaci\xf3n importada")
B.Ag=new A.a("Remover cotas pr\xf3prias","Remove own heights","Quitar cotas propias")
B.lA=new A.a("Alinhar","Align","Alinear")
B.tt=new A.a("Lista de materiais na prancha","Bill of materials on the sheet","Lista de materiales en la l\xe1mina")
B.tK=new A.a("Qtd.","Qty","Cant.")
B.k_=new A.a("\u2026 mais {n} itens (ver relat\xf3rio)","\u2026 {n} more items (see report)","\u2026 {n} \xedtems m\xe1s (ver informe)")
B.tY=new A.a("GeoTIFF de eleva\xe7\xe3o: {n} cotas de {w}\xd7{h} px ({crs})","Elevation GeoTIFF: {n} spot heights from {w}\xd7{h} px ({crs})","GeoTIFF de elevaci\xf3n: {n} cotas de {w}\xd7{h} px ({crs})")
B.B2=new A.a("V\xe3os do piv\xf4","Pivot spans","Vanos del pivote")
B.nN=new A.a("V\xe3o","Span","Vano")
B.kD=new A.a("R inicial","R start","R inicial")
B.ES=new A.a("R final","R end","R final")
B.bQ=new A.a("Aspersores","Sprinklers","Aspersores")
B.vv=new A.a("q por aspersor","q per sprinkler","q por aspersor")
B.im=new A.a("P no v\xe3o","P at span","P en el vano")
B.jM=new A.a("Bocal sugerido","Suggested nozzle","Boquilla sugerida")
B.jl=new A.a("Espa\xe7amento dos aspersores (m)","Sprinkler spacing (m)","Espaciado de los aspersores (m)")
B.xS=new A.a("Aspersor do piv\xf4 (cat\xe1logo)","Pivot sprinkler (catalogue)","Aspersor del pivote (cat\xe1logo)")
B.EB=new A.a("Regulador de press\xe3o (cat\xe1logo)","Pressure regulator (catalogue)","Regulador de presi\xf3n (cat\xe1logo)")
B.kk=new A.a("Custo por torre","Cost per tower","Costo por torre")
B.x9=new A.a("Aspersores do piv\xf4","Pivot sprinklers","Aspersores del pivote")
B.ts=new A.a("Canh\xe3o final","End gun","Ca\xf1\xf3n final")
B.or=new A.a("Suavizar curva (spline pelos pontos)","Smooth contour (spline through the points)","Suavizar curva (spline por los puntos)")
B.oG=new A.a("M\xe1x. de pontos","Max. points","M\xe1x. de puntos")
B.qD=new A.a("Motor","Motor","Motor")
B.wy=new A.a("Linha principal em anel: o dimensionamento LP usa caminhos em \xe1rvore (aproxima\xe7\xe3o); a an\xe1lise final confere as press\xf5es","Looped mainline: LP sizing uses tree paths (approximation); the final analysis checks the pressures","L\xednea principal en anillo: el dimensionamiento LP usa caminos en \xe1rbol (aproximaci\xf3n); el an\xe1lisis final verifica las presiones")
B.tm=new A.a("Inclu\xeddos no app","Bundled with the app","Incluidos en la app")
B.lQ=new A.a("Carregados agora","Loaded now","Cargados ahora")
B.nE=new A.a("Importar pacote (.oci.cat)\u2026","Import pack (.oci.cat)\u2026","Importar paquete (.oci.cat)\u2026")
B.Dz=new A.a("URL de um pacote ou de um \xedndice (index.json)","URL of a pack or of an index (index.json)","URL de un paquete o de un \xedndice (index.json)")
B.ox=new A.a("Carregar da URL","Load from URL","Cargar de la URL")
B.Cd=new A.a("Carregando\u2026","Loading\u2026","Cargando\u2026")
B.v6=new A.a("{n} pacote(s) carregado(s)","{n} pack(s) loaded","{n} paquete(s) cargado(s)")
B.nG=new A.a("N\xe3o foi poss\xedvel carregar: {e}","Could not load: {e}","No se pudo cargar: {e}")
B.zC=new A.a("Exportar pacote .oci.cat\u2026","Export pack .oci.cat\u2026","Exportar paquete .oci.cat\u2026")
B.Cp=new A.a("Exportar cat\xe1logo como pacote","Export catalogue as a pack","Exportar cat\xe1logo como paquete")
B.iM=new A.a("Gera um arquivo .oci.cat com os itens deste cat\xe1logo, para compartilhar ou publicar num reposit\xf3rio da comunidade. O formato (JSON aberto) est\xe1 documentado em catalogs/README.md.","Writes an .oci.cat file with the items of this catalogue, to share or publish in a community repository. The format (open JSON) is documented in catalogs/README.md.","Genera un archivo .oci.cat con los \xedtems de este cat\xe1logo, para compartir o publicar en un repositorio de la comunidad. El formato (JSON abierto) est\xe1 documentado en catalogs/README.md.")
B.nF=new A.a("Fabricante","Manufacturer","Fabricante")
B.m2=new A.a("Nome do pacote","Pack name","Nombre del paquete")
B.FG=new A.a("Descri\xe7\xe3o (linhas de produto)","Description (product lines)","Descripci\xf3n (l\xedneas de producto)")
B.ux=new A.a("Fonte (URL da folha de dados)","Source (data sheet URL)","Fuente (URL de la hoja de datos)")
B.vn=new A.a("Pacote {f} exportado ({n} itens)","Pack {f} exported ({n} items)","Paquete {f} exportado ({n} \xedtems)")
B.C0=new A.a("Pacotes s\xe3o arquivos JSON abertos (.oci.cat): fabricantes, revendas e a comunidade podem public\xe1-los num reposit\xf3rio e voc\xea os carrega por arquivo ou URL. Formato em catalogs/README.md.","Packs are open JSON files (.oci.cat): manufacturers, dealers and the community can publish them in a repository and you load them from a file or a URL. Format in catalogs/README.md.","Los paquetes son archivos JSON abiertos (.oci.cat): fabricantes, distribuidores y la comunidad pueden publicarlos en un repositorio y usted los carga desde un archivo o una URL. Formato en catalogs/README.md.")
B.xC=new A.a("de {o}","from {o}","de {o}")
B.y6=new A.a("O JSON n\xe3o \xe9 um cat\xe1logo nem um pacote .oci.cat","The JSON is neither a catalogue nor an .oci.cat pack","El JSON no es un cat\xe1logo ni un paquete .oci.cat")
B.Bh=new A.a("Este arquivo \xe9 um \xedndice de pacotes, n\xe3o um pacote (carregue-o pela URL)","This file is a pack index, not a pack (load it by URL)","Este archivo es un \xedndice de paquetes, no un paquete (c\xe1rguelo por URL)")
B.C4=new A.a("O JSON n\xe3o \xe9 um \xedndice de pacotes","The JSON is not a pack index","El JSON no es un \xedndice de paquetes")
B.BW=new A.a("Pacote gravado por uma vers\xe3o mais nova do formato","Pack written by a newer format version","Paquete escrito por una versi\xf3n m\xe1s nueva del formato")
B.Ds=new A.a("Coordenada do local (lat, lon)","Site coordinate (lat, lon)","Coordenada del sitio (lat, lon)")
B.qj=new A.a("-22.9068, -43.1729 \xb7 link do Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 Google Maps link \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 enlace de Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W")
B.Fy=new A.a("Sem desenho ainda? Cole a coordenada do terreno: a origem do projeto vai para l\xe1 e a eleva\xe7\xe3o \xe9 baixada num quadrado ao redor.","No drawing yet? Paste the site coordinate: the project origin goes there and the elevation is downloaded over a square around it.","\xbfSin dibujo todav\xeda? Pegue la coordenada del terreno: el origen del proyecto va all\xed y la elevaci\xf3n se descarga en un cuadrado alrededor.")
B.By=new A.a("Usar coordenada","Use coordinate","Usar coordenada")
B.uH=new A.a("Lado da \xe1rea (m)","Area side (m)","Lado del \xe1rea (m)")
B.ls=new A.a("Coordenada n\xe3o reconhecida","Coordinate not recognised","Coordenada no reconocida")
B.ih=new A.a("Gerar curvas de n\xedvel ap\xf3s baixar","Generate contours after downloading","Generar curvas de nivel tras descargar")
B.jg=new A.a("Intervalo (m; 0 = autom\xe1tico)","Interval (m; 0 = automatic)","Intervalo (m; 0 = autom\xe1tico)")
B.F1=new A.a("{n} cotas importadas ({s}); {c} curvas de n\xedvel a cada {i} m","{n} spot heights imported ({s}); {c} contours every {i} m","{n} cotas importadas ({s}); {c} curvas de nivel cada {i} m")
B.BK=new A.a("Georrefer\xeancia definida em {lat}, {lon} ({crs})","Georeference set at {lat}, {lon} ({crs})","Georreferencia definida en {lat}, {lon} ({crs})")
B.nB=new A.a("Exemplos","Examples","Ejemplos")
B.mb=new A.a("Boas-vindas e galeria de exemplos\u2026","Welcome and example gallery\u2026","Bienvenida y galer\xeda de ejemplos\u2026")
B.Ec=new A.a("Bem-vindo ao OpenCADIrrigation","Welcome to OpenCADIrrigation","Bienvenido a OpenCADIrrigation")
B.Fd=new A.a("CAD para projeto de irriga\xe7\xe3o pressurizada, direto no navegador. Comece por um exemplo pronto ou fa\xe7a o tutorial interativo: ele come\xe7a localizando a sua \xe1rea no mapa de sat\xe9lite e baixando o relevo da internet, e segue em cerca de 70 passos curtos em que voc\xea mesmo navega, desenha, monta a rede e projeta; cada passo reconhece quando voc\xea o completou e avan\xe7a sozinho. Leva uns 20 minutos e pode ser pulado a qualquer momento (Ajuda \u2192 Tutorial interativo reabre depois).","CAD for pressurised irrigation design, right in the browser. Start from a ready example or take the interactive tutorial: it begins by locating your site on the satellite map and downloading the terrain from the internet, then goes on in about 70 short steps in which you navigate, draw, build the network and design it yourself; each step recognises when you have completed it and moves on. It takes about 20 minutes and can be skipped at any time (Help \u2192 Interactive tutorial reopens it).","CAD para dise\xf1o de riego presurizado, directamente en el navegador. Empiece por un ejemplo listo o haga el tutorial interactivo: comienza ubicando su \xe1rea en el mapa satelital y descargando el relieve de internet, y sigue en unos 70 pasos cortos en los que usted mismo navega, dibuja, arma la red y dise\xf1a; cada paso reconoce cuando lo complet\xf3 y avanza solo. Tarda unos 20 minutos y puede omitirse en cualquier momento (Ayuda \u2192 Tutorial interactivo lo reabre).")
B.Bs=new A.a("Comece por um exemplo","Start from an example","Empiece por un ejemplo")
B.nM=new A.a("Cada projeto abre pronto para calcular: pressione F5 ou \u25b6 e veja zonas, press\xf5es, di\xe2metros e lista de materiais. Arquivo \u2192 Exemplos reabre qualquer um deles.","Each project opens ready to design: press F5 or \u25b6 and see zones, pressures, pipe sizes and the bill of materials. File \u2192 Examples reopens any of them.","Cada proyecto se abre listo para calcular: pulse F5 o \u25b6 y vea zonas, presiones, di\xe1metros y lista de materiales. Archivo \u2192 Ejemplos reabre cualquiera de ellos.")
B.tp=new A.a("Iniciar tutorial","Start tutorial","Iniciar tutorial")
B.DT=new A.a("Come\xe7ar do zero","Start from scratch","Empezar de cero")
B.rP=new A.a("Pomar","Orchard","Huerto")
B.m7=new A.a("Microaspers\xe3o em citros e gotejamento em uva, po\xe7o com bomba e filtro, terreno em declive.","Micro-sprinklers on citrus and drip on grapes, well with pump and filter, sloping ground.","Microaspersi\xf3n en c\xedtricos y goteo en uva, pozo con bomba y filtro, terreno en pendiente.")
B.o9=new A.a("2 zonas \xb7 1,1 ha \xb7 po\xe7o + bomba","2 zones \xb7 1.1 ha \xb7 well + pump","2 zonas \xb7 1,1 ha \xb7 pozo + bomba")
B.bR=new A.a("Jardim residencial","Residential garden","Jard\xedn residencial")
B.nK=new A.a("Sprays pop-up no gramado da frente, rotores nos fundos e gotejamento nos canteiros, ligados \xe0 rede p\xfablica com hidr\xf4metro e anti-refluxo.","Pop-up sprays on the front lawn, rotors at the back and drip in the beds, fed by the mains with a meter and a backflow preventer.","Difusores emergentes en el c\xe9sped frontal, rotores atr\xe1s y goteo en los canteros, conectados a la red p\xfablica con contador y antirretorno.")
B.wS=new A.a("3 zonas \xb7 640 m\xb2 \xb7 rede p\xfablica","3 zones \xb7 640 m\xb2 \xb7 mains supply","3 zonas \xb7 640 m\xb2 \xb7 red p\xfablica")
B.cW=new A.a("Campo de futebol","Football pitch","Campo de f\xfatbol")
B.lt=new A.a("Campo oficial 105 \xd7 68 m com aspersores de impacto em cinco linhas, reservat\xf3rio, bomba e turnos noturnos.","Full-size 105 \xd7 68 m pitch with impact sprinklers in five rows, reservoir, pump and night-time shifts.","Campo oficial de 105 \xd7 68 m con aspersores de impacto en cinco filas, dep\xf3sito, bomba y turnos nocturnos.")
B.En=new A.a("5 zonas \xb7 40 aspersores \xb7 bomba","5 zones \xb7 40 sprinklers \xb7 pump","5 zonas \xb7 40 aspersores \xb7 bomba")
B.ix=new A.a("Lavoura gotejada","Drip row crop","Cultivo en hileras con goteo")
B.tP=new A.a("Quatro talh\xf5es de tomate com fita gotejadora, submains com v\xe1lvulas, filtro de tela, bomba e terreno em declive.","Four tomato blocks on drip tape, submains with valves, screen filter, pump and sloping ground.","Cuatro parcelas de tomate con cinta de goteo, submains con v\xe1lvulas, filtro de malla, bomba y terreno en pendiente.")
B.Fz=new A.a("4 zonas \xb7 2,9 ha \xb7 filtro + bomba","4 zones \xb7 2.9 ha \xb7 filter + pump","4 zonas \xb7 2,9 ha \xb7 filtro + bomba")
B.Ar=new A.a("Piv\xf4 de 300 m em milho alimentado por adutora, po\xe7o e bomba; relat\xf3rio de torres, v\xe3os e bocais.","A 300 m pivot on maize fed by a mainline, well and pump; tower, span and sprinkler report.","Pivote de 300 m en ma\xedz alimentado por conducci\xf3n, pozo y bomba; informe de torres, tramos y boquillas.")
B.lw=new A.a("1 piv\xf4 \xb7 28 ha \xb7 po\xe7o + bomba","1 pivot \xb7 28 ha \xb7 well + pump","1 pivote \xb7 28 ha \xb7 pozo + bomba")
B.kB=new A.a("Turno {n} \u2014 {z}","Shift {n} \u2014 {z}","Turno {n} \u2014 {z}")
B.kV=new A.a("Resid\xeancia Exemplo","Example Residence","Residencia Ejemplo")
B.ks=new A.a("Lote 16 \xd7 40 m","Lot 16 \xd7 40 m","Lote 16 \xd7 40 m")
B.y5=new A.a("Jardim residencial \u2014 exemplo OpenCADIrrigation","Residential garden \u2014 OpenCADIrrigation example","Jard\xedn residencial \u2014 ejemplo OpenCADIrrigation")
B.qd=new A.a("Lote","Lot","Lote")
B.mi=new A.a("Casa","House","Casa")
B.nb=new A.a("Gramado da frente","Front lawn","C\xe9sped frontal")
B.Aj=new A.a("Gramado dos fundos","Back lawn","C\xe9sped trasero")
B.mh=new A.a("Canteiro","Bed","Cantero")
B.i5=new A.a("Zona 1 \u2014 sprays","Zone 1 \u2014 sprays","Zona 1 \u2014 difusores")
B.q5=new A.a("Zona 2 \u2014 rotores","Zone 2 \u2014 rotors","Zona 2 \u2014 rotores")
B.pC=new A.a("Zona 3 \u2014 gotejamento","Zone 3 \u2014 drip","Zona 3 \u2014 goteo")
B.vj=new A.a("Rede p\xfablica","Mains supply","Red p\xfablica")
B.lE=new A.a("Arbustos","Shrubs","Arbustos")
B.tQ=new A.a("Rua","Street","Calle")
B.d9=new A.a("Clube Exemplo","Example Club","Club Ejemplo")
B.jZ=new A.a("Campo oficial 105 \xd7 68 m","Full-size pitch 105 \xd7 68 m","Campo oficial 105 \xd7 68 m")
B.kx=new A.a("Campo de futebol \u2014 exemplo OpenCADIrrigation","Football pitch \u2014 OpenCADIrrigation example","Campo de f\xfatbol \u2014 ejemplo OpenCADIrrigation")
B.mf=new A.a("Campo","Pitch","Campo")
B.wB=new A.a("Linha {n}","Row {n}","Fila {n}")
B.a6=new A.a("Reservat\xf3rio","Reservoir","Dep\xf3sito")
B.cq=new A.a("Casa de bombas","Pump house","Casa de bombas")
B.c9=new A.a("Grama esportiva","Sports turf","C\xe9sped deportivo")
B.yd=new A.a("Lavoura gotejada","Drip row crop","Cultivo con goteo")
B.zx=new A.a("S\xedtio Exemplo","Example Farm","Finca Ejemplo")
B.Dr=new A.a("Talh\xf5es 1 a 4","Blocks 1 to 4","Parcelas 1 a 4")
B.Bj=new A.a("Lavoura de tomate gotejada \u2014 exemplo OpenCADIrrigation","Drip-irrigated tomato field \u2014 OpenCADIrrigation example","Cultivo de tomate con goteo \u2014 ejemplo OpenCADIrrigation")
B.R=new A.a("Talh\xe3o {n}","Block {n}","Parcela {n}")
B.cC=new A.a("Tronco","Trunk","Tronco")
B.aL=new A.a("Ramal oeste","West branch","Ramal oeste")
B.ax=new A.a("Ramal leste","East branch","Ramal este")
B.P=new A.a("Estrada","Road","Camino")
B.r=new A.a("Gleba","Field","Campo")
B.v9=new A.a("Piv\xf4 1 \u2014 raio 300 m","Pivot 1 \u2014 300 m radius","Pivote 1 \u2014 radio 300 m")
B.k9=new A.a("Piv\xf4 central \u2014 exemplo OpenCADIrrigation","Centre pivot \u2014 OpenCADIrrigation example","Pivote central \u2014 ejemplo OpenCADIrrigation")
B.zY=new A.a("Piv\xf4 1","Pivot 1","Pivote 1")
B.G=new A.a("Adutora","Mainline","Conducci\xf3n")
B.cJ=new A.a("\xc1rea do piv\xf4","Pivot area","\xc1rea del pivote")
B.d1=new A.a("Estufa de hortali\xe7as","Vegetable greenhouse","Invernadero de hortalizas")
B.wb=new A.a("Quatro t\xfaneis de piment\xe3o com tubo gotejador autocompensante, uma zona por t\xfanel, reservat\xf3rio, bomba pequena e filtro de discos.","Four pepper tunnels on pressure-compensating dripline, one zone per tunnel, tank, small pump and disc filter.","Cuatro t\xfaneles de pimiento con tuber\xeda de goteo autocompensante, una zona por t\xfanel, dep\xf3sito, bomba peque\xf1a y filtro de discos.")
B.kf=new A.a("4 zonas \xb7 1.800 m\xb2 \xb7 reservat\xf3rio + bomba","4 zones \xb7 1,800 m\xb2 \xb7 tank + pump","4 zonas \xb7 1.800 m\xb2 \xb7 dep\xf3sito + bomba")
B.bM=new A.a("Viveiro de mudas","Plant nursery","Vivero de plantas")
B.zm=new A.a("Tr\xeas canteiros de 12 \xd7 48 m com microaspersores suspensos em malha 4 \xd7 4 m, uma zona por canteiro, caixa d\u2019\xe1gua elevada, bomba pequena e filtro de discos.","Three 12 \xd7 48 m beds under overhead micro-sprinklers on a 4 \xd7 4 m grid, one zone per bed, elevated tank, small pump and disc filter.","Tres canteros de 12 \xd7 48 m con microaspersores suspendidos en malla de 4 \xd7 4 m, una zona por cantero, tanque elevado, bomba peque\xf1a y filtro de discos.")
B.kz=new A.a("3 zonas \xb7 108 microaspersores \xb7 bomba","3 zones \xb7 108 micro-sprinklers \xb7 pump","3 zonas \xb7 108 microaspersores \xb7 bomba")
B.ca=new A.a("Cafezal em curvas de n\xedvel","Coffee on contour lines","Cafetal en curvas de nivel")
B.wr=new A.a("Tr\xeas talh\xf5es de caf\xe9 em encosta com laterais curvas que seguem as curvas de n\xedvel (bloco guiado), tubo gotejador PC, po\xe7o e bomba no p\xe9 do morro.","Three coffee blocks on a hillside with curved laterals following the contours (guided block), PC dripline, well and pump at the foot of the slope.","Tres parcelas de caf\xe9 en ladera con laterales curvos que siguen las curvas de nivel (bloque guiado), tuber\xeda de goteo PC, pozo y bomba al pie de la pendiente.")
B.AM=new A.a("3 zonas \xb7 2,7 ha \xb7 po\xe7o + bomba","3 zones \xb7 2.7 ha \xb7 well + pump","3 zonas \xb7 2,7 ha \xb7 pozo + bomba")
B.d7=new A.a("Bananal","Banana plantation","Platanal")
B.xG=new A.a("Dois talh\xf5es de banana com microaspersores autocompensantes em 5 \xd7 5 m, po\xe7o com bomba submersa, filtro de discos e terreno em declive.","Two banana blocks under pressure-compensating micro-sprinklers at 5 \xd7 5 m, well with submersible pump, disc filter and sloping ground.","Dos parcelas de banano con microaspersores autocompensantes a 5 \xd7 5 m, pozo con bomba sumergible, filtro de discos y terreno en pendiente.")
B.z0=new A.a("2 zonas \xb7 1,2 ha \xb7 bomba submersa","2 zones \xb7 1.2 ha \xb7 submersible pump","2 zonas \xb7 1,2 ha \xb7 bomba sumergible")
B.cr=new A.a("Cana-de-a\xe7\xfacar subsuperficial","Subsurface drip sugarcane","Ca\xf1a de az\xfacar con goteo subterr\xe1neo")
B.pR=new A.a("Dois talh\xf5es de cana com tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, submains enterrados, reservat\xf3rio, bomba, filtro de tela e ventosa.","Two sugarcane blocks on 20 mm PC dripline buried 0.3 m deep, 180 m laterals, buried submains, reservoir, pump, screen filter and air valve.","Dos parcelas de ca\xf1a con tuber\xeda de goteo PC de 20 mm enterrada a 0,3 m, laterales de 180 m, submains enterrados, dep\xf3sito, bomba, filtro de malla y ventosa.")
B.mo=new A.a("2 zonas \xb7 3,2 ha \xb7 filtro + bomba","2 zones \xb7 3.2 ha \xb7 filter + pump","2 zonas \xb7 3,2 ha \xb7 filtro + bomba")
B.bG=new A.a("Gotejamento por gravidade","Gravity-fed drip","Goteo por gravedad")
B.jk=new A.a("Reservat\xf3rio 40 m acima de dois talh\xf5es de hortali\xe7as gotejados, sem bomba: registro, v\xe1lvula reguladora de press\xe3o e filtro de discos na adutora; curvas de n\xedvel da encosta.","A reservoir 40 m above two drip-irrigated vegetable blocks, no pump: gate valve, pressure reducing valve and disc filter on the mainline; hillside contours.","Dep\xf3sito 40 m por encima de dos parcelas de hortalizas con goteo, sin bomba: v\xe1lvula de compuerta, reguladora de presi\xf3n y filtro de discos en la conducci\xf3n; curvas de nivel de la ladera.")
B.iI=new A.a("2 zonas \xb7 1,2 ha \xb7 sem bomba","2 zones \xb7 1.2 ha \xb7 no pump","2 zonas \xb7 1,2 ha \xb7 sin bomba")
B.d2=new A.a("Pastagem em aspers\xe3o","Sprinkler-irrigated pasture","Pastura con aspersi\xf3n")
B.ik=new A.a("Tr\xeas piquetes de 72 \xd7 72 m com linhas de aspersores de impacto em 12 \xd7 18 m, submains com v\xe1lvulas, reservat\xf3rio, bomba e v\xe1lvula de reten\xe7\xe3o.","Three 72 \xd7 72 m paddocks with impact-sprinkler spray lines at 12 \xd7 18 m, submains with valves, reservoir, pump and check valve.","Tres potreros de 72 \xd7 72 m con l\xedneas de aspersores de impacto a 12 \xd7 18 m, submains con v\xe1lvulas, dep\xf3sito, bomba y v\xe1lvula de retenci\xf3n.")
B.jc=new A.a("3 zonas \xb7 1,6 ha \xb7 72 aspersores","3 zones \xb7 1.6 ha \xb7 72 sprinklers","3 zonas \xb7 1,6 ha \xb7 72 aspersores")
B.bZ=new A.a("Buraco de golfe","Golf hole","Hoyo de golf")
B.CE=new A.a("Tee com sprays, fairway com rotores em malha triangular (duas zonas) e green com rotores no per\xedmetro, lago com bomba e turnos noturnos.","Tee with sprays, fairway with rotors on a triangular grid (two zones) and green with rotors around the edge, pond with pump and night-time shifts.","Tee con difusores, fairway con rotores en malla triangular (dos zonas) y green con rotores en el per\xedmetro, laguna con bomba y turnos nocturnos.")
B.jh=new A.a("4 zonas \xb7 64 emissores \xb7 lago + bomba","4 zones \xb7 64 heads \xb7 pond + pump","4 zonas \xb7 64 emisores \xb7 laguna + bomba")
B.uj=new A.a("Piv\xf4 setorial com canh\xe3o","Sector pivot with end gun","Pivote sectorial con ca\xf1\xf3n")
B.Fk=new A.a("Piv\xf4 de 250 m em soja que gira 270\xb0, deixando livre o quadrante da sede, com canh\xe3o final de 12 m\xb3/h; lago, bomba de 30 cv e registro.","A 250 m pivot on soybean sweeping 270\xb0, leaving the farmstead quadrant free, with a 12 m\xb3/h end gun; pond, 30 hp pump and gate valve.","Pivote de 250 m en soja que gira 270\xb0, dejando libre el cuadrante del casco, con ca\xf1\xf3n final de 12 m\xb3/h; laguna, bomba de 30 CV y v\xe1lvula de compuerta.")
B.wZ=new A.a("1 piv\xf4 \xb7 15,7 ha \xb7 lago + bomba","1 pivot \xb7 15.7 ha \xb7 pond + pump","1 pivote \xb7 15,7 ha \xb7 laguna + bomba")
B.cP=new A.a("Piv\xf4 linear","Linear move","Pivote lineal")
B.x8=new A.a("Lateral m\xf3vel de 392 m em trigo percorrendo 800 m ao longo de um canal, capta\xe7\xe3o com bomba de 30 cv e v\xe1lvula de reten\xe7\xe3o; relat\xf3rio de torres e bocais.","A 392 m lateral-move machine on wheat travelling 800 m along a canal, intake with a 30 hp pump and check valve; tower and sprinkler report.","Lateral de avance frontal de 392 m en trigo que recorre 800 m a lo largo de un canal, toma con bomba de 30 CV y v\xe1lvula de retenci\xf3n; informe de torres y boquillas.")
B.tw=new A.a("1 linear \xb7 32 ha \xb7 canal + bomba","1 linear \xb7 32 ha \xb7 canal + pump","1 lineal \xb7 32 ha \xb7 canal + bomba")
B.DN=new A.a("Hortifruti Exemplo","Example Growers","Hortalizas Ejemplo")
B.E0=new A.a("T\xfaneis 1 a 4","Tunnels 1 to 4","T\xfaneles 1 a 4")
B.vN=new A.a("Estufa de hortali\xe7as \u2014 exemplo OpenCADIrrigation","Vegetable greenhouse \u2014 OpenCADIrrigation example","Invernadero de hortalizas \u2014 ejemplo OpenCADIrrigation")
B.cx=new A.a("Terreno","Site","Terreno")
B.tU=new A.a("T\xfanel {n}","Tunnel {n}","T\xfanel {n}")
B.E1=new A.a("Piment\xe3o","Bell pepper","Pimiento")
B.wE=new A.a("Viveiro Exemplo","Example Nursery","Vivero Ejemplo")
B.Ap=new A.a("Canteiros 1 a 3","Beds 1 to 3","Canteros 1 a 3")
B.kY=new A.a("Viveiro de mudas \u2014 exemplo OpenCADIrrigation","Plant nursery \u2014 OpenCADIrrigation example","Vivero de plantas \u2014 ejemplo OpenCADIrrigation")
B.vD=new A.a("Canteiro {n}","Bed {n}","Cantero {n}")
B.qH=new A.a("Mudas","Seedlings","Plantines")
B.tB=new A.a("Caixa d\u2019\xe1gua","Tank","Tanque")
B.o8=new A.a("Encosta norte \u2014 talh\xf5es 1 a 3","North slope \u2014 blocks 1 to 3","Ladera norte \u2014 parcelas 1 a 3")
B.tq=new A.a("Cafezal em curvas de n\xedvel \u2014 exemplo OpenCADIrrigation","Coffee on contour lines \u2014 OpenCADIrrigation example","Cafetal en curvas de nivel \u2014 ejemplo OpenCADIrrigation")
B.aK=new A.a("Talh\xf5es 1 e 2","Blocks 1 and 2","Parcelas 1 y 2")
B.B7=new A.a("Bananal \u2014 exemplo OpenCADIrrigation","Banana plantation \u2014 OpenCADIrrigation example","Platanal \u2014 ejemplo OpenCADIrrigation")
B.qG=new A.a("Usina Exemplo","Example Mill","Ingenio Ejemplo")
B.vi=new A.a("Cana-de-a\xe7\xfacar em gotejamento subsuperficial \u2014 exemplo OpenCADIrrigation","Subsurface drip sugarcane \u2014 OpenCADIrrigation example","Ca\xf1a de az\xfacar con goteo subterr\xe1neo \u2014 ejemplo OpenCADIrrigation")
B.Fc=new A.a("S\xedtio Exemplo","Example Smallholding","Finca Ejemplo")
B.E5=new A.a("Gotejamento por gravidade \u2014 exemplo OpenCADIrrigation","Gravity-fed drip \u2014 OpenCADIrrigation example","Goteo por gravedad \u2014 ejemplo OpenCADIrrigation")
B.Br=new A.a("Reservat\xf3rio no alto","Hilltop reservoir","Dep\xf3sito en lo alto")
B.C9=new A.a("V\xe1lvula reguladora de press\xe3o","Pressure reducing valve","V\xe1lvula reguladora de presi\xf3n")
B.iH=new A.a("Piquetes 1 a 3","Paddocks 1 to 3","Potreros 1 a 3")
B.rm=new A.a("Pastagem em aspers\xe3o \u2014 exemplo OpenCADIrrigation","Sprinkler-irrigated pasture \u2014 OpenCADIrrigation example","Pastura con aspersi\xf3n \u2014 ejemplo OpenCADIrrigation")
B.vg=new A.a("Piquete {n}","Paddock {n}","Potrero {n}")
B.rK=new A.a("Pastagem","Pasture","Pastura")
B.mn=new A.a("Cerca","Fence","Cerco")
B.A9=new A.a("Buraco 1 \u2014 par 4","Hole 1 \u2014 par 4","Hoyo 1 \u2014 par 4")
B.At=new A.a("Buraco de golfe \u2014 exemplo OpenCADIrrigation","Golf hole \u2014 OpenCADIrrigation example","Hoyo de golf \u2014 ejemplo OpenCADIrrigation")
B.uK=new A.a("Tee","Tee","Tee")
B.nQ=new A.a("Fairway","Fairway","Fairway")
B.py=new A.a("Fairway {n}","Fairway {n}","Fairway {n}")
B.os=new A.a("Green","Green","Green")
B.BB=new A.a("Bunker","Bunker","B\xfanker")
B.ch=new A.a("Lago","Pond","Laguna")
B.pY=new A.a("Piv\xf4 setorial","Sector pivot","Pivote sectorial")
B.wN=new A.a("Piv\xf4 2 \u2014 raio 250 m, setor de 270\xb0","Pivot 2 \u2014 250 m radius, 270\xb0 sector","Pivote 2 \u2014 radio 250 m, sector de 270\xb0")
B.ow=new A.a("Piv\xf4 setorial com canh\xe3o final \u2014 exemplo OpenCADIrrigation","Sector pivot with end gun \u2014 OpenCADIrrigation example","Pivote sectorial con ca\xf1\xf3n final \u2014 ejemplo OpenCADIrrigation")
B.tb=new A.a("Piv\xf4 2","Pivot 2","Pivote 2")
B.ui=new A.a("Soja","Soybean","Soja")
B.ud=new A.a("Sede","Farmstead","Casco")
B.oA=new A.a("Linear 1 \u2014 392 \xd7 800 m","Linear 1 \u2014 392 \xd7 800 m","Lineal 1 \u2014 392 \xd7 800 m")
B.Ay=new A.a("Piv\xf4 linear \u2014 exemplo OpenCADIrrigation","Linear move \u2014 OpenCADIrrigation example","Pivote lineal \u2014 ejemplo OpenCADIrrigation")
B.Dp=new A.a("Linear 1","Linear 1","Lineal 1")
B.uS=new A.a("Trigo","Wheat","Trigo")
B.mg=new A.a("Canal","Canal","Canal")
B.A8=new A.a("Capta\xe7\xe3o","Intake","Toma")
B.rQ=new A.a("Densograma (l\xe2mina aplicada)","Densogram (water applied)","Densograma (l\xe1mina aplicada)")
B.yJ=new A.a("Densograma\u2026","Densogram\u2026","Densograma\u2026")
B.wC=new A.a("Densograma \u2014 \xe1gua aplicada pelos aspersores","Densogram \u2014 water applied by the sprinklers","Densograma \u2014 agua aplicada por los aspersores")
B.A_=new A.a("Mapa da taxa de aplica\xe7\xe3o (mm/h) somando o c\xedrculo molhado de cada aspersor e microaspersor como est\xe1 no desenho: posi\xe7\xe3o, arco, orienta\xe7\xe3o e, depois do c\xe1lculo, a press\xe3o de cada um. A uniformidade \xe9 medida dentro das \xe1reas irrigadas (ou na \xe1rea molhada, sem \xe1reas).","Map of the application rate (mm/h) adding up the wetted circle of every sprinkler and micro-sprinkler as drawn: position, arc, orientation and, after the design, the pressure of each one. Uniformity is measured inside the irrigated areas (or over the wetted area when there are none).","Mapa de la tasa de aplicaci\xf3n (mm/h) sumando el c\xedrculo mojado de cada aspersor y microaspersor tal como est\xe1 en el dibujo: posici\xf3n, arco, orientaci\xf3n y, tras el c\xe1lculo, la presi\xf3n de cada uno. La uniformidad se mide dentro de las \xe1reas regadas (o en el \xe1rea mojada, si no hay \xe1reas).")
B.oh=new A.a("Perfil de distribui\xe7\xe3o do aspersor","Sprinkler distribution profile","Perfil de distribuci\xf3n del aspersor")
B.oN=new A.a("Triangular (aspersor de impacto de um bocal)","Triangular (single-nozzle impact sprinkler)","Triangular (aspersor de impacto de una boquilla)")
B.wn=new A.a("El\xedptico (rotor de v\xe1rios bocais, microaspersor)","Elliptical (multi-nozzle rotor, micro-sprinkler)","El\xedptico (rotor de varias boquillas, microaspersor)")
B.mL=new A.a("Uniforme (spray, precipita\xe7\xe3o equilibrada)","Uniform (spray head, matched precipitation)","Uniforme (difusor, precipitaci\xf3n equilibrada)")
B.wh=new A.a("Tamanho da c\xe9lula (m; 0 = autom\xe1tico)","Cell size (m; 0 = automatic)","Tama\xf1o de celda (m; 0 = autom\xe1tico)")
B.DR=new A.a("Usar a press\xe3o calculada de cada emissor","Use the computed pressure of each emitter","Usar la presi\xf3n calculada de cada emisor")
B.iX=new A.a("Sem resultados: cada emissor na press\xe3o nominal.","No results: every emitter at its nominal pressure.","Sin resultados: cada emisor a su presi\xf3n nominal.")
B.zb=new A.a("Nenhum aspersor com raio molhado no desenho.","No sprinkler with a wetted radius in the drawing.","Ning\xfan aspersor con radio mojado en el dibujo.")
B.iZ=new A.a("\xc1rea avaliada","Area evaluated","\xc1rea evaluada")
B.vs=new A.a("\xe1reas irrigadas","irrigated areas","\xe1reas regadas")
B.p3=new A.a("\xe1rea molhada","wetted area","\xe1rea mojada")
B.Fv=new A.a("Superf\xedcie","Surface","Superficie")
B.xF=new A.a("C\xe9lula","Cell","Celda")
B.Eg=new A.a("Vaz\xf5es","Flows","Caudales")
B.mj=new A.a("do c\xe1lculo","from the design","del c\xe1lculo")
B.BL=new A.a("nominais","nominal","nominales")
B.Fa=new A.a("Taxa m\xe9dia","Mean rate","Tasa media")
B.uZ=new A.a("M\xednima / m\xe1xima","Minimum / maximum","M\xednima / m\xe1xima")
B.EO=new A.a("quarto inferior","low quarter","cuarto inferior")
B.ou=new A.a("Coeficiente de programa\xe7\xe3o (5 %)","Scheduling coefficient (5 %)","Coeficiente de programaci\xf3n (5 %)")
B.y7=new A.a("Pontos secos (< metade da m\xe9dia)","Dry spots (< half the mean)","Puntos secos (< mitad de la media)")
B.lj=new A.a("Coeficiente de programa\xe7\xe3o: quantas vezes o tempo de rega precisa crescer para os 5 % mais secos receberem a l\xe2mina m\xe9dia (1 = perfeito; at\xe9 1,3 \xe9 bom). CU \u2265 84 % e DU \u2265 75 % indicam boa sobreposi\xe7\xe3o.","Scheduling coefficient: how many times longer the system must run so the driest 5 % receive the mean depth (1 = perfect; up to 1.3 is good). CU \u2265 84 % and DU \u2265 75 % mean a good overlap.","Coeficiente de programaci\xf3n: cu\xe1ntas veces debe aumentar el tiempo de riego para que el 5 % m\xe1s seco reciba la l\xe1mina media (1 = perfecto; hasta 1,3 es bueno). CU \u2265 84 % y DU \u2265 75 % indican buen solape.")
B.xq=new A.a("Exportar CSV","Export CSV","Exportar CSV")
B.ED=new A.a("Densograma  CU {cu} %  DU {du} %","Densogram  CU {cu} %  DU {du} %","Densograma  CU {cu} %  DU {du} %")
B.aM=new A.a("Controlador","Controller","Controlador")
B.AR=new A.a("Rota de fios","Wire route","Ruta de cables")
B.yp=new A.a("Cota de ordenada","Ordinate dimension","Cota de ordenada")
B.u5=new A.a("Clique para colocar o controlador; depois desenhe as rotas de fios (WR) dele at\xe9 as v\xe1lvulas.","Click to place the controller; then draw the wire routes (WR) from it to the valves.","Haga clic para colocar el controlador; luego dibuje las rutas de cables (WR) desde \xe9l hasta las v\xe1lvulas.")
B.qK=new A.a("Desenhe a rota dos fios do controlador passando pelas v\xe1lvulas (Enter termina). Rotas que se tocam num v\xe9rtice se unem; cada v\xe1lvula no caminho recebe o seu fio de esta\xe7\xe3o e compartilha o comum.","Draw the wire route from the controller through the valves (Enter ends it). Routes touching at a vertex join; every valve on the way gets its station wire and shares the common.","Dibuje la ruta de cables desde el controlador pasando por las v\xe1lvulas (Enter termina). Las rutas que se tocan en un v\xe9rtice se unen; cada v\xe1lvula en el camino recibe su cable de estaci\xf3n y comparte el com\xfan.")
B.j9=new A.a("Clique no ponto e depois onde vai o texto: chamada vertical cota o X, horizontal cota o Y (a partir da origem do desenho).","Click the point, then where the text goes: a vertical leader dimensions X, a horizontal one Y (from the drawing origin).","Haga clic en el punto y luego donde va el texto: una l\xednea vertical acota X, una horizontal Y (desde el origen del dibujo).")
B.cT=new A.a("El\xe9trica","Electrical","El\xe9ctrico")
B.rc=new A.a("Controladores","Controllers","Controladores")
B.zd=new A.a("Fios el\xe9tricos","Wires","Cables el\xe9ctricos")
B.yX=new A.a("Imagens","Images","Im\xe1genes")
B.oE=new A.a("Hachuras","Hatches","Sombreados")
B.r1=new A.a("S\xedmbolos","Symbols","S\xedmbolos")
B.wa=new A.a("esta\xe7\xf5es","stations","estaciones")
B.DW=new A.a("Conector de emenda \xe0 prova d'\xe1gua","Waterproof wire connector","Conector de empalme estanco")
B.oY=new A.a("E{n}","S{n}","E{n}")
B.k7=new A.a("Esta\xe7\xf5es usadas","Stations used","Estaciones usadas")
B.cD=new A.a("Fio comum","Common wire","Cable com\xfan")
B.qY=new A.a("V\xe1lvulas abertas juntas","Valves open together","V\xe1lvulas abiertas juntas")
B.ET=new A.a("Corrente de pico","Peak current","Corriente de pico")
B.BN=new A.a("Controlador \xb7 esta\xe7\xe3o","Controller \xb7 station","Controlador \xb7 estaci\xf3n")
B.cN=new A.a("Fio de esta\xe7\xe3o","Station wire","Cable de estaci\xf3n")
B.bO=new A.a("Tens\xe3o no solenoide","Solenoid voltage","Tensi\xf3n en el solenoide")
B.El=new A.a("Comum","Common","Com\xfan")
B.yO=new A.a("El\xe9trico","Electrical","El\xe9ctrico")
B.y2=new A.a("Sem projeto el\xe9trico: coloque um controlador (CTRL) e desenhe as rotas de fios (WR) at\xe9 as v\xe1lvulas.","No electrical design: place a controller (CTRL) and draw the wire routes (WR) to the valves.","Sin dise\xf1o el\xe9ctrico: coloque un controlador (CTRL) y dibuje las rutas de cables (WR) hasta las v\xe1lvulas.")
B.tN=new A.a("Rota","Route","Ruta")
B.c7=new A.a("Fio","Wire","Cable")
B.je=new A.a("Abertas juntas","Open together","Abiertas juntas")
B.jd=new A.a("Cotar o di\xe2metro (\xd8)","Dimension the diameter (\xd8)","Acotar el di\xe1metro (\xd8)")
B.v3=new A.a("Cota o X (desligado: o Y)","Dimensions X (off: Y)","Acota X (apagado: Y)")
B.C1=new A.a("Esta\xe7\xf5es","Stations","Estaciones")
B.y0=new A.a("Tens\xe3o de sa\xedda (V CA)","Output voltage (V AC)","Tensi\xf3n de salida (V CA)")
B.i7=new A.a("M\xe1ximo de esta\xe7\xf5es juntas (0 = pelos turnos)","Most stations at once (0 = from the system flows)","M\xe1ximo de estaciones juntas (0 = seg\xfan los turnos)")
B.nW=new A.a("Fios","Wires","Cables")
B.kK=new A.a("Se\xe7\xe3o (mm\xb2)","Section (mm\xb2)","Secci\xf3n (mm\xb2)")
B.rV=new A.a("Resist\xeancia (\u03a9/km)","Resistance (\u03a9/km)","Resistencia (\u03a9/km)")
B.AA=new A.a("El\xe9trica (solenoides 24 V CA)","Electrical (24 V AC solenoids)","El\xe9ctrico (solenoides 24 V CA)")
B.mI=new A.a("Corrente de partida (A)","Inrush current (A)","Corriente de arranque (A)")
B.u2=new A.a("Corrente de reten\xe7\xe3o (A)","Holding current (A)","Corriente de retenci\xf3n (A)")
B.pp=new A.a("Tens\xe3o m\xednima no solenoide (V)","Minimum solenoid voltage (V)","Tensi\xf3n m\xednima en el solenoide (V)")
B.iD=new A.a("Folga de fio (%)","Wire slack (%)","Holgura de cable (%)")
B.Ct=new A.a("Rotas de fios sem controlador","Wire routes without a controller","Rutas de cables sin controlador")
B.DO=new A.a("V\xe1lvula sem fio at\xe9 um controlador","Valve without a wire to a controller","V\xe1lvula sin cable hasta un controlador")
B.yH=new A.a("Rota de fios que n\xe3o chega a nenhum controlador","Wire route that reaches no controller","Ruta de cables que no llega a ning\xfan controlador")
B.nl=new A.a("Controlador fora das rotas de fios","Controller off the wire routes","Controlador fuera de las rutas de cables")
B.pl=new A.a("Nenhum fio habilitado no cat\xe1logo","No wire enabled in the catalogue","Ning\xfan cable habilitado en el cat\xe1logo")
B.rr=new A.a("Controlador com menos esta\xe7\xf5es que v\xe1lvulas","Controller with fewer stations than valves","Controlador con menos estaciones que v\xe1lvulas")
B.re=new A.a("Tens\xe3o no solenoide abaixo da m\xednima","Solenoid voltage below the minimum","Tensi\xf3n en el solenoide por debajo de la m\xednima")
B.AK=new A.a("O turno abre mais v\xe1lvulas do que o controlador aciona juntas","The system flow opens more valves than the controller drives at once","El turno abre m\xe1s v\xe1lvulas de las que el controlador acciona a la vez")
B.qI=new A.a("H\xe1 rotas de fios, mas nenhum controlador: sem ele n\xe3o h\xe1 de onde partir a tens\xe3o das v\xe1lvulas nem como dimensionar os fios.","There are wire routes but no controller: without it there is nowhere for the valve voltage to come from and no way to size the wires.","Hay rutas de cables pero ning\xfan controlador: sin \xe9l no hay de d\xf3nde salga la tensi\xf3n de las v\xe1lvulas ni c\xf3mo dimensionar los cables.")
B.Ew=new A.a("Coloque um controlador (CTRL) sobre o in\xedcio de uma rota de fios.","Place a controller (CTRL) on the start of a wire route.","Coloque un controlador (CTRL) sobre el inicio de una ruta de cables.")
B.Fj=new A.a("A v\xe1lvula n\xe3o est\xe1 em nenhuma rota de fios ligada a um controlador, ent\xe3o n\xe3o ter\xe1 esta\xe7\xe3o nem fio no or\xe7amento e n\xe3o abrir\xe1 sozinha.","The valve is on no wire route connected to a controller, so it gets no station and no wire in the bill of materials and will not open by itself.","La v\xe1lvula no est\xe1 en ninguna ruta de cables conectada a un controlador, as\xed que no tendr\xe1 estaci\xf3n ni cable en el presupuesto y no se abrir\xe1 sola.")
B.jG=new A.a("Estenda uma rota de fios (WR) at\xe9 a v\xe1lvula, terminando exatamente sobre ela ou passando por ela.","Extend a wire route (WR) to the valve, ending exactly on it or passing through it.","Extienda una ruta de cables (WR) hasta la v\xe1lvula, terminando exactamente sobre ella o pasando por ella.")
B.EF=new A.a("Esta rota de fios n\xe3o se liga a nenhum controlador (nem por outra rota); os fios dela n\xe3o entram no c\xe1lculo.","This wire route connects to no controller (not even through another route); its wires are left out of the design.","Esta ruta de cables no se conecta a ning\xfan controlador (ni por otra ruta); sus cables quedan fuera del c\xe1lculo.")
B.pw=new A.a("Ligue a rota a outra rota por um v\xe9rtice comum ou at\xe9 um controlador, ou apague-a se sobrou.","Join the route to another one at a shared vertex or to a controller, or delete it if it is left over.","Una la ruta a otra por un v\xe9rtice com\xfan o hasta un controlador, o b\xf3rrela si sobra.")
B.lK=new A.a("O controlador n\xe3o est\xe1 sobre nenhuma rota de fios, ent\xe3o n\xe3o aciona nenhuma v\xe1lvula.","The controller is on no wire route, so it drives no valve.","El controlador no est\xe1 sobre ninguna ruta de cables, as\xed que no acciona ninguna v\xe1lvula.")
B.Cv=new A.a("Mova o controlador para o in\xedcio de uma rota ou desenhe uma rota (WR) a partir dele.","Move the controller to the start of a route or draw a route (WR) from it.","Mueva el controlador al inicio de una ruta o dibuje una ruta (WR) desde \xe9l.")
B.le=new A.a("O cat\xe1logo n\xe3o tem fios habilitados; o c\xe1lculo sup\xf4s um fio de cobre de 1,5 mm\xb2 e n\xe3o p\xf4s fios no or\xe7amento.","The catalogue has no wire enabled; the design assumed a 1.5 mm\xb2 copper wire and left the wires out of the bill of materials.","El cat\xe1logo no tiene cables habilitados; el c\xe1lculo supuso un cable de cobre de 1,5 mm\xb2 y dej\xf3 los cables fuera del presupuesto.")
B.AT=new A.a("Habilite fios no cat\xe1logo (aba Fios) ou restaure os fios padr\xe3o.","Enable wires in the catalogue (Wires tab) or restore the default wires.","Habilite cables en el cat\xe1logo (pesta\xf1a Cables) o restaure los cables por defecto.")
B.zk=new A.a("H\xe1 mais v\xe1lvulas ligadas ao controlador do que esta\xe7\xf5es: algumas zonas ficariam sem sa\xedda para abrir.","More valves are wired to the controller than it has stations: some zones would have no output to open them.","Hay m\xe1s v\xe1lvulas conectadas al controlador que estaciones: algunas zonas quedar\xedan sin salida para abrirlas.")
B.Dc=new A.a("Use um controlador com mais esta\xe7\xf5es (ou um m\xf3dulo de expans\xe3o), ou divida as v\xe1lvulas entre dois controladores.","Use a controller with more stations (or an expansion module), or split the valves between two controllers.","Use un controlador con m\xe1s estaciones (o un m\xf3dulo de expansi\xf3n), o divida las v\xe1lvulas entre dos controladores.")
B.io=new A.a("Mesmo com o fio mais grosso habilitado, a queda de tens\xe3o no fio de esta\xe7\xe3o e no comum deixa o solenoide abaixo da tens\xe3o m\xednima ao abrir: a v\xe1lvula pode n\xe3o abrir ou zumbir.","Even with the thickest enabled wire, the voltage drop in the station and common wires leaves the solenoid below the minimum voltage while opening: the valve may not open or may chatter.","Aun con el cable m\xe1s grueso habilitado, la ca\xedda de tensi\xf3n en el cable de estaci\xf3n y en el com\xfan deja el solenoide por debajo de la tensi\xf3n m\xednima al abrir: la v\xe1lvula puede no abrir o vibrar.")
B.w0=new A.a("Habilite fios mais grossos no cat\xe1logo, aproxime o controlador das v\xe1lvulas, reduza as v\xe1lvulas abertas juntas no mesmo comum ou use um controlador de dois fios (decodificadores).","Enable thicker wires in the catalogue, bring the controller closer to the valves, open fewer valves together on the same common or use a two-wire (decoder) controller.","Habilite cables m\xe1s gruesos en el cat\xe1logo, acerque el controlador a las v\xe1lvulas, abra menos v\xe1lvulas juntas en el mismo com\xfan o use un controlador de dos hilos (decodificadores).")
B.CS=new A.a("Um turno abre ao mesmo tempo mais v\xe1lvulas deste controlador do que ele consegue acionar juntas.","A system flow opens more valves of this controller at once than it can drive together.","Un turno abre a la vez m\xe1s v\xe1lvulas de este controlador de las que puede accionar juntas.")
B.DQ=new A.a("Divida o turno (Projeto \u2192 Manejo) ou aumente o m\xe1ximo de esta\xe7\xf5es simult\xe2neas do controlador.","Split the system flow (Design \u2192 Management) or raise the controller's stations at once.","Divida el turno (Dise\xf1o \u2192 Manejo) o aumente el m\xe1ximo de estaciones simult\xe1neas del controlador.")
B.pj=new A.a("Habilitar os fios do cat\xe1logo","Enable the catalogue wires","Habilitar los cables del cat\xe1logo")
B.th=new A.a("Controlador com esta\xe7\xf5es suficientes","Controller with enough stations","Controlador con estaciones suficientes")
B.xc=new A.a("{n} fio(s) habilitado(s) no cat\xe1logo","{n} wire(s) enabled in the catalogue","{n} cable(s) habilitado(s) en el cat\xe1logo")
B.ri=new A.a("controlador passou a ter {n} esta\xe7\xf5es","controller now has {n} stations","el controlador ahora tiene {n} estaciones")
B.oK=new A.a("Configura\xe7\xf5es","Settings","Configuraci\xf3n")
B.Bw=new A.a("Detalhes do projeto","Project details","Detalles del proyecto")
B.kC=new A.a("Par\xe2metros","Parameters","Par\xe1metros")
B.v7=new A.a("Unidades","Units","Unidades")
B.n9=new A.a("Cat\xe1logo","Catalogue","Cat\xe1logo")
B.uw=new A.a("Autom\xe1tico\u2026","Automatic\u2026","Autom\xe1tico\u2026")
B.kN=new A.a("Agrupa as zonas e os piv\xf4s no menor n\xfamero de turnos que cabe na vaz\xe3o m\xe1xima (as maiores demandas primeiro), um turno depois do outro.","Groups the zones and pivots into the fewest system flows that fit the maximum flow (largest demands first), one flow after the other.","Agrupa las zonas y los pivotes en el menor n\xfamero de turnos que cabe en el caudal m\xe1ximo (las mayores demandas primero), un turno tras otro.")
B.tW=new A.a("Vaz\xe3o m\xe1xima por turno ({u}; 0 = da fonte)","Maximum flow per system flow ({u}; 0 = the supply's)","Caudal m\xe1ximo por turno ({u}; 0 = el de la fuente)")
B.uG=new A.a("M\xe1ximo de zonas juntas (0 = sem limite)","Most zones open together (0 = no limit)","M\xe1ximo de zonas juntas (0 = sin l\xedmite)")
B.nn=new A.a("Limite usado: {q}","Limit used: {q}","L\xedmite usado: {q}")
B.na=new A.a("Sem limite de vaz\xe3o: informe a vaz\xe3o m\xe1xima ou a vaz\xe3o de projeto da fonte de \xe1gua.","No flow limit: enter the maximum flow or the design flow of the water supply.","Sin l\xedmite de caudal: indique el caudal m\xe1ximo o el caudal de dise\xf1o de la fuente de agua.")
B.CA=new A.a("Gerar turnos","Generate system flows","Generar turnos")
B.xg=new A.a("{n} turno(s); maior demanda {q}","{n} system flow(s); peak demand {q}","{n} turno(s); mayor demanda {q}")
B.n4=new A.a("Sozinhas acima da vaz\xe3o m\xe1xima (cada uma ficou num turno pr\xf3prio): {z}","Above the maximum flow on their own (each got a flow of its own): {z}","Por s\xed solas superan el caudal m\xe1ximo (cada una qued\xf3 en un turno propio): {z}")
B.kF=new A.a("Demanda: {q}","Demand: {q}","Demanda: {q}")
B.fs=new A.aT(B.fw,[B.oe,B.r9,B.bW,B.lD,B.nS,B.Ez,B.ci,B.ay,B.c2,B.cH,B.c0,B.F,B.t,B.cV,B.oz,B.c6,B.bP,B.bJ,B.iF,B.r2,B.jy,B.ka,B.jR,B.xn,B.jO,B.iq,B.CU,B.xW,B.mu,B.tC,B.bX,B.Da,B.Eb,B.xb,B.rN,B.c1,B.ke,B.B9,B.mr,B.jw,B.j1,B.pt,B.ra,B.mH,B.xU,B.k4,B.lx,B.yw,B.qo,B.nI,B.w1,B.vY,B.li,B.vA,B.pO,B.zv,B.vM,B.vh,B.l2,B.yC,B.n3,B.j8,B.mX,B.uE,B.tS,B.u4,B.t1,B.yA,B.tj,B.iS,B.D6,B.vW,B.An,B.oV,B.rg,B.ru,B.z5,B.vc,B.x0,B.B3,B.ql,B.zH,B.Am,B.nO,B.vm,B.nj,B.lz,B.l8,B.aH,B.tJ,B.nY,B.u_,B.yW,B.rI,B.tI,B.xw,B.iO,B.aQ,B.Bi,B.zq,B.rL,B.nC,B.FF,B.c_,B.nw,B.o_,B.cn,B.rw,B.ve,B.DH,B.q7,B.zw,B.uX,B.y3,B.Fi,B.uu,B.i3,B.zr,B.n1,B.a4,B.mx,B.yx,B.vQ,B.BF,B.nd,B.m3,B.ns,B.Dq,B.A,B.aQ,B.Cq,B.zA,B.aA,B.cG,B.jC,B.lm,B.d8,B.yD,B.n2,B.tE,B.oC,B.CT,B.ne,B.m5,B.BC,B.r4,B.cd,B.d8,B.aQ,B.tM,B.we,B.FE,B.jv,B.bV,B.p1,B.wm,B.qR,B.EI,B.Fo,B.Bg,B.xM,B.w4,B.ww,B.vr,B.kH,B.r7,B.lh,B.of,B.oR,B.qe,B.oB,B.x2,B.jK,B.a5,B.Dl,B.CZ,B.Eq,B.xf,B.ua,B.iJ,B.aC,B.A,B.As,B.pM,B.a5,B.ij,B.EL,B.qw,B.pP,B.AE,B.Cs,B.j6,B.rB,B.A5,B.ue,B.xs,B.Ad,B.j7,B.wc,B.nf,B.a4,B.mw,B.uz,B.ws,B.aN,B.m6,B.CV,B.jU,B.cf,B.a3,B.mT,B.ps,B.az,B.B_,B.rt,B.cR,B.bI,B.qv,B.is,B.z1,B.zW,B.pT,B.BM,B.j3,B.Ao,B.A0,B.w5,B.pV,B.DI,B.qi,B.Cg,B.iL,B.qn,B.rU,B.uh,B.cd,B.rl,B.zQ,B.j0,B.uV,B.aO,B.c1,B.y1,B.me,B.aF,B.cX,B.Aq,B.p8,B.a3,B.bU,B.Df,B.B8,B.DF,B.AD,B.yl,B.ys,B.ya,B.tF,B.xL,B.bK,B.F,B.o7,B.BX,B.FB,B.FI,B.wP,B.nZ,B.EG,B.az,B.co,B.d5,B.t2,B.aP,B.x6,B.a4,B.j_,B.jA,B.nR,B.jo,B.kE,B.mB,B.bY,B.aJ,B.A,B.pi,B.ct,B.Dt,B.pN,B.t0,B.Fs,B.DV,B.il,B.d_,B.Fq,B.x5,B.FA,B.EC,B.z7,B.F,B.t,B.aD,B.vp,B.BY,B.aE,B.lV,B.F0,B.xX,B.oF,B.lr,B.vo,B.lG,B.zN,B.lM,B.pS,B.zl,B.AJ,B.zO,B.p4,B.rn,B.CM,B.oS,B.vT,B.B6,B.xj,B.zf,B.wM,B.E9,B.Cu,B.xD,B.F3,B.xr,B.nX,B.F,B.bK,B.A,B.aD,B.k3,B.vd,B.d_,B.d4,B.cw,B.EK,B.zU,B.AL,B.F6,B.Bv,B.lJ,B.mt,B.nt,B.p2,B.cX,B.mQ,B.cg,B.t6,B.q_,B.zJ,B.iT,B.id,B.wU,B.oq,B.rA,B.a3,B.qQ,B.Du,B.Fg,B.aG,B.p7,B.kJ,B.vR,B.cK,B.aB,B.az,B.d5,B.xE,B.Dw,B.yR,B.Ee,B.C3,B.kp,B.Ax,B.l_,B.wg,B.tz,B.Ci,B.x_,B.yN,B.D1,B.mJ,B.Dy,B.r8,B.rz,B.C5,B.Ai,B.tl,B.yt,B.uP,B.uC,B.D3,B.z6,B.d6,B.aJ,B.xR,B.ie,B.iB,B.oj,B.qP,B.wx,B.Do,B.Ej,B.aC,B.oW,B.A,B.cU,B.cG,B.aA,B.F,B.aB,B.xO,B.un,B.uQ,B.cg,B.aJ,B.bJ,B.a4,B.aG,B.D2,B.vy,B.z,B.ko,B.n5,B.zo,B.qg,B.qh,B.AB,B.yV,B.cu,B.cE,B.o3,B.AZ,B.Eo,B.Q,B.EW,B.uy,B.rT,B.mp,B.qc,B.rS,B.r_,B.wf,B.p_,B.ii,B.yT,B.i_,B.hZ,B.Au,B.lN,B.ol,B.Db,B.pB,B.zZ,B.q6,B.v1,B.rx,B.pH,B.jE,B.ly,B.Eh,B.Dh,B.w_,B.nq,B.DJ,B.mY,B.ck,B.wG,B.q8,B.C6,B.xk,B.iP,B.yY,B.ip,B.lS,B.rZ,B.cO,B.ck,B.iy,B.pW,B.o1,B.cO,B.xK,B.l6,B.qb,B.AC,B.qp,B.rD,B.bY,B.aD,B.aE,B.cQ,B.jj,B.wo,B.zy,B.aF,B.yr,B.cZ,B.Cl,B.CF,B.EZ,B.q4,B.mE,B.AF,B.mC,B.oZ,B.uD,B.m1,B.xt,B.yL,B.yI,B.i9,B.xZ,B.c4,B.mm,B.nV,B.lO,B.CP,B.rE,B.tk,B.uR,B.xT,B.cf,B.rY,B.oJ,B.kG,B.va,B.ct,B.A,B.mG,B.n7,B.wi,B.np,B.zR,B.zE,B.rC,B.CN,B.kR,B.A4,B.co,B.ot,B.kO,B.cm,B.lX,B.zh,B.pf,B.CI,B.zK,B.k0,B.BD,B.te,B.Bf,B.DX,B.v2,B.xx,B.w2,B.pZ,B.i2,B.wd,B.nm,B.aC,B.A,B.c8,B.cU,B.aA,B.vb,B.aF,B.mS,B.vH,B.md,B.F_,B.iz,B.a3,B.bU,B.ir,B.EU,B.d4,B.cw,B.CC,B.mc,B.zn,B.wX,B.CG,B.ER,B.pK,B.cz,B.mF,B.BG,B.k8,B.us,B.rq,B.uo,B.ul,B.rH,B.t4,B.ry,B.yv,B.ia,B.ld,B.Bo,B.Cz,B.Fe,B.rs,B.ku,B.wY,B.EN,B.xY,B.CD,B.tZ,B.AX,B.kv,B.nr,B.qx,B.Bt,B.um,B.xB,B.zM,B.z8,B.kb,B.BO,B.pe,B.Ba,B.t7,B.ze,B.iU,B.vZ,B.vu,B.D8,B.CY,B.xN,B.oD,B.cj,B.oI,B.EX,B.iG,B.cv,B.y4,B.c3,B.vL,B.lC,B.ny,B.F2,B.DA,B.yB,B.pv,B.js,B.uv,B.i8,B.oX,B.iv,B.Ep,B.pF,B.EH,B.DL,B.AN,B.vx,B.q0,B.uF,B.qC,B.CW,B.Fb,B.lL,B.uB,B.rO,B.qa,B.mq,B.l5,B.E7,B.xV,B.l0,B.zi,B.iV,B.x7,B.Cj,B.xu,B.ic,B.EE,B.E3,B.yG,B.tu,B.j2,B.qV,B.k1,B.ye,B.pE,B.Bd,B.BQ,B.iE,B.qJ,B.l7,B.iR,B.kM,B.oi,B.Ed,B.Fr,B.uN,B.j5,B.Fu,B.xa,B.vl,B.r5,B.lY,B.wl,B.u0,B.BV,B.z9,B.Cn,B.Di,B.po,B.lu,B.oU,B.tR,B.yb,B.nA,B.m_,B.Bx,B.tG,B.jq,B.mv,B.kT,B.Ck,B.pk,B.mP,B.yh,B.cj,B.vO,B.lF,B.kW,B.oL,B.rj,B.ph,B.nP,B.ay,B.kS,B.pc,B.mZ,B.pJ,B.wL,B.tA,B.zt,B.ub,B.vk,B.rh,B.n_,B.Dj,B.i4,B.zT,B.BP,B.D9,B.CJ,B.AV,B.vf,B.xz,B.kd,B.jt,B.wp,B.Em,B.xA,B.ni,B.Ae,B.tg,B.kh,B.uU,B.cb,B.Q,B.AG,B.CL,B.yg,B.DU,B.cu,B.cE,B.d3,B.bT,B.qq,B.zD,B.cA,B.bF,B.bS,B.cc,B.bL,B.rJ,B.m4,B.Bz,B.wq,B.Ce,B.Fx,B.cp,B.cY,B.c8,B.zX,B.ml,B.DZ,B.pG,B.r6,B.BJ,B.lo,B.E2,B.Be,B.yc,B.qM,B.vU,B.c_,B.aG,B.cI,B.c4,B.nU,B.cZ,B.Bp,B.aP,B.it,B.z2,B.qf,B.Ca,B.wK,B.u9,B.mA,B.oy,B.Cm,B.lv,B.CX,B.jN,B.kq,B.bH,B.mK,B.pq,B.bH,B.uO,B.BH,B.o2,B.cY,B.zu,B.n8,B.aH,B.EM,B.DE,B.lP,B.iC,B.yk,B.Bl,B.F4,B.wJ,B.kQ,B.yU,B.z4,B.Cx,B.tT,B.Cb,B.B4,B.BS,B.A2,B.v5,B.zV,B.vz,B.Ah,B.AI,B.kt,B.F5,B.Bc,B.km,B.yM,B.ty,B.t8,B.xH,B.t5,B.jf,B.ja,B.tO,B.Cc,B.CB,B.jT,B.ju,B.w9,B.Bq,B.yo,B.oM,B.y8,B.m9,B.z3,B.ki,B.Bu,B.pQ,B.DS,B.jp,B.a5,B.kZ,B.r0,B.xJ,B.lb,B.uT,B.on,B.aB,B.jQ,B.vE,B.qs,B.cm,B.x3,B.lU,B.cK,B.wV,B.DG,B.uJ,B.jn,B.B1,B.ig,B.yu,B.u8,B.u1,B.pa,B.xQ,B.lq,B.Ch,B.yQ,B.uc,B.pb,B.yE,B.tD,B.n0,B.pg,B.ti,B.DC,B.C2,B.D7,B.tH,B.zp,B.r3,B.d0,B.BT,B.tr,B.C_,B.zj,B.Ey,B.qA,B.Ei,B.jJ,B.F9,B.Aw,B.ib,B.CQ,B.wH,B.FC,B.ji,B.mO,B.px,B.Ac,B.la,B.E_,B.FD,B.jx,B.pX,B.D_,B.iW,B.ce,B.jF,B.kg,B.aP,B.cl,B.Bn,B.oa,B.qW,B.qX,B.cy,B.yF,B.wv,B.u7,B.Cw,B.EQ,B.i1,B.Fl,B.jb,B.q9,B.tL,B.qz,B.o0,B.l3,B.iN,B.y9,B.ur,B.wQ,B.x1,B.uM,B.jV,B.aH,B.qr,B.pL,B.zz,B.yj,B.xe,B.Cr,B.qO,B.ta,B.lR,B.w8,B.Ev,B.jB,B.kA,B.l1,B.bN,B.nh,B.Fm,B.qu,B.t_,B.kj,B.om,B.ci,B.uL,B.Eu,B.BZ,B.t3,B.De,B.BE,B.no,B.cM,B.aE,B.cp,B.cS,B.n6,B.cz,B.cB,B.DK,B.nk,B.mR,B.E8,B.qF,B.aI,B.u3,B.DM,B.vG,B.uI,B.rX,B.AW,B.jS,B.og,B.mN,B.oT,B.nH,B.Cy,B.vI,B.pd,B.F7,B.lc,B.p9,B.rp,B.vX,B.td,B.E4,B.xl,B.pu,B.mD,B.iY,B.wO,B.u6,B.cs,B.aN,B.ma,B.cl,B.zI,B.kX,B.iw,B.B5,B.wz,B.A6,B.nv,B.lI,B.qZ,B.ob,B.pI,B.to,B.yq,B.qU,B.z_,B.j4,B.p6,B.ok,B.k6,B.BU,B.jL,B.rk,B.F8,B.xy,B.zF,B.jW,B.y_,B.Dx,B.ug,B.cL,B.qB,B.zs,B.c5,B.iQ,B.C7,B.Bb,B.wW,B.kn,B.kr,B.vK,B.kU,B.zP,B.qL,B.cF,B.wu,B.Fw,B.vJ,B.i0,B.oo,B.AY,B.rv,B.B0,B.xd,B.Fn,B.c5,B.CO,B.lW,B.D4,B.uW,B.ro,B.pU,B.lB,B.Ft,B.q3,B.oO,B.d6,B.vS,B.q1,B.tf,B.jP,B.rG,B.up,B.cF,B.qN,B.Ex,B.qm,B.xo,B.yy,B.CK,B.v8,B.yf,B.v0,B.qS,B.oQ,B.lp,B.nT,B.Dg,B.iK,B.qk,B.wT,B.mU,B.nD,B.Cf,B.mM,B.Ek,B.pn,B.uk,B.od,B.DP,B.kc,B.mk,B.rd,B.lH,B.tV,B.zS,B.kL,B.mW,B.m8,B.op,B.x4,B.xi,B.Bk,B.tv,B.Dk,B.tx,B.pA,B.tn,B.ll,B.AU,B.q2,B.o5,B.k2,B.wI,B.xh,B.Dv,B.tc,B.yi,B.Ak,B.BA,B.pr,B.D0,B.kP,B.wF,B.vB,B.xv,B.pz,B.jH,B.xI,B.w6,B.Av,B.jz,B.tX,B.jD,B.t9,B.wA,B.yZ,B.Ff,B.EA,B.mz,B.kI,B.jX,B.lk,B.EP,B.rF,B.yz,B.lT,B.C8,B.yn,B.mV,B.lf,B.wD,B.DB,B.EY,B.w3,B.i6,B.vt,B.Ab,B.Aa,B.wR,B.AP,B.Ea,B.l4,B.Az,B.rf,B.wk,B.Co,B.rb,B.ym,B.zL,B.zG,B.Al,B.nJ,B.pm,B.E6,B.jY,B.A7,B.zB,B.wj,B.rM,B.nL,B.yK,B.BI,B.oP,B.k5,B.vq,B.nz,B.FH,B.lZ,B.EV,B.Dd,B.vP,B.uq,B.DD,B.Er,B.rW,B.ut,B.kl,B.w7,B.ky,B.wt,B.xP,B.o6,B.my,B.vV,B.xp,B.D5,B.AO,B.Fp,B.l9,B.vC,B.m0,B.uf,B.Fh,B.CR,B.v_,B.EJ,B.vw,B.DY,B.oH,B.A1,B.v4,B.Et,B.o4,B.kw,B.nc,B.nu,B.yS,B.jm,B.A3,B.iA,B.zg,B.ov,B.AH,B.Dn,B.ng,B.qy,B.pD,B.p0,B.BR,B.Ef,B.Bm,B.vF,B.zc,B.yP,B.iu,B.ms,B.bW,B.aO,B.c6,B.Dm,B.qT,B.c0,B.c2,B.cy,B.F,B.rR,B.lg,B.cV,B.ay,B.cH,B.bP,B.jI,B.xm,B.za,B.AS,B.jr,B.oc,B.CH,B.AQ,B.uY,B.qE,B.cv,B.c3,B.nx,B.Af,B.uA,B.qt,B.cR,B.bI,B.aO,B.p5,B.ln,B.bN,B.Es,B.Ag,B.bX,B.ce,B.lA,B.bV,B.tt,B.a5,B.tK,B.k_,B.tY,B.B2,B.nN,B.kD,B.ES,B.bQ,B.vv,B.im,B.jM,B.jl,B.xS,B.EB,B.kk,B.cB,B.x9,B.ts,B.or,B.oG,B.qD,B.wy,B.tm,B.lQ,B.nE,B.Dz,B.ox,B.Cd,B.v6,B.nG,B.zC,B.Cp,B.iM,B.nF,B.m2,B.FG,B.ux,B.vn,B.C0,B.xC,B.y6,B.Bh,B.C4,B.BW,B.Ds,B.qj,B.Fy,B.By,B.uH,B.ls,B.ih,B.jg,B.F1,B.BK,B.nB,B.mb,B.Ec,B.Fd,B.Bs,B.nM,B.tp,B.DT,B.rP,B.m7,B.o9,B.bR,B.nK,B.wS,B.cW,B.lt,B.En,B.ix,B.tP,B.Fz,B.aI,B.Ar,B.lw,B.kB,B.bR,B.kV,B.ks,B.y5,B.qd,B.mi,B.nb,B.Aj,B.mh,B.i5,B.q5,B.pC,B.vj,B.bL,B.lE,B.t,B.tQ,B.cW,B.d9,B.jZ,B.kx,B.mf,B.wB,B.a6,B.cq,B.c9,B.t,B.yd,B.zx,B.Dr,B.Bj,B.R,B.cA,B.a6,B.cC,B.aL,B.ax,B.P,B.r,B.aI,B.z,B.v9,B.k9,B.zY,B.Q,B.bF,B.G,B.cJ,B.r,B.d1,B.wb,B.kf,B.bM,B.zm,B.kz,B.ca,B.wr,B.AM,B.d7,B.xG,B.z0,B.cr,B.pR,B.mo,B.bG,B.jk,B.iI,B.d2,B.ik,B.jc,B.bZ,B.CE,B.jh,B.uj,B.Fk,B.wZ,B.cP,B.x8,B.tw,B.d1,B.DN,B.E0,B.vN,B.cx,B.tU,B.E1,B.cb,B.t,B.bM,B.wE,B.Ap,B.kY,B.cx,B.vD,B.qH,B.tB,B.t,B.ca,B.z,B.o8,B.tq,B.R,B.d3,B.Q,B.G,B.r,B.d7,B.z,B.aK,B.B7,B.R,B.bT,B.Q,B.r,B.P,B.G,B.cr,B.qG,B.aK,B.vi,B.R,B.bS,B.r,B.P,B.a6,B.cC,B.aL,B.ax,B.bG,B.Fc,B.aK,B.E5,B.R,B.cc,B.Br,B.C9,B.r,B.G,B.aL,B.ax,B.d2,B.z,B.iH,B.rm,B.vg,B.rK,B.mn,B.P,B.a6,B.t,B.bZ,B.d9,B.A9,B.At,B.uK,B.nQ,B.py,B.os,B.BB,B.ch,B.c9,B.cq,B.t,B.pY,B.z,B.wN,B.ow,B.tb,B.ui,B.ch,B.ud,B.cJ,B.r,B.P,B.G,B.cP,B.z,B.oA,B.Ay,B.Dp,B.uS,B.mg,B.A8,B.aN,B.r,B.G,B.rQ,B.yJ,B.wC,B.A_,B.oh,B.oN,B.wn,B.mL,B.wh,B.DR,B.iX,B.cI,B.cs,B.zb,B.bQ,B.iZ,B.vs,B.p3,B.Fv,B.xF,B.Eg,B.mj,B.BL,B.Fa,B.uZ,B.EO,B.ou,B.y7,B.lj,B.xq,B.cL,B.ED,B.aM,B.AR,B.yp,B.u5,B.qK,B.j9,B.aM,B.cT,B.rc,B.zd,B.yX,B.oE,B.r1,B.cS,B.cT,B.wa,B.DW,B.oY,B.k7,B.cD,B.qY,B.ET,B.BN,B.cN,B.bO,B.El,B.yO,B.y2,B.aM,B.cM,B.tN,B.c7,B.cN,B.cD,B.je,B.bO,B.cQ,B.jd,B.v3,B.cn,B.C1,B.y0,B.i7,B.nW,B.c7,B.kK,B.rV,B.AA,B.mI,B.u2,B.pp,B.iD,B.Ct,B.DO,B.yH,B.nl,B.pl,B.rr,B.re,B.AK,B.qI,B.Ew,B.Fj,B.jG,B.EF,B.pw,B.lK,B.Cv,B.le,B.AT,B.zk,B.Dc,B.io,B.w0,B.CS,B.DQ,B.pj,B.th,B.xc,B.ri,B.oK,B.Bw,B.kC,B.v7,B.n9,B.d0,B.uw,B.kN,B.tW,B.uG,B.nn,B.na,B.CA,B.xg,B.n4,B.kF],A.S("aT<c,+(c,c,c)>"))
B.a1={}
B.bx=new A.aT(B.a1,[],A.S("aT<c,r<+(L,e)>>"))
B.as=new A.aT(B.a1,[],A.S("aT<c,c>"))
B.O=new A.C(0,0)
B.fF=new A.cY(0,0,0,1)
B.fG=new A.m(0.0016666666666666666,12)
B.fH=new A.m(0.011111111111111112,65)
B.bC=new A.m(0,0)
B.fI=new A.m(0,110)
B.fJ=new A.m(0,27)
B.fK=new A.m(0,37)
B.fL=new A.m(0,45)
B.fM=new A.m(0,50)
B.fN=new A.m(0,53)
B.fO=new A.m(0,58)
B.fP=new A.m(0,60)
B.fQ=new A.m(0,63)
B.fR=new A.m(0,70)
B.fS=new A.m(0,72)
B.bD=new A.m(0,78)
B.fT=new A.m(0,80)
B.fU=new A.m(0,82)
B.fV=new A.m(0,85)
B.bE=new A.m(0,90)
B.fW=new A.m(0.044444444444444446,55)
B.fZ=new A.m(0.041666666666666664,78)
B.h_=new A.m(0.002777777777777778,18)
B.h0=new A.m(0.0011111111111111111,20)
B.h1=new A.m(0.0005555555555555556,25)
B.h2=new A.m(0.06388888888888888,38)
B.h3=new A.m(0.001388888888888889,41)
B.h5=new A.m(0.03333333333333333,55)
B.h9=new A.m(0.022222222222222223,31)
B.hb=new A.m(0.03888888888888889,40)
B.hc=new A.m(0.0022222222222222222,55)
B.hd=new A.m(0.006944444444444444,60)
B.he=new A.m(0.005555555555555556,53)
B.hf=new A.m(0.003333333333333333,36)
B.hg=new A.m(0.0011111111111111111,68)
B.hh=new A.m("","")
B.hi=new A.m(0.0019444444444444444,28)
B.hj=new A.m(0.03194444444444444,72)
B.hk=new A.m(0.015277777777777777,45)
B.hl=new A.m(0.016666666666666666,30)
B.hm=new A.m(0.005555555555555556,80)
B.hp=new A.m(0.011666666666666667,27)
B.hq=new A.m(0.016666666666666666,42)
B.hr=new A.m(0.011111111111111112,45)
B.hs=new A.m(0.0075,26)
B.ht=new A.m(0.0016666666666666666,80)
B.hv=new A.m(0.09166666666666666,42)
B.hx=new A.m(0.0077777777777777776,55)
B.hy=new A.m(0.027777777777777776,33)
B.hz=new A.m(0.0077777777777777776,40)
B.hA=new A.m(0.0025,46)
B.hB=new A.m(0.0038888888888888888,49)
B.hC=new A.m(0.022222222222222223,52)
B.hD=new A.m(0.009722222222222222,40)
B.hF=new A.m(0.004166666666666667,25)
B.hG=new A.m(0.027777777777777776,60)
B.hH=new A.m(0.013888888888888888,74)
B.hI=new A.m(0.11666666666666667,45)
B.hJ=new A.m(0.022222222222222223,66)
B.hK=new A.m(0.0077777777777777776,98)
B.hL=new A.m(0.019444444444444445,48)
B.hM=new A.m(0.005,42)
B.hN=new A.m(0.08333333333333333,65)
B.hO=new A.m(0.002777777777777778,35)
B.hP=new A.m(0,1/0)
B.hQ=new A.m(0.003333333333333333,72)
B.hR=new A.m(0.05,38)
B.hS=new A.m(0.016666666666666666,64)
B.hT=new A.m(0.06388888888888888,60)
B.hU=new A.m(0.015277777777777777,80)
B.hV=new A.m(0.0009722222222222222,34)
B.hW=new A.m(0.005,38)
B.hX=new A.m(0.003333333333333333,65)
B.hY=new A.m(0.009722222222222222,58)
B.FJ=new A.d6([0,0,0,0])
B.fv={pump_s3:0,pump_s5:1,pump_sub:2,pump_s15:3,pump_s25:4,pump_s30:5}
B.FK=new A.c0(B.fv,6,t.lq)
B.FM=new A.c0(B.a1,0,t.lq)
B.FL=new A.c0(B.a1,0,A.S("c0<f>"))
B.FY=A.bt("rp")
B.FZ=A.bt("rq")
B.G_=A.bt("oR")
B.G0=A.bt("bJ")
B.G1=A.bt("oS")
B.G2=A.bt("oT")
B.G3=A.bt("oU")
B.G4=A.bt("N")
B.G5=A.bt("pr")
B.G6=A.bt("ps")
B.G7=A.bt("pt")
B.G8=A.bt("m_")
B.da=new A.dS(0,0,0,0,0,0,0,0,0,0)
B.db=new A.fc(B.bm,B.bi,B.bB,B.aZ)})();(function staticFields(){$.kw=null
$.b1=A.d([],A.S("o<N>"))
$.mM=null
$.ms=null
$.mr=null
$.nN=null
$.nD=null
$.nZ=null
$.l6=null
$.lh=null
$.mf=null
$.kB=A.d([],A.S("o<r<N>?>"))
$.d8=null
$.ee=null
$.ef=null
$.m8=!1
$.ab=B.u
$.kN=A.l(t.N,A.S("eJ"))
$.lV=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"rs","o3",()=>A.la("_$dart_dartClosure"))
s($,"rr","mj",()=>A.la("_$dart_dartClosure_dartJSInterop"))
s($,"rN","oj",()=>A.d([new J.eB()],A.S("o<dK>")))
s($,"rz","o7",()=>A.bU(A.jZ({
toString:function(){return"$receiver$"}})))
s($,"rA","o8",()=>A.bU(A.jZ({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"rB","o9",()=>A.bU(A.jZ(null)))
s($,"rC","oa",()=>A.bU(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"rF","od",()=>A.bU(A.jZ(void 0)))
s($,"rG","oe",()=>A.bU(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"rE","oc",()=>A.bU(A.n4(null)))
s($,"rD","ob",()=>A.bU(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"rI","og",()=>A.bU(A.n4(void 0)))
s($,"rH","of",()=>A.bU(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"rJ","mk",()=>A.pw())
s($,"rL","oi",()=>A.p1(A.q7(A.d([-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-1,-2,-2,-2,-2,-2,62,-2,62,-2,63,52,53,54,55,56,57,58,59,60,61,-2,-2,-2,-1,-2,-2,-2,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-2,-2,-2,-2,63,-2,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,-2,-2,-2,-2,-2],t.t))))
s($,"rK","oh",()=>A.p2(0))
s($,"rt","o4",()=>A.n_("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"rM","fQ",()=>A.nW(B.G4))
s($,"rv","o5",()=>A.lP(0,"",B.O,B.h))
s($,"rw","o6",()=>A.n_("^e(\\d{1,15})$"))})();(function nativeSupport(){!function(){var s=function(a){var m={}
m[a]=1
return Object.keys(hunkHelpers.convertToFastObject(m))[0]}
v.getIsolateTag=function(a){return s("___dart_"+a+v.isolateTag)}
var r="___dart_isolate_tags_"
var q=Object[r]||(Object[r]=Object.create(null))
var p="_ZxYxX"
for(var o=0;;o++){var n=s(p+"_"+o+"_")
if(!(n in q)){q[n]=1
v.isolateTag=n
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.cS,SharedArrayBuffer:A.cS,ArrayBufferView:A.dG,DataView:A.eP,Float32Array:A.eQ,Float64Array:A.eR,Int16Array:A.eS,Int32Array:A.eT,Int8Array:A.eU,Uint16Array:A.eV,Uint32Array:A.eW,Uint8ClampedArray:A.dH,CanvasPixelArray:A.dH,Uint8Array:A.eX})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.cT.$nativeSuperclassTag="ArrayBufferView"
A.dZ.$nativeSuperclassTag="ArrayBufferView"
A.e_.$nativeSuperclassTag="ArrayBufferView"
A.dE.$nativeSuperclassTag="ArrayBufferView"
A.e0.$nativeSuperclassTag="ArrayBufferView"
A.e1.$nativeSuperclassTag="ArrayBufferView"
A.dF.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
Function.prototype.$6=function(a,b,c,d,e,f){return this(a,b,c,d,e,f)}
Function.prototype.$1$1=function(a){return this(a)}
Function.prototype.$1$2=function(a,b){return this(a,b)}
Function.prototype.$1$0=function(){return this()}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var s=document.scripts
function onLoad(b){for(var q=0;q<s.length;++q){s[q].removeEventListener("load",onLoad,false)}a(b.target)}for(var r=0;r<s.length;++r){s[r].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var s=A.r9
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()