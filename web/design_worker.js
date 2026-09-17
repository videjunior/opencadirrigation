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
if(a[b]!==s){A.qd(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.d(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.li(b)
return new s(c,this)}:function(){if(s===null)s=A.li(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.li(a).prototype
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
ln(a,b,c,d){return{i:a,p:b,e:c,x:d}},
lj(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.ll==null){A.pV()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.l(A.m8("Return interceptor for "+A.y(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.jN
if(o==null)o=$.jN=A.ke(n)
p=q[o]}if(p!=null)return p
p=A.q_(a)
if(p!=null)return p
if(typeof a=="function")return B.d9
s=Object.getPrototypeOf(a)
if(s==null)return B.bn
if(s===Object.prototype)return B.bn
if(typeof q=="function"){o=$.jN
if(o==null)o=$.jN=A.ke(n)
Object.defineProperty(q,o,{value:B.aH,enumerable:false,writable:true,configurable:true})
return B.aH}return B.aH},
lJ(a,b){if(a<0||a>4294967295)throw A.l(A.aO(a,0,4294967295,"length",null))
return J.nS(new Array(a),b)},
lK(a,b){if(a<0)throw A.l(A.d3("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("n<0>"))},
ek(a,b){if(a<0)throw A.l(A.d3("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("n<0>"))},
nS(a,b){var s=A.d(a,b.j("n<0>"))
s.$flags=1
return s},
nT(a,b){var s=t.bP
return J.ls(s.a(a),s.a(b))},
lL(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
nU(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.lL(r))break;++b}return b},
nV(a,b){var s,r,q
for(s=a.length;b>0;b=r){r=b-1
if(!(r<s))return A.b(a,r)
q=a.charCodeAt(r)
if(q!==32&&q!==13&&!J.lL(q))break}return b},
cx(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.df.prototype
return J.em.prototype}if(typeof a=="string")return J.cf.prototype
if(a==null)return J.dg.prototype
if(typeof a=="boolean")return J.el.prototype
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bS.prototype
if(typeof a=="symbol")return J.dj.prototype
if(typeof a=="bigint")return J.dh.prototype
return a}if(a instanceof A.I)return a
return J.lj(a)},
af(a){if(typeof a=="string")return J.cf.prototype
if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bS.prototype
if(typeof a=="symbol")return J.dj.prototype
if(typeof a=="bigint")return J.dh.prototype
return a}if(a instanceof A.I)return a
return J.lj(a)},
a1(a){if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bS.prototype
if(typeof a=="symbol")return J.dj.prototype
if(typeof a=="bigint")return J.dh.prototype
return a}if(a instanceof A.I)return a
return J.lj(a)},
pP(a){if(typeof a=="number")return J.ce.prototype
if(a==null)return a
if(!(a instanceof A.I))return J.cp.prototype
return a},
pQ(a){if(typeof a=="number")return J.ce.prototype
if(typeof a=="string")return J.cf.prototype
if(a==null)return a
if(!(a instanceof A.I))return J.cp.prototype
return a},
aU(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.cx(a).Y(a,b)},
lq(a,b){if(typeof a=="number"&&typeof b=="number")return a-b
return J.pP(a).U(a,b)},
fw(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.pZ(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.af(a).h(a,b)},
kQ(a,b,c){return J.a1(a).i(a,b,c)},
bL(a,b){return J.a1(a).k(a,b)},
lr(a,b){return J.a1(a).B(a,b)},
nk(a,b){return J.a1(a).aX(a,b)},
ls(a,b){return J.pQ(a).S(a,b)},
fx(a,b){return J.a1(a).I(a,b)},
nl(a,b,c,d){return J.a1(a).W(a,b,c,d)},
bM(a){return J.a1(a).gu(a)},
aI(a){return J.cx(a).gK(a)},
lt(a){return J.af(a).gF(a)},
nm(a){return J.af(a).ga8(a)},
aa(a){return J.a1(a).gt(a)},
kR(a){return J.a1(a).gM(a)},
as(a){return J.af(a).gm(a)},
nn(a){return J.a1(a).gcs(a)},
no(a){return J.cx(a).gO(a)},
aC(a,b,c){return J.a1(a).aF(a,b,c)},
np(a,b){return J.af(a).sm(a,b)},
lu(a,b){return J.a1(a).a3(a,b)},
d1(a){return J.cx(a).q(a)},
ei:function ei(){},
el:function el(){},
dg:function dg(){},
di:function di(){},
bT:function bT(){},
eH:function eH(){},
cp:function cp(){},
bS:function bS(){},
dh:function dh(){},
dj:function dj(){},
n:function n(a){this.$ti=a},
ej:function ej(){},
ia:function ia(a){this.$ti=a},
c3:function c3(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
ce:function ce(){},
df:function df(){},
em:function em(){},
cf:function cf(){}},A={kV:function kV(){},
lz(a,b,c){if(t.Y.b(a))return new A.dI(a,b.j("@<0>").v(c).j("dI<1,2>"))
return new A.c4(a,b.j("@<0>").v(c).j("c4<1,2>"))},
lN(a){return new A.er("Field '"+a+"' has been assigned during initialization.")},
bD(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ja(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
cw(a,b,c){return a},
lm(a){var s,r
for(s=$.aS.length,r=0;r<s;++r)if(a===$.aS[r])return!0
return!1},
bW(a,b,c,d){A.cO(b,"start")
if(c!=null){A.cO(c,"end")
if(b>c)A.bq(A.aO(b,0,c,"start",null))}return new A.dD(a,b,c,d.j("dD<0>"))},
kY(a,b,c,d){if(t.Y.b(a))return new A.ca(a,b,c.j("@<0>").v(d).j("ca<1,2>"))
return new A.by(a,b,c.j("@<0>").v(d).j("by<1,2>"))},
m4(a,b,c){if(t.Y.b(a)){A.k0(b)
return void 1}A.k0(b)
return void 1},
k0(a){A.nq(a,"count",t.S)},
at(){return new A.dC("No element")},
bY:function bY(){},
d5:function d5(a,b){this.a=a
this.$ti=b},
c4:function c4(a,b){this.a=a
this.$ti=b},
dI:function dI(a,b){this.a=a
this.$ti=b},
dH:function dH(){},
ab:function ab(a,b){this.a=a
this.$ti=b},
er:function er(a){this.a=a},
j_:function j_(){},
x:function x(){},
t:function t(){},
dD:function dD(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aL:function aL(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
by:function by(a,b,c){this.a=a
this.b=b
this.$ti=c},
ca:function ca(a,b,c){this.a=a
this.b=b
this.$ti=c},
dq:function dq(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
r:function r(a,b,c){this.a=a
this.b=b
this.$ti=c},
B:function B(a,b,c){this.a=a
this.b=b
this.$ti=c},
dG:function dG(a,b,c){this.a=a
this.b=b
this.$ti=c},
dy:function dy(a,b,c){this.a=a
this.b=b
this.$ti=c},
i_:function i_(a,b,c){this.a=a
this.b=b
this.$ti=c},
dz:function dz(a,b,c){this.a=a
this.b=b
this.$ti=c},
d8:function d8(a){this.$ti=a},
d9:function d9(a){this.$ti=a},
cq:function cq(a,b){this.a=a
this.$ti=b},
bH:function bH(a,b){this.a=a
this.$ti=b},
U:function U(){},
bn:function bn(a,b){this.a=a
this.$ti=b},
dV:function dV(){},
lC(){throw A.l(A.bo("Cannot modify unmodifiable Map"))},
lD(){throw A.l(A.bo("Cannot modify constant Set"))},
n3(a){var s=A.n2(a)
if(s!=null)return s
return"minified:"+a},
pZ(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.dX.b(a)},
y(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.d1(a)
return s},
eJ(a){var s,r=$.lR
if(r==null)r=$.lR=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
o4(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.b(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
eK(a){var s,r,q,p
if(a instanceof A.I)return A.aB(A.av(a),null)
s=J.cx(a)
if(s===B.d8||s===B.da||t.cx.b(a)){r=B.aL(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.aB(A.av(a),null)},
lY(a){var s,r,q
if(a==null||typeof a=="number"||A.lc(a))return J.d1(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.ax)return a.q(0)
if(a instanceof A.b3)return a.cb(!0)
s=$.nj()
for(r=0;r<1;++r){q=s[r].dZ(a)
if(q!=null)return q}return"Instance of '"+A.eK(a)+"'"},
o5(a,b,c){var s,r,q,p
if(c<=500&&b===0&&c===a.length)return String.fromCharCode.apply(null,a)
for(s=b,r="";s<c;s=q){q=s+500
p=q<c?q:c
r+=String.fromCharCode.apply(null,a.subarray(s,p))}return r},
ap(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aT(s,10)|55296)>>>0,s&1023|56320)}throw A.l(A.aO(a,0,1114111,null,null))},
o6(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.b6(h,1000)
g+=B.c.bn(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
aM(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
eI(a){return a.c?A.aM(a).getUTCFullYear()+0:A.aM(a).getFullYear()+0},
lW(a){return a.c?A.aM(a).getUTCMonth()+1:A.aM(a).getMonth()+1},
lS(a){return a.c?A.aM(a).getUTCDate()+0:A.aM(a).getDate()+0},
lT(a){return a.c?A.aM(a).getUTCHours()+0:A.aM(a).getHours()+0},
lV(a){return a.c?A.aM(a).getUTCMinutes()+0:A.aM(a).getMinutes()+0},
lX(a){return a.c?A.aM(a).getUTCSeconds()+0:A.aM(a).getSeconds()+0},
lU(a){return a.c?A.aM(a).getUTCMilliseconds()+0:A.aM(a).getMilliseconds()+0},
o3(a){var s=a.$thrownJsError
if(s==null)return null
return A.cy(s)},
cz(a){throw A.l(A.mI(a))},
b(a,b){if(a==null)J.as(a)
throw A.l(A.fr(a,b))},
fr(a,b){var s,r="index"
if(!A.mx(b))return new A.bf(!0,b,r,null)
s=A.a0(J.as(a))
if(b<0||b>=s)return A.i9(b,s,a,r)
return A.l0(b,r)},
mI(a){return new A.bf(!0,a,null,null)},
lg(a){return a},
l(a){return A.a8(a,new Error())},
a8(a,b){var s
if(a==null)a=new A.bF()
b.dartException=a
s=A.qf
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
qf(){return J.d1(this.dartException)},
bq(a,b){throw A.a8(a,b==null?new Error():b)},
a9(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.bq(A.p1(a,b,c),s)},
p1(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.dF("'"+s+"': Cannot "+o+" "+l+k+n)},
k(a){throw A.l(A.al(a))},
bG(a){var s,r,q,p,o,n
a=A.n0(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.d([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.jk(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
jl(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
m7(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
kW(a,b){var s=b==null,r=s?null:b.method
return new A.eo(a,r,s?null:b.receiver)},
bK(a){var s
if(a==null)return new A.iB(a)
if(a instanceof A.da){s=a.a
return A.c2(a,s==null?A.dW(s):s)}if(typeof a!=="object")return a
if("dartException" in a)return A.c2(a,a.dartException)
return A.pB(a)},
c2(a,b){if(t.fz.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
pB(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aT(r,16)&8191)===10)switch(q){case 438:return A.c2(a,A.kW(A.y(s)+" (Error "+q+")",null))
case 445:case 5007:A.y(s)
return A.c2(a,new A.dv())}}if(a instanceof TypeError){p=$.n7()
o=$.n8()
n=$.n9()
m=$.na()
l=$.nd()
k=$.ne()
j=$.nc()
$.nb()
i=$.ng()
h=$.nf()
g=p.aa(s)
if(g!=null)return A.c2(a,A.kW(A.C(s),g))
else{g=o.aa(s)
if(g!=null){g.method="call"
return A.c2(a,A.kW(A.C(s),g))}else if(n.aa(s)!=null||m.aa(s)!=null||l.aa(s)!=null||k.aa(s)!=null||j.aa(s)!=null||m.aa(s)!=null||i.aa(s)!=null||h.aa(s)!=null){A.C(s)
return A.c2(a,new A.dv())}}return A.c2(a,new A.eV(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.dB()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.c2(a,new A.bf(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.dB()
return a},
cy(a){var s
if(a instanceof A.da)return a.b
if(a==null)return new A.dP(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.dP(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
mX(a){if(a==null)return J.aI(a)
if(typeof a=="object")return A.eJ(a)
return J.aI(a)},
pN(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.i(0,a[s],a[r])}return b},
pO(a,b){var s,r=a.length
for(s=0;s<r;++s)b.k(0,a[s])
return b},
pb(a,b,c,d,e,f){t.Z.a(a)
switch(A.a0(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.l(new A.jC("Unsupported number of arguments for wrapped closure"))},
fq(a,b){var s=a.$identity
if(!!s)return s
s=A.pH(a,b)
a.$identity=s
return s},
pH(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.pb)},
nB(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.eO().constructor.prototype):Object.create(new A.cC(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.lB(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.nx(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.lB(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
nx(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.l("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.nr)}throw A.l("Error in functionType of tearoff")},
ny(a,b,c,d){var s=A.ly
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
lB(a,b,c,d){if(c)return A.nA(a,b,d)
return A.ny(b.length,d,a,b)},
nz(a,b,c,d){var s=A.ly,r=A.ns
switch(b?-1:a){case 0:throw A.l(new A.eN("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
nA(a,b,c){var s,r
if($.lw==null)$.lw=A.lv("interceptor")
if($.lx==null)$.lx=A.lv("receiver")
s=b.length
r=A.nz(s,c,a,b)
return r},
li(a){return A.nB(a)},
nr(a,b){return A.dT(v.typeUniverse,A.av(a.a),b)},
ly(a){return a.a},
ns(a){return a.b},
lv(a){var s,r,q,p=new A.cC("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.l(A.d3("Field name "+a+" not found.",null))},
ke(a){return v.getIsolateTag(a)},
q_(a){var s,r,q,p,o,n=A.C($.mP.$1(a)),m=$.ka[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.kl[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=A.v($.mG.$2(a,n))
if(q!=null){m=$.ka[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.kl[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.kr(s)
$.ka[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.kl[n]=s
return s}if(p==="-"){o=A.kr(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.mZ(a,s)
if(p==="*")throw A.l(A.m8(n))
if(v.leafTags[n]===true){o=A.kr(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.mZ(a,s)},
mZ(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.ln(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
kr(a){return J.ln(a,!1,null,!!a.$iaK)},
q1(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.kr(s)
else return J.ln(s,c,null,null)},
pV(){if(!0===$.ll)return
$.ll=!0
A.pW()},
pW(){var s,r,q,p,o,n,m,l
$.ka=Object.create(null)
$.kl=Object.create(null)
A.pU()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.n_.$1(o)
if(n!=null){m=A.q1(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
pU(){var s,r,q,p,o,n,m=B.cP()
m=A.d_(B.cQ,A.d_(B.cR,A.d_(B.aM,A.d_(B.aM,A.d_(B.cS,A.d_(B.cT,A.d_(B.cU(B.aL),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.mP=new A.ki(p)
$.mG=new A.kj(o)
$.n_=new A.kk(n)},
d_(a,b){return a(b)||b},
oJ(a,b){var s,r
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.b(b,s)
if(!J.aU(r,b[s]))return!1}return!0},
pJ(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
nW(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.l(A.b8("Illegal RegExp pattern ("+String(o)+")",a,null))},
pL(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
n0(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
qb(a,b,c){var s=A.qc(a,b,c)
return s},
qc(a,b,c){var s,r,q
if(b===""){if(a==="")return c
s=a.length
for(r=c,q=0;q<s;++q)r=r+a[q]+c
return r.charCodeAt(0)==0?r:r}if(a.indexOf(b,0)<0)return a
if(a.length<500||c.indexOf("$",0)>=0)return a.split(b).join(c)
return a.replace(new RegExp(A.n0(b),"g"),A.pL(c))},
A:function A(a,b){this.a=a
this.b=b},
a:function a(a,b,c){this.a=a
this.b=b
this.c=c},
cW:function cW(a){this.a=a},
aR:function aR(a){this.a=a},
d6:function d6(){},
br:function br(a,b,c){this.a=a
this.b=b
this.$ti=c},
dJ:function dJ(a,b){this.a=a
this.$ti=b},
cs:function cs(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
d7:function d7(){},
c5:function c5(a,b,c){this.a=a
this.b=b
this.$ti=c},
eh:function eh(){},
cd:function cd(a,b){this.a=a
this.$ti=b},
dx:function dx(){},
jk:function jk(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dv:function dv(){},
eo:function eo(a,b,c){this.a=a
this.b=b
this.c=c},
eV:function eV(a){this.a=a},
iB:function iB(a){this.a=a},
da:function da(a,b){this.a=a
this.b=b},
dP:function dP(a){this.a=a
this.b=null},
ax:function ax(){},
e4:function e4(){},
e5:function e5(){},
eQ:function eQ(){},
eO:function eO(){},
cC:function cC(a,b){this.a=a
this.b=b},
eN:function eN(a){this.a=a},
bw:function bw(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ib:function ib(a){this.a=a},
ie:function ie(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
ad:function ad(a,b){this.a=a
this.$ti=b},
az:function az(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
am:function am(a,b){this.a=a
this.$ti=b},
M:function M(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
K:function K(a,b){this.a=a
this.$ti=b},
ag:function ag(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ki:function ki(a){this.a=a},
kj:function kj(a){this.a=a},
kk:function kk(a){this.a=a},
b3:function b3(){},
cU:function cU(){},
cV:function cV(){},
cu:function cu(){},
en:function en(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
jR:function jR(a){this.b=a},
p2(a){return a},
nY(a){return new Int8Array(a)},
nZ(a){return new Uint8Array(a)},
bI(a,b,c){if(a>>>0!==a||a>=c)throw A.l(A.fr(b,a))},
cH:function cH(){},
dt:function dt(){},
ew:function ew(){},
cI:function cI(){},
dr:function dr(){},
ds:function ds(){},
ex:function ex(){},
ey:function ey(){},
ez:function ez(){},
eA:function eA(){},
eB:function eB(){},
eC:function eC(){},
eD:function eD(){},
du:function du(){},
eE:function eE(){},
dK:function dK(){},
dL:function dL(){},
dM:function dM(){},
dN:function dN(){},
l1(a,b){var s=b.c
return s==null?b.c=A.dR(a,"bj",[b.x]):s},
m3(a){var s=a.w
if(s===6||s===7)return A.m3(a.x)
return s===11||s===12},
oc(a){return a.as},
mY(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
Y(a){return A.jX(v.typeUniverse,a,!1)},
pY(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.c1(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
c1(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.c1(a1,s,a3,a4)
if(r===s)return a2
return A.mi(a1,r,!0)
case 7:s=a2.x
r=A.c1(a1,s,a3,a4)
if(r===s)return a2
return A.mh(a1,r,!0)
case 8:q=a2.y
p=A.cZ(a1,q,a3,a4)
if(p===q)return a2
return A.dR(a1,a2.x,p)
case 9:o=a2.x
n=A.c1(a1,o,a3,a4)
m=a2.y
l=A.cZ(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.l8(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.cZ(a1,j,a3,a4)
if(i===j)return a2
return A.mj(a1,k,i)
case 11:h=a2.x
g=A.c1(a1,h,a3,a4)
f=a2.y
e=A.py(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.mg(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.cZ(a1,d,a3,a4)
o=a2.x
n=A.c1(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.l9(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.l(A.e1("Attempted to substitute unexpected RTI kind "+a0))}},
cZ(a,b,c,d){var s,r,q,p,o=b.length,n=A.jY(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.c1(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
pz(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.jY(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.c1(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
py(a,b,c,d){var s,r=b.a,q=A.cZ(a,r,c,d),p=b.b,o=A.cZ(a,p,c,d),n=b.c,m=A.pz(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.f2()
s.a=q
s.b=o
s.c=m
return s},
d(a,b){a[v.arrayRti]=b
return a},
k9(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.pS(s)
return a.$S()}return null},
pX(a,b){var s
if(A.m3(b))if(a instanceof A.ax){s=A.k9(a)
if(s!=null)return s}return A.av(a)},
av(a){if(a instanceof A.I)return A.i(a)
if(Array.isArray(a))return A.q(a)
return A.lb(J.cx(a))},
q(a){var s=a[v.arrayRti],r=t.dG
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.lb(a)},
lb(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.p9(a,s)},
p9(a,b){var s=a instanceof A.ax?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.oT(v.typeUniverse,s.name)
b.$ccache=r
return r},
pS(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.jX(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
pR(a){return A.bJ(A.i(a))},
lk(a){var s=A.k9(a)
return A.bJ(s==null?A.av(a):s)},
lf(a){var s
if(a instanceof A.b3)return A.pM(a.$r,a.aK())
s=a instanceof A.ax?A.k9(a):null
if(s!=null)return s
if(t.aJ.b(a))return J.no(a).a
if(Array.isArray(a))return A.q(a)
return A.av(a)},
bJ(a){var s=a.r
return s==null?a.r=new A.jW(a):s},
pM(a,b){var s,r,q=b,p=q.length
if(p===0)return t.aK
if(0>=p)return A.b(q,0)
s=A.dT(v.typeUniverse,A.lf(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.b(q,r)
s=A.ml(v.typeUniverse,s,A.lf(q[r]))}return A.dT(v.typeUniverse,s,a)},
be(a){return A.bJ(A.jX(v.typeUniverse,a,!1))},
p8(a){var s=this
s.b=A.pw(s)
return s.b(a)},
pw(a){var s,r,q,p,o
if(a===t.K)return A.ph
if(A.cA(a))return A.pl
s=a.w
if(s===6)return A.p6
if(s===1)return A.mz
if(s===7)return A.pc
r=A.pv(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.cA)){a.f="$i"+q
if(q==="o")return A.pf
if(a===t.m)return A.pe
return A.pk}}else if(s===10){p=A.pJ(a.x,a.y)
o=p==null?A.mz:p
return o==null?A.dW(o):o}return A.p4},
pv(a){if(a.w===8){if(a===t.S)return A.mx
if(a===t.i||a===t.H)return A.pg
if(a===t.N)return A.pj
if(a===t.y)return A.lc}return null},
p7(a){var s=this,r=A.p3
if(A.cA(s))r=A.oY
else if(s===t.K)r=A.dW
else if(A.d0(s)){r=A.p5
if(s===t.aV)r=A.mo
else if(s===t.bl)r=A.v
else if(s===t.o9)r=A.X
else if(s===t.jh)r=A.w
else if(s===t.jX)r=A.oW
else if(s===t.mU)r=A.oX}else if(s===t.S)r=A.a0
else if(s===t.N)r=A.C
else if(s===t.y)r=A.oV
else if(s===t.H)r=A.ar
else if(s===t.i)r=A.T
else if(s===t.m)r=A.mp
s.a=r
return s.a(a)},
p4(a){var s=this
if(a==null)return A.d0(s)
return A.mS(v.typeUniverse,A.pX(a,s),s)},
p6(a){if(a==null)return!0
return this.x.b(a)},
pk(a){var s,r=this
if(a==null)return A.d0(r)
s=r.f
if(a instanceof A.I)return!!a[s]
return!!J.cx(a)[s]},
pf(a){var s,r=this
if(a==null)return A.d0(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.I)return!!a[s]
return!!J.cx(a)[s]},
pe(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.I)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
my(a){if(typeof a=="object"){if(a instanceof A.I)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
p3(a){var s=this
if(a==null){if(A.d0(s))return a}else if(s.b(a))return a
throw A.a8(A.mu(a,s),new Error())},
p5(a){var s=this
if(a==null||s.b(a))return a
throw A.a8(A.mu(a,s),new Error())},
mu(a,b){return new A.cX("TypeError: "+A.mb(a,A.aB(b,null)))},
mK(a,b,c,d){if(A.mS(v.typeUniverse,a,b))return a
throw A.a8(A.oL("The type argument '"+A.aB(a,null)+"' is not a subtype of the type variable bound '"+A.aB(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
mb(a,b){return A.eb(a)+": type '"+A.aB(A.lf(a),null)+"' is not a subtype of type '"+b+"'"},
oL(a){return new A.cX("TypeError: "+a)},
b4(a,b){return new A.cX("TypeError: "+A.mb(a,b))},
pc(a){var s=this
return s.x.b(a)||A.l1(v.typeUniverse,s).b(a)},
ph(a){return a!=null},
dW(a){if(a!=null)return a
throw A.a8(A.b4(a,"Object"),new Error())},
pl(a){return!0},
oY(a){return a},
mz(a){return!1},
lc(a){return!0===a||!1===a},
oV(a){if(!0===a)return!0
if(!1===a)return!1
throw A.a8(A.b4(a,"bool"),new Error())},
X(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.a8(A.b4(a,"bool?"),new Error())},
T(a){if(typeof a=="number")return a
throw A.a8(A.b4(a,"double"),new Error())},
oW(a){if(typeof a=="number")return a
if(a==null)return a
throw A.a8(A.b4(a,"double?"),new Error())},
mx(a){return typeof a=="number"&&Math.floor(a)===a},
a0(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.a8(A.b4(a,"int"),new Error())},
mo(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.a8(A.b4(a,"int?"),new Error())},
pg(a){return typeof a=="number"},
ar(a){if(typeof a=="number")return a
throw A.a8(A.b4(a,"num"),new Error())},
w(a){if(typeof a=="number")return a
if(a==null)return a
throw A.a8(A.b4(a,"num?"),new Error())},
pj(a){return typeof a=="string"},
C(a){if(typeof a=="string")return a
throw A.a8(A.b4(a,"String"),new Error())},
v(a){if(typeof a=="string")return a
if(a==null)return a
throw A.a8(A.b4(a,"String?"),new Error())},
mp(a){if(A.my(a))return a
throw A.a8(A.b4(a,"JSObject"),new Error())},
oX(a){if(a==null)return a
if(A.my(a))return a
throw A.a8(A.b4(a,"JSObject?"),new Error())},
mD(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.aB(a[q],b)
return s},
pq(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.mD(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.aB(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
mv(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
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
if(!(j===2||j===3||j===4||j===5||k===p))o+=" extends "+A.aB(k,a4)}o+=">"}else o=""
p=a3.x
i=a3.y
h=i.a
g=h.length
f=i.b
e=f.length
d=i.c
c=d.length
b=A.aB(p,a4)
for(a="",a0="",q=0;q<g;++q,a0=a1)a+=a0+A.aB(h[q],a4)
if(e>0){a+=a0+"["
for(a0="",q=0;q<e;++q,a0=a1)a+=a0+A.aB(f[q],a4)
a+="]"}if(c>0){a+=a0+"{"
for(a0="",q=0;q<c;q+=3,a0=a1){a+=a0
if(d[q+1])a+="required "
a+=A.aB(d[q+2],a4)+" "+d[q]}a+="}"}if(a2!=null){a4.toString
a4.length=a2}return o+"("+a+") => "+b},
aB(a,b){var s,r,q,p,o,n,m,l=a.w
if(l===5)return"erased"
if(l===2)return"dynamic"
if(l===3)return"void"
if(l===1)return"Never"
if(l===4)return"any"
if(l===6){s=a.x
r=A.aB(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(l===7)return"FutureOr<"+A.aB(a.x,b)+">"
if(l===8){p=A.pA(a.x)
o=a.y
return o.length>0?p+("<"+A.mD(o,b)+">"):p}if(l===10)return A.pq(a,b)
if(l===11)return A.mv(a,b,null)
if(l===12)return A.mv(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.b(b,n)
return b[n]}return"?"},
pA(a){var s=A.n2(a)
if(s!=null)return s
return"minified:"+a},
oU(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
oT(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.jX(a,b,!1)
else if(typeof m=="number"){s=m
r=A.dS(a,5,"#")
q=A.jY(s)
for(p=0;p<s;++p)q[p]=r
o=A.dR(a,b,q)
n[b]=o
return o}else return m},
oS(a,b){return A.mm(a.tR,b)},
oR(a,b){return A.mm(a.eT,b)},
jX(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.mk(a,null,b,!1)
r.set(b,s)
return s},
dT(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.mk(a,b,c,!0)
q.set(c,r)
return r},
ml(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.l8(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
mk(a,b,c,d){return A.oH(A.oB(a,b,c,d))},
c_(a,b){b.a=A.p7
b.b=A.p8
return b},
dS(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.bd(null,null)
s.w=b
s.as=c
r=A.c_(a,s)
a.eC.set(c,r)
return r},
mi(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.oP(a,b,r,c)
a.eC.set(r,s)
return s},
oP(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.cA(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.d0(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.bd(null,null)
q.w=6
q.x=b
q.as=c
return A.c_(a,q)},
mh(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.oN(a,b,r,c)
a.eC.set(r,s)
return s},
oN(a,b,c,d){var s,r
if(d){s=b.w
if(A.cA(b)||b===t.K)return b
else if(s===1)return A.dR(a,"bj",[b])
else if(b===t.a||b===t.T)return t.gK}r=new A.bd(null,null)
r.w=7
r.x=b
r.as=c
return A.c_(a,r)},
oQ(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.bd(null,null)
s.w=13
s.x=b
s.as=q
r=A.c_(a,s)
a.eC.set(q,r)
return r},
dQ(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
oM(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
dR(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.dQ(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.bd(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.c_(a,r)
a.eC.set(p,q)
return q},
l8(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.dQ(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.bd(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.c_(a,o)
a.eC.set(q,n)
return n},
mj(a,b,c){var s,r,q="+"+(b+"("+A.dQ(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.bd(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.c_(a,s)
a.eC.set(q,r)
return r},
mg(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.dQ(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.dQ(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.oM(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.bd(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.c_(a,p)
a.eC.set(r,o)
return o},
l9(a,b,c,d){var s,r=b.as+("<"+A.dQ(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.oO(a,b,c,r,d)
a.eC.set(r,s)
return s},
oO(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.jY(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.c1(a,b,r,0)
m=A.cZ(a,c,r,0)
return A.l9(a,n,m,c!==m)}}l=new A.bd(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.c_(a,l)},
oB(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
oH(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.oD(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.md(a,r,l,k,!1)
else if(q===46)r=A.md(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.ct(a.u,a.e,k.pop()))
break
case 94:k.push(A.oQ(a.u,k.pop()))
break
case 35:k.push(A.dS(a.u,5,"#"))
break
case 64:k.push(A.dS(a.u,2,"@"))
break
case 126:k.push(A.dS(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.oF(a,k)
break
case 38:A.oE(a,k)
break
case 63:p=a.u
k.push(A.mi(p,A.ct(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.mh(p,A.ct(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.oC(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.me(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.oI(a.u,a.e,o)
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
return A.ct(a.u,a.e,m)},
oD(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
md(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.oU(s,o.x)[p]
if(n==null)A.bq('No "'+p+'" in "'+A.oc(o)+'"')
d.push(A.dT(s,o,n))}else d.push(p)
return m},
oF(a,b){var s,r=a.u,q=A.mc(a,b),p=b.pop()
if(typeof p=="string")b.push(A.dR(r,p,q))
else{s=A.ct(r,a.e,p)
switch(s.w){case 11:b.push(A.l9(r,s,q,a.n))
break
default:b.push(A.l8(r,s,q))
break}}},
oC(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.mc(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.ct(p,a.e,o)
q=new A.f2()
q.a=s
q.b=n
q.c=m
b.push(A.mg(p,r,q))
return
case-4:b.push(A.mj(p,b.pop(),s))
return
default:throw A.l(A.e1("Unexpected state under `()`: "+A.y(o)))}},
oE(a,b){var s=b.pop()
if(0===s){b.push(A.dS(a.u,1,"0&"))
return}if(1===s){b.push(A.dS(a.u,4,"1&"))
return}throw A.l(A.e1("Unexpected extended operation "+A.y(s)))},
mc(a,b){var s=b.splice(a.p)
A.me(a.u,a.e,s)
a.p=b.pop()
return s},
ct(a,b,c){if(typeof c=="string")return A.dR(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.oG(a,b,c)}else return c},
me(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.ct(a,b,c[s])},
oI(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.ct(a,b,c[s])},
oG(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.l(A.e1("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.l(A.e1("Bad index "+c+" for "+b.q(0)))},
mS(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.a7(a,b,null,c,null)
r.set(c,s)}return s},
a7(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.cA(d))return!0
s=b.w
if(s===4)return!0
if(A.cA(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.a7(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.a7(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.a7(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.a7(a,b.x,c,d,e))return!1
return A.a7(a,A.l1(a,b),c,d,e)}if(s===6)return A.a7(a,p,c,d,e)&&A.a7(a,b.x,c,d,e)
if(q===7){if(A.a7(a,b,c,d.x,e))return!0
return A.a7(a,b,c,A.l1(a,d),e)}if(q===6)return A.a7(a,b,c,p,e)||A.a7(a,b,c,d.x,e)
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
if(!A.a7(a,j,c,i,e)||!A.a7(a,i,e,j,c))return!1}return A.mw(a,b.x,c,d.x,e)}if(q===11){if(b===t.dY)return!0
if(p)return!1
return A.mw(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.pd(a,b,c,d,e)}if(o&&q===10)return A.pi(a,b,c,d,e)
return!1},
mw(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.a7(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.a7(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.a7(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.a7(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.a7(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
pd(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.dT(a,b,r[o])
return A.mn(a,p,null,c,d.y,e)}return A.mn(a,b.y,null,c,d.y,e)},
mn(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.a7(a,b[s],d,e[s],f))return!1
return!0},
pi(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.a7(a,r[s],c,q[s],e))return!1
return!0},
d0(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.cA(a))if(s!==6)r=s===7&&A.d0(a.x)
return r},
cA(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.iD},
mm(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
jY(a){return a>0?new Array(a):v.typeUniverse.sEA},
bd:function bd(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
f2:function f2(){this.c=this.b=this.a=null},
jW:function jW(a){this.a=a},
f1:function f1(){},
cX:function cX(a){this.a=a},
or(){var s,r,q
if(self.scheduleImmediate!=null)return A.pD()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.fq(new A.jx(s),1)).observe(r,{childList:true})
return new A.jw(s,r,q)}else if(self.setImmediate!=null)return A.pE()
return A.pF()},
os(a){self.scheduleImmediate(A.fq(new A.jy(t.M.a(a)),0))},
ot(a){self.setImmediate(A.fq(new A.jz(t.M.a(a)),0))},
ou(a){A.ok(B.cN,t.M.a(a))},
ok(a,b){return A.oK(0,b)},
oK(a,b){var s=new A.jU()
s.cH(a,b)
return s},
mA(a){return new A.eX(new A.ae($.a5,a.j("ae<0>")),a.j("eX<0>"))},
mt(a,b){a.$2(0,null)
b.b=!0
return b.a},
mq(a,b){A.oZ(a,b)},
ms(a,b){var s,r,q=b.$ti
q.j("1/?").a(a)
s=a==null?q.c.a(a):a
if(!b.b)b.a.bK(s)
else{r=b.a
if(q.j("bj<1>").b(s))r.bO(s)
else r.bP(s)}},
mr(a,b){var s=A.bK(a),r=A.cy(a),q=b.b,p=b.a
if(q)p.bc(new A.b5(s,r))
else p.bL(new A.b5(s,r))},
oZ(a,b){var s,r,q=new A.jZ(b),p=new A.k_(b)
if(a instanceof A.ae)a.c9(q,p,t.z)
else{s=t.z
if(a instanceof A.ae)a.cu(q,p,s)
else{r=new A.ae($.a5,t._)
r.a=8
r.c=a
r.c9(q,p,s)}}},
mF(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.a5.cr(new A.k5(s),t.r,t.S,t.z)},
mf(a,b,c){return 0},
kS(a){var s
if(t.fz.b(a)){s=a.gaH()
if(s!=null)return s}return B.cW},
l6(a,b,c){var s,r,q,p,o={},n=o.a=a
for(s=t._;r=n.a,(r&4)!==0;n=a){a=s.a(n.c)
o.a=a}if(n===b){s=A.of()
b.bL(new A.b5(new A.bf(!0,n,null,"Cannot complete a future with itself"),s))
return}q=b.a&1
s=n.a=r|q
if((s&24)===0){p=t.F.a(b.c)
b.a=b.a&1|4
b.c=n
n.c3(p)
return}if(!c)if(b.c==null)n=(s&16)===0||q!==0
else n=!1
else n=!0
if(n){p=b.aR()
b.aJ(o.a)
A.cT(b,p)
return}b.a^=2
A.fo(null,null,b.b,t.M.a(new A.jG(o,b)))},
cT(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d={},c=d.a=a
for(s=t.t,r=t.F;;){q={}
p=c.a
o=(p&16)===0
n=!o
if(b==null){if(n&&(p&1)===0){m=s.a(c.c)
A.le(m.a,m.b)}return}q.a=b
l=b.a
for(c=b;l!=null;c=l,l=k){c.a=null
A.cT(d.a,c)
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
A.le(j.a,j.b)
return}g=$.a5
if(g!==h)$.a5=h
else g=null
c=c.c
if((c&15)===8)new A.jK(q,d,n).$0()
else if(o){if((c&1)!==0)new A.jJ(q,j).$0()}else if((c&2)!==0)new A.jI(d,q).$0()
if(g!=null)$.a5=g
c=q.c
if(c instanceof A.ae){p=q.a.$ti
p=p.j("bj<2>").b(c)||!p.y[1].b(c)}else p=!1
if(p){f=q.a.b
if((c.a&24)!==0){e=r.a(f.c)
f.c=null
b=f.aS(e)
f.a=c.a&30|f.a&1
f.c=c.c
d.a=c
continue}else A.l6(c,f,!0)
return}}f=q.a.b
e=r.a(f.c)
f.c=null
b=f.aS(e)
c=q.b
p=q.c
if(!c){f.$ti.c.a(p)
f.a=8
f.c=p}else{s.a(p)
f.a=f.a&1|16
f.c=p}d.a=f
c=f}},
pr(a,b){var s
if(t.ng.b(a))return b.cr(a,t.z,t.K,t.l)
s=t.mq
if(s.b(a))return s.a(a)
throw A.l(A.e_(a,"onError",u.c))},
pn(){var s,r
for(s=$.cY;s!=null;s=$.cY){$.dY=null
r=s.b
$.cY=r
if(r==null)$.dX=null
s.a.$0()}},
px(){$.ld=!0
try{A.pn()}finally{$.dY=null
$.ld=!1
if($.cY!=null)$.lp().$1(A.mJ())}},
mE(a){var s=new A.eY(a),r=$.dX
if(r==null){$.cY=$.dX=s
if(!$.ld)$.lp().$1(A.mJ())}else $.dX=r.b=s},
pu(a){var s,r,q,p=$.cY
if(p==null){A.mE(a)
$.dY=$.dX
return}s=new A.eY(a)
r=$.dY
if(r==null){s.b=p
$.cY=$.dY=s}else{q=r.b
s.b=q
$.dY=r.b=s
if(q==null)$.dX=s}},
qo(a,b){A.cw(a,"stream",t.K)
return new A.fi(b.j("fi<0>"))},
le(a,b){A.pu(new A.k4(a,b))},
mC(a,b,c,d,e){var s,r=$.a5
if(r===c)return d.$0()
$.a5=c
s=r
try{r=d.$0()
return r}finally{$.a5=s}},
pt(a,b,c,d,e,f,g){var s,r=$.a5
if(r===c)return d.$1(e)
$.a5=c
s=r
try{r=d.$1(e)
return r}finally{$.a5=s}},
ps(a,b,c,d,e,f,g,h,i){var s,r=$.a5
if(r===c)return d.$2(e,f)
$.a5=c
s=r
try{r=d.$2(e,f)
return r}finally{$.a5=s}},
fo(a,b,c,d){t.M.a(d)
if(B.u!==c){d=c.df(d)
d=d}A.mE(d)},
jx:function jx(a){this.a=a},
jw:function jw(a,b,c){this.a=a
this.b=b
this.c=c},
jy:function jy(a){this.a=a},
jz:function jz(a){this.a=a},
jU:function jU(){},
jV:function jV(a,b){this.a=a
this.b=b},
eX:function eX(a,b){this.a=a
this.b=!1
this.$ti=b},
jZ:function jZ(a){this.a=a},
k_:function k_(a){this.a=a},
k5:function k5(a){this.a=a},
cv:function cv(a,b){var _=this
_.a=a
_.e=_.d=_.c=_.b=null
_.$ti=b},
bZ:function bZ(a,b){this.a=a
this.$ti=b},
b5:function b5(a,b){this.a=a
this.b=b},
cr:function cr(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
ae:function ae(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
jD:function jD(a,b){this.a=a
this.b=b},
jH:function jH(a,b){this.a=a
this.b=b},
jG:function jG(a,b){this.a=a
this.b=b},
jF:function jF(a,b){this.a=a
this.b=b},
jE:function jE(a,b){this.a=a
this.b=b},
jK:function jK(a,b,c){this.a=a
this.b=b
this.c=c},
jL:function jL(a,b){this.a=a
this.b=b},
jM:function jM(a){this.a=a},
jJ:function jJ(a,b){this.a=a
this.b=b},
jI:function jI(a,b){this.a=a
this.b=b},
eY:function eY(a){this.a=a
this.b=null},
fi:function fi(a){this.$ti=a},
dU:function dU(){},
fe:function fe(){},
jT:function jT(a,b){this.a=a
this.b=b},
k4:function k4(a,b){this.a=a
this.b=b},
ig(a,b){return new A.bw(a.j("@<0>").v(b).j("bw<1,2>"))},
S(a,b,c){return b.j("@<0>").v(c).j("lO<1,2>").a(A.pN(a,new A.bw(b.j("@<0>").v(c).j("bw<1,2>"))))},
m(a,b){return new A.bw(a.j("@<0>").v(b).j("bw<1,2>"))},
et(a){return new A.bp(a.j("bp<0>"))},
J(a){return new A.bp(a.j("bp<0>"))},
ah(a,b){return b.j("lP<0>").a(A.pO(a,new A.bp(b.j("bp<0>"))))},
l7(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
aq(a,b,c){var s=new A.Q(a,b,c.j("Q<0>"))
s.c=a.e
return s},
nX(a,b,c){var s=A.ig(b,c)
a.X(0,new A.ih(s,b,c))
return s},
V(a,b,c){var s=A.ig(b,c)
s.B(0,a)
return s},
cF(a,b){var s,r,q=A.et(b)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.k)(a),++r)q.k(0,b.a(a[r]))
return q},
dl(a,b){var s=A.et(b)
s.B(0,a)
return s},
kX(a){var s,r
if(A.lm(a))return"{...}"
s=new A.cQ("")
try{r={}
B.a.k($.aS,a)
s.a+="{"
r.a=!0
a.X(0,new A.ik(r,s))
s.a+="}"}finally{if(0>=$.aS.length)return A.b($.aS,-1)
$.aS.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
bp:function bp(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
f8:function f8(a){this.a=a
this.c=this.b=null},
Q:function Q(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
ih:function ih(a,b,c){this.a=a
this.b=b
this.c=c},
F:function F(){},
a2:function a2(){},
ij:function ij(a){this.a=a},
ik:function ik(a,b){this.a=a
this.b=b},
bU:function bU(){},
dO:function dO(){},
pp(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.bK(r)
q=A.b8(String(s),null,null)
throw A.l(q)}q=A.k1(p)
return q},
k1(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.f4(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.k1(a[s])
return a},
oy(a,b,c,d,e,f,g,a0){var s,r,q,p,o,n,m,l,k,j,i=a0>>>2,h=3-(a0&3)
for(s=b.length,r=a.length,q=f.$flags|0,p=c,o=0;p<d;++p){if(!(p<s))return A.b(b,p)
n=b[p]
o|=n
i=(i<<8|n)&16777215;--h
if(h===0){m=g+1
l=i>>>18&63
if(!(l<r))return A.b(a,l)
q&2&&A.a9(f)
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
q&2&&A.a9(f)
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
q&2&&A.a9(f)
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
throw A.l(A.e_(b,"Not a byte value at index "+p+": 0x"+B.c.bC(b[p],16),null))},
ox(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i="Invalid encoding before padding",h="Invalid character",g=B.c.aT(a1,2),f=a1&3,e=$.ni()
for(s=a.length,r=e.length,q=d.$flags|0,p=b,o=0;p<c;++p){if(!(p<s))return A.b(a,p)
n=a.charCodeAt(p)
o|=n
m=n&127
if(!(m<r))return A.b(e,m)
l=e[m]
if(l>=0){g=(g<<6|l)&16777215
f=f+1&3
if(f===0){k=a0+1
q&2&&A.a9(d)
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
if(f===3){if((g&3)!==0)throw A.l(A.b8(i,a,p))
k=a0+1
q&2&&A.a9(d)
s=d.length
if(!(a0<s))return A.b(d,a0)
d[a0]=g>>>10
if(!(k<s))return A.b(d,k)
d[k]=g>>>2}else{if((g&15)!==0)throw A.l(A.b8(i,a,p))
q&2&&A.a9(d)
if(!(a0<d.length))return A.b(d,a0)
d[a0]=g>>>4}j=(3-f)*3
if(n===37)j+=2
return A.ma(a,p+1,c,-j-1)}throw A.l(A.b8(h,a,p))}if(o>=0&&o<=127)return(g<<2|f)>>>0
for(p=b;p<c;++p){if(!(p<s))return A.b(a,p)
if(a.charCodeAt(p)>127)break}throw A.l(A.b8(h,a,p))},
ov(a,b,c,d){var s=A.ow(a,b,c),r=(d&3)+(s-b),q=B.c.aT(r,2)*3,p=r&3
if(p!==0&&s<c)q+=p-1
if(q>0)return new Uint8Array(q)
return $.nh()},
ow(a,b,c){var s,r=a.length,q=c,p=q,o=0
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
ma(a,b,c,d){var s,r,q
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
if(b===c)break}if(b!==c)throw A.l(A.b8("Invalid padding character",a,b))
return-s-1},
lM(a,b,c){return new A.dk(a,b)},
p0(a){return a.n()},
oz(a,b){return new A.jO(a,[],A.pI())},
oA(a,b,c){var s,r=new A.cQ(""),q=A.oz(r,b)
q.b5(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
f4:function f4(a,b){this.a=a
this.b=b
this.c=null},
f5:function f5(a){this.a=a},
d4:function d4(){},
fz:function fz(){},
jB:function jB(a){this.a=0
this.b=a},
fy:function fy(){},
jA:function jA(){this.a=0},
bN:function bN(){},
e7:function e7(){},
dk:function dk(a,b){this.a=a
this.b=b},
eq:function eq(a,b){this.a=a
this.b=b},
ep:function ep(){},
id:function id(a){this.b=a},
ic:function ic(a){this.a=a},
jP:function jP(){},
jQ:function jQ(a,b){this.a=a
this.b=b},
jO:function jO(a,b,c){this.c=a
this.a=b
this.b=c},
fs(a){var s=A.o4(a,null)
if(s!=null)return s
throw A.l(A.b8(a,null,null))},
nL(a,b){a=A.a8(a,new Error())
if(a==null)a=A.dW(a)
a.stack=b.q(0)
throw a},
b9(a,b,c,d){var s,r=c?J.lK(a,d):J.lJ(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
eu(a,b,c){var s,r=A.d([],c.j("n<0>"))
for(s=J.aa(a);s.l();)B.a.k(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
p(a,b){var s,r
if(Array.isArray(a))return A.d(a.slice(0),b.j("n<0>"))
s=A.d([],b.j("n<0>"))
for(r=J.aa(a);r.l();)B.a.k(s,r.gp())
return s},
oh(a){var s
A.cO(0,"start")
s=A.oi(a,0,null)
return s},
oi(a,b,c){var s=a.length
if(b>=s)return""
return A.o5(a,b,s)},
ob(a){return new A.en(a,A.nW(a,!1,!0,!1,!1,""))},
m5(a,b,c){var s=J.aa(b)
if(!s.l())return a
if(c.length===0){do a+=A.y(s.gp())
while(s.l())}else{a+=A.y(s.gp())
while(s.l())a=a+c+A.y(s.gp())}return a},
of(){return A.cy(new Error())},
nC(a,b,c,d,e,f,g,h,i){var s="microsecond",r=A.o6(a,b,c,d,e,f,g,h,i)
if(r==null)return null
if(h>999)A.bq(A.aO(h,0,999,s,null))
if(r<-864e13||r>864e13)A.bq(A.aO(r,-864e13,864e13,"millisecondsSinceEpoch",null))
if(r===864e13&&h!==0)A.bq(A.e_(h,s,"Time including microseconds is outside valid range"))
A.cw(i,"isUtc",t.y)
return new A.bs(r,h,i)},
nE(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.n5().dA(a)
if(c!=null){s=new A.h8()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.fs(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.fs(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.fs(q)
if(4>=r.length)return A.b(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.b(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.b(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.b(r,7)
j=new A.h9().$1(r[7])
i=B.c.bn(j,1000)
q=r.length
if(8>=q)return A.b(r,8)
h=r[8]!=null
if(h){if(9>=q)return A.b(r,9)
g=r[9]
if(g!=null){f=g==="-"?-1:1
if(10>=q)return A.b(r,10)
q=r[10]
q.toString
e=A.fs(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.nC(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.l(A.b8("Time out of range",a,null))
return d}else throw A.l(A.b8("Invalid date format",a,null))},
lF(a){var s,r
try{s=A.nE(a)
return s}catch(r){if(A.bK(r) instanceof A.dc)return null
else throw r}},
lE(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
nD(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
h7(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
bt(a){if(a>=10)return""+a
return"0"+a},
ac(a,b,c){var s,r,q
for(s=a.length,r=0;r<s;++r){q=a[r]
if(q.b===b)return q}throw A.l(A.e_(b,"name","No enum value with that name"))},
eb(a){if(typeof a=="number"||A.lc(a)||a==null)return J.d1(a)
if(typeof a=="string")return JSON.stringify(a)
return A.lY(a)},
nM(a,b){A.cw(a,"error",t.K)
A.cw(b,"stackTrace",t.l)
A.nL(a,b)},
e1(a){return new A.e0(a)},
d3(a,b){return new A.bf(!1,null,b,a)},
e_(a,b,c){return new A.bf(!0,a,b,c)},
nq(a,b,c){return a},
l0(a,b){return new A.dw(null,null,!0,a,b,"Value not in range")},
aO(a,b,c,d,e){return new A.dw(b,c,!0,a,d,"Invalid value")},
m2(a,b,c){if(0>a||a>c)throw A.l(A.aO(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.l(A.aO(b,a,c,"end",null))
return b}return c},
cO(a,b){if(a<0)throw A.l(A.aO(a,0,null,b,null))
return a},
i9(a,b,c,d){return new A.eg(b,!0,a,d,"Index out of range")},
bo(a){return new A.dF(a)},
m8(a){return new A.eT(a)},
l2(a){return new A.dC(a)},
al(a){return new A.e6(a)},
b8(a,b,c){return new A.dc(a,b,c)},
nR(a,b,c){var s,r
if(A.lm(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.d([],t.s)
B.a.k($.aS,a)
try{A.pm(a,s)}finally{if(0>=$.aS.length)return A.b($.aS,-1)
$.aS.pop()}r=A.m5(b,t.e7.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
kU(a,b,c){var s,r
if(A.lm(a))return b+"..."+c
s=new A.cQ(b)
B.a.k($.aS,a)
try{r=s
r.a=A.m5(r.a,a,", ")}finally{if(0>=$.aS.length)return A.b($.aS,-1)
$.aS.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
pm(a,b){var s,r,q,p,o,n,m,l=a.gt(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.l())return
s=A.y(l.gp())
B.a.k(b,s)
k+=s.length+2;++j}if(!l.l()){if(j<=5)return
if(0>=b.length)return A.b(b,-1)
r=b.pop()
if(0>=b.length)return A.b(b,-1)
q=b.pop()}else{p=l.gp();++j
if(!l.l()){if(j<=4){B.a.k(b,A.y(p))
return}r=A.y(p)
if(0>=b.length)return A.b(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.l();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2;--j}B.a.k(b,"...")
return}}q=A.y(p)
r=A.y(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.a.k(b,m)
B.a.k(b,q)
B.a.k(b,r)},
cK(a,b,c,d){var s
if(B.e===c){s=J.aI(a)
b=J.aI(b)
return A.ja(A.bD(A.bD($.fv(),s),b))}if(B.e===d){s=J.aI(a)
b=J.aI(b)
c=J.aI(c)
return A.ja(A.bD(A.bD(A.bD($.fv(),s),b),c))}s=J.aI(a)
b=J.aI(b)
c=J.aI(c)
d=J.aI(d)
d=A.ja(A.bD(A.bD(A.bD(A.bD($.fv(),s),b),c),d))
return d},
o_(a){var s,r,q=$.fv()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.k)(a),++r)q=A.bD(q,J.aI(a[r]))
return A.ja(q)},
bs:function bs(a,b,c){this.a=a
this.b=b
this.c=c},
h8:function h8(){},
h9:function h9(){},
c9:function c9(){},
f0:function f0(){},
O:function O(){},
e0:function e0(a){this.a=a},
bF:function bF(){},
bf:function bf(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dw:function dw(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
eg:function eg(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
dF:function dF(a){this.a=a},
eT:function eT(a){this.a=a},
dC:function dC(a){this.a=a},
e6:function e6(a){this.a=a},
eG:function eG(){},
dB:function dB(){},
jC:function jC(a){this.a=a},
dc:function dc(a,b,c){this.a=a
this.b=b
this.c=c},
j:function j(){},
ai:function ai(a,b,c){this.a=a
this.b=b
this.$ti=c},
an:function an(){},
I:function I(){},
fj:function fj(){},
cQ:function cQ(a){this.a=a},
i7:function i7(a){this.a=a},
i8:function i8(a){this.a=a},
po(){var s=new A.ae($.a5,t.cU)
s.bK(null)
return s},
kt(a,b){var s=null
return A.q7(a,b)},
q7(a0,a1){var s=0,r=A.mA(t.r),q=1,p=[],o,n,m,l,k,j,i,h,g,f,e,d,c,b,a
var $async$kt=A.mF(function(a2,a3){if(a2===1){p.push(a3)
s=q}for(;;)switch(s){case 0:b=null
q=3
g=t.P.a(a0.h(0,"project"))
f=A.v(a0.h(0,"lang"))
if(f==null)f="en"
e=A.X(a0.h(0,"sizeZones"))
d=A.X(a0.h(0,"sizeMain"))
o=new A.hc(g,f,e!==!1,d!==!1)
n=A.o7(o.a)
g=o.b
m=new A.i7(B.a.A(B.dE,g)?g:"en")
l=A.nG(n,new A.ku(m))
g=o.c
f=o.d
e=b
if(e==null)e=A.pK()
s=6
return A.mq(l.aY(new A.kv(a1),f,g,e),$async$kt)
case 6:k=a3
j=A.m(t.N,t.z)
J.kQ(j,"type","done")
J.lr(j,new A.hd(k,n.e,n.r).n())
a1.$1(j)
q=1
s=5
break
case 3:q=2
a=p.pop()
i=A.bK(a)
h=A.cy(a)
a1.$1(A.S(["type","error","message",A.y(i),"stack",A.y(h)],t.N,t.z))
s=5
break
case 2:s=1
break
case 5:return A.ms(null,r)
case 1:return A.mr(p.at(-1),r)}})
return A.mt($async$kt,r)},
hc:function hc(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
hd:function hd(a,b,c){this.a=a
this.b=b
this.c=c},
he:function he(){},
ku:function ku(a){this.a=a},
kv:function kv(a){this.a=a},
nG(a,b){var s=Date.now(),r=t.N,q=A.d([],t.lT),p=A.d([],t.s),o=A.d([],t.o6),n=A.d([],t.p4),m=A.d([],t.cu),l=A.kZ(a).bq()
return new A.e9(a,b,l,new A.e8(new A.bs(s,0,!1),A.m(r,t.kV),A.m(r,t.oY),q,p,o,n,m,A.J(r)),A.m(r,r),A.m(r,t.x))},
bg:function bg(a,b){this.a=a
this.b=b},
c7:function c7(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
e9:function e9(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
hr:function hr(){},
hy:function hy(){},
hK:function hK(){},
hJ:function hJ(){},
hL:function hL(a,b,c){this.a=a
this.b=b
this.c=c},
hl:function hl(a){this.a=a},
hs:function hs(){},
hx:function hx(a){this.a=a},
hw:function hw(){},
hz:function hz(a){this.a=a},
hm:function hm(a){this.a=a},
hn:function hn(){},
ho:function ho(a){this.a=a},
hp:function hp(){},
hq:function hq(a){this.a=a},
hI:function hI(a){this.a=a},
hN:function hN(){},
hO:function hO(a,b,c){this.a=a
this.b=b
this.c=c},
hv:function hv(a){this.a=a},
ht:function ht(a,b,c,d,e,f,g,h,i,j){var _=this
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
hu:function hu(){},
hV:function hV(){},
hU:function hU(a,b,c){this.a=a
this.b=b
this.c=c},
hW:function hW(a){this.a=a},
hX:function hX(a){this.a=a},
hY:function hY(){},
hZ:function hZ(){},
hC:function hC(a,b,c){this.a=a
this.b=b
this.c=c},
hD:function hD(a,b){this.a=a
this.b=b},
hA:function hA(a){this.a=a},
hB:function hB(){},
hE:function hE(a,b,c){this.a=a
this.b=b
this.c=c},
hF:function hF(a,b){this.a=a
this.b=b},
hG:function hG(a,b){this.a=a
this.b=b},
hH:function hH(a){this.a=a},
hM:function hM(a,b){this.a=a
this.b=b},
hT:function hT(a){this.a=a},
hP:function hP(a){this.a=a},
hQ:function hQ(){},
hR:function hR(){},
hS:function hS(){},
mO(a,b,c,d){var s,r=new A.kd()
if(c>0&&Math.abs(c-b)>0.5)s=A.y(r.$1(b))+" \xd7 "+A.y(r.$1(c))+" mm"
else s=b>0?A.y(r.$1(b))+" mm":""
return B.k.dY(A.y(d.$1("fit."+a.b))+" "+s)},
q8(f5,f6,f7,f8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7=null,e8=f5.c,e9=t.N,f0=A.m(e9,t.kh),f1=new A.kG(f0),f2=new A.kI(e8,f7),f3=new A.kF(),f4=A.m(e9,t.h)
for(s=f5.e,r=s.length,q=0;p=s.length,q<p;s.length===r||(0,A.k)(s),++q){o=s[q]
f4.i(0,o.a,o)}r=A.J(e9)
for(q=0;q<s.length;s.length===p||(0,A.k)(s),++q){o=s[q]
if(o instanceof A.aj||o instanceof A.aA)r.k(0,o.a)}for(p=f6.a,n=A.i(p).j("M<2>"),m=new A.M(p,p.r,p.e,n),l=t.n,k=t.C;m.l();){j=m.d
i=j.w
h=A.q(i)
g=h.j("u(1)")
h=h.j("B<1>")
f=h.j("j.E")
e=A.p(new A.B(i,g.a(new A.kx(f2)),h),f)
d=A.q(e)
c=d.j("u(1)")
d=d.j("B<1>")
b=d.j("j.E")
a=A.p(new A.B(e,c.a(new A.ky(r)),d),b)
a0=A.p(new A.B(e,c.a(new A.kz(r)),d),b)
for(d=j.r,c=A.i(d),b=new A.Q(d,d.r,c.j("Q<1>")),b.c=d.e,c=c.c,a1=e7,a2=a1,a3=a2,a4=a3;b.l();){d=b.d
o=f4.h(0,d==null?c.a(d):d)
if(o instanceof A.b6){a4=o
continue}if(o instanceof A.aW||o instanceof A.bm){a3=o
continue}if(o instanceof A.aH){a2=o
continue}if(o instanceof A.aX){a1=o
continue}continue}a5=A.p(new A.B(i,g.a(new A.kA()),h),f)
i=a5.length
if(i!==0)h=a4!=null||a3!=null
else h=!1
if(h)for(h=a3 instanceof A.aW,g=a4!=null,f=j.a,d=A.q(a),c=d.j("e(1)"),d=d.j("r<1,e>"),q=0;q<a5.length;a5.length===i||(0,A.k)(a5),++q){if(a5[q].b!==f)continue
if(g){b=e8.a2(a4.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}else a6=0
if(h){b=e8.a2(a3.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}if(a.length!==0)a7=new A.r(a,c.a(f2),d).L(0,B.q)
else a7=a0.length!==0?f2.$1(B.a.gu(a0)):0
if(a6<=0)a6=a7
b=a6>0
if(b)f1.$3$qty(B.af,a6,2)
if(a7>0&&b&&Math.abs(a7-a6)>0.5)f1.$4$qty$size2(B.v,Math.max(a7,a6),2,Math.min(a7,a6))}if(a.length===0)continue
i=A.q(a)
h=i.j("r<1,e>")
a8=A.p(new A.r(a,i.j("e(1)").a(f2),h),h.j("t.E"))
a9=B.a.L(a8,B.q)
b0=a.length
b1=a4!=null||a3!=null||a2!=null||a1!=null
if(b0===1){if(!b1&&a0.length===0&&a5.length===0)f1.$2(B.I,B.a.gu(a8))
if(a1!=null){b2=e8.a0(a1.f)
if(b2!=null)f1.$2(B.m,b2.w)}continue}if(b0===2){if(0>=b0)return A.b(a,0)
b3=a[0]
if(1>=b0)return A.b(a,1)
b4=a[1]
j=j.a
b5=f3.$2(b3,j)
b6=f3.$2(b4,j)
j=b5.a
i=b5.b
b7=Math.acos(B.b.a_(-j*b6.a+-i*b6.b,-1,1))*180/3.141592653589793
b8=f2.$1(b3)
b9=f2.$1(b4)
c0=Math.abs(b8-b9)>0.5
if(b7>60)f1.$2(B.ac,a9)
else if(b7>15)f1.$2(B.ad,a9)
else if(b3.f!==b4.f&&!c0&&a5.length===0)f1.$2(B.Q,a9)
if(c0)f1.$3$size2(B.v,Math.max(b8,b9),Math.min(b8,b9))
if(a1!=null){b2=e8.a0(a1.f)
if(b2!=null){j=b2.w
f1.$3$size2(B.H,a9,j>0?Math.min(j,a9):0)
f1.$2(B.m,j)}}continue}if(b0===3){for(j=j.a,c1=0,c2=1/0,c3=0;c3<3;++c3){i=A.d([],k)
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
j.push(f2.$1(a[c3]))}c6=B.a.L(j,B.q)
if(!(c1>=0&&c1<a.length))return A.b(a,c1)
c7=f2.$1(a[c1])
i=Math.max(c6,c7)
f1.$3$size2(B.H,i,c7<c6-0.5?c7:0)
i=j.length
if(0>=i)return A.b(j,0)
h=j[0]
if(1>=i)return A.b(j,1)
if(Math.abs(h-j[1])>0.5)f1.$3$size2(B.v,B.a.L(j,B.q),B.a.L(j,B.G))
if(c7>c6+0.5)f1.$3$size2(B.v,c7,c6)
continue}f1.$2(B.ae,a9)
for(j=a8.length,i=a9-0.5,q=0;q<a8.length;a8.length===j||(0,A.k)(a8),++q){b2=a8[q]
if(b2<i)f1.$3$size2(B.v,a9,b2)}}c8=A.m(e9,t.cr)
for(f4=new A.M(p,p.r,p.e,n);f4.l();){p=f4.d
n=p.b
c8.i(0,B.b.ae(n.a,3)+"|"+B.b.ae(n.b,3)+"|"+p.d.b,p)}c9=new A.kH(c8)
d0=new A.kD(r)
for(f4=s.length,r=f6.z,p=f5.b.k4,n=p>0,m=f6.b,l=A.q(m),k=l.j("u(1)"),l=l.j("B<1>"),j=l.j("j.E"),q=0;q<s.length;s.length===f4||(0,A.k)(s),++q){o=s[q]
if(r.A(0,o.a))continue
A:{i={}
i.a=null
h=o instanceof A.aj
if(h)i.a=o
if(h){d1=new A.B(m,k.a(new A.kB(i)),l)
if(!d1.gt(0).l())break A
d2=d1.gt(0)
if(!d2.l())A.bq(A.at())
h=d2.gp().x
h=e8.N(h==null?i.a.e:h)
d3=h==null?e7:h.e
if(d3==null)d3=16
d4=d0.$2(c9.$2(J.bM(i.a.d),B.f),i.a.a)
d5=d0.$2(c9.$2(J.kR(i.a.d),B.f),i.a.a)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.I,d3)
if(!d5)f1.$2(B.I,d3)
a1=e8.a0(i.a.r)
if(a1!=null&&i.a.gb3()>0)f1.$3$qty(B.m,a1.w,i.a.gb3())
break A}i=o instanceof A.aA
d6=i?o:e7
if(i){d7=e8.ad(d6.e)
d3=d7==null?e7:d7.e
if(d3==null)d3=16
i=d6.d
h=J.a1(i)
g=c9.$2(h.gu(i),B.f)
f=d6.a
d4=d0.$2(g,f)
d5=d0.$2(c9.$2(h.gM(i),B.f),f)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.J,d3)
if(!d5)f1.$2(B.J,d3)
break A}i={}
i.a=null
h=o instanceof A.aE
if(h)i.a=o
if(h){if(n){d1=A.p(new A.B(m,k.a(new A.kC(i)),l),j)
if(d1.length===0)break A
h=f7.$1(B.a.gu(d1))
d3=h==null?e7:h.e
if(d3==null)d3=0
d8=B.b.J(A.aT(i.a.d)/p)
if(d3>0&&d8>0)f1.$3$qty(B.Q,d3,d8)}break A}break A}}d9=A.m(e9,t.q)
e0=A.d([],t.e0)
e1=new A.kw()
for(e9=new A.M(f0,f0.r,f0.e,f0.$ti.j("M<2>"));e9.l();){f4=e9.d
d8=f4.a
e2=f4.b
f4=d8.a
s=d8.b
r=d8.c
e3=e8.dz(f4,s,r)
if(e3==null){B.a.k(e0,d8)
e4=A.mO(f4,s,r,f8)+" *"
e5="generic|"+e4
e6=d9.h(0,e5)
if(e6!=null)e6.d+=e2
else d9.i(0,e5,new A.ak(e1.$1(f4),e4,"un",e2,0,e7,"",""))
continue}s=e3.a
e6=d9.h(0,s)
if(e6!=null)e6.d+=e2
else d9.i(0,s,new A.ak(e1.$1(f4),e3.b,"un",e2,e3.w,s,e3.d,e3.c))}for(e9=d9.$ti,f4=new A.M(d9,d9.r,d9.e,e9.j("M<2>"));f4.l();){s=f4.d
s.d=Math.ceil(s.d)}e9=e9.j("am<2>")
e9=A.p(new A.am(d9,e9),e9.j("j.E"))
return new A.i4(e9,e0)},
db:function db(a,b,c){this.a=a
this.b=b
this.c=c},
i4:function i4(a,b){this.a=a
this.b=b},
kd:function kd(){},
kG:function kG(a){this.a=a},
kI:function kI(a,b){this.a=a
this.b=b},
kF:function kF(){},
kx:function kx(a){this.a=a},
ky:function ky(a){this.a=a},
kz:function kz(a){this.a=a},
kA:function kA(){},
kH:function kH(a){this.a=a},
kD:function kD(a){this.a=a},
kE:function kE(a,b){this.a=a
this.b=b},
kB:function kB(a){this.a=a},
kC:function kC(a){this.a=a},
kw:function kw(){},
q9(c2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7={},b8=c2.b,b9=b8.length,c0=c2.c,c1=c0.length
if(b9===0)return new A.cG(B.L,B.bd,0,0)
s=A.d([],t.ot)
r=A.d([],t.n)
for(q=c0.length,p=0,o=0,n=0;n<c0.length;c0.length===q||(0,A.k)(c0),++n){m=c0[n]
l=m.b
k=m.c
if(k<0){k=-k
switch(l.a){case 0:j=B.bh
break
case 2:j=B.U
break
case 1:j=B.ai
break
default:j=null}l=j}B.a.k(s,l)
B.a.k(r,k)
if(l!==B.ai)++p
if(l!==B.U)++o}i=b9+p
h=i+o
g=h+1
f=J.ek(c1,t.kI)
for(e=0;e<c1;++e)f[e]=new Float64Array(g)
q=t.S
d=A.b9(c1,-1,!1,q)
c=A.d([],t.X)
for(b=i,a=b9,a0=0;a0<c1;++a0){if(!(a0<c0.length))return A.b(c0,a0)
m=c0[a0]
a1=m.c<0?-1:1
if(!(a0<f.length))return A.b(f,a0)
a2=f[a0]
m.a.X(0,new A.kJ(b9,a2,a1))
if(!(a0<r.length))return A.b(r,a0)
j=r[a0]
a2.$flags&2&&A.a9(a2)
a3=a2.length
if(!(h<a3))return A.b(a2,h)
a2[h]=j
if(!(a0<s.length))return A.b(s,a0)
switch(s[a0].a){case 0:if(!(a<a3))return A.b(a2,a)
a2[a]=1
a4=a+1
B.a.i(d,a0,a)
a=a4
break
case 2:if(!(a<a3))return A.b(a2,a)
a2[a]=-1;++a
if(!(b<a3))return A.b(a2,b)
a2[b]=1
B.a.i(d,a0,b)
a5=b+1
B.a.k(c,b)
b=a5
break
case 1:if(!(b<a3))return A.b(a2,b)
a2[b]=1
B.a.i(d,a0,b)
a5=b+1
B.a.k(c,b)
b=a5
break}}b7.a=0
a6=new A.kK(f,g,c1,d)
a7=new A.kM(b7,new A.kL(g,h,c1,d,f),50*(c1+h)+1000,1e-9,h,c1,f,d,a6)
c0=c.length
if(c0!==0){a8=new Float64Array(g)
for(n=0;n<c0;++n){a9=c[n]
if(!(a9<g))return A.b(a8,a9)
a8[a9]=1}b0=a7.$2(a8,B.wL)
if(b0===B.bi)return new A.cG(b0,A.b9(b9,0,!1,t.i),0,b7.a)
for(b1=0,a0=0;a0<c1;++a0)if(B.a.A(c,d[a0])){if(!(a0<f.length))return A.b(f,a0)
c0=f[a0]
if(!(h<c0.length))return A.b(c0,h)
b1+=c0[h]}if(b1>0.000001)return new A.cG(B.dG,A.b9(b9,0,!1,t.i),0,b7.a)
for(a0=0;a0<c1;++a0){if(!B.a.A(c,d[a0]))continue
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
b4[b3]=j}b0=a7.$2(b4,A.cF(c,q))
b5=A.b9(b9,0,!1,t.i)
for(a0=0;a0<c1;++a0){c0=d[a0]
if(c0<b9){if(!(a0<f.length))return A.b(f,a0)
q=f[a0]
if(!(h<q.length))return A.b(q,h)
B.a.i(b5,c0,q[h])}}for(c0=b8.length,b6=0,b3=0;b3<b9;++b3){if(!(b3<c0))return A.b(b8,b3)
b6+=b8[b3]*b5[b3]}b8=b0===B.L?B.L:b0
return new A.cG(b8,b5,b6,b7.a)},
cj:function cj(a,b){this.a=a
this.b=b},
ci:function ci(a,b,c){this.a=a
this.b=b
this.c=c},
ii:function ii(a,b,c){this.b=a
this.c=b
this.d=c},
cG:function cG(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bx:function bx(a,b){this.a=a
this.b=b},
kJ:function kJ(a,b,c){this.a=a
this.b=b
this.c=c},
kL:function kL(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
kK:function kK(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kM:function kM(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
mT(b7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=t.N,b2=A.m(b1,t.dV),b3=t.n,b4=A.d([],b3),b5=A.d([],t.cH),b6=A.d([],t.s)
for(s=b7.a,r=s.length,q=b7.w,p=b7.r,o=t.S,n=b7.c,m=b7.b,l=0;l<s.length;s.length===r||(0,A.k)(s),++l){k=s[l]
j=m.h(0,k)
if(j==null)j=B.bg
i=n.h(0,k)
if(i==null)i=0
h=A.m(b1,o)
for(g=j.length,f=k+":",e=0;e<j.length;j.length===g||(0,A.k)(j),++e){d=j[e]
c=q?p:1
b=d.a
B.a.k(b4,d.Q*i*c)
B.a.k(b6,f+b)
h.i(0,b,b4.length-1)}b2.i(0,k,h)}a=A.m(o,o)
for(r=b7.e,p=t.i,n=t.jq,a0=0;a0<r.length;++a0){a1=r[a0]
if(a1.b!=null)continue
a2=a1.a
a2=a2>0?a2:0.001
B.a.k(b4,q?a2:Math.max(a2,0.001))
B.a.k(b6,"H"+a1.d)
a.i(0,a0,b4.length-1)
g=a1.c
if(g!=null&&g>0){f=a.h(0,a0)
f.toString
B.a.k(b5,new A.ci(n.a(A.S([f,1],o,p)),B.U,g))}}for(q=s.length,l=0;l<s.length;s.length===q||(0,A.k)(s),++l){h=b2.h(0,s[l])
if(h.a===0)continue
g=A.m(o,p)
for(f=new A.M(h,h.r,h.e,A.i(h).j("M<2>"));f.l();)g.i(0,f.d,1)
B.a.k(b5,new A.ci(n.a(g),B.ai,1))}for(q=b7.f,g=q.length,l=0;l<q.length;q.length===g||(0,A.k)(q),++l){a3=q[l]
a4=A.m(o,p)
f=a3.a
if(!(f<r.length))return A.b(r,f)
c=r[f].b
if(c!=null)a5=0+c
else{f=a.h(0,f)
f.toString
a4.i(0,f,1)
a5=0}a3.b.X(0,new A.kn(b2,a4))
if(a4.a===0)continue
f=a3.d
if(f!=null){c=A.ig(o,p)
c.B(0,a4)
B.a.k(b5,new A.ci(n.a(c),B.bh,f+a3.c-a5))}f=a3.e
if(f!=null&&isFinite(f)){c=A.ig(o,p)
c.B(0,a4)
B.a.k(b5,new A.ci(n.a(c),B.U,f+a3.c-a5))}}if(b4.length===0){b1=A.d([],b3)
for(b3=r.length,l=0;l<r.length;r.length===b3||(0,A.k)(r),++l){b4=r[l].b
b1.push(b4==null?0:b4)}return new A.dm(!0,B.bj)}a6=A.q9(new A.ii(b4,b5,b6))
if(a6.a!==B.L)return new A.dm(!1,B.bj)
a7=A.m(b1,t.x)
for(b1=s.length,b4=b7.d,b5=a6.b,b6=b5.length,q=t.an,l=0;l<s.length;s.length===b1||(0,A.k)(s),++l){k=s[l]
p=b2.h(0,k)
p.toString
j=m.h(0,k)
if(j==null)j=B.bg
if(p.a===0)continue
a8=A.d([],q)
for(o=j.length,e=0;e<j.length;j.length===o||(0,A.k)(j),++e){d=j[e]
n=p.h(0,d.a)
n.toString
if(!(n>=0&&n<b6))return A.b(b5,n)
a9=b5[n]
if(a9>0.02)B.a.k(a8,new A.A(d,a9))}if(a8.length===0)B.a.k(a8,new A.A(B.a.gM(j),1))
B.a.am(a8,new A.ko())
p=b4.h(0,k)
a7.i(0,k,A.q6(a8,p==null?1:p))}b0=A.d([],b3)
for(a0=0;a0<r.length;++a0){b1=r[a0].b
if(b1==null){b1=a.h(0,a0)
b1.toString
if(!(b1>=0&&b1<b6))return A.b(b5,b1)
b1=b5[b1]}B.a.k(b0,b1)}return new A.dm(!0,a7)},
q6(a,b){var s,r,q,p,o,n,m=Math.max(1,b)
if(a.length<=m)return A.mB(a)
s=A.q(a).c
r=A.bW(a,0,A.cw(m,"count",t.S),s).cv(0)
for(s=A.bW(a,m,null,s),q=s.$ti,s=new A.aL(s,s.gm(0),q.j("aL<t.E>")),q=q.j("t.E"),p=0;s.l();){o=s.d
p+=(o==null?q.a(o):o).b}n=B.a.gM(r)
B.a.i(r,r.length-1,new A.A(n.a,n.b+p))
return A.mB(r)},
mB(a){var s,r,q,p,o=B.a.W(a,0,new A.k2(),t.i)
if(o<=0)return a
s=A.d([],t.an)
for(r=a.length,q=0;q<a.length;a.length===r||(0,A.k)(a),++q){p=a[q]
s.push(new A.A(p.a,p.b/o))}return s},
dp:function dp(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dn:function dn(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
ev:function ev(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
dm:function dm(a,b){this.a=a
this.b=b},
kn:function kn(a,b){this.a=a
this.b=b},
km:function km(a,b){this.a=a
this.b=b},
ko:function ko(){},
k2:function k2(){},
kT(a,b,c,d){return new A.aV(b,c,a,d,A.d([],t.hz),A.J(t.N),A.d([],t.I))},
lI(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return new A.G(h,g,s,i,n,f,o,j,l,r,c,a0,k,d,p,a1,m,q,a,b,e)},
kZ(a){var s=t.N,r=t.Q
return new A.il(a,new A.iz(A.m(s,t.cr),A.d([],t.I),A.m(s,t.kM),A.m(s,s),A.m(s,s),A.m(s,r),A.m(s,r),A.J(s),A.J(s),A.d([],t.s),A.J(s)),A.m(t.S,t.g2))},
bQ:function bQ(a,b){this.a=a
this.b=b},
b7:function b7(a,b,c,d,e,f,g,h,i,j){var _=this
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
aV:function aV(a,b,c,d,e,f,g){var _=this
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
G:function G(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
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
iz:function iz(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
il:function il(a,b,c){var _=this
_.a=a
_.d=_.c=_.b=$
_.e=b
_.f=c
_.r=0},
io:function io(){},
ip:function ip(){},
iv:function iv(){},
ix:function ix(){},
iw:function iw(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
iq:function iq(a,b,c){this.a=a
this.b=b
this.c=c},
ir:function ir(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
is:function is(a){this.a=a},
it:function it(){},
iu:function iu(a){this.a=a},
iy:function iy(a){this.a=a},
im:function im(){},
la(a,b){var s=a.f/1000
if(b<=0||s<=0)return 0
switch(a.x.a){case 0:return A.mR(a.r,s,b,1)
case 1:return A.mM(s,b,a.y,1,a.w/1000)}},
kb(a,b){var s,r=a.gbE(),q=a.c+a.ax
if(r<=0||q<=0)return 0
s=B.b.a_(b/q,0,1)
return a.a===B.C?r*(1-s*s):r*(1-s)},
kc(a,b){var s,r,q,p,o,n,m
if(b<=0)return 0
s=Math.max(4,200)
r=b/s
for(q=a.as,p=0,o=0;o<s;){n=o*r;++o
m=o*r
p+=(A.la(a,A.kb(a,n)+q)+4*A.la(a,A.kb(a,(n+m)/2)+q)+A.la(a,A.kb(a,m)+q))/6*r}return p},
pC(c9,d0,d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8=A.d([],t.s),b9=d0==null?new A.k6():d0,c0=c9.gbE(),c1=c9.as,c2=c0+c1,c3=c9.c,c4=A.kc(c9,c3),c5=b9.$1(c3),c6=c9.Q,c7=c1>0?c9.at:0,c8=Math.max(c6,c7)
c7=c9.z
s=c9.cx
r=c8+c4+c5+c7+s
q=A.d([],t.i5)
p=c9.gcw()
o=A.d([0],t.n)
for(n=c9.e,m=1;m<=p;++m)o.push(m*n)
if(c3-c9.gcw()*n>0.000001)o.push(c3)
for(l=o.length,k=0;j=o.length,k<j;o.length===l||(0,A.k)(o),++k){i=o[k]
j=A.kc(c9,i)
h=b9.$1(i)
if(typeof h!=="number")return A.cz(h)
g=c6+j+h+c7+s
if(g>r)r=g}for(l=r-c7-s,f=0,k=0;k<o.length;o.length===j||(0,A.k)(o),++k,f=d){i=o[k]
h=A.kc(c9,i)
e=b9.$1(i)
if(typeof e!=="number")return A.cz(e)
d=f+1
B.a.k(q,new A.cl(f,i,A.kb(c9,i)+c1,l-h-e,b9.$1(i)))}c=c9.f/1000
b=c>0?A.ft(c,c2):0
if(b>c9.dx+0.000001)B.a.k(b8,"velocity_exceeded:"+d1)
a=c0*3600
o=c9.a
j=o===B.C
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
a9=Math.max(1,B.b.a1(a8/Math.max(e,0.1)))
if(h)b0=0
else b0=j?c0*(a7*a7-a5*a5)/a4:c0*a8/a0
b1=(a5+a7)/2
a8=A.kc(c9,b1)
b2=b9.$1(b1)
if(typeof b2!=="number")return A.cz(b2)
b3=l-a8-b2
b4=b0/a9
a8=d3.length
b5=""
if(a8!==0&&b4>0)for(b6=1/0,k=0;k<d3.length;d3.length===a8||(0,A.k)(d3),++k){b2=d3[k]
b7=b2.a
c=Math.abs(b2.b.a7(Math.max(b3,0.1))-b4)
if(c<b6){b6=c
b5=b7}}++m
B.a.k(a3,new A.bz(m,a5,a7,a9,b4,b3,b5))}}return new A.cL(d1,a3,d2,o,c2,c1,r,c4,c5,c8,c7,s,p,q,c9.gci(),c9.ay,c9.ch,a1,a2,b,b8)},
pT(a,b,c,d){return new A.kh(A.m(t.S,t.i),a,72,c,d,b,d.$1(b))},
ck:function ck(a,b){this.a=a
this.b=b},
iM:function iM(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2){var _=this
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
cl:function cl(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
bz:function bz(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cL:function cL(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
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
iJ:function iJ(){},
iK:function iK(){},
iL:function iL(){},
k6:function k6(){},
kh:function kh(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
l5(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){return new A.cS(a0,a4,d,q,f,a1,p,j,i,b,a,k,r,o,l,e,a3,s,a2,g,n,c,m,h)},
bb:function bb(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
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
au:function au(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
bO:function bO(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cS:function cS(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){var _=this
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
js:function js(){},
jr:function jr(){},
jt:function jt(){},
ju:function ju(){},
jv:function jv(){},
cn:function cn(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
aQ:function aQ(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b2:function b2(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
j6:function j6(){},
j7:function j7(){},
j8:function j8(){},
j9:function j9(){},
ak:function ak(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cb:function cb(a,b,c,d,e,f,g,h,i,j){var _=this
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
bC:function bC(a,b,c,d,e,f,g,h,i,j){var _=this
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
e8:function e8(a,b,c,d,e,f,g,h,i){var _=this
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
_.as=_.Q=_.z=0},
hf:function hf(){},
hg:function hg(){},
hh:function hh(){},
hi:function hi(){},
hj:function hj(){},
hk:function hk(){},
lH(a){var s,r=A.ar(a.h(0,"k")),q=A.ar(a.h(0,"x")),p=A.w(a.h(0,"ra"))
if(p==null)p=null
if(p==null)p=0
s=A.w(a.h(0,"rb"))
if(s==null)s=null
return new A.bP(r,q,p,s==null?0:s)},
mQ(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(a<=0||b<=0||c<=0)return 0
s=A.d([],t.n)
for(r=0;r<24;++r)for(q=(r+0.5)/24*b,p=0;p<24;++p){o=(p+0.5)/24*c
for(n=0,m=-2;m<=3;++m)for(l=m*b,k=-2;k<=3;++k){j=q-l
i=o-k*c
h=Math.sqrt(j*j+i*i)
if(h<a)n+=1-h/a}B.a.k(s,n)}g=B.a.L(s,new A.kf())/s.length
if(g<=0)return 0
return 100*(1-B.a.W(s,0,new A.kg(g),t.i)/s.length/g)},
bP:function bP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kf:function kf(){},
kg:function kg(a){this.a=a},
mR(a,b,c,d){var s
if(c===0||d===0)return 0
s=10.67*d*Math.pow(Math.abs(c),1.852)/(Math.pow(a,1.852)*Math.pow(b,4.871))
return c<0?-s:s},
ft(a,b){return b/(3.141592653589793*a*a/4)},
mL(a,b){var s,r,q,p,o,n
if(b<=0)return 0
if(b<2000)return 64/b
if(b<4000){s=a/3.7+5.74/Math.pow(4000,0.9)
r=-0.8685889638065035*Math.log(s)
q=Math.pow(r,-2)
p=q*(2-0.00514215/(s*r))
o=b/2000
return 7*q-p+o*(0.128-17*q+2.5*p+o*(-0.128+13*q-2*p+o*(0.032-3*q+0.5*p)))}n=Math.log(a/3.7+5.74/Math.pow(b,0.9))/2.302585092994046
return 0.25/(n*n)},
mM(a,b,c,d,e){var s,r
if(b===0||d===0)return 0
s=A.ft(a,Math.abs(b))
r=A.mL(e/a,s*a/c)*(d/a)*s*s/19.6133
return b<0?-r:r},
mN(a,b,c,d,e,f,g){switch(f.a){case 0:return A.mR(a,b,c,e)
case 1:return A.mM(b,c,d,e,g)}},
cc:function cc(a,b){this.a=a
this.b=b},
mW(a,b,c){var s=A.ft(a,Math.abs(b)),r=c*s*s/19.6133
return b<0?-r:r},
q4(a,b){var s=3.141592653589793*a*a/4
return b/(19.6133*s*s)},
bh:function bh(a,b,c){this.a=a
this.b=b
this.c=c},
ec(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.dd(f,d,n,g,c,h,e,l,i,a,k,b,j,B.n)},
lQ(a,b){return new A.iA(b,a)},
de:function de(a,b){this.a=a
this.b=b},
bk:function bk(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=d
_.f=e
_.r=f
_.w=g},
bR:function bR(a,b){this.a=a
this.b=b},
cE:function cE(a,b){this.a=a
this.b=b},
dd:function dd(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
iA:function iA(a,b){this.a=a
this.b=b},
eF:function eF(a,b){this.a=a
this.b=b},
es:function es(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.e=d},
cJ:function cJ(a,b,c){this.a=a
this.c=b
this.d=c},
ee:function ee(a,b,c){this.a=a
this.b=b
this.c=c},
i6:function i6(){},
m1(a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.q(a4),a2=a1.j("B<1>"),a3=A.p(new A.B(a4,a1.j("u(1)").a(new A.iW()),a2),a2.j("j.E"))
a1=a3.length
if(a1===0)return B.dU
if(a1===1){s=B.a.gu(a3)
r=s.a
q=s.b
return A.m1(A.d([new A.A(0,1.33*q),new A.A(r,q),new A.A(2*r,0)],t.fU))}if(a1===2){if(0>=a1)return A.b(a3,0)
p=a3[0]
o=p.a
n=p.b
if(1>=a1)return A.b(a3,1)
m=a3[1]
l=(m.b-n)/(m.a-o)
return new A.cN(0,l,n-l*o,1)}for(k=0,j=0,i=0,h=0,g=0,f=0,a2=0,e=0;e<a1;++e){d=a3[e]
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
a0=A.o8(A.d([A.d([h,i,j,a2],d),A.d([i,j,k,f],d),A.d([j,k,a1,g],d)],t.iA))
d=a0.length
if(0>=d)return A.b(a0,0)
g=a0[0]
if(1>=d)return A.b(a0,1)
a1=a0[1]
if(2>=d)return A.b(a0,2)
return new A.cN(g,a1,a0[2],1)},
o8(a){var s,r,q,p,o,n,m,l,k,j
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
B.a.i(o,l,o[l]-m*a[s][l])}}}o=A.d([],t.n)
for(s=0;s<3;++s){k=a[s]
j=k[s]
o.push(Math.abs(j)<1e-18?0:k[3]/j)}return o},
fp(a,b){var s
if(b<=0)return 1
if(a<=0)return 1/b
s=Math.pow(1+a,b)
return a*s/(s-1)},
mH(a,b,c,d,e){return 9788.99803*b*c/Math.max(e,0.05)/1000*d*a},
cN:function cN(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
iX:function iX(){},
iW:function iW(){},
od(a){var s,r,q,p=J.ek(a,t.jq)
for(s=t.S,r=t.i,q=0;q<a;++q)p[q]=A.m(s,r)
return new A.j0(a,p,A.b9(a,0,!1,r))},
j0:function j0(a,b,c){this.a=a
this.b=b
this.c=c},
j1:function j1(){},
j2:function j2(){},
j3:function j3(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
j4:function j4(a,b,c){this.a=a
this.b=b
this.c=c},
j5:function j5(){},
op(a,b,c){var s,r,q,p,o,n,m,l,k,j,i=A.q(a),h=i.j("B<1>"),g=A.p(new A.B(a,i.j("u(1)").a(new A.jm()),h),h.j("j.E"))
i=g.length
if(i===0)return B.cE
s=B.a.L(g,new A.jn())/i
h=t.i
r=A.eu(g,!0,h)
B.a.a4(r)
q=B.a.gu(r)
p=B.a.gM(r)
if(s<=0)return new A.dE(i,s,q,p,0,0,0,0,0,0)
o=B.a.W(g,0,new A.jo(s),h)
n=Math.max(1,B.b.ao(i/4))
m=A.bW(r,0,A.cw(n,"count",t.S),A.q(r).c).L(0,new A.jp())/n
h=B.a.W(g,0,new A.jq(s),h)
l=Math.sqrt(h/(i>1?i-1:1))/s
h=Math.sqrt(Math.max(1,b))
k=Math.sqrt(l*l+c*c)
j=p>0?100*(p-q)/p:0
return new A.dE(i,s,q,p,100*(1-o/i/s),100*m/s,100*(1-1.27*c/h)*(m/s),100*(1-k),j,l)},
dE:function dE(a,b,c,d,e,f,g,h,i,j){var _=this
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
jm:function jm(){},
jn:function jn(){},
jo:function jo(a){this.a=a},
jp:function jp(){},
jq:function jq(a){this.a=a},
aY:function aY(a,b,c){this.c=a
this.a=b
this.b=c},
i5:function i5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ao(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.H(e,h,l,a,i,f,g,d,k,j,n,b,m,c)},
o2(a){var s,r,q,p,o,n,m,l,k,j,i,h=null,g=A.C(a.h(0,"id")),f=A.C(a.h(0,"name")),e=A.v(a.h(0,"sup"))
if(e==null)e=""
s=A.v(a.h(0,"code"))
if(s==null)s=""
r=A.ar(a.h(0,"nominalMm"))
q=A.ar(a.h(0,"idMm"))
p=A.v(a.h(0,"material"))
if(p==null)p="pvc"
p=A.ac(B.dk,p,t.f7)
o=A.w(a.h(0,"c"))
if(o==null)o=h
if(o==null)o=150
n=A.w(a.h(0,"roughMm"))
if(n==null)n=h
if(n==null)n=0.0015
m=A.w(a.h(0,"ratingM"))
if(m==null)m=h
if(m==null)m=60
l=A.w(a.h(0,"wallMm"))
if(l==null)l=h
if(l==null)l=2
k=A.w(a.h(0,"cost"))
if(k==null)k=h
if(k==null)k=0
j=t.O.a(a.h(0,"usage"))
if(j==null)j=["zone","mainline"]
j=J.aC(j,new A.iH(),t.W).ap(0)
i=A.X(a.h(0,"enabled"))
return A.ao(s,k,i!==!1,o,g,q,p,f,r,m,n,e,j,l)},
o0(a){var s,r,q,p,o,n,m,l=A.C(a.h(0,"id")),k=A.C(a.h(0,"name")),j=A.v(a.h(0,"sup"))
if(j==null)j=""
s=A.v(a.h(0,"code"))
if(s==null)s=""
r=A.ac(B.di,A.C(a.h(0,"kind")),t.hF)
q=J.aC(t.j.a(a.h(0,"nozzles")),new A.iC(),t.mP)
q=A.p(q,q.$ti.j("t.E"))
p=A.w(a.h(0,"cost"))
if(p==null)p=null
if(p==null)p=0
o=A.w(a.h(0,"inletMm"))
if(o==null)o=null
if(o==null)o=20
n=A.w(a.h(0,"riser"))
if(n==null)n=null
if(n==null)n=0
m=A.X(a.h(0,"enabled"))
return new A.a3(l,k,j,s,r,q,p,o,n,m!==!1)},
cR(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){return new A.aP(j,n,r,b,o,k,g,f,a,d,m,l,e,a0,s,p,q,i,c,h)},
eL(a,b,c,d,e,f,g,h,i,j,k){return new A.aN(e,h,k,a,j,i,A.m1(i),c,g,f,b,d)},
o9(a){var s,r,q,p,o,n,m,l,k=null,j=A.C(a.h(0,"id")),i=A.C(a.h(0,"name")),h=A.v(a.h(0,"sup"))
if(h==null)h=""
s=A.v(a.h(0,"code"))
if(s==null)s=""
r=A.w(a.h(0,"kw"))
if(r==null)r=k
if(r==null)r=0
q=J.aC(t.j.a(a.h(0,"points")),new A.iY(),t.aL)
q=A.p(q,q.$ti.j("t.E"))
p=A.w(a.h(0,"eff"))
if(p==null)p=k
if(p==null)p=0.7
o=A.w(a.h(0,"minQ"))
if(o==null)o=k
if(o==null)o=0
n=A.w(a.h(0,"maxQ"))
if(n==null)n=k
if(n==null)n=1
m=A.w(a.h(0,"cost"))
if(m==null)m=k
if(m==null)m=0
l=A.X(a.h(0,"enabled"))
return A.eL(s,m,p,l!==!1,j,n,o,i,q,r,h)},
lA(a,b,c,d,e,f){return new A.fA(c,b,e,f,d,a)},
nw(a){var s,r,q,p,o=t.O,n=o.a(a.h(0,"pipes"))
if(n==null)n=[]
n=J.aC(n,new A.fK(),t.p)
n=A.p(n,n.$ti.j("t.E"))
s=o.a(a.h(0,"outlets"))
if(s==null)s=[]
s=J.aC(s,new A.fL(),t.fa)
s=A.p(s,s.$ti.j("t.E"))
r=o.a(a.h(0,"tapes"))
if(r==null)r=[]
r=J.aC(r,new A.fM(),t.gs)
r=A.p(r,r.$ti.j("t.E"))
q=o.a(a.h(0,"valves"))
if(q==null)q=[]
q=J.aC(q,new A.fN(),t.e4)
q=A.p(q,q.$ti.j("t.E"))
p=o.a(a.h(0,"pumps"))
if(p==null)p=[]
p=J.aC(p,new A.fO(),t.dz)
p=A.p(p,p.$ti.j("t.E"))
o=o.a(a.h(0,"fittings"))
if(o==null)o=[]
o=J.aC(o,new A.fP(),t.kN)
o=A.p(o,o.$ti.j("t.E"))
return A.lA(o,s,n,p,r,q)},
nu(){var s,r,q,p,o,n,m,l,k,j="Microaspersor 360\xb0",i="Microaspersor PC",h='Aspersor de impacto 3/4"',g='V\xe1lvula hidr\xe1ulica 3"',f='V\xe1lvula hidr\xe1ulica 4"',e='Filtro de discos 2" (120 mesh)',d='Ventosa 2"',c=new A.fC("en"),b=new A.fD(),a=t.W,a0=A.d([A.ao("",0.9,!0,140,"pe16",13.6,B.am,"PE 16 mm (PN 4)",16,40,0.003,"",A.ah([B.p],a),1.2),A.ao("",1.3,!0,140,"pe20",17,B.am,"PE 20 mm (PN 4)",20,40,0.003,"",A.ah([B.p],a),1.5),A.ao("",2.1,!0,145,"pe25",21,B.y,"PE 25 mm (PN 6)",25,60,0.003,"",A.ah([B.p,B.i],a),2),A.ao("",3.2,!0,145,"pe32",27.2,B.y,"PE 32 mm (PN 6)",32,60,0.003,"",A.ah([B.p,B.i],a),2.4),A.ao("",4.9,!0,145,"pe40",34,B.y,"PE 40 mm (PN 6)",40,60,0.003,"",A.ah([B.i],a),3),A.ao("",7.4,!0,145,"pe50",42.6,B.y,"PE 50 mm (PN 6)",50,60,0.003,"",A.ah([B.i],a),3.7),A.ao("",4.5,!0,150,"pvc35",32,B.o,"PVC DN 35 PN 80",35,80,0.0015,"",A.ah([B.i,B.j],a),1.5),A.ao("",7.2,!0,150,"pvc50",46.4,B.o,"PVC DN 50 PN 80",50,80,0.0015,"",A.ah([B.i,B.j],a),1.8),A.ao("",14.5,!0,150,"pvc75",70.6,B.o,"PVC DN 75 PN 80",75,80,0.0015,"",A.ah([B.i,B.j],a),2.2),A.ao("",24,!0,150,"pvc100",96,B.o,"PVC DN 100 PN 80",100,80,0.0015,"",A.ah([B.i,B.j],a),2.5),A.ao("",36,!0,150,"pvc125",118.6,B.o,"PVC DN 125 PN 80",125,80,0.0015,"",A.ah([B.j],a),3.2),A.ao("",52,!0,150,"pvc150",144,B.o,"PVC DN 150 PN 80",150,80,0.0015,"",A.ah([B.j],a),3.8),A.ao("",88,!0,150,"pvc200",191.6,B.o,"PVC DN 200 PN 80",200,80,0.0015,"",A.ah([B.j],a),4.9),A.ao("",135,!0,150,"pvc250",239.4,B.o,"PVC DN 250 PN 80",250,80,0.0015,"",A.ah([B.j],a),6.2),A.ao("",42,!0,150,"pead110",96.8,B.y,"PEAD 110 mm PN 10",110,100,0.002,"",A.ah([B.j],a),6.6),A.ao("",85,!0,150,"pead160",141,B.y,"PEAD 160 mm PN 10",160,100,0.002,"",A.ah([B.j],a),9.5),A.ao("",160,!1,120,"steel150",154,B.bm,c.$3('A\xe7o galvanizado 6"','Galvanised steel 6"','Acero galvanizado 6"'),150,200,0.15,"",A.ah([B.j],a),4.5)],t.D)
a=t.nB
s=A.d([new A.a3("drip_pc",c.$3("Gotejador PC (bot\xe3o)","PC dripper (button)","Gotero PC (bot\xf3n)"),"","",B.al,A.d([new A.D("pc2","2 L/h PC",b.$3(2,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.D("pc4","4 L/h PC",b.$3(4,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.D("pc8","8 L/h PC",b.$3(8,10,0.03),360,5,40,10,0.03,0.05,0.05)],a),0.6,0,0,!0),new A.a3("drip_turb",c.$3("Gotejador turbulento","Turbulent dripper","Gotero turbulento"),"","",B.al,A.d([new A.D("t2","2 L/h",b.$3(2,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.D("t4","4 L/h",b.$3(4,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.D("t8","8 L/h",b.$3(8,10,0.5),360,5,25,10,0.04,0.05,0.05)],a),0.35,0,0,!0),new A.a3("micro",c.$3(j,"Micro-sprinkler 360\xb0",j),"","",B.ak,A.d([new A.D("m35",c.$3("35 L/h (raio 3,0 m)","35 L/h (radius 3.0 m)","35 L/h (radio 3,0 m)"),b.$4$radiusM(35,15,0.5,3),360,10,30,15,0.05,0.05,0.05),new A.D("m50",c.$3("50 L/h (raio 3,5 m)","50 L/h (radius 3.5 m)","50 L/h (radio 3,5 m)"),b.$4$radiusM(50,15,0.5,3.5),360,10,30,15,0.05,0.05,0.05),new A.D("m70",c.$3("70 L/h (raio 4,0 m)","70 L/h (radius 4.0 m)","70 L/h (radio 4,0 m)"),b.$4$radiusM(70,15,0.5,4),360,10,30,15,0.05,0.05,0.05),new A.D("m120",c.$3("120 L/h (raio 5,0 m)","120 L/h (radius 5.0 m)","120 L/h (radio 5,0 m)"),b.$4$radiusM(120,20,0.5,5),360,15,35,20,0.05,0.05,0.05)],a),2.8,0,0.3,!0),new A.a3("micro_pc",c.$3(i,"PC micro-sprinkler",i),"","",B.ak,A.d([new A.D("mpc40",c.$3("40 L/h PC (raio 3,5 m)","40 L/h PC (radius 3.5 m)","40 L/h PC (radio 3,5 m)"),b.$4$radiusM(40,15,0.05,3.5),360,12,40,20,0.05,0.05,0.05),new A.D("mpc70",c.$3("70 L/h PC (raio 4,5 m)","70 L/h PC (radius 4.5 m)","70 L/h PC (radio 4,5 m)"),b.$4$radiusM(70,15,0.05,4.5),360,12,40,20,0.05,0.05,0.05)],a),3.9,0,0.3,!0),new A.a3("impact34",c.$3(h,'Impact sprinkler 3/4"',h),"","",B.V,A.d([new A.D("i3.5",c.$3("Bocal 3,5 mm (0,9 m\xb3/h, R 12 m)","Nozzle 3.5 mm (0.9 m\xb3/h, R 12 m)","Boquilla 3,5 mm (0,9 m\xb3/h, R 12 m)"),b.$4$radiusM(900,30,0.5,12),360,20,45,30,0.03,0.05,0.05),new A.D("i4.0",c.$3("Bocal 4,0 mm (1,2 m\xb3/h, R 13 m)","Nozzle 4.0 mm (1.2 m\xb3/h, R 13 m)","Boquilla 4,0 mm (1,2 m\xb3/h, R 13 m)"),b.$4$radiusM(1200,30,0.5,13),360,20,45,30,0.03,0.05,0.05),new A.D("i4.5",c.$3("Bocal 4,5 mm (1,5 m\xb3/h, R 14 m)","Nozzle 4.5 mm (1.5 m\xb3/h, R 14 m)","Boquilla 4,5 mm (1,5 m\xb3/h, R 14 m)"),b.$4$radiusM(1500,30,0.5,14),360,20,45,30,0.03,0.05,0.05),new A.D("i5.0",c.$3("Bocal 5,0 mm (1,9 m\xb3/h, R 15 m)","Nozzle 5.0 mm (1.9 m\xb3/h, R 15 m)","Boquilla 5,0 mm (1,9 m\xb3/h, R 15 m)"),b.$4$radiusM(1900,30,0.5,15),360,25,50,35,0.03,0.05,0.05)],a),18,20,1,!0),new A.a3("gun",c.$3('Canh\xe3o hidr\xe1ulico 1,5"','Big gun 1.5"','Ca\xf1\xf3n de riego 1,5"'),"","",B.bk,A.d([new A.D("g14",c.$3("Bocal 14 mm (15 m\xb3/h, R 32 m)","Nozzle 14 mm (15 m\xb3/h, R 32 m)","Boquilla 14 mm (15 m\xb3/h, R 32 m)"),b.$4$radiusM(15e3,40,0.5,32),360,30,70,40,0.03,0.05,0.05),new A.D("g18",c.$3("Bocal 18 mm (25 m\xb3/h, R 40 m)","Nozzle 18 mm (25 m\xb3/h, R 40 m)","Boquilla 18 mm (25 m\xb3/h, R 40 m)"),b.$4$radiusM(25e3,45,0.5,40),360,35,80,45,0.03,0.05,0.05)],a),420,40,1.5,!0),new A.a3("rotor",c.$3('Rotor de jardim 1/2"','Turf rotor 1/2"','Rotor de jard\xedn 1/2"'),"","",B.V,A.d([new A.D("r1.5","#1.5 (0,35 m\xb3/h, R 8 m)",b.$4$radiusM(350,25,0.5,8),360,17,45,25,0.03,0.05,0.05),new A.D("r3","#3 (0,70 m\xb3/h, R 10 m)",b.$4$radiusM(700,25,0.5,10),360,17,45,25,0.03,0.05,0.05),new A.D("r3_180","#3 180\xb0 (0,35 m\xb3/h, R 10 m)",b.$4$radiusM(350,25,0.5,10),180,17,45,25,0.03,0.05,0.05),new A.D("r3_90","#3 90\xb0 (0,18 m\xb3/h, R 10 m)",b.$4$radiusM(180,25,0.5,10),90,17,45,25,0.03,0.05,0.05)],a),45,15,0.1,!0),new A.a3("spray",c.$3('Spray pop-up 4"','Pop-up spray 4"','Difusor emergente 4"'),"","",B.V,A.d([new A.D("s12","12F (0,60 m\xb3/h, R 3,7 m)",b.$4$radiusM(600,20,0.5,3.7),360,10,30,20,0.04,0.05,0.05),new A.D("s12h","12H (0,30 m\xb3/h, R 3,7 m)",b.$4$radiusM(300,20,0.5,3.7),180,10,30,20,0.04,0.05,0.05),new A.D("s12q","12Q (0,15 m\xb3/h, R 3,7 m)",b.$4$radiusM(150,20,0.5,3.7),90,10,30,20,0.04,0.05,0.05),new A.D("s15","15F (0,84 m\xb3/h, R 4,6 m)",b.$4$radiusM(840,20,0.5,4.6),360,10,30,20,0.04,0.05,0.05)],a),12,15,0,!0),new A.a3("demand",c.$3("Ponto de demanda","Demand point","Punto de demanda"),"","",B.bl,A.d([new A.D("d5","5 m\xb3/h @ 20 m",b.$3(5000,20,0),360,20,80,20,0,0.5,0.5),new A.D("d10","10 m\xb3/h @ 20 m",b.$3(1e4,20,0),360,20,80,20,0,0.5,0.5),new A.D("d20","20 m\xb3/h @ 25 m",b.$3(2e4,25,0),360,25,80,25,0,0.5,0.5)],a),0,50,0,!0)],t.dO)
a=c.$3("Fita gotejadora 16 mm, 1,0 L/h @ 0,30 m","Drip tape 16 mm, 1.0 L/h @ 0.30 m","Cinta de goteo 16 mm, 1,0 L/h @ 0,30 m")
a=A.cR(0.3,"",0.45,0.03,8,b.$3(1,7,0.5),0.3,!0,140,"tape16_10_30",15.6,12,4,a,16,15,0.002,"",20,30)
r=c.$3("Fita gotejadora 16 mm, 1,6 L/h @ 0,20 m","Drip tape 16 mm, 1.6 L/h @ 0.20 m","Cinta de goteo 16 mm, 1,6 L/h @ 0,20 m")
r=A.cR(0.3,"",0.55,0.03,8,b.$3(1.6,7,0.5),0.2,!0,140,"tape16_16_20",15.6,12,4,r,16,15,0.002,"",20,30)
q=c.$3("Tubo gotejador 16 mm, 1,6 L/h @ 0,50 m","Dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo 16 mm, 1,6 L/h @ 0,50 m")
q=A.cR(0.4,"",1.1,0.03,10,b.$3(1.6,10,0.5),0.5,!0,140,"drip16_16_50",13.8,25,5,q,16,30,0.002,"",20,30)
p=c.$3("Tubo gotejador 16 mm, 2,4 L/h @ 0,75 m","Dripline 16 mm, 2.4 L/h @ 0.75 m","Tuber\xeda de goteo 16 mm, 2,4 L/h @ 0,75 m")
p=A.cR(0.4,"",1.05,0.03,10,b.$3(2.4,10,0.5),0.75,!0,140,"drip16_24_75",13.8,25,5,p,16,30,0.002,"",20,30)
o=c.$3("Tubo gotejador PC 16 mm, 1,6 L/h @ 0,50 m","PC dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo PC 16 mm, 1,6 L/h @ 0,50 m")
o=A.cR(0.4,"",1.6,0.03,15,b.$3(1.6,10,0.04),0.5,!0,140,"drip16pc_16_50",13.8,40,6,o,16,40,0.002,"",150,50)
n=c.$3("Tubo gotejador PC 20 mm, 2,3 L/h @ 0,75 m","PC dripline 20 mm, 2.3 L/h @ 0.75 m","Tuber\xeda de goteo PC 20 mm, 2,3 L/h @ 0,75 m")
m=A.d([a,r,q,p,o,A.cR(0.4,"",2.1,0.03,15,b.$3(2.3,10,0.04),0.75,!0,140,"drip20pc_23_75",17.5,40,6,n,20,40,0.002,"",150,50)],t.kU)
n=new A.fB()
l=A.d([new A.P("ev25",c.$3('V\xe1lvula el\xe9trica 1"','Solenoid valve 1"','Electrov\xe1lvula 1"'),"","",B.F,25,n.$2(6,25),0.00005555555555555556,0.0016666666666666666,120,0,!0),new A.P("ev40",c.$3('V\xe1lvula el\xe9trica 1\xbd"','Solenoid valve 1\xbd"','Electrov\xe1lvula 1\xbd"'),"","",B.F,40,n.$2(5.5,40),0.0002777777777777778,0.0044444444444444444,260,0,!0),new A.P("ev50",c.$3('V\xe1lvula el\xe9trica 2"','Solenoid valve 2"','Electrov\xe1lvula 2"'),"","",B.F,50,n.$2(5,50),0.0005555555555555556,0.008333333333333333,380,0,!0),new A.P("ev80",c.$3(g,'Hydraulic valve 3"',g),"","",B.F,80,n.$2(4.5,80),0.001388888888888889,0.022222222222222223,900,0,!0),new A.P("ev100",c.$3(f,'Hydraulic valve 4"',f),"","",B.F,100,n.$2(4,100),0.002777777777777778,0.03888888888888889,1500,0,!0),new A.P("prv50",c.$3('V\xe1lvula reguladora de press\xe3o 2"','Pressure reducing valve 2"','V\xe1lvula reguladora de presi\xf3n 2"'),"","",B.a0,50,n.$2(3,50),0,0.008333333333333333,650,25,!0),new A.P("prv80",c.$3('V\xe1lvula reguladora de press\xe3o 3"','Pressure reducing valve 3"','V\xe1lvula reguladora de presi\xf3n 3"'),"","",B.a0,80,n.$2(3,80),0,0.022222222222222223,1200,30,!0),new A.P("gate50",c.$3('Registro gaveta 2"','Gate valve 2"','V\xe1lvula de compuerta 2"'),"","",B.aI,50,n.$2(0.2,50),0,0.011111111111111112,90,0,!0),new A.P("gate100",c.$3('Registro gaveta 4"','Gate valve 4"','V\xe1lvula de compuerta 4"'),"","",B.aI,100,n.$2(0.2,100),0,0.041666666666666664,420,0,!0),new A.P("check100",c.$3('V\xe1lvula de reten\xe7\xe3o 4"','Check valve 4"','V\xe1lvula de retenci\xf3n 4"'),"","",B.aJ,100,n.$2(2,100),0,0.041666666666666664,380,0,!0),new A.P("filter_disc50",c.$3(e,'Disc filter 2" (120 mesh)',e),"","",B.aK,50,new A.bh(62208,2,0),0,0.006944444444444444,850,0,!0),new A.P("filter_screen80",c.$3('Filtro de tela 3"','Screen filter 3"','Filtro de malla 3"'),"","",B.aK,80,new A.bh(9000,2,0),0,0.016666666666666666,1400,0,!0),new A.P("meter50",c.$3('Hidr\xf4metro 2"','Water meter 2"','Contador de agua 2"'),"","",B.cH,50,n.$2(7,50),0,0.005555555555555556,700,0,!0),new A.P("backflow50",c.$3('V\xe1lvula anti-refluxo 2"','Backflow preventer 2"','V\xe1lvula antirretorno 2"'),"","",B.cG,50,n.$2(8,50),0,0.006944444444444444,900,0,!0),new A.P("air50",c.$3(d,'Air release valve 2"',d),"","",B.cI,50,B.a1,0,1,180,0,!0)],t.bD)
n=t.fU
k=A.d([A.eL("",2200,0.55,!0,"pump_small",0.004166666666666667,0,c.$3("Bomba centr\xedfuga 3 cv (10 m\xb3/h @ 35 m)","Centrifugal pump 3 hp (10 m\xb3/h @ 35 m)","Bomba centr\xedfuga 3 CV (10 m\xb3/h @ 35 m)"),A.d([B.dV,B.dZ,B.e7,B.e6],n),0,""),A.eL("",6500,0.65,!0,"pump_mid",0.016666666666666666,0,c.$3("Bomba centr\xedfuga 10 cv (40 m\xb3/h @ 45 m)","Centrifugal pump 10 hp (40 m\xb3/h @ 45 m)","Bomba centr\xedfuga 10 CV (40 m\xb3/h @ 45 m)"),A.d([B.dW,B.e1,B.e4,B.e3],n),0,""),A.eL("",18e3,0.72,!0,"pump_big",0.05,0,c.$3("Bomba centr\xedfuga 30 cv (120 m\xb3/h @ 55 m)","Centrifugal pump 30 hp (120 m\xb3/h @ 55 m)","Bomba centr\xedfuga 30 CV (120 m\xb3/h @ 55 m)"),A.d([B.dX,B.eb,B.e_,B.ea],n),0,""),A.eL("",5400,0.6,!0,"pump_sub",0.009722222222222222,0,c.$3("Bomba submersa 7,5 cv (25 m\xb3/h @ 60 m)","Submersible pump 7.5 hp (25 m\xb3/h @ 60 m)","Bomba sumergible 7,5 CV (25 m\xb3/h @ 60 m)"),A.d([B.dY,B.e9,B.e0,B.e5],n),0,"")],t.fH)
return A.lA(A.nv(a0,"en"),s,a0,k,m,l)},
nv(a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d="Adaptador roscado",c="Conector inicial de lateral",b="Tubo de subida",a="Riser",a0=new A.fI(a6),a1=A.q(a5),a2=a1.j("e(1)"),a3=new A.r(a5,a2.a(new A.fE()),a1.j("r<1,e>")).ap(0),a4=A.p(a3,A.i(a3).c)
B.a.a4(a4)
s=A.d([],t.eK)
r=new A.fH()
q=new A.fJ()
for(a3=a4.length,p=a3,o=0;o<p;h===a3||(0,A.k)(a4),++o,p=h){n=a4[o]
m=r.$1(n)
B.a.k(s,new A.W("cpl"+m,A.y(a0.$3("Luva","Coupler","Manguito"))+" "+m+" mm","","",B.Q,n,0,q.$2(4,n),!0,""))
B.a.k(s,new A.W("el90_"+m,A.y(a0.$3("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0"))+" "+m+" mm","","",B.ac,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.W("el45_"+m,A.y(a0.$3("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0"))+" "+m+" mm","","",B.ad,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.W("tee"+m,A.y(a0.$3("T\xea","Tee","Te"))+" "+m+" mm","","",B.H,n,0,q.$2(8,n),!0,""))
B.a.k(s,new A.W("cross"+m,A.y(a0.$3("Cruzeta","Cross","Cruz"))+" "+m+" mm","","",B.ae,n,0,q.$2(11,n),!0,""))
B.a.k(s,new A.W("cap"+m,A.y(a0.$3("Tamp\xe3o (cap)","End cap","Tap\xf3n"))+" "+m+" mm","","",B.I,n,0,q.$2(3,n),!0,""))
B.a.k(s,new A.W("adp"+m,A.y(a0.$3(d,"Threaded adapter",d))+" "+m+" mm","","",B.af,n,0,q.$2(5,n),!0,""))
for(p=a4.length,l="red"+m+"x",k=n<=75,j="teer"+m+"x",i=0;h=a4.length,i<h;a4.length===p||(0,A.k)(a4),++i){g=a4[i]
if(g>=n)continue
f=r.$1(g)
B.a.k(s,new A.W(l+f,A.y(a0.$3("Redu\xe7\xe3o","Reducer","Reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.v,n,g,q.$2(5,n),!0,""))
if(g>=20||k)B.a.k(s,new A.W(j+f,A.y(a0.$3("T\xea de redu\xe7\xe3o","Reducing tee","Te de reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.H,n,g,q.$2(9,n),!0,""))}}a3=A.ah([16,20],t.i)
a3.B(0,new A.by(new A.B(a5,a1.j("u(1)").a(new A.fF()),a1.j("B<1>")),a2.a(new A.fG()),a1.j("by<1,e>")))
e=A.p(a3,a3.$ti.c)
B.a.a4(e)
for(a1=e.length,o=0;o<e.length;e.length===a1||(0,A.k)(e),++o){n=e[o]
m=r.$1(n)
B.a.k(s,new A.W("to"+m,A.y(a0.$3(c,"Lateral take-off",c))+" "+m+" mm","","",B.w,n,0,1.2,!0,""))
B.a.k(s,new A.W("te"+m,A.y(a0.$3("Final de linha","Line end","Final de l\xednea"))+" "+m+" mm","","",B.J,n,0,0.9,!0,""))}B.a.k(s,new A.W("riser_micro",a0.$3("Haste/tubinho de microaspersor","Micro-sprinkler stake/tube","Estaca/microtubo de microaspersor"),"","",B.m,0,0,1.1,!0,""))
B.a.k(s,new A.W("riser20",A.y(a0.$3(b,a,b))+" 20 mm","","",B.m,20,0,6,!0,""))
B.a.k(s,new A.W("riser25",A.y(a0.$3(b,a,b))+" 25 mm","","",B.m,25,0,8,!0,""))
B.a.k(s,new A.W("riser40",A.y(a0.$3(b,a,b))+" 40 mm","","",B.m,40,0,18,!0,""))
return s},
aZ:function aZ(a,b){this.a=a
this.b=b},
H:function H(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
iI:function iI(){},
iH:function iH(){},
ba:function ba(a,b){this.a=a
this.b=b},
D:function D(a,b,c,d,e,f,g,h,i,j){var _=this
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
a3:function a3(a,b,c,d,e,f,g,h,i,j){var _=this
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
iD:function iD(a){this.a=a},
iE:function iE(a){this.a=a},
iF:function iF(){},
iC:function iC(){},
aP:function aP(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){var _=this
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
aG:function aG(a,b){this.a=a
this.b=b},
P:function P(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
aN:function aN(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
iZ:function iZ(){},
iY:function iY(){},
a6:function a6(a,b){this.a=a
this.b=b},
W:function W(a,b,c,d,e,f,g,h,i,j){var _=this
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
fA:function fA(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
fS:function fS(a){this.a=a},
fT:function fT(){},
fQ:function fQ(a){this.a=a},
fR:function fR(){},
fY:function fY(a){this.a=a},
fZ:function fZ(){},
h5:function h5(a){this.a=a},
h6:function h6(){},
fW:function fW(a){this.a=a},
fX:function fX(){},
fU:function fU(a){this.a=a},
fV:function fV(){},
h_:function h_(){},
h0:function h0(){},
h1:function h1(){},
h2:function h2(){},
h3:function h3(){},
h4:function h4(){},
fK:function fK(){},
fL:function fL(){},
fM:function fM(){},
fN:function fN(){},
fO:function fO(){},
fP:function fP(){},
fC:function fC(a){this.a=a},
fD:function fD(){},
fB:function fB(){},
fI:function fI(a){this.a=a},
fE:function fE(){},
fH:function fH(){},
fJ:function fJ(){},
fF:function fF(){},
fG:function fG(){},
nK(b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=null,a6="rot",a7="scope",a8="spec",a9="depth",b0="zone",b1="mainline",b2=A.ac(B.dn,A.C(b5.h(0,"type")),t.od),b3=A.C(b5.h(0,"id")),b4=A.v(b5.h(0,"layer"))
if(b4==null)b4="DRAWING"
s=A.v(b5.h(0,"name"))
if(s==null)s=""
r=new A.i2(b5)
q=new A.i1(b5)
p=new A.i0(b5)
switch(b2.a){case 0:r=t.j
return new A.ch(A.bB(r.a(b5.h(0,"a"))),A.bB(r.a(b5.h(0,"b"))),b3,b4,s)
case 1:r=r.$0()
q=A.X(b5.h(0,"closed"))
return new A.cM(r,q===!0,b3,b4,s)
case 2:return new A.e3(q.$0(),p.$1("r"),b3,b4,s)
case 3:return new A.d2(q.$0(),p.$1("r"),p.$1("s"),p.$1("w"),b3,b4,s)
case 4:r=r.$0()
q=A.X(b5.h(0,"closed"))
return new A.cP(r,q===!0,b3,b4,s)
case 5:r=r.$0()
q=p.$2("ang",45)
p=p.$2("sp",1)
o=A.X(b5.h(0,"solid"))
return new A.ed(r,q,p,o===!0,b3,b4,s)
case 6:r=q.$0()
q=A.v(b5.h(0,"kind"))
if(q==null)q="tree"
return new A.eP(r,A.ac(B.ds,q,t.ai),p.$2("size",2),p.$1(a6),b3,b4,s)
case 7:r=q.$0()
q=A.v(b5.h(0,"text"))
if(q==null)q=""
return new A.eS(r,q,p.$2("h",1),p.$1(a6),b3,b4,s)
case 8:r=t.j
return new A.ea(A.bB(r.a(b5.h(0,"a"))),A.bB(r.a(b5.h(0,"b"))),p.$2("off",1),b3,b4,s)
case 9:r=t.j
return new A.dZ(A.bB(r.a(b5.h(0,"v"))),A.bB(r.a(b5.h(0,"a"))),A.bB(r.a(b5.h(0,"b"))),p.$2("r",2),b3,b4,s)
case 10:return new A.eM(A.bB(t.j.a(b5.h(0,"c"))),q.$0(),b3,b4,s)
case 11:r=r.$0()
q=A.v(b5.h(0,"text"))
if(q==null)q=""
return new A.cD(r,q,p.$2("h",1),b3,b4,s)
case 12:r=q.$0()
q=p.$2("w",1)
o=p.$2("h",1)
n=p.$1(a6)
p=p.$2("op",1)
m=A.v(b5.h(0,"mime"))
if(m==null)m="image/png"
l=b5.h(0,"data")!=null?B.cL.br(A.C(b5.h(0,"data"))):a5
k=A.v(b5.h(0,"src"))
return new A.ef(r,q,o,n,p,m,l,k==null?"":k,b3,b4,s)
case 13:r=r.$0()
p=p.$1("z")
q=A.X(b5.h(0,"gen"))
return new A.c6(r,p,q===!0,b3,b4,s)
case 14:return new A.dA(q.$0(),p.$1("z"),b3,b4,s)
case 15:r=r.$0()
q=A.ac(B.B,A.C(b5.h(0,a7)),t.E)
o=A.v(b5.h(0,a8))
n=A.X(b5.h(0,"auto"))
return A.o1(n!==!1,p.$1(a9),b3,b4,s,o,r,q)
case 16:r=r.$0()
q=A.v(b5.h(0,a8))
o=A.X(b5.h(0,"auto"))
n=A.v(b5.h(0,"outlet"))
if(n==null)n=""
m=A.v(b5.h(0,"nozzle"))
l=p.$2("head",20)
k=p.$2("sp",5)
j=p.$2("off",0)
i=p.$2("arc",360)
h=p.$1("riser")
return A.oe(i,o!==!1,p.$1(a9),l,b3,b4,s,m,j,n,q,r,h,k)
case 17:r=r.$0()
q=A.v(b5.h(0,a8))
if(q==null)q=""
o=p.$2("inlet",10)
n=A.X(b5.h(0,"reg"))
m=p.$2("submin",0)
return A.oj(p.$1(a9),p.$1("flush"),b3,o,b4,s,r,n===!0,m,q)
case 18:r=q.$0()
q=A.v(b5.h(0,a7))
if(q==null)q=b0
q=A.ac(B.B,q,t.E)
o=A.v(b5.h(0,"outlet"))
if(o==null)o=""
n=A.v(b5.h(0,"nozzle"))
m=p.$2("head",20)
l=p.$2("arc",360)
k=p.$1(a6)
p=p.$1("riser")
j=A.v(b5.h(0,b0))
return new A.aX(r,q,o,n,m,l,k,p,j==null?"":j,b3,b4,s)
case 19:r=q.$0()
q=A.v(b5.h(0,a8))
o=A.v(b5.h(0,b0))
if(o==null)o=s
n=p.$1(a6)
m=A.w(b5.h(0,"fixed"))
if(m==null)m=a5
return new A.b6(r,q,o,n,m,p.$1(a9),b3,b4,s)
case 20:r=q.$0()
q=A.X(b5.h(0,"calc"))
return new A.aH(r,q!==!1,p.$1("dh"),p.$1("mh"),p.$1("dq"),p.$1("mq"),p.$1("wl"),b3,b4,s)
case 21:r=q.$0()
q=A.v(b5.h(0,a8))
o=p.$2("speed",1)
p=p.$1(a6)
n=A.v(b5.h(0,a7))
if(n==null)n=b1
return new A.bm(r,q,o,p,A.ac(B.B,n,t.E),b3,b4,s)
case 22:r=q.$0()
q=A.v(b5.h(0,a8))
o=A.v(b5.h(0,a7))
if(o==null)o=b1
return new A.aW(r,q,A.ac(B.B,o,t.E),p.$1("set"),p.$1(a6),b3,b4,s)
case 23:r=q.$0()
q=A.v(b5.h(0,a7))
if(q==null)q=b0
q=A.ac(B.B,q,t.E)
p=A.w(b5.h(0,"z"))
return new A.cg(r,q,p==null?a5:p,b3,b4,s)
case 24:r=r.$0()
q=p.$2(a9,5)
o=p.$2("eff",0.9)
n=A.v(b5.h(0,"crop"))
if(n==null)n=""
m=A.w(b5.h(0,"epp"))
m=m==null?a5:B.b.ai(m)
if(m==null)m=0
l=A.X(b5.h(0,"wb"))
return new A.cB(r,q,o,n,m,l===!0,p.$2("eto",5),p.$2("kc",1),p.$2("awc",120),p.$2("root",0.6),p.$2("mad",0.5),p.$1("psp"),p.$1("rsp"),p.$2("wf",1),b3,b4,s)
case 25:r=q.$0()
q=p.$2("r",400)
o=p.$1("ang")
n=A.v(b5.h(0,"kind"))
if(n==null)n="pivot"
n=A.ac(B.dm,n,t.n7)
m=p.$1("travel")
l=p.$2("span",50)
k=A.v(b5.h(0,a8))
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
a4=A.v(b5.h(0,b0))
if(a4==null)a4=""
return new A.b_(p.$2("ssp",2.5),A.v(b5.h(0,"sspec")),A.v(b5.h(0,"rspec")),p.$1("tcost"),r,q,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,b3,b4,s)}},
c0(a){var s=J.aC(a,new A.k3(),t.bd)
s=A.p(s,s.$ti.j("t.E"))
return s},
o1(a,b,c,d,e,f,g,h){return new A.aE(g,h,f,a,b,c,d,e)},
oe(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.aj(l,k,b,j,h,d,n,i,a,m,c,e,f,g)},
oj(a,b,c,d,e,f,g,h,i,j){return new A.aA(g,j,d,h,i,a,b,c,e,f)},
nI(a){var s,r=a.gC()
A:{s=B.a2===r||B.a3===r||B.a4===r||B.a5===r||B.a6===r||B.a7===r||B.a8===r||B.a9===r||B.aa===r||B.ab===r
break A}return s},
nH(a){var s
A:{s=null
if(a instanceof A.aE){s=a.e
break A}if(a instanceof A.aj){s=B.f
break A}if(a instanceof A.aA){s=B.f
break A}if(a instanceof A.aX){s=a.e
break A}if(a instanceof A.b6)break A
if(a instanceof A.aH){s=B.h
break A}if(a instanceof A.bm){s=a.w
break A}if(a instanceof A.aW){s=a.f
break A}if(a instanceof A.cg){s=a.e
break A}if(a instanceof A.b_){s=B.h
break A}break A}return s},
nJ(a){var s
A:{if(a instanceof A.ch){s=A.d([a.d,a.e],t.C)
break A}if(t.f.b(a)){s=a.gP()
break A}if(a instanceof A.d2){s=a.dQ()
break A}s=null
break A}return s},
aD:function aD(a,b){this.a=a
this.b=b},
L:function L(a,b){this.a=a
this.b=b},
E:function E(){},
i2:function i2(a){this.a=a},
i3:function i3(){},
i1:function i1(a){this.a=a},
i0:function i0(a){this.a=a},
bc:function bc(){},
a4:function a4(){},
k3:function k3(){},
ch:function ch(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cM:function cM(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
e3:function e3(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
d2:function d2(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
cP:function cP(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
ed:function ed(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
aF:function aF(a,b){this.a=a
this.b=b},
eP:function eP(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eS:function eS(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
ea:function ea(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
dZ:function dZ(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eM:function eM(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cD:function cD(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
ef:function ef(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
c6:function c6(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
dA:function dA(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
aE:function aE(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
aj:function aj(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
aA:function aA(a,b,c,d,e,f,g,h,i,j){var _=this
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
aX:function aX(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
b6:function b6(a,b,c,d,e,f,g,h,i){var _=this
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
bm:function bm(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
aW:function aW(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
cg:function cg(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
b_:function b_(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var _=this
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
cB:function cB(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
eW:function eW(){},
eZ:function eZ(){},
f_:function f_(){},
f3:function f3(){},
f6:function f6(){},
f7:function f7(){},
f9:function f9(){},
fa:function fa(){},
fb:function fb(){},
fc:function fc(){},
fd:function fd(){},
ff:function ff(){},
fg:function fg(){},
fh:function fh(){},
fk:function fk(){},
fl:function fl(){},
fm:function fm(){},
fn:function fn(){},
m0(a,b,c){var s=a.a,r=a.b
return new A.z(s+(b.a-s)*c,r+(b.b-r)*c)},
bB(a){var s=J.af(a)
return new A.z(A.ar(s.h(a,0)),A.ar(s.h(a,1)))},
nt(a){var s,r,q,p,o,n
for(s=a.$ti,r=new A.aL(a,a.gm(0),s.j("aL<t.E>")),s=s.j("t.E"),q=B.cJ;r.l();){p=r.d
if(p==null)p=s.a(p)
o=p.a
n=Math.min(q.a,o)
p=p.b
q=new A.e2(n,Math.min(q.b,p),Math.max(q.c,o),Math.max(q.d,p))}return q},
lh(a,b,c){var s,r=c.U(0,b),q=r.ck(r)
if(q===0)return new A.A(b,0)
s=B.b.a_(a.U(0,b).ck(r)/q,0,1)
return new A.A(b.aj(0,r.aq(0,s)),s)},
aT(a){var s,r,q,p,o,n
for(s=J.af(a),r=0,q=1;q<s.gm(a);++q){p=s.h(a,q-1)
o=s.h(a,q)
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)}return r},
q5(a,b){var s,r,q,p,o,n,m,l,k,j,i,h
for(s=b.length,r=s-1,q=a.b,p=a.a,o=!1,n=0;n<s;m=n+1,r=n,n=m){l=b[n]
if(!(r>=0&&r<s))return A.b(b,r)
k=b[r]
j=l.b
i=k.b
if(j>q!==i>q){h=l.a
h=p<(k.a-h)*(q-j)/(i-j)+h
j=h}else j=!1
if(j)o=!o}return o},
ks(a,b){var s,r,q,p,o,n,m,l,k=J.af(a)
if(k.gF(a))return B.an
for(s=b,r=1;r<k.gm(a);++r){q=r-1
p=k.h(a,q)
o=k.h(a,r)
n=p.a-o.a
o=p.b-o.b
m=Math.sqrt(n*n+o*o)
if(s<=m||r===k.gm(a)-1){l=m===0?0:B.b.a_(s/m,0,1)
return A.m0(k.h(a,q),k.h(a,r),l)}s-=m}return k.gM(a)},
n1(a,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.q(a0),c=d.j("B<1>"),b=A.p(new A.B(a0,d.j("u(1)").a(new A.kO(a)),c),c.j("j.E"))
B.a.a4(b)
if(b.length===0){d=A.p(a,t.g)
return A.d([d],t.gv)}s=A.d([],t.gv)
d=J.a1(a)
c=t.C
r=A.d([d.gu(a)],c)
for(q=0,p=0,o=1;o<d.gm(a);++o,q=i){n=d.h(a,o-1)
m=d.h(a,o)
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
f=(b[p]-q)/j}e=A.m0(n,m,f)
B.a.k(r,e)
B.a.k(s,r)
r=A.d([e],c);++p}B.a.k(r,m)}B.a.k(s,r)
d=t.ji
d=A.p(new A.B(s,t.eV.a(new A.kP()),d),d.j("j.E"))
return d},
pG(c1,c2,c3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=J.af(c1)
if(c0.gm(c1)<2){c0=A.p(c1,t.g)
return c0}if(c0.gm(c1)===2)return A.d([c0.h(c1,0),c0.h(c1,1)],t.C)
s=c0.gm(c1)
r=new A.k7(c2,c1,s)
q=A.d([],t.C)
p=c2?s:s-1
for(o=0;o<p;o=l){n=r.$1(o-1)
m=r.$1(o)
l=o+1
k=r.$1(l)
j=r.$1(o+2)
i=new A.k8()
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
B.a.k(q,new A.z(((d*a8+b*a9)*b0+b4*b9)*b1+(b4*b6+(a0*b7+a3*b8)*b2)*b3,((c*a8+a*a9)*b0+b5*b9)*b1+(b5*b6+(a1*b7+a4*b8)*b2)*b3))}}B.a.k(q,c2?c0.gu(c1):c0.gM(c1))
return q},
z:function z(a,b){this.a=a
this.b=b},
e2:function e2(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kO:function kO(a){this.a=a},
kP:function kP(){},
k7:function k7(a,b,c){this.a=a
this.b=b
this.c=c},
k8:function k8(){},
lG(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4){return new A.ha(b1,h,b3,a0,p,n,a1,a,c,l,a7,a3,a4,k,b4,b0,m,r,j,i,a8,d,a6,o,e,q,g,f,b,b2,a5,a2,s,a9)},
nF(b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5=null
if(b6==null)return A.lG(!0,!0,0.05,"R$",1,1,0.3,B.ag,0,1,2000,0.1,1,2,3,2,100,3,0,1.5,5,6,0.75,0.65,!0,B.a_,10,5,B.aG,!0,B.cF,0,20,500)
s=new A.hb(b6)
r=A.oq(t.dZ.a(b6.h(0,"units")))
q=A.v(b6.h(0,"method"))
if(q==null)q="hazenWilliams"
q=A.ac(B.dl,q,t.m1)
p=s.$2("temp",20)
o=s.$2("vZone",1.5)
n=s.$2("vMain",2)
m=s.$2("vLat",2)
l=s.$2("minorPct",5)
k=A.X(b6.h(0,"minor"))
j=s.$2("tol",0.05)
i=s.$2("interest",0.1)
h=A.w(b6.h(0,"term"))
h=h==null?b5:B.b.ai(h)
if(h==null)h=10
g=s.$2("kwh",0.75)
f=s.$2("eff",0.65)
e=s.$2("hours",2000)
d=s.$2("zoneHours",500)
c=A.X(b6.h(0,"trade"))
b=A.w(b6.h(0,"latSizes"))
b=b==null?b5:B.b.ai(b)
if(b==null)b=1
a=A.w(b6.h(0,"subSizes"))
a=a==null?b5:B.b.ai(a)
if(a==null)a=3
a0=s.$2("cScale",1)
a1=s.$2("cOffset",0)
a2=s.$2("densify",5)
a3=A.v(b6.h(0,"currency"))
if(a3==null)a3="R$"
a4=A.v(b6.h(0,"sizing"))
if(a4==null)a4="lp"
a4=A.ac(B.dp,a4,t.fA)
a5=A.w(b6.h(0,"mainSizes"))
a5=a5==null?b5:B.b.ai(a5)
if(a5==null)a5=3
a6=A.w(b6.h(0,"epp"))
a6=a6==null?b5:B.b.ai(a6)
if(a6==null)a6=1
a7=A.w(b6.h(0,"maxNodes"))
a7=a7==null?b5:B.b.ai(a7)
if(a7==null)a7=100
a8=s.$2("flushV",0.3)
a9=s.$2("flushH",1)
b0=A.X(b6.h(0,"surge"))
b1=s.$2("closure",0)
b2=A.X(b6.h(0,"fittings"))
b3=s.$2("stick",6)
s=s.$2("zoneVar",0)
b4=A.v(b6.h(0,"terrain"))
if(b4==null)b4="idw"
return A.lG(k!==!1,b0!==!1,j,a3,a6,a9,a8,q,a1,a0,e,i,b,m,a5,n,a7,a,s,o,l,b3,g,f,b2!==!1,a4,h,a2,A.ac(B.dq,b4,t.oW),c!==!1,r,b1,p,d)},
m6(a,b,c,d,e){return new A.b1(b,c,e,d,a)},
lZ(a,b,c,d,e,f,g,h,i){var s
if(i==null){$.l_=$.l_+1
s="p"+B.c.bC(1000*Date.now(),36)+B.c.bC((A.cK(Date.now(),0,B.e,B.e)^$.l_*2654435761)>>>0,36)}else s=i
return new A.iO(s,b==null?new A.bs(Date.now(),0,!1):b,e,f,a,h,c,g,d)},
m_(){var s,r,q,p=A.d([],t.j8)
for(s=0;s<22;++s){r=B.dF[s]
q=B.dJ.h(0,r)
p.push(new A.ay(r,q==null?4294967295:q,!0,!1))}return p},
o7(a){var s,r,q,p,o,n,m,l,k,j,i,h,g=null
if(!J.aU(a.h(0,"format"),"opencadirrigation")&&!J.aU(a.h(0,"format"),"irrigationcad"))throw A.l(B.d4)
s=t.dZ
r=s.a(a.h(0,"meta"))
if(r==null)r=A.lZ("",g,"",g,g,"New project","","",g)
else{q=A.v(r.h(0,"uid"))
p=A.v(r.h(0,"created"))
p=A.lF(p==null?"":p)
o=A.v(r.h(0,"modified"))
o=A.lF(o==null?"":o)
n=A.v(r.h(0,"name"))
if(n==null)n=""
m=A.v(r.h(0,"client"))
if(m==null)m=""
l=A.v(r.h(0,"site"))
if(l==null)l=""
k=A.v(r.h(0,"designer"))
if(k==null)k=""
j=A.v(r.h(0,"notes"))
if(j==null)j=""
if(r.h(0,"georef")!=null){r=t.P.a(r.h(0,"georef"))
i=B.b.ai(A.ar(r.h(0,"zone")))
h=A.X(r.h(0,"north"))
r=new A.i5(i,h!==!1,A.ar(r.h(0,"e0")),A.ar(r.h(0,"n0")))}else r=g
q=A.lZ(m,p,k,r,o,n,j,l,q)
r=q}s=A.nF(s.a(a.h(0,"params")))
q=a.h(0,"catalog")!=null?A.nw(t.P.a(a.h(0,"catalog"))):A.nu()
p=t.O
o=p.a(a.h(0,"layers"))
if(o==null)o=[]
o=J.aC(o,new A.iP(),t.df)
o=A.p(o,o.$ti.j("t.E"))
o=new A.iQ().$1(o)
n=p.a(a.h(0,"entities"))
if(n==null)n=[]
n=J.aC(n,new A.iR(),t.h)
n=A.p(n,n.$ti.j("t.E"))
p=p.a(a.h(0,"systemFlows"))
if(p==null)p=[]
p=J.aC(p,new A.iS(),t.k)
p=A.p(p,p.$ti.j("t.E"))
m=A.w(a.h(0,"nextId"))
m=m==null?g:B.b.ai(m)
if(m==null)m=1
if(o==null)o=A.m_()
s=new A.iN(r,s,q,o,n,p,m)
r=A.v(a.h(0,"currentLayer"))
s.w=r==null?"DRAWING":r
return s},
ay:function ay(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cm:function cm(a,b){this.a=a
this.b=b},
ha:function ha(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4){var _=this
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
_.p1=b4},
hb:function hb(a){this.a=a},
b1:function b1(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
iO:function iO(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
iN:function iN(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w="DRAWING"},
iT:function iT(){},
iU:function iU(){},
iV:function iV(){},
iP:function iP(){},
iQ:function iQ(){},
iR:function iR(){},
iS:function iS(){},
qa(c2,c3,c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=null,c1=A.nJ(c2)
if(c1==null||J.as(c1)<2)return A.d([c2],t.u)
s=A.q(c3)
r=s.j("B<1>")
r=A.dl(new A.B(c3,s.j("u(1)").a(new A.kN(A.aT(c1))),r),r.j("j.E"))
q=A.p(r,A.i(r).c)
B.a.a4(q)
if(q.length===0)return A.d([c2],t.u)
p=A.n1(c1,q)
if(p.length<2)return A.d([c2],t.u)
s=t.u
o=A.d([],s)
for(r=c2 instanceof A.cD,n=c2 instanceof A.cP,m=c2 instanceof A.aA,l=c2 instanceof A.aj,k=c2 instanceof A.aE,j=c2 instanceof A.c6,i=c2 instanceof A.cM,h=c2 instanceof A.ch,g=c2.c,f=g+" (",e=g.length===0,d=c2.a,c=0,b=0;b<p.length;++b){a=b===0
a0=a?d:c4.$0()
if(e)a1=""
else a1=a?g:f+(b+1)+")"
if(!(b<p.length))return A.b(p,b)
a2=p[b]
a3=A.aT(a2)
A:{a4=h?c2:c0
if(h){a=a4.b
a5=J.a1(a2)
B.a.k(o,new A.ch(a5.gu(a2),a5.gM(a2),a0,a,a1))
break A}a6=i?c2:c0
if(i){B.a.k(o,new A.cM(a2,!1,a0,a6.b,a1))
break A}a7=j?c2:c0
if(j){a=a7.b
B.a.k(o,new A.c6(a2,a7.e,!1,a0,a,a1))
break A}a6=k?c2:c0
if(k){a=a6.b
a5=a6.e
a8=a6.f
a9=a6.r
b0=a6.w
B.a.k(o,new A.aE(a2,a5,a8,a9,b0,a0,a,a1))
break A}b1=l?c2:c0
if(l){b2=b1.z
b2=b2>0?b2:b1.y
a=b1.y
b3=B.b.ao((c-b2)/a)
b4=b2+(b3<0?0:b3)*a
b5=(b4<c-1e-9?b4+a:b4)-c
a5=b1.b
a8=b1.e
a9=b1.f
b0=b1.r
b6=b1.w
b7=b1.x
b8=b5<=1e-9?1e-9:b5
B.a.k(o,new A.aj(a2,a8,a9,b0,b6,b7,a,b8,b1.Q,b1.as,b1.at,a0,a5,a1))
break A}b9=m?c2:c0
if(m){a=b9.b
a5=b9.e
a8=b9.f
a9=b9.r
b0=b9.w
b6=b9.x
B.a.k(o,new A.aA(a2,a5,a8,a9,b0,b6,b===p.length-1?b9.y:0,a0,a,a1))
break A}b1=n?c2:c0
if(n){B.a.k(o,new A.cP(a2,!1,a0,b1.b,a1))
break A}a4=r?c2:c0
if(r){a=a4.b
B.a.k(o,new A.cD(a2,a4.e,a4.f,a0,a,a1))
break A}return A.d([c2],s)}c+=a3}return o},
kN:function kN(a){this.a=a},
co:function co(a,b){this.a=a
this.b=b},
bE:function bE(a,b){this.a=a
this.b=b},
eR:function eR(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=10
_.f=!1
_.r=null},
jb:function jb(){},
jc:function jc(){},
jd:function jd(){},
l3(a,b,c,d){var s=new A.je(a,b,c,d,A.m(t.S,t.J))
s.cW()
return s},
ol(c9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3=t.S,c4=A.m(t.N,c3),c5=t.n,c6=A.d([],c5),c7=A.d([],c5),c8=A.d([],c5)
for(c5=c9.length,s=0;s<c9.length;c9.length===c5||(0,A.k)(c9),++s){r=c9[s]
q=r.a
p=r.b
o=r.c
if(!isFinite(q)||!isFinite(p)||!isFinite(o))continue
n=""+B.b.a1(q*1000)+"|"+B.b.a1(p*1000)
m=c4.h(0,n)
if(m!=null){B.a.i(c8,m,o)
continue}c4.i(0,n,c6.length)
B.a.k(c6,q)
B.a.k(c7,p)
B.a.k(c8,o)}l=c6.length
if(l<3)return A.l3(c6,c7,c8,A.d([],t.ae))
k=B.a.L(c6,B.G)
j=B.a.L(c6,B.q)
i=B.a.L(c7,B.G)
h=B.a.L(c7,B.q)
g=Math.max(Math.max(j-k,h-i),0.000001)
if(g<1e-9)return A.l3(c6,c7,c8,A.d([],t.ae))
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
b=new A.jh(r,c5)
a=new A.bX(l,l+1,l+2)
b.$1(a)
B.a.k(c,a)
a0=J.ek(l,c3)
for(m=0;m<l;++m)a0[m]=m
B.a.am(a0,new A.ji(new A.jg(r,k,g,B.c.a_(B.b.ao(Math.sqrt(l)/2),1,512),c5,i)))
a1=A.d([],d)
B.a.k(a1,a)
for(a2=a0.length,a3=t.hD,s=0;s<a0.length;a0.length===a2||(0,A.k)(a0),++s){m=a0[s]
if(!(m<r.length))return A.b(r,m)
q=r[m]
if(!(m<c5.length))return A.b(c5,m)
p=c5[m]
a4=A.d([],d)
a5=A.d([],d)
for(a6=a1.length,a7=0;a7<a1.length;a1.length===a6||(0,A.k)(a1),++a7){a8=a1[a7]
a9=q-a8.d
b0=p-a8.e
if(a9*a9+b0*b0<=a8.f*1.000000000001)B.a.k(a4,a8)
else B.a.k(a5,a8)}if(a4.length===0)continue
b1=A.m(c3,c3)
b2=A.d([],a3)
b3=new A.jj(b1,b2)
for(a6=a4.length,a7=0;a7<a4.length;a4.length===a6||(0,A.k)(a4),++a7){a8=a4[a7]
b4=a8.a
b5=a8.b
b3.$2(b4,b5)
b6=a8.c
b3.$2(b5,b6)
b3.$2(b6,b4)}for(a6=b2.length,a7=0;a7<b2.length;b2.length===a6||(0,A.k)(b2),++a7){b4=b2[a7]
b7=b4.a
b8=b4.b
if(b1.h(0,b7<b8?b7*4194304+b8:b8*4194304+b7)!==1)continue
a8=new A.bX(b7,b8,m)
b.$1(a8)
B.a.k(a5,a8)}a1=a5}b9=A.d([],d)
for(c3=a1.length,s=0;s<a1.length;a1.length===c3||(0,A.k)(a1),++s){a8=a1[s]
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
B.a.k(b9,c2>0?a8:new A.bX(d,b5,a2))}return A.l3(c6,c7,c8,b9)},
bX:function bX(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=0},
je:function je(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=1
_.w=_.r=0},
jh:function jh(a,b){this.a=a
this.b=b},
jg:function jg(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
ji:function ji(a){this.a=a},
jj:function jj(a,b){this.a=a
this.b=b},
jf:function jf(){},
fu(a){var s=B.b.a_(a,0,60)
return 0.000001792/(1+0.0337*s+0.000221*s*s)},
oq(a){var s,r,q,p
if(a==null)return B.cF
s=A.v(a.h(0,"length"))
if(s==null)s="m"
s=A.ac(B.dz,s,t.hu)
r=A.v(a.h(0,"flow"))
if(r==null)r="lph"
r=A.ac(B.dB,r,t.mf)
q=A.v(a.h(0,"pressure"))
if(q==null)q="mH2O"
q=A.ac(B.dA,q,t.c4)
p=A.v(a.h(0,"diameter"))
if(p==null)p="mm"
return new A.eU(s,r,q,A.ac(B.dj,p,t.ks))},
bl:function bl(a,b){this.a=a
this.b=b},
bi:function bi(a,b){this.a=a
this.b=b},
bA:function bA(a,b){this.a=a
this.b=b},
c8:function c8(a,b){this.a=a
this.b=b},
eU:function eU(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
q0(){var s,r=v.G,q=new A.kq(r)
if(typeof q=="function")A.bq(A.d3("Attempting to rewrap a JS function.",null))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.p_,q)
s[$.lo()]=q
r.addEventListener("message",s)},
kq:function kq(a){this.a=a},
kp:function kp(a){this.a=a},
n2(a){return v.mangledGlobalNames[a]},
qd(a){throw A.a8(A.lN(a),new Error())},
qe(){throw A.a8(A.lN(""),new Error())},
p_(a,b,c){t.Z.a(a)
if(A.a0(c)>=1)return a.$1(b)
return a.$0()},
mV(a,b,c){A.mK(c,t.H,"T","min")
return Math.min(c.a(a),c.a(b))},
mU(a,b,c){A.mK(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.kV.prototype={}
J.ei.prototype={
Y(a,b){return a===b},
gK(a){return A.eJ(a)},
q(a){return"Instance of '"+A.eK(a)+"'"},
gO(a){return A.bJ(A.lb(this))}}
J.el.prototype={
q(a){return String(a)},
gK(a){return a?519018:218159},
gO(a){return A.bJ(t.y)},
$iN:1,
$iu:1}
J.dg.prototype={
Y(a,b){return null==b},
q(a){return"null"},
gK(a){return 0},
$iN:1}
J.di.prototype={$ia_:1}
J.bT.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.eH.prototype={}
J.cp.prototype={}
J.bS.prototype={
q(a){var s=a[$.n4()]
if(s==null)s=a[$.lo()]
if(s==null)return this.cG(a)
return"JavaScript function for "+J.d1(s)},
$ibv:1}
J.dh.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.dj.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.n.prototype={
aX(a,b){return new A.ab(a,A.q(a).j("@<1>").v(b).j("ab<1,2>"))},
k(a,b){A.q(a).c.a(b)
a.$flags&1&&A.a9(a,29)
a.push(b)},
dR(a,b){a.$flags&1&&A.a9(a,"removeAt",1)
if(b<0||b>=a.length)throw A.l(A.l0(b,null))
return a.splice(b,1)[0]},
dF(a,b,c){A.q(a).c.a(c)
a.$flags&1&&A.a9(a,"insert",2)
if(b<0||b>a.length)throw A.l(A.l0(b,null))
a.splice(b,0,c)},
T(a,b){var s
a.$flags&1&&A.a9(a,"remove",1)
for(s=0;s<a.length;++s)if(J.aU(a[s],b)){a.splice(s,1)
return!0}return!1},
B(a,b){var s
A.q(a).j("j<1>").a(b)
a.$flags&1&&A.a9(a,"addAll",2)
if(Array.isArray(b)){this.cJ(a,b)
return}for(s=J.aa(b);s.l();)a.push(s.gp())},
cJ(a,b){var s,r
t.dG.a(b)
s=b.length
if(s===0)return
if(a===b)throw A.l(A.al(a))
for(r=0;r<s;++r)a.push(b[r])},
V(a){a.$flags&1&&A.a9(a,"clear","clear")
a.length=0},
aF(a,b,c){var s=A.q(a)
return new A.r(a,s.v(c).j("1(2)").a(b),s.j("@<1>").v(c).j("r<1,2>"))},
dK(a,b){var s,r=A.b9(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.i(r,s,A.y(a[s]))
return r.join(b)},
a3(a,b){return A.bW(a,b,null,A.q(a).c)},
L(a,b){var s,r,q
A.q(a).j("1(1,1)").a(b)
s=a.length
if(s===0)throw A.l(A.at())
if(0>=s)return A.b(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.l(A.al(a))}return r},
W(a,b,c,d){var s,r,q
d.a(b)
A.q(a).v(d).j("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.l(A.al(a))}return r},
ag(a,b,c){var s,r,q,p=A.q(a)
p.j("u(1)").a(b)
p.j("1()?").a(c)
s=a.length
for(r=0;r<s;++r){q=a[r]
if(b.$1(q))return q
if(a.length!==s)throw A.l(A.al(a))}p=c.$0()
return p},
I(a,b){if(!(b>=0&&b<a.length))return A.b(a,b)
return a[b]},
cF(a,b,c){var s=a.length
if(b>s)throw A.l(A.aO(b,0,s,"start",null))
if(c<b||c>s)throw A.l(A.aO(c,b,s,"end",null))
if(b===c)return A.d([],A.q(a))
return A.d(a.slice(b,c),A.q(a))},
gu(a){if(a.length>0)return a[0]
throw A.l(A.at())},
gM(a){var s=a.length
if(s>0)return a[s-1]
throw A.l(A.at())},
Z(a,b){var s,r
A.q(a).j("u(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.l(A.al(a))}return!1},
gcs(a){return new A.bn(a,A.q(a).j("bn<1>"))},
am(a,b){var s,r,q,p,o,n=A.q(a)
n.j("f(1,1)?").a(b)
a.$flags&2&&A.a9(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.pa()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cB()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.fq(b,2))
if(p>0)this.d3(a,p)},
a4(a){return this.am(a,null)},
d3(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
cn(a,b){var s,r=a.length
if(0>=r)return-1
for(s=0;s<r;++s){if(!(s<a.length))return A.b(a,s)
if(J.aU(a[s],b))return s}return-1},
A(a,b){var s
for(s=0;s<a.length;++s)if(J.aU(a[s],b))return!0
return!1},
gF(a){return a.length===0},
ga8(a){return a.length!==0},
q(a){return A.kU(a,"[","]")},
gt(a){return new J.c3(a,a.length,A.q(a).j("c3<1>"))},
gK(a){return A.eJ(a)},
gm(a){return a.length},
sm(a,b){a.$flags&1&&A.a9(a,"set length","change the length of")
if(b<0)throw A.l(A.aO(b,0,null,"newLength",null))
if(b>a.length)A.q(a).c.a(null)
a.length=b},
h(a,b){A.a0(b)
if(!(b>=0&&b<a.length))throw A.l(A.fr(a,b))
return a[b]},
i(a,b,c){A.q(a).c.a(c)
a.$flags&2&&A.a9(a)
if(!(b>=0&&b<a.length))throw A.l(A.fr(a,b))
a[b]=c},
$ix:1,
$ij:1,
$io:1}
J.ej.prototype={
dZ(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.eK(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.ia.prototype={}
J.c3.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.k(q)
throw A.l(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iR:1}
J.ce.prototype={
S(a,b){var s
A.ar(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gb1(b)
if(this.gb1(a)===s)return 0
if(this.gb1(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gb1(a){return a===0?1/a<0:a<0},
ai(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.l(A.bo(""+a+".toInt()"))},
ao(a){var s,r
if(a>=0){if(a<=2147483647){s=a|0
return a===s?s:s+1}}else if(a>=-2147483648)return a|0
r=Math.ceil(a)
if(isFinite(r))return r
throw A.l(A.bo(""+a+".ceil()"))},
J(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.l(A.bo(""+a+".floor()"))},
a1(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.l(A.bo(""+a+".round()"))},
by(a){if(a<0)return-Math.round(-a)
else return Math.round(a)},
a_(a,b,c){if(B.c.S(b,c)>0)throw A.l(A.mI(b))
if(this.S(a,b)<0)return b
if(this.S(a,c)>0)return c
return a},
ae(a,b){var s
if(b>20)throw A.l(A.aO(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gb1(a))return"-"+s
return s},
bC(a,b){var s,r,q,p,o
if(b<2||b>36)throw A.l(A.aO(b,2,36,"radix",null))
s=a.toString(b)
r=s.length
q=r-1
if(!(q>=0))return A.b(s,q)
if(s.charCodeAt(q)!==41)return s
p=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(s)
if(p==null)A.bq(A.bo("Unexpected toString result: "+s))
r=p.length
if(1>=r)return A.b(p,1)
s=p[1]
if(3>=r)return A.b(p,3)
o=+p[3]
r=p[2]
if(r!=null){s+=r
o-=r.length}return s+B.k.aq("0",o)},
q(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gK(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
U(a,b){return a-b},
b6(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
if(b<0)return s-b
else return s+b},
bn(a,b){return(a|0)===a?a/b|0:this.da(a,b)},
da(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.l(A.bo("Result of truncating division is "+A.y(s)+": "+A.y(a)+" ~/ "+b))},
aT(a,b){var s
if(a>0)s=this.d6(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
d6(a,b){return b>31?0:a>>>b},
gO(a){return A.bJ(t.H)},
$iaJ:1,
$ie:1,
$iaw:1}
J.df.prototype={
gO(a){return A.bJ(t.S)},
$iN:1,
$if:1}
J.em.prototype={
gO(a){return A.bJ(t.i)},
$iN:1}
J.cf.prototype={
ar(a,b,c){return a.substring(b,A.m2(b,c,a.length))},
dY(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(0>=o)return A.b(p,0)
if(p.charCodeAt(0)===133){s=J.nU(p,1)
if(s===o)return""}else s=0
r=o-1
if(!(r>=0))return A.b(p,r)
q=p.charCodeAt(r)===133?J.nV(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
aq(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.l(B.cV)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
dP(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aq(c,s)+a},
S(a,b){var s
A.C(b)
if(a===b)s=0
else s=a<b?-1:1
return s},
q(a){return a},
gK(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gO(a){return A.bJ(t.N)},
gm(a){return a.length},
h(a,b){if(b>=a.length)throw A.l(A.fr(a,b))
return a[b]},
$iN:1,
$iaJ:1,
$iiG:1,
$ic:1}
A.bY.prototype={
gt(a){return new A.d5(J.aa(this.ga5()),A.i(this).j("d5<1,2>"))},
gm(a){return J.as(this.ga5())},
gF(a){return J.lt(this.ga5())},
ga8(a){return J.nm(this.ga5())},
a3(a,b){var s=A.i(this)
return A.lz(J.lu(this.ga5(),b),s.c,s.y[1])},
I(a,b){return A.i(this).y[1].a(J.fx(this.ga5(),b))},
gu(a){return A.i(this).y[1].a(J.bM(this.ga5()))},
gM(a){return A.i(this).y[1].a(J.kR(this.ga5()))},
q(a){return J.d1(this.ga5())}}
A.d5.prototype={
l(){return this.a.l()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iR:1}
A.c4.prototype={
ga5(){return this.a}}
A.dI.prototype={$ix:1}
A.dH.prototype={
h(a,b){return this.$ti.y[1].a(J.fw(this.a,A.a0(b)))},
i(a,b,c){var s=this.$ti
J.kQ(this.a,b,s.c.a(s.y[1].a(c)))},
sm(a,b){J.np(this.a,b)},
k(a,b){var s=this.$ti
J.bL(this.a,s.c.a(s.y[1].a(b)))},
$ix:1,
$io:1}
A.ab.prototype={
aX(a,b){return new A.ab(this.a,this.$ti.j("@<1>").v(b).j("ab<1,2>"))},
ga5(){return this.a}}
A.er.prototype={
q(a){return"LateInitializationError: "+this.a}}
A.j_.prototype={}
A.x.prototype={}
A.t.prototype={
gt(a){var s=this
return new A.aL(s,s.gm(s),A.i(s).j("aL<t.E>"))},
gF(a){return this.gm(this)===0},
gu(a){if(this.gm(this)===0)throw A.l(A.at())
return this.I(0,0)},
gM(a){var s=this
if(s.gm(s)===0)throw A.l(A.at())
return s.I(0,s.gm(s)-1)},
aF(a,b,c){var s=A.i(this)
return new A.r(this,s.v(c).j("1(t.E)").a(b),s.j("@<t.E>").v(c).j("r<1,2>"))},
L(a,b){var s,r,q,p=this
A.i(p).j("t.E(t.E,t.E)").a(b)
s=p.gm(p)
if(s===0)throw A.l(A.at())
r=p.I(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.I(0,q))
if(s!==p.gm(p))throw A.l(A.al(p))}return r},
a3(a,b){return A.bW(this,b,null,A.i(this).j("t.E"))},
ap(a){var s,r=this,q=A.et(A.i(r).j("t.E"))
for(s=0;s<r.gm(r);++s)q.k(0,r.I(0,s))
return q}}
A.dD.prototype={
gcT(){var s=J.as(this.a),r=this.c
if(r==null||r>s)return s
return r},
gd8(){var s=J.as(this.a),r=this.b
if(r>s)return s
return r},
gm(a){var s,r=J.as(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
I(a,b){var s=this,r=s.gd8()+b
if(b<0||r>=s.gcT())throw A.l(A.i9(b,s.gm(0),s,"index"))
return J.fx(s.a,r)},
a3(a,b){var s,r,q=this
A.cO(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.d8(q.$ti.j("d8<1>"))
return A.bW(q.a,s,r,q.$ti.c)},
dW(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.af(n),l=m.gm(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=p.$ti.c
return b?J.lK(0,n):J.lJ(0,n)}r=A.b9(s,m.I(n,o),b,p.$ti.c)
for(q=1;q<s;++q){B.a.i(r,q,m.I(n,o+q))
if(m.gm(n)<l)throw A.l(A.al(p))}return r},
cv(a){return this.dW(0,!0)}}
A.aL.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=J.af(q),o=p.gm(q)
if(r.b!==o)throw A.l(A.al(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.I(q,s);++r.c
return!0},
$iR:1}
A.by.prototype={
gt(a){return new A.dq(J.aa(this.a),this.b,A.i(this).j("dq<1,2>"))},
gm(a){return J.as(this.a)},
gF(a){return J.lt(this.a)},
gu(a){return this.b.$1(J.bM(this.a))},
gM(a){return this.b.$1(J.kR(this.a))},
I(a,b){return this.b.$1(J.fx(this.a,b))}}
A.ca.prototype={$ix:1}
A.dq.prototype={
l(){var s=this,r=s.b
if(r.l()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iR:1}
A.r.prototype={
gm(a){return J.as(this.a)},
I(a,b){return this.b.$1(J.fx(this.a,b))}}
A.B.prototype={
gt(a){return new A.dG(J.aa(this.a),this.b,this.$ti.j("dG<1>"))}}
A.dG.prototype={
l(){var s,r
for(s=this.a,r=this.b;s.l();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iR:1}
A.dy.prototype={
a3(a,b){this.b.aj(0,A.k0(b))
return void 1},
gt(a){var s=this.a
return new A.dz(s.gt(s),this.b,A.i(this).j("dz<1>"))}}
A.i_.prototype={
gm(a){var s=this.a,r=B.c.U(s.gm(s),this.b)
if(r>=0)return r
return 0},
a3(a,b){this.b.aj(0,A.k0(b))
return void 1},
$ix:1}
A.dz.prototype={
l(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.l()
this.b=0
return s.l()},
gp(){return this.a.gp()},
$iR:1}
A.d8.prototype={
gt(a){return B.cO},
gF(a){return!0},
gm(a){return 0},
gu(a){throw A.l(A.at())},
gM(a){throw A.l(A.at())},
I(a,b){throw A.l(A.aO(b,0,0,"index",null))},
a3(a,b){A.cO(b,"count")
return this}}
A.d9.prototype={
l(){return!1},
gp(){throw A.l(A.at())},
$iR:1}
A.cq.prototype={
gt(a){return new A.bH(J.aa(this.a),this.$ti.j("bH<1>"))}}
A.bH.prototype={
l(){var s,r
for(s=this.a,r=this.$ti.c;s.l();)if(r.b(s.gp()))return!0
return!1},
gp(){return this.$ti.c.a(this.a.gp())},
$iR:1}
A.U.prototype={
sm(a,b){throw A.l(A.bo("Cannot change the length of a fixed-length list"))},
k(a,b){A.av(a).j("U.E").a(b)
throw A.l(A.bo("Cannot add to a fixed-length list"))}}
A.bn.prototype={
gm(a){return J.as(this.a)},
I(a,b){var s=this.a,r=J.af(s)
return r.I(s,r.gm(s)-1-b)}}
A.dV.prototype={}
A.A.prototype={$r:"+(1,2)",$s:1}
A.a.prototype={$r:"+(1,2,3)",$s:2}
A.cW.prototype={$r:"+(1,2,3,4)",$s:3}
A.aR.prototype={$r:"+run,stage,zoneId,zoneIndex(1,2,3,4)",$s:4}
A.d6.prototype={
gF(a){return this.gm(this)===0},
q(a){return A.kX(this)},
i(a,b,c){var s=A.i(this)
s.c.a(b)
s.y[1].a(c)
A.lC()},
T(a,b){A.lC()},
gb_(){return new A.bZ(this.dv(),A.i(this).j("bZ<ai<1,2>>"))},
dv(){var s=this
return function(){var r=0,q=1,p=[],o,n,m,l,k
return function $async$gb_(a,b,c){if(b===1){p.push(c)
r=q}for(;;)switch(r){case 0:o=s.ga9(),o=o.gt(o),n=A.i(s),m=n.y[1],n=n.j("ai<1,2>")
case 2:if(!o.l()){r=3
break}l=o.gp()
k=s.h(0,l)
r=4
return a.b=new A.ai(l,k==null?m.a(k):k,n),1
case 4:r=2
break
case 3:return 0
case 1:return a.c=p.at(-1),3}}}},
$ih:1}
A.br.prototype={
gm(a){return this.b.length},
gbW(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
E(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.E(b))return null
return this.b[this.a[b]]},
X(a,b){var s,r,q,p
this.$ti.j("~(1,2)").a(b)
s=this.gbW()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])},
ga9(){return new A.dJ(this.gbW(),this.$ti.j("dJ<1>"))}}
A.dJ.prototype={
gm(a){return this.a.length},
gF(a){return 0===this.a.length},
ga8(a){return 0!==this.a.length},
gt(a){var s=this.a
return new A.cs(s,s.length,this.$ti.j("cs<1>"))}}
A.cs.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c
if(r>=s.b){s.d=null
return!1}s.d=s.a[r]
s.c=r+1
return!0},
$iR:1}
A.d7.prototype={
k(a,b){A.i(this).c.a(b)
A.lD()},
T(a,b){A.lD()}}
A.c5.prototype={
gm(a){return this.b},
gF(a){return this.b===0},
ga8(a){return this.b!==0},
gt(a){var s,r=this,q=r.$keys
if(q==null){q=Object.keys(r.a)
r.$keys=q}s=q
return new A.cs(s,s.length,r.$ti.j("cs<1>"))},
A(a,b){return!1}}
A.eh.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.cd&&this.a.Y(0,b.a)&&A.lk(this)===A.lk(b)},
gK(a){return A.cK(this.a,A.lk(this),B.e,B.e)},
q(a){var s=B.a.dK([A.bJ(this.$ti.c)],", ")
return this.a.q(0)+" with "+("<"+s+">")}}
A.cd.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.pY(A.k9(this.a),this.$ti)}}
A.dx.prototype={}
A.jk.prototype={
aa(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
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
A.dv.prototype={
q(a){return"Null check operator used on a null value"}}
A.eo.prototype={
q(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.eV.prototype={
q(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.iB.prototype={
q(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.da.prototype={}
A.dP.prototype={
q(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$ibV:1}
A.ax.prototype={
q(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.n3(r==null?"unknown":r)+"'"},
$ibv:1,
ge2(){return this},
$C:"$1",
$R:1,
$D:null}
A.e4.prototype={$C:"$0",$R:0}
A.e5.prototype={$C:"$2",$R:2}
A.eQ.prototype={}
A.eO.prototype={
q(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.n3(s)+"'"}}
A.cC.prototype={
Y(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.cC))return!1
return this.$_target===b.$_target&&this.a===b.a},
gK(a){return(A.mX(this.a)^A.eJ(this.$_target))>>>0},
q(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.eK(this.a)+"'")}}
A.eN.prototype={
q(a){return"RuntimeError: "+this.a}}
A.bw.prototype={
gm(a){return this.a},
gF(a){return this.a===0},
ga9(){return new A.ad(this,A.i(this).j("ad<1>"))},
gb_(){return new A.K(this,A.i(this).j("K<1,2>"))},
E(a){var s,r
if(typeof a=="string"){s=this.b
if(s==null)return!1
return s[a]!=null}else if(typeof a=="number"&&(a&0x3fffffff)===a){r=this.c
if(r==null)return!1
return r[a]!=null}else return this.dG(a)},
dG(a){var s=this.d
if(s==null)return!1
return this.b0(this.bS(s,a),a)>=0},
B(a,b){A.i(this).j("h<1,2>").a(b).X(0,new A.ib(this))},
h(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.dH(b)},
dH(a){var s,r,q=this.d
if(q==null)return null
s=this.bS(q,a)
r=this.b0(s,a)
if(r<0)return null
return s[r].b},
i(a,b,c){var s,r,q=this,p=A.i(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.bF(s==null?q.b=q.bk():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.bF(r==null?q.c=q.bk():r,b,c)}else q.dJ(b,c)},
dJ(a,b){var s,r,q,p,o=this,n=A.i(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.bk()
r=o.bu(a)
q=s[r]
if(q==null)s[r]=[o.b8(a,b)]
else{p=o.b0(q,a)
if(p>=0)q[p].b=b
else q.push(o.b8(a,b))}},
ac(a,b){var s,r,q=this,p=A.i(q)
p.c.a(a)
p.j("2()").a(b)
if(q.E(a)){s=q.h(0,a)
return s==null?p.y[1].a(s):s}r=b.$0()
q.i(0,a,r)
return r},
T(a,b){var s=this
if(typeof b=="string")return s.bG(s.b,b)
else if(typeof b=="number"&&(b&0x3fffffff)===b)return s.bG(s.c,b)
else return s.dI(b)},
dI(a){var s,r,q,p,o=this,n=o.d
if(n==null)return null
s=o.bu(a)
r=n[s]
q=o.b0(r,a)
if(q<0)return null
p=r.splice(q,1)[0]
o.bH(p)
if(r.length===0)delete n[s]
return p.b},
V(a){var s=this
if(s.a>0){s.b=s.c=s.d=s.e=s.f=null
s.a=0
s.b7()}},
X(a,b){var s,r,q=this
A.i(q).j("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.l(A.al(q))
s=s.c}},
bF(a,b,c){var s,r=A.i(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.b8(b,c)
else s.b=c},
bG(a,b){var s
if(a==null)return null
s=a[b]
if(s==null)return null
this.bH(s)
delete a[b]
return s.b},
b7(){this.r=this.r+1&1073741823},
b8(a,b){var s=this,r=A.i(s),q=new A.ie(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else{r=s.f
r.toString
q.d=r
s.f=r.c=q}++s.a
s.b7()
return q},
bH(a){var s=this,r=a.d,q=a.c
if(r==null)s.e=q
else r.c=q
if(q==null)s.f=r
else q.d=r;--s.a
s.b7()},
bu(a){return J.aI(a)&1073741823},
bS(a,b){return a[this.bu(b)]},
b0(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aU(a[r].a,b))return r
return-1},
q(a){return A.kX(this)},
bk(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ilO:1}
A.ib.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.i(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).j("~(1,2)")}}
A.ie.prototype={}
A.ad.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.az(s,s.r,s.e,this.$ti.j("az<1>"))},
A(a,b){return this.a.E(b)}}
A.az.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.al(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iR:1}
A.am.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.M(s,s.r,s.e,this.$ti.j("M<1>"))}}
A.M.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.al(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iR:1}
A.K.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.ag(s,s.r,s.e,this.$ti.j("ag<1,2>"))}}
A.ag.prototype={
gp(){var s=this.d
s.toString
return s},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.al(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.ai(s.a,s.b,r.$ti.j("ai<1,2>"))
r.c=s.c
return!0}},
$iR:1}
A.ki.prototype={
$1(a){return this.a(a)},
$S:24}
A.kj.prototype={
$2(a,b){return this.a(a,b)},
$S:32}
A.kk.prototype={
$1(a){return this.a(A.C(a))},
$S:37}
A.b3.prototype={
q(a){return this.cb(!1)},
cb(a){var s,r,q,p,o,n=this.cU(),m=this.aK(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.b(m,q)
o=m[q]
l=a?l+A.lY(o):l+A.y(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
cU(){var s,r=this.$s
while($.jS.length<=r)B.a.k($.jS,null)
s=$.jS[r]
if(s==null){s=this.cP()
B.a.i($.jS,r,s)}return s},
cP(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.ek(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.a.i(j,q,r[s])}}j=A.eu(j,!1,k)
j.$flags=3
return j}}
A.cU.prototype={
aK(){return[this.a,this.b]},
Y(a,b){if(b==null)return!1
return b instanceof A.cU&&this.$s===b.$s&&J.aU(this.a,b.a)&&J.aU(this.b,b.b)},
gK(a){return A.cK(this.$s,this.a,this.b,B.e)}}
A.cV.prototype={
aK(){return[this.a,this.b,this.c]},
Y(a,b){var s=this
if(b==null)return!1
return b instanceof A.cV&&s.$s===b.$s&&J.aU(s.a,b.a)&&J.aU(s.b,b.b)&&J.aU(s.c,b.c)},
gK(a){var s=this
return A.cK(s.$s,s.a,s.b,s.c)}}
A.cu.prototype={
aK(){return this.a},
Y(a,b){if(b==null)return!1
return b instanceof A.cu&&this.$s===b.$s&&A.oJ(this.a,b.a)},
gK(a){return A.cK(this.$s,A.o_(this.a),B.e,B.e)}}
A.en.prototype={
q(a){return"RegExp/"+this.a+"/"+this.b.flags},
dA(a){var s=this.b.exec(a)
if(s==null)return null
return new A.jR(s)},
$iiG:1,
$ioa:1}
A.jR.prototype={
h(a,b){var s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.cH.prototype={
gO(a){return B.wY},
$iN:1}
A.dt.prototype={}
A.ew.prototype={
gO(a){return B.wZ},
$iN:1}
A.cI.prototype={
gm(a){return a.length},
$iaK:1}
A.dr.prototype={
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
i(a,b,c){A.T(c)
a.$flags&2&&A.a9(a)
A.bI(b,a,a.length)
a[b]=c},
$ix:1,
$ij:1,
$io:1}
A.ds.prototype={
i(a,b,c){A.a0(c)
a.$flags&2&&A.a9(a)
A.bI(b,a,a.length)
a[b]=c},
$ix:1,
$ij:1,
$io:1}
A.ex.prototype={
gO(a){return B.x_},
$iN:1}
A.ey.prototype={
gO(a){return B.x0},
$iN:1,
$ibu:1}
A.ez.prototype={
gO(a){return B.x1},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1}
A.eA.prototype={
gO(a){return B.x2},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1}
A.eB.prototype={
gO(a){return B.x3},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1}
A.eC.prototype={
gO(a){return B.x5},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1}
A.eD.prototype={
gO(a){return B.x6},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1}
A.du.prototype={
gO(a){return B.x7},
gm(a){return a.length},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1}
A.eE.prototype={
gO(a){return B.x8},
gm(a){return a.length},
h(a,b){A.a0(b)
A.bI(b,a,a.length)
return a[b]},
$iN:1,
$il4:1}
A.dK.prototype={}
A.dL.prototype={}
A.dM.prototype={}
A.dN.prototype={}
A.bd.prototype={
j(a){return A.dT(v.typeUniverse,this,a)},
v(a){return A.ml(v.typeUniverse,this,a)}}
A.f2.prototype={}
A.jW.prototype={
q(a){return A.aB(this.a,null)}}
A.f1.prototype={
q(a){return this.a}}
A.cX.prototype={$ibF:1}
A.jx.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:15}
A.jw.prototype={
$1(a){var s,r
this.a.a=t.M.a(a)
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:30}
A.jy.prototype={
$0(){this.a.$0()},
$S:2}
A.jz.prototype={
$0(){this.a.$0()},
$S:2}
A.jU.prototype={
cH(a,b){if(self.setTimeout!=null)self.setTimeout(A.fq(new A.jV(this,b),0),a)
else throw A.l(A.bo("`setTimeout()` not found."))}}
A.jV.prototype={
$0(){this.b.$0()},
$S:0}
A.eX.prototype={}
A.jZ.prototype={
$1(a){return this.a.$2(0,a)},
$S:58}
A.k_.prototype={
$2(a,b){this.a.$2(1,new A.da(a,t.l.a(b)))},
$S:86}
A.k5.prototype={
$2(a,b){this.a(A.a0(a),b)},
$S:88}
A.cv.prototype={
gp(){var s=this.b
return s==null?this.$ti.c.a(s):s},
d4(a,b){var s,r,q
a=A.a0(a)
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
o.d=null}q=o.d4(m,n)
if(1===q)return!0
if(0===q){o.b=null
p=o.e
if(p==null||p.length===0){o.a=A.mf
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
o.a=A.mf
throw n
return!1}if(0>=p.length)return A.b(p,-1)
o.a=p.pop()
m=1
continue}throw A.l(A.l2("sync*"))}return!1},
e4(a){var s,r,q=this
if(a instanceof A.bZ){s=a.a()
r=q.e
if(r==null)r=q.e=[]
B.a.k(r,q.a)
q.a=s
return 2}else{q.d=J.aa(a)
return 2}},
$iR:1}
A.bZ.prototype={
gt(a){return new A.cv(this.a(),this.$ti.j("cv<1>"))}}
A.b5.prototype={
q(a){return A.y(this.a)},
$iO:1,
gaH(){return this.b}}
A.cr.prototype={
dM(a){if((this.c&15)!==6)return!0
return this.b.b.bz(t.iW.a(this.d),a.a,t.y,t.K)},
dC(a){var s,r=this,q=r.e,p=null,o=t.z,n=t.K,m=a.a,l=r.b.b
if(t.ng.b(q))p=l.dT(q,m,a.b,o,n,t.l)
else p=l.bz(t.mq.a(q),m,o,n)
try{o=r.$ti.j("2/").a(p)
return o}catch(s){if(t.do.b(A.bK(s))){if((r.c&1)!==0)throw A.l(A.d3("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.l(A.d3("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.ae.prototype={
cu(a,b,c){var s,r,q=this.$ti
q.v(c).j("1/(2)").a(a)
s=$.a5
if(s===B.u){if(!t.ng.b(b)&&!t.mq.b(b))throw A.l(A.e_(b,"onError",u.c))}else{c.j("@<0/>").v(q.c).j("1(2)").a(a)
b=A.pr(b,s)}r=new A.ae(s,c.j("ae<0>"))
this.b9(new A.cr(r,3,a,b,q.j("@<1>").v(c).j("cr<1,2>")))
return r},
c9(a,b,c){var s,r=this.$ti
r.v(c).j("1/(2)").a(a)
s=new A.ae($.a5,c.j("ae<0>"))
this.b9(new A.cr(s,19,a,b,r.j("@<1>").v(c).j("cr<1,2>")))
return s},
d5(a){this.a=this.a&1|16
this.c=a},
aJ(a){this.a=a.a&30|this.a&1
this.c=a.c},
b9(a){var s,r=this,q=r.a
if(q<=3){a.a=t.F.a(r.c)
r.c=a}else{if((q&4)!==0){s=t._.a(r.c)
if((s.a&24)===0){s.b9(a)
return}r.aJ(s)}A.fo(null,null,r.b,t.M.a(new A.jD(r,a)))}},
c3(a){var s,r,q,p,o,n,m=this,l={}
l.a=a
if(a==null)return
s=m.a
if(s<=3){r=t.F.a(m.c)
m.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){n=t._.a(m.c)
if((n.a&24)===0){n.c3(a)
return}m.aJ(n)}l.a=m.aS(a)
A.fo(null,null,m.b,t.M.a(new A.jH(l,m)))}},
aR(){var s=t.F.a(this.c)
this.c=null
return this.aS(s)},
aS(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
bP(a){var s,r=this
r.$ti.c.a(a)
s=r.aR()
r.a=8
r.c=a
A.cT(r,s)},
cO(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.aR()
q.aJ(a)
A.cT(q,r)},
bc(a){var s=this.aR()
this.d5(a)
A.cT(this,s)},
bK(a){var s=this.$ti
s.j("1/").a(a)
if(s.j("bj<1>").b(a)){this.bO(a)
return}this.cN(a)},
cN(a){var s=this
s.$ti.c.a(a)
s.a^=2
A.fo(null,null,s.b,t.M.a(new A.jF(s,a)))},
bO(a){A.l6(this.$ti.j("bj<1>").a(a),this,!1)
return},
bL(a){this.a^=2
A.fo(null,null,this.b,t.M.a(new A.jE(this,a)))},
$ibj:1}
A.jD.prototype={
$0(){A.cT(this.a,this.b)},
$S:0}
A.jH.prototype={
$0(){A.cT(this.b,this.a.a)},
$S:0}
A.jG.prototype={
$0(){A.l6(this.a.a,this.b,!0)},
$S:0}
A.jF.prototype={
$0(){this.a.bP(this.b)},
$S:0}
A.jE.prototype={
$0(){this.a.bc(this.b)},
$S:0}
A.jK.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.dS(t.mY.a(q.d),t.z)}catch(p){s=A.bK(p)
r=A.cy(p)
if(k.c&&t.t.a(k.b.a.c).a===s){q=k.a
q.c=t.t.a(k.b.a.c)}else{q=s
o=r
if(o==null)o=A.kS(q)
n=k.a
n.c=new A.b5(q,o)
q=n}q.b=!0
return}if(j instanceof A.ae&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=t.t.a(j.c)
q.b=!0}return}if(j instanceof A.ae){m=k.b.a
l=new A.ae(m.b,m.$ti)
j.cu(new A.jL(l,m),new A.jM(l),t.r)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.jL.prototype={
$1(a){this.a.cO(this.b)},
$S:15}
A.jM.prototype={
$2(a,b){A.dW(a)
t.l.a(b)
this.a.bc(new A.b5(a,b))},
$S:148}
A.jJ.prototype={
$0(){var s,r,q,p,o,n,m,l
try{q=this.a
p=q.a
o=p.$ti
n=o.c
m=n.a(this.b)
q.c=p.b.b.bz(o.j("2/(1)").a(p.d),m,o.j("2/"),n)}catch(l){s=A.bK(l)
r=A.cy(l)
q=s
p=r
if(p==null)p=A.kS(q)
o=this.a
o.c=new A.b5(q,p)
o.b=!0}},
$S:0}
A.jI.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=t.t.a(l.a.a.c)
p=l.b
if(p.a.dM(s)&&p.a.e!=null){p.c=p.a.dC(s)
p.b=!1}}catch(o){r=A.bK(o)
q=A.cy(o)
p=t.t.a(l.a.a.c)
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.kS(p)
m=l.b
m.c=new A.b5(p,n)
p=m}p.b=!0}},
$S:0}
A.eY.prototype={}
A.fi.prototype={}
A.dU.prototype={$im9:1}
A.fe.prototype={
dU(a){var s,r,q
t.M.a(a)
try{if(B.u===$.a5){a.$0()
return}A.mC(null,null,this,a,t.r)}catch(q){s=A.bK(q)
r=A.cy(q)
A.le(A.dW(s),t.l.a(r))}},
df(a){return new A.jT(this,t.M.a(a))},
h(a,b){return null},
dS(a,b){b.j("0()").a(a)
if($.a5===B.u)return a.$0()
return A.mC(null,null,this,a,b)},
bz(a,b,c,d){c.j("@<0>").v(d).j("1(2)").a(a)
d.a(b)
if($.a5===B.u)return a.$1(b)
return A.pt(null,null,this,a,b,c,d)},
dT(a,b,c,d,e,f){d.j("@<0>").v(e).v(f).j("1(2,3)").a(a)
e.a(b)
f.a(c)
if($.a5===B.u)return a.$2(b,c)
return A.ps(null,null,this,a,b,c,d,e,f)},
cr(a,b,c,d){return b.j("@<0>").v(c).v(d).j("1(2,3)").a(a)}}
A.jT.prototype={
$0(){return this.a.dU(this.b)},
$S:0}
A.k4.prototype={
$0(){A.nM(this.a,this.b)},
$S:0}
A.bp.prototype={
gt(a){var s=this,r=new A.Q(s,s.r,A.i(s).j("Q<1>"))
r.c=s.e
return r},
gm(a){return this.a},
gF(a){return this.a===0},
ga8(a){return this.a!==0},
A(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.R.a(s[b])!=null}else if(typeof b=="number"&&(b&1073741823)===b){r=this.c
if(r==null)return!1
return t.R.a(r[b])!=null}else return this.cQ(b)},
cQ(a){var s=this.d
if(s==null)return!1
return this.bi(s[this.bd(a)],a)>=0},
gu(a){var s=this.e
if(s==null)throw A.l(A.l2("No elements"))
return A.i(this).c.a(s.a)},
gM(a){var s=this.f
if(s==null)throw A.l(A.l2("No elements"))
return A.i(this).c.a(s.a)},
k(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.bI(s==null?q.b=A.l7():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.bI(r==null?q.c=A.l7():r,b)}else return q.cI(b)},
cI(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.l7()
r=p.bd(a)
q=s[r]
if(q==null)s[r]=[p.bl(a)]
else{if(p.bi(q,a)>=0)return!1
q.push(p.bl(a))}return!0},
T(a,b){var s=this
if(typeof b=="string"&&b!=="__proto__")return s.c6(s.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return s.c6(s.c,b)
else return s.d2(b)},
d2(a){var s,r,q,p,o=this,n=o.d
if(n==null)return!1
s=o.bd(a)
r=n[s]
q=o.bi(r,a)
if(q<0)return!1
p=r.splice(q,1)[0]
if(0===r.length)delete n[s]
o.cc(p)
return!0},
bI(a,b){A.i(this).c.a(b)
if(t.R.a(a[b])!=null)return!1
a[b]=this.bl(b)
return!0},
c6(a,b){var s
if(a==null)return!1
s=t.R.a(a[b])
if(s==null)return!1
this.cc(s)
delete a[b]
return!0},
bj(){this.r=this.r+1&1073741823},
bl(a){var s,r=this,q=new A.f8(A.i(r).c.a(a))
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.c=s
r.f=s.b=q}++r.a
r.bj()
return q},
cc(a){var s=this,r=a.c,q=a.b
if(r==null)s.e=q
else r.b=q
if(q==null)s.f=r
else q.c=r;--s.a
s.bj()},
bd(a){return J.aI(a)&1073741823},
bi(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aU(a[r].a,b))return r
return-1},
$ilP:1}
A.f8.prototype={}
A.Q.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.l(A.al(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.j("1?").a(r.a)
s.c=r.b
return!0}},
$iR:1}
A.ih.prototype={
$2(a,b){this.a.i(0,this.b.a(a),this.c.a(b))},
$S:122}
A.F.prototype={
gt(a){return new A.aL(a,this.gm(a),A.av(a).j("aL<F.E>"))},
I(a,b){return this.h(a,b)},
gF(a){return this.gm(a)===0},
ga8(a){return!this.gF(a)},
gu(a){if(this.gm(a)===0)throw A.l(A.at())
return this.h(a,0)},
gM(a){if(this.gm(a)===0)throw A.l(A.at())
return this.h(a,this.gm(a)-1)},
Z(a,b){var s,r
A.av(a).j("u(F.E)").a(b)
s=this.gm(a)
for(r=0;r<s;++r){if(b.$1(this.h(a,r)))return!0
if(s!==this.gm(a))throw A.l(A.al(a))}return!1},
ag(a,b,c){var s,r,q,p=A.av(a)
p.j("u(F.E)").a(b)
p.j("F.E()?").a(c)
s=this.gm(a)
for(r=0;r<s;++r){q=this.h(a,r)
if(b.$1(q))return q
if(s!==this.gm(a))throw A.l(A.al(a))}p=c.$0()
return p},
aF(a,b,c){var s=A.av(a)
return new A.r(a,s.v(c).j("1(F.E)").a(b),s.j("@<F.E>").v(c).j("r<1,2>"))},
W(a,b,c,d){var s,r,q
d.a(b)
A.av(a).v(d).j("1(1,F.E)").a(c)
s=this.gm(a)
for(r=b,q=0;q<s;++q){r=c.$2(r,this.h(a,q))
if(s!==this.gm(a))throw A.l(A.al(a))}return r},
a3(a,b){return A.bW(a,b,null,A.av(a).j("F.E"))},
ap(a){var s,r=A.et(A.av(a).j("F.E"))
for(s=0;s<this.gm(a);++s)r.k(0,this.h(a,s))
return r},
k(a,b){var s
A.av(a).j("F.E").a(b)
s=this.gm(a)
this.sm(a,s+1)
this.i(a,s,b)},
aX(a,b){return new A.ab(a,A.av(a).j("@<F.E>").v(b).j("ab<1,2>"))},
gcs(a){return new A.bn(a,A.av(a).j("bn<F.E>"))},
q(a){return A.kU(a,"[","]")}}
A.a2.prototype={
X(a,b){var s,r,q,p=A.i(this)
p.j("~(a2.K,a2.V)").a(b)
for(s=this.ga9(),s=s.gt(s),p=p.j("a2.V");s.l();){r=s.gp()
q=this.h(0,r)
b.$2(r,q==null?p.a(q):q)}},
gb_(){return this.ga9().aF(0,new A.ij(this),A.i(this).j("ai<a2.K,a2.V>"))},
E(a){return this.ga9().A(0,a)},
gm(a){var s=this.ga9()
return s.gm(s)},
gF(a){var s=this.ga9()
return s.gF(s)},
q(a){return A.kX(this)},
$ih:1}
A.ij.prototype={
$1(a){var s=this.a,r=A.i(s)
r.j("a2.K").a(a)
s=s.h(0,a)
if(s==null)s=r.j("a2.V").a(s)
return new A.ai(a,s,r.j("ai<a2.K,a2.V>"))},
$S(){return A.i(this.a).j("ai<a2.K,a2.V>(a2.K)")}}
A.ik.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.y(a)
r.a=(r.a+=s)+": "
s=A.y(b)
r.a+=s},
$S:11}
A.bU.prototype={
gF(a){return this.gm(this)===0},
ga8(a){return this.gm(this)!==0},
B(a,b){var s
for(s=J.aa(A.i(this).j("j<1>").a(b));s.l();)this.k(0,s.gp())},
q(a){return A.kU(this,"{","}")},
dw(a,b){var s
A.i(this).j("u(1)").a(b)
for(s=this.gt(this);s.l();)if(!b.$1(s.gp()))return!1
return!0},
a3(a,b){return A.m4(this,b,A.i(this).c)},
gu(a){var s=this.gt(this)
if(!s.l())throw A.l(A.at())
return s.gp()},
gM(a){var s,r=this.gt(this)
if(!r.l())throw A.l(A.at())
do s=r.gp()
while(r.l())
return s},
I(a,b){var s,r
A.cO(b,"index")
s=this.gt(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.l(A.i9(b,b-r,this,"index"))},
$ix:1,
$ij:1,
$ib0:1}
A.dO.prototype={}
A.f4.prototype={
h(a,b){var s,r=this.b
if(r==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.d0(b):s}},
gm(a){return this.b==null?this.c.a:this.aC().length},
gF(a){return this.gm(0)===0},
ga9(){if(this.b==null){var s=this.c
return new A.ad(s,A.i(s).j("ad<1>"))}return new A.f5(this)},
i(a,b,c){var s,r,q=this
A.C(b)
if(q.b==null)q.c.i(0,b,c)
else if(q.E(b)){s=q.b
s[b]=c
r=q.a
if(r==null?s!=null:r!==s)r[b]=null}else q.cd().i(0,b,c)},
E(a){if(this.b==null)return this.c.E(a)
if(typeof a!="string")return!1
return Object.prototype.hasOwnProperty.call(this.a,a)},
T(a,b){if(this.b!=null&&!this.E(b))return null
return this.cd().T(0,b)},
X(a,b){var s,r,q,p,o=this
t.lc.a(b)
if(o.b==null)return o.c.X(0,b)
s=o.aC()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.k1(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.l(A.al(o))}},
aC(){var s=t.O.a(this.c)
if(s==null)s=this.c=A.d(Object.keys(this.a),t.s)
return s},
cd(){var s,r,q,p,o,n=this
if(n.b==null)return n.c
s=A.m(t.N,t.z)
r=n.aC()
for(q=0;p=r.length,q<p;++q){o=r[q]
s.i(0,o,n.h(0,o))}if(p===0)B.a.k(r,"")
else B.a.V(r)
n.a=n.b=null
return n.c=s},
d0(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.k1(this.a[a])
return this.b[a]=s}}
A.f5.prototype={
gm(a){return this.a.gm(0)},
I(a,b){var s=this.a
if(s.b==null)s=s.ga9().I(0,b)
else{s=s.aC()
if(!(b>=0&&b<s.length))return A.b(s,b)
s=s[b]}return s},
gt(a){var s=this.a
if(s.b==null){s=s.ga9()
s=s.gt(s)}else{s=s.aC()
s=new J.c3(s,s.length,A.q(s).j("c3<1>"))}return s},
A(a,b){return this.a.E(b)}}
A.d4.prototype={
gbs(){return B.cM}}
A.fz.prototype={
br(a){var s
t.J.a(a)
s=a.length
if(s===0)return""
s=new A.jB("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/").du(a,0,s,!0)
s.toString
return A.oh(s)}}
A.jB.prototype={
du(a,b,c,d){var s,r,q,p,o
t.J.a(a)
s=this.a
r=(s&3)+(c-b)
q=B.c.bn(r,3)
p=q*4
if(r-q*3>0)p+=4
o=new Uint8Array(p)
this.a=A.oy(this.b,a,b,c,!0,o,0,s)
if(p>0)return o
return null}}
A.fy.prototype={
br(a){var s,r,q,p=A.m2(0,null,a.length)
if(0===p)return new Uint8Array(0)
s=new A.jA()
r=s.dm(a,0,p)
r.toString
q=s.a
if(q<-1)A.bq(A.b8("Missing padding character",a,p))
if(q>0)A.bq(A.b8("Invalid length, must be multiple of four",a,p))
s.a=-1
return r}}
A.jA.prototype={
dm(a,b,c){var s,r=this,q=r.a
if(q<0){r.a=A.ma(a,b,c,q)
return null}if(b===c)return new Uint8Array(0)
s=A.ov(a,b,c,q)
r.a=A.ox(a,b,c,s,0,r.a)
return s}}
A.bN.prototype={}
A.e7.prototype={}
A.dk.prototype={
q(a){var s=A.eb(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.eq.prototype={
q(a){return"Cyclic error in JSON stringify"}}
A.ep.prototype={
dl(a,b){var s=A.pp(a,this.gdn().a)
return s},
dt(a,b){var s=A.oA(a,this.gbs().b,null)
return s},
gbs(){return B.dc},
gdn(){return B.db}}
A.id.prototype={}
A.ic.prototype={}
A.jP.prototype={
cA(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.k.ar(a,r,q)
r=q+1
o=A.ap(92)
s.a+=o
o=A.ap(117)
s.a+=o
o=A.ap(100)
s.a+=o
o=p>>>8&15
o=A.ap(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.ap(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.ap(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.k.ar(a,r,q)
r=q+1
o=A.ap(92)
s.a+=o
switch(p){case 8:o=A.ap(98)
s.a+=o
break
case 9:o=A.ap(116)
s.a+=o
break
case 10:o=A.ap(110)
s.a+=o
break
case 12:o=A.ap(102)
s.a+=o
break
case 13:o=A.ap(114)
s.a+=o
break
default:o=A.ap(117)
s.a+=o
o=A.ap(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.ap(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.ap(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.k.ar(a,r,q)
r=q+1
o=A.ap(92)
s.a+=o
o=A.ap(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.k.ar(a,r,m)},
bb(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.l(new A.eq(a,null))}B.a.k(s,a)},
b5(a){var s,r,q,p,o=this
if(o.cz(a))return
o.bb(a)
try{s=o.b.$1(a)
if(!o.cz(s)){q=A.lM(a,null,o.gc0())
throw A.l(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.bK(p)
q=A.lM(a,r,o.gc0())
throw A.l(q)}},
cz(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.q(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.cA(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.bb(a)
q.e0(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return!0}else if(t.av.b(a)){q.bb(a)
r=q.e1(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return r}else return!1},
e0(a){var s,r,q=this.c
q.a+="["
s=J.af(a)
if(s.ga8(a)){this.b5(s.h(a,0))
for(r=1;r<s.gm(a);++r){q.a+=","
this.b5(s.h(a,r))}}q.a+="]"},
e1(a){var s,r,q,p,o,n,m=this,l={}
if(a.gF(a)){m.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.b9(s,null,!1,t.iD)
q=l.a=0
l.b=!0
a.X(0,new A.jQ(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.cA(A.C(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.b(r,n)
m.b5(r[n])}p.a+="}"
return!0}}
A.jQ.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.i(s,r.a++,a)
B.a.i(s,r.a++,b)},
$S:11}
A.jO.prototype={
gc0(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.bs.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.bs&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gK(a){return A.cK(this.a,this.b,B.e,B.e)},
S(a,b){var s
t.cs.a(b)
s=B.c.S(this.a,b.a)
if(s!==0)return s
return B.c.S(this.b,b.b)},
q(a){var s=this,r=A.lE(A.eI(s)),q=A.bt(A.lW(s)),p=A.bt(A.lS(s)),o=A.bt(A.lT(s)),n=A.bt(A.lV(s)),m=A.bt(A.lX(s)),l=A.h7(A.lU(s)),k=s.b,j=k===0?"":A.h7(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
bB(){var s=this,r=A.eI(s)>=-9999&&A.eI(s)<=9999?A.lE(A.eI(s)):A.nD(A.eI(s)),q=A.bt(A.lW(s)),p=A.bt(A.lS(s)),o=A.bt(A.lT(s)),n=A.bt(A.lV(s)),m=A.bt(A.lX(s)),l=A.h7(A.lU(s)),k=s.b,j=k===0?"":A.h7(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iaJ:1}
A.h8.prototype={
$1(a){if(a==null)return 0
return A.fs(a)},
$S:12}
A.h9.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.b(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:12}
A.c9.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.c9},
gK(a){return B.c.gK(0)},
S(a,b){t.jS.a(b)
return 0},
q(a){return"0:00:00."+B.k.dP(B.c.q(0),6,"0")},
$iaJ:1}
A.f0.prototype={
q(a){return this.G()},
$iZ:1}
A.O.prototype={
gaH(){return A.o3(this)}}
A.e0.prototype={
q(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.eb(s)
return"Assertion failed"}}
A.bF.prototype={}
A.bf.prototype={
gbh(){return"Invalid argument"+(!this.a?"(s)":"")},
gbg(){return""},
q(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gbh()+q+o
if(!s.a)return n
return n+s.gbg()+": "+A.eb(s.gbv())},
gbv(){return this.b}}
A.dw.prototype={
gbv(){return A.w(this.b)},
gbh(){return"RangeError"},
gbg(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.y(q):""
else if(q==null)s=": Not greater than or equal to "+A.y(r)
else if(q>r)s=": Not in inclusive range "+A.y(r)+".."+A.y(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.y(r)
return s}}
A.eg.prototype={
gbv(){return A.a0(this.b)},
gbh(){return"RangeError"},
gbg(){if(A.a0(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gm(a){return this.f}}
A.dF.prototype={
q(a){return"Unsupported operation: "+this.a}}
A.eT.prototype={
q(a){return"UnimplementedError: "+this.a}}
A.dC.prototype={
q(a){return"Bad state: "+this.a}}
A.e6.prototype={
q(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.eb(s)+"."}}
A.eG.prototype={
q(a){return"Out of Memory"},
gaH(){return null},
$iO:1}
A.dB.prototype={
q(a){return"Stack Overflow"},
gaH(){return null},
$iO:1}
A.jC.prototype={
q(a){return"Exception: "+this.a}}
A.dc.prototype={
q(a){var s,r,q,p,o,n,m,l,k,j,i,h=this.a,g=""!==h?"FormatException: "+h:"FormatException",f=this.c,e=this.b
if(typeof e=="string"){if(f!=null)s=f<0||f>e.length
else s=!1
if(s)f=null
if(f==null){if(e.length>78)e=B.k.ar(e,0,75)+"..."
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
k=""}return g+l+B.k.ar(e,i,j)+k+"\n"+B.k.aq(" ",f-i+l.length)+"^\n"}else return f!=null?g+(" (at offset "+A.y(f)+")"):g}}
A.j.prototype={
aX(a,b){return A.lz(this,A.i(this).j("j.E"),b)},
aF(a,b,c){var s=A.i(this)
return A.kY(this,s.v(c).j("1(j.E)").a(b),s.j("j.E"),c)},
W(a,b,c,d){var s,r
d.a(b)
A.i(this).v(d).j("1(1,j.E)").a(c)
for(s=this.gt(this),r=b;s.l();)r=c.$2(r,s.gp())
return r},
Z(a,b){var s
A.i(this).j("u(j.E)").a(b)
for(s=this.gt(this);s.l();)if(b.$1(s.gp()))return!0
return!1},
gm(a){var s,r=this.gt(this)
for(s=0;r.l();)++s
return s},
gF(a){return!this.gt(this).l()},
ga8(a){return!this.gF(this)},
a3(a,b){return A.m4(this,b,A.i(this).j("j.E"))},
gu(a){var s=this.gt(this)
if(!s.l())throw A.l(A.at())
return s.gp()},
gM(a){var s,r=this.gt(this)
if(!r.l())throw A.l(A.at())
do s=r.gp()
while(r.l())
return s},
ag(a,b,c){var s,r
A.i(this).j("u(j.E)").a(b)
for(s=this.gt(this);s.l();){r=s.gp()
if(b.$1(r))return r}throw A.l(A.at())},
dB(a,b){return this.ag(0,b,null)},
I(a,b){var s,r
A.cO(b,"index")
s=this.gt(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.l(A.i9(b,b-r,this,"index"))},
q(a){return A.nR(this,"(",")")}}
A.ai.prototype={
q(a){return"MapEntry("+A.y(this.a)+": "+A.y(this.b)+")"}}
A.an.prototype={
gK(a){return A.I.prototype.gK.call(this,0)},
q(a){return"null"}}
A.I.prototype={$iI:1,
Y(a,b){return this===b},
gK(a){return A.eJ(this)},
q(a){return"Instance of '"+A.eK(this)+"'"},
gO(a){return A.pR(this)},
toString(){return this.q(this)}}
A.fj.prototype={
q(a){return""},
$ibV:1}
A.cQ.prototype={
gm(a){return this.a.length},
q(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$iog:1}
A.i7.prototype={
gbT(){var s,r=this.a
A:{if("pt"===r){s=0
break A}if("es"===r){s=2
break A}s=1
break A}return s},
$2(a,b){var s,r,q,p={}
A.C(a)
t.md.a(b)
s=B.dI.h(0,a)
if(s==null)r=a
else if(this.gbT()===0){q=s.a
r=q}else{q=this.gbT()===1?s.b:s.c
r=q}p.a=r
if(b!=null)b.X(0,new A.i8(p))
return p.a},
$1(a){return this.$2(a,null)}}
A.i8.prototype={
$2(a,b){var s,r
A.C(a)
A.C(b)
s=this.a
r=s.a
return s.a=A.qb(r,"{"+a+"}",b)},
$S:119}
A.hc.prototype={
n(){var s=this
return A.S(["project",s.a,"lang",s.b,"sizeZones",s.c,"sizeMain",s.d],t.N,t.z)}}
A.hd.prototype={
n(){var s=this.a.n(),r=this.b,q=A.q(r),p=q.j("r<1,h<c,@>>")
r=A.p(new A.r(r,q.j("h<c,@>(1)").a(new A.he()),p),p.j("t.E"))
return A.S(["results",s,"entities",r,"nextId",this.c],t.N,t.z)}}
A.he.prototype={
$1(a){return t.h.a(a).n()},
$S:13}
A.ku.prototype={
$1(a){return this.a.$1(A.C(a))},
$S:100}
A.kv.prototype={
$1(a){var s=A.m(t.N,t.z)
J.kQ(s,"type","progress")
J.lr(s,a.n())
return this.a.$1(s)},
$S:91}
A.bg.prototype={
G(){return"DesignStage."+this.b}}
A.c7.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"stage",r.a.b)
q.i(0,"done",r.b)
q.i(0,"total",r.c)
s=r.d
if(s!=null)q.i(0,"zone",s)
q.i(0,"zi",r.e)
q.i(0,"zn",r.f)
return q},
q(a){var s=this,r=s.d==null?"":" zone "+s.e+"/"+s.f
return"DesignProgress("+s.a.b+" "+s.b+"/"+s.c+r+")"}}
A.e9.prototype={
ak(a){var s=this.c.c.h(0,a)
s=s==null?null:s.a
return s==null?this.c.e.h(0,a):s},
cf(a){var s,r,q,p,o,n,m,l=null,k=this.a,j=k.c,i=j.N(a.at),h=i==null,g=h?l:i.f
if(g==null)g=a.ax
k=k.b
s=h?l:i.w
if(s==null)s=a.ay
h=h?l:i.x
if(h==null)h=0.15
r=new A.iM(a.z,a.d,a.x,a.Q,a.as,g,s*k.cx+k.cy,h,k.b,A.fu(k.c),a.ch,a.CW,a.cx,a.cy,a.db,a.dx,a.dy,a.fr,a.fx,a.fy,a.go,Math.max(k.e,3))
q=this.c.Q
p=q==null||q.c.length===0?l:A.pT(r,a.w,a.y*3.141592653589793/180,q.gds())
o=a.c
if(!(o.length!==0)){k=a.k1
o=k.length!==0?k:this.b.$1("tool.pivot")}k=A.d([],t.dD)
j=j.a0(a.e)
j=j==null?l:j.f
if(j==null)j=B.dw
h=j.length
n=0
for(;n<j.length;j.length===h||(0,A.k)(j),++n){m=j[n]
k.push(new A.A(m.b,m.c))}return A.pC(r,p,a.a,o,k)},
be(a){var s,r,q,p,o=this
if(o.c.e.E(a)){s=o.a.a6(a)
if(!(s instanceof A.b_))return B.bp
r=o.d.d
q=r.h(0,a)
if(q==null)q=o.cf(s)
r.i(0,a,q)
return new A.A(q.e,q.r)}r=o.d.c
p=r.h(0,a)
if(p==null)p=o.az(a)
r.i(0,a,p)
return new A.A(p.d,p.r)},
aU(a){var s=this.e.h(0,a.f)
if(s==null)s=a.x
return this.a.c.N(s)},
au(a){var s,r,q=a.y
if(q!=null)return this.a.c.ad(q).f/1000
s=this.aU(a)
if(s!=null)return s.f/1000
r=this.a.c.ab(a.Q)
return r.length===0?0.05:B.a.gu(r).f/1000},
aw(a){var s
switch(a.Q.a){case 0:s=this.a.b.f
break
case 1:s=this.a.b.d
break
case 2:s=this.a.b.e
break
default:s=null}return s},
bf(a){var s=this.a.b
s=s.w&&a.Q!==B.p?1+s.r/100:1
return Math.max(a.w*s,0.001)},
ca(a){var s,r,q,p,o,n,m,l,k,j=this,i=null
switch(a.d.a){case 0:s=j.a
r=s.c.ad(a.y)
q=j.aU(a)
s=s.b
p=r==null
o=p?i:r.CW
if(o==null)o=q==null?i:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?i:q.x/1000
n=p==null?0.0000015:p}p=j.au(a)
m=j.bf(a)
l=s.w?a.as:0
return A.ec(!1,i,p,a.b,o*s.cx+s.cy,a.a,B.ah,m,l,0,i,n,a,a.c)
case 1:q=j.a.c.a2(a.ay)
s=q==null?i:q.r
if(s==null)s=B.aQ
return A.ec(!1,s,0.05,a.b,150,a.a,B.bb,1,0,0,i,0.0000015,a,a.c)
case 3:q=j.a.c.a2(a.ay)
s=q==null
k=s?i:q.r
if(k==null)k=B.a1
p=k.a>0?k:B.aQ
return A.ec((s?i:q.e)===B.aJ,p,0.05,a.b,150,a.a,B.bb,1,0,0,i,0.0000015,a,a.c)
case 4:q=j.a.c.a2(a.ay)
s=q==null?i:q.r
return A.ec(!1,s,0.05,a.b,150,a.a,B.K,1,0,a.ax,i,0.0000015,a,a.c)
case 2:q=j.a.c.aG(a.ch)
if(q==null)s=i
else{s=q.r
s=new A.cN(s.a,s.b,s.c,a.CW)}return A.ec(!1,i,0.05,a.b,150,a.a,B.ba,1,0,0,s,0.0000015,a,a.c)}},
bX(a,b,c){var s,r,q,p
if(c<=0)return 0
s=this.a.b
r=b.f/1000
q=this.bf(a)
p=A.mN(b.w*s.cx+s.cy,r,c,A.fu(s.c),q,s.b,b.x/1000)
return p+(s.w&&a.as>0?A.mW(r,c,a.as):0)},
bQ(a,b){var s,r,q,p,o,n,m,l,k=this
if(b<=0)return 0
s=k.a
r=s.c.ad(a.y)
q=k.aU(a)
s=s.b
p=r==null
o=p?null:r.CW
if(o==null)o=q==null?null:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?null:q.x/1000
n=p==null?0.0000015:p}m=k.au(a)
p=k.bf(a)
l=A.mN(o*s.cx+s.cy,m,b,A.fu(s.c),p,s.b,n)
return l+(s.w&&a.as>0?A.mW(m,b,a.as):0)},
aP(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.Q.a(c)
s=A.S([a,null],t.N,t.B)
r=A.d([a],t.s)
for(q=0;q<r.length;q=p){p=q+1
o=r[q]
if(o===b)break
for(n=this.c.a.h(0,o).w,m=n.length,l=0;l<n.length;n.length===m||(0,A.k)(n),++l){k=n[l]
if(!c.A(0,k.a))continue
j=k.b
if(o===j)j=k.c
if(!s.E(j)){s.i(0,j,k)
B.a.k(r,j)}}}if(!s.E(b))return B.du
i=A.d([],t.I)
for(h=b;h!==a;){n=s.h(0,h)
n.toString
B.a.k(i,n)
g=n.b
h=h===g?n.c:g}n=t.g9
n=A.p(new A.bn(i,n),n.j("t.E"))
return n},
aI(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.bq.a(a)
t.Q.a(b)
s=t.N
r=A.m(s,t.B)
q=A.m(s,s)
p=A.m(s,t.S)
o=A.d([],t.s)
for(s=J.aa(a);s.l();){n=s.gp()
r.i(0,n,null)
q.i(0,n,n)
p.i(0,n,0)
B.a.k(o,n)}for(m=0;m<o.length;m=l){l=m+1
k=o[m]
for(s=this.c.a.h(0,k).w,n=s.length,j=0;j<s.length;s.length===n||(0,A.k)(s),++j){i=s[j]
if(!b.A(0,i.a))continue
h=i.b
if(k===h)h=i.c
if(!r.E(h)){r.i(0,h,i)
g=q.h(0,k)
g.toString
q.i(0,h,g)
g=p.h(0,k)
g.toString
p.i(0,h,g+1)
B.a.k(o,h)}}}return new A.a(r,q,p)},
c1(a,b){var s,r,q,p
t.c8.a(a)
s=A.d([],t.I)
for(r=b;;){q=a.h(0,r)
if(q==null)break
B.a.k(s,q)
p=q.b
r=r===p?q.c:p}return s},
aO(a,b){var s,r,q,p
t.d.a(b)
for(s=b.length,r=a.f+1e-9,q=0;q<s;++q){p=b[q]
if(p.f>r)return p}return null},
R(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a.b
e=A.lQ(A.fu(e.c),e.b)
s=t.N
r=A.m(s,t.b)
q=A.d([],t.lp)
p=new A.ee(e,r,q)
o=f.c.c.h(0,a).b
n=f.c.f.h(0,a)
if(n==null)n=A.J(s)
for(e=A.aq(n,n.r,A.i(n).c),m=e.$ti.c;e.l();){l=e.d
if(l==null)l=m.a(l)
k=f.c.a.h(0,l)
k.toString
if(l===o){j=k.Q
i=j==null
h=i?k.c-k.e:j
r.i(0,l,new A.bk(l,B.T,h,(i?k.c-k.e:j)+b,null,1,0))
continue}j=k.Q
g=new A.bk(l,B.S,j==null?k.c-k.e:j,null,null,1,0)
r.i(0,l,g)
f.bM(p,g,k,c)}e=f.c.r.h(0,a)
if(e==null)e=A.J(s)
e=A.aq(e,e.r,A.i(e).c)
s=e.$ti.c
while(e.l()){r=e.d
if(r==null)r=s.a(r)
r=f.c.ah(r)
r.toString
B.a.k(q,f.ca(r))}return p},
bM(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=c.f,e=f.length
if(e===0)return
if(!d){b.d=B.a.W(f,0,new A.hr(),t.i)
return}for(s=a.b,r=c.a,q=a.c,p=r+"_s",o=c.c,n=!0,m=0,l=0;l<f.length;f.length===e||(0,A.k)(f),++l){k=f[l]
if(n){b.f=k.c
b.r=k.d
b.w=k.x
n=!1}else{j=k.c
if(b.f===j&&Math.abs(b.w-k.x)<1e-9)b.r=b.r+k.d
else{i=m+1
h=p+m
g=c.Q
if(g==null)g=o-c.e
s.i(0,h,new A.bk(h,B.S,g,null,j,k.d,k.x))
B.a.k(q,new A.dd("sat_"+h,r,h,B.ah,0.5,0.01,150,0.0000015,0,!1,null,null,0,B.n))
m=i}}}},
aN(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this.c.f.h(0,a)
if(d==null)d=A.J(t.N)
d=A.aq(d,d.r,A.i(d).c)
s=this.a
r=b.c
q=d.$ti.c
p=0
o=0
n=0
while(d.l()){m=d.d
if(m==null)m=q.a(m)
l=this.c.a.h(0,m)
l.toString
m=r.h(0,m)
k=m==null?null:m.a
if(k==null)continue
for(m=l.f,j=m.length,i=l.c,h=0;h<m.length;m.length===j||(0,A.k)(m),++h){g=m[h]
f=g.b
if(f===-2)continue
e=g.a
if(e.length!==0&&s.a6(e) instanceof A.aA&&f!==0)continue
f=l.Q
if(f==null)f=i-l.e
e=g.d
p+=(k-(f+g.x))*e
o+=g.e*e
n+=e}}if(n===0)return B.bp
return new A.A(p/n,o/n)},
af(g3,g4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8=f6.a,f9=t.e.a(f8.a6(g3)),g0=t.s,g1=A.d([],g0),g2=f9==null
if(g2||!f6.c.c.E(g3)){f8=g2?f7:f9.f
if(f8==null)f8=""
return f6.bR(g3,f8,A.d(["valve_missing"],g0))}s=f6.c.c.h(0,g3)
r=s.a
q=s.b
g2=f6.c.a.h(0,q)
g2.toString
p=f6.c.f.h(0,g3)
if(p==null)p=A.J(t.N)
if(p.a>1){o=f6.c.r.h(0,g3)
o=o==null?f7:o.a===0
o=o!==!1}else o=!0
if(o)return f6.bR(g3,f9.f,A.d(["zone_empty"],g0))
n=f9.w
g0=n==null
if(!g0)m=f6.R(g3,n,g4).H()
else if(!g4){l=f6.aN(g3,f6.R(g3,10,!1).H())
n=10+(l.b-l.a)
m=f6.R(g3,n,!1).H()}else{k=f6.aN(g3,f6.R(g3,10,!1).H()).b
j=Math.max(k*3,5)
m=f6.R(g3,j,!0).H()
i=0
for(;;){if(!(f6.aN(g3,m).a<k&&i<20))break
j*=2
m=f6.R(g3,j,!0).H();++i}for(h=0,g=0;g<28;++g){f=(h+j)/2
if(f6.aN(g3,f6.R(g3,f,!0).H()).a>k)j=f
else h=f
if(j-h<0.001)break}n=(h+j)/2
m=f6.R(g3,n,!0).H()
g4=!0}if(!m.a)B.a.k(g1,"not_converged")
if(g0){g0=f6.d_(g3,m).a
e=g0[0]
d=g0[1]
c=g0[2]
b=g0[3]
if(d-e<=b-c+1e-9)g0=e<c-0.000001||d>b+0.000001
else g0=!1
if(g0){n+=(c+b)/2-(e+d)/2
m=f6.R(g3,n,g4).H()}}a=A.d([],t.w)
a0=A.d([],t.n)
for(g0=A.aq(p,p.r,A.i(p).c),o=m.c,a1=g0.$ti.c,a2=0,a3=1/0,a4=-1/0,a5=-1/0,a6=1/0,a7=0,a8=0,a9=0,b0=0;g0.l();){b1=g0.d
if(b1==null)b1=a1.a(b1)
b2=f6.c.a.h(0,b1)
b2.toString
b3=o.h(0,b1)
if(b3==null)continue
for(b1=b2.f,b4=b1.length,b5=b2.b,b6=b3.a,b7=b2.c,b8=0;b8<b1.length;b1.length===b4||(0,A.k)(b1),++b8){b9=b1[b8]
c0=b2.Q
if(c0==null)c0=b7-b2.e
c1=b9.x
c2=b6-(c0+c1)
c0=b9.c
c3=g4?c0.a7(Math.max(c2,0)):c0.a7(b9.e)
c4=b9.d
a2+=c3*c4
c5=b9.b
if(c5===-2)continue
c6=b2.Q
if(c6==null)c6=b7-b2.e
c7=b9.e
c8=b9.f
c9=b9.r
B.a.k(a,new A.au(b9.a,c5,b5,c6+c1,c2,c3,c0.a7(c7),c4,c8,c9,b9.y))
for(d0=0;d0<c4;++d0)B.a.k(a0,c0.a7(Math.max(c2,0)))
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
b1=a1.ok
if(b1>0&&d1>0){b1/=200
a5=Math.max(a5,d1*(1-b1))
a6=Math.min(a6,d1*(1+b1))}d2=g0?a9/a8:0
d3=f6.cS(a)
d4=A.op(a0,d3,d2)
d5=A.d([],t.A)
d6=A.d([],t.c)
g0=f6.c.r.h(0,g3)
if(g0==null)g0=A.J(t.N)
g0=A.aq(g0,g0.r,A.i(g0).c)
b1=m.d
b2=g0.$ti.c
f8=f8.c
b4=f6.e
while(g0.l()){b5=g0.d
if(b5==null)b5=b2.a(b5)
b6=f6.c.ah(b5)
b6.toString
d7=b1.h(0,b5)
if(d7==null)continue
b7=b6.b
c0=f6.c.a.h(0,b7)
c0.toString
c1=b6.c
c4=f6.c.a.h(0,c1)
c4.toString
d8=o.h(0,b7).a
d9=o.h(0,c1).a
b7=b6.f
if(b6.d===B.d){e0=b4.h(0,b7)
e1=f8.N(e0==null?b6.x:e0)
e2=f8.ad(b6.y)
e3=f6.au(b6)
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
B.a.k(d5,new A.bb(b5,b7,b6.r,b6.cx,b6.cy,c7,e5,b6.w,e3,e7,e8,c1,e4,e9,d8-c5,d9-c6,c8,g3,e4>f6.aw(b6)+0.000001))
if(e4>f6.aw(b6)+0.000001)B.a.k(g1,"velocity_exceeded:"+b7)
b5=e6?f7:e2.ay
if(b5==null)b5=e1==null?f7:e1.y
if((b5==null?0:b5)>0){b5=c0.Q
if(b5==null)b5=c0.c-c0.e
b6=c4.Q
if(b6==null)b6=c4.c-c4.e
b6=Math.max(d8-b5,d9-b6)
b5=e6?f7:e2.ay
b5=b6>(b5==null?e1.y:b5)}else b5=!1
if(b5)B.a.k(g1,"pressure_rating_exceeded:"+b7)}else{b6=d7.a
c1=d7.c
c5=d7.e
c6=c0.Q
c0=c6==null?c0.c-c0.e:c6
c6=c4.Q
c4=c6==null?c4.c-c4.e:c6
B.a.k(d6,new A.bO(b7,b5,b6,c1,c5,d8-c0,d9-c4,d7.d.b))}}for(g0=a.length,o=a5-0.000001,b1=a6+0.000001,b8=0;b8<g0;++b8){f0=a[b8]
b2=f0.e
if(!(b2>=o&&b2<=b1)){g0=f0.a
B.a.k(g1,b2<a5?"outlet_under_pressure:"+g0:"outlet_over_pressure:"+g0)
break}}f1=f8.a2(f9.e)
g0=f1==null
f2=g0?f7:f1.r.b2(a2)
if(f2==null)f2=0
if(!g0)o=a2>f1.x+1e-9||a2<f1.w-1e-9
else o=!1
if(o)B.a.k(g1,"valve_flow_out_of_range")
o=f6.c.r.h(0,g3)
if(o==null)o=A.J(t.N)
o=A.aq(o,o.r,A.i(o).c)
b1=o.$ti.c
f3=0
while(o.l()){b2=o.d
if(b2==null)b2=b1.a(b2)
f4=f6.c.ah(b2)
if(f4.d!==B.d)continue
e2=f8.ad(f4.y)
b2=e2==null?f7:e2.cx
if(b2==null){e0=b4.h(0,f4.f)
b2=f8.N(e0==null?f4.x:e0)
b2=b2==null?f7:b2.Q}if(b2==null)b2=0
f3+=b2*f4.w}f8=n+f2
f5=A.mH(a1.Q,a2,f8,a1.ax,a1.as)
a1=f6.c.a.h(0,r)
a1.toString
o=f9.f
g2=g2.gaA()
b1=a1.gaA()
b2=A.cF(g1,t.N)
b2=A.p(b2,A.i(b2).c)
a1=a1.gaA()
g0=g0?f7:f1.b
if(g0==null)g0=""
b4=g4?f6.cZ(g3,a):0
return A.l5(a6,a5,f5,m.a,d6,n,b0,d3,a4,a3,d1,a,b4,f3,d5,f8+(g2-b1),a2,d4,a1,g3,f2,g0,b2,o)},
az(a){return this.af(a,!0)},
cS(a){var s,r,q,p,o,n,m,l,k,j
t.ms.a(a)
if(a.length===0)return Math.max(1,this.a.b.fx)
for(s=this.a,r=B.a.gt(s.e),q=new A.bH(r,t.jc),p=t.mu;q.l();){o=p.a(r.gp())
n=o.w
if(n<=0||o.d.length<3)continue
for(m=a.length,o=o.d,l=0,k=0;j=a.length,k<j;a.length===m||(0,A.k)(a),++k)if(A.q5(a[k].c,o))++l
if(l*2>=j)return n}return Math.max(1,s.b.fx)},
cZ(a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=null
t.ms.a(a8)
if(a8.length===0)return 0
s=A.q(a8)
r=new A.r(a8,s.j("c(1)").a(new A.hy()),s.j("r<1,c>")).ap(0)
q=A.d([],t.h0)
p=A.d([],t.iv)
for(s=A.aq(r,r.r,A.i(r).c),o=this.a,n=s.$ti.c;s.l();){m=s.d
l=o.a6(m==null?n.a(m):m)
if(l instanceof A.aj)B.a.k(q,l)
if(l instanceof A.aX)B.a.k(p,l)}for(s=a8.length,k=0,j=0,i=0;i<s;++i){h=a8[i]
n=h.w
k+=h.e*n
j+=n}k=j>0?k/j:0
if(q.length!==0){g=B.a.gu(q)
s=o.c.a0(g.r)
f=s==null?a6:s.aB(g.w)
e=f==null?a6:f.c.cq(k)
if(e==null)e=0
if(e<=0)return 0
d=A.d([],t.n)
for(s=q.length,i=0;i<q.length;q.length===s||(0,A.k)(q),++i){c=q[i]
o=c.d
if(J.as(o)<2)continue
b=A.ks(o,A.aT(o)/2)
for(o=q.length,a=1/0,a0=0;a0<q.length;q.length===o||(0,A.k)(q),++a0){a1=q[a0]
if(c===a1)continue
a=Math.min(a,a1.dr(b))}if(isFinite(a))B.a.k(d,a)}if(d.length===0)return 0
B.a.a4(d)
s=d.length
o=s/2|0
if(!(o<s))return A.b(d,o)
return A.mQ(e,g.y,d[o])}if(p.length>=4){h=B.a.gu(p)
s=o.c.a0(h.f)
f=s==null?a6:s.aB(h.r)
e=f==null?a6:f.c.cq(k)
if(e==null)e=0
if(e<=0)return 0
a2=A.d([],t.n)
a3=p.length>400?B.a.cF(p,0,400):p
for(s=a3.length,i=0;o=a3.length,i<o;a3.length===s||(0,A.k)(a3),++i){c=a3[i]
for(n=c.d,m=n.a,n=n.b,a=1/0,a0=0;a0<a3.length;a3.length===o||(0,A.k)(a3),++a0){a1=a3[a0]
if(c===a1)continue
a4=a1.d
a5=m-a4.a
a4=n-a4.b
a=Math.min(a,Math.sqrt(a5*a5+a4*a4))}if(isFinite(a))B.a.k(a2,a)}if(a2.length===0)return 0
B.a.a4(a2)
s=a2.length
o=s/2|0
if(!(o<s))return A.b(a2,o)
g=a2[o]
return A.mQ(e,g,g)}return 0},
d_(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this.c.f.h(0,a)
if(c==null)c=A.J(t.N)
c=A.aq(c,c.r,A.i(c).c)
s=b.c
r=c.$ti.c
q=1/0
p=-1/0
o=-1/0
n=1/0
while(c.l()){m=c.d
if(m==null)m=r.a(m)
l=this.c.a.h(0,m)
l.toString
k=s.h(0,m)
if(k==null)continue
for(m=l.f,j=m.length,i=k.a,h=l.Q,l=l.c-l.e,g=0;g<j;++g){f=m[g]
if(f.b===-2)continue
e=h==null?l:h
d=i-(e+f.x)
q=Math.min(q,d)
p=Math.max(p,d)
o=Math.max(o,f.f)
n=Math.min(n,f.r)}}if(!isFinite(q))return B.wK
return new A.cW([q,p,o,n])},
bR(a,b,c){return A.l5(0,0,0,!1,B.be,0,0,1,0,0,0,B.dv,0,0,B.bf,0,0,B.cE,0,a,0,"",t.bF.a(c),b)},
bo(a){var s,r,q,p,o,n
t.bq.a(a)
s=A.m(t.N,t.e5)
for(r=A.aq(a,a.r,A.i(a).c),q=this.a.c,p=r.$ti.c;r.l();){o=r.d
if(o==null)o=p.a(o)
n=this.c.ah(o)
if(n.d!==B.d||!n.z||n.y!=null)continue
if(q.ab(n.Q).length===0)continue
J.bL(s.ac(n.f,new A.hK()),n)}return s},
aL(a,b,c,d){var s,r,q,p,o,n
t.e5.a(a)
t.U.a(c)
t.hZ.a(d)
for(s=J.aa(a),r=b.f/1000,q=0;s.l();){p=s.gp()
if(!d.A(0,p))continue
o=this.au(p)
n=c.h(0,p.a)
if(n==null)n=0
q+=Math.abs(n)*(1-Math.pow(o/r,4.871))}return q},
av(a){return J.nl(t.e5.a(a),0,new A.hJ(),t.i)},
aW(a,b){var s=this.a.c.ab(a.Q),r=A.q(s),q=r.j("B<1>"),p=A.p(new A.B(s,r.j("u(1)").a(new A.hL(this,b,a)),q),q.j("j.E"))
return p.length===0?A.d([B.a.gM(s)],t.D):p},
c_(a){var s
switch(a.Q.a){case 0:s=Math.max(1,this.a.b.ch)
break
case 1:s=Math.max(1,this.a.b.CW)
break
case 2:s=Math.max(1,this.a.b.fr)
break
default:s=null}return s},
ba(a){a.b.X(0,new A.hl(this))},
dc(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.L.a(b)
s=A.d([],t.s)
for(r=A.i(b),q=new A.K(b,r.j("K<1,2>")).gt(0),p=t.G,o=d.a.c,n=d.e;q.l();){m=q.d
n.i(0,m.a,B.a.gu(o.ab(p.a(J.bM(m.b)).Q)).a)}for(r=r.j("ag<1,2>"),l=0;l<4;++l){k=d.R(a,10,!1).H()
for(q=new A.ag(b,b.r,b.e,r),p=k.d,j=!1;q.l();){m=q.d
for(o=m.b,i=J.a1(o),h=i.gt(o),g=0;h.l();){f=p.h(0,h.gp().a)
f=f==null?null:f.a
g=Math.max(g,Math.abs(f==null?0:f))}e=B.a.gu(d.aW(i.gu(o),g))
h=e.f/1000
if(g/(3.141592653589793*h*h/4)>d.aw(i.gu(o))+0.000001)B.a.k(s,"velocity_exceeded:"+m.a)
o=m.a
i=e.a
if(n.h(0,o)!==i){n.i(0,o,i)
j=!0}}if(!j)break}return s},
c7(a9,b0,b1,b2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=this
t.L.a(b0)
t.bF.a(b1)
s=a8.c.c.h(0,a9).b
r=a8.c.r.h(0,a9)
if(r==null)r=A.J(t.N)
q=a8.e
p=a8.f
o=A.i(b0).j("ag<1,2>")
n=a8.a.c
m=t.G
l=t.N
k=t.i
j=0
for(;;){if(j<400)i=!(b2.w>=b2.y-0.000001&&b2.x<=b2.z+0.000001)
else i=!1
if(!i)break
h=b2.gbx()
if(h==null)break
g=a8.bm(a9,h)
if(g==null)break
i=a8.aP(s,g,r)
f=A.cF(i,A.q(i).c)
i=A.m(l,k)
for(e=b2.at,d=e.length,c=0;c<e.length;e.length===d||(0,A.k)(e),++c){b=e[c]
i.i(0,b.a,b.at)}for(e=new A.ag(b0,b0.r,b0.e,o),a=null,a0=null,a1=0;e.l();){a2=e.d
d=a2.b
a3=J.a1(d)
if(!a3.Z(d,f.gaE(f)))continue
a4=m.a(a3.gu(d))
a5=q.h(0,a4.f)
a4=n.N(a5==null?a4.x:a5)
a4.toString
a6=a8.aO(a4,n.ab(m.a(a3.gu(d)).Q))
if(a6==null)continue
a7=a8.aL(d,a6,i,f)/Math.max((a6.Q-a4.Q)*a8.av(d),0.000001)
if(a7>a1){a=a2.a
a1=a7
a0=a6}}if(a==null){B.a.k(b1,"cannot_meet_pressure_window")
break}q.i(0,a,a0.a)
p.T(0,a)
b2=a8.af(a9,!1);++j}return b2},
cR(a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.dV.a(a2)
s=t.N
r=A.m(s,t.bF)
q=this.c.f.h(0,a1)
if(q==null)q=A.J(s)
q=A.aq(q,q.r,A.i(q).c)
p=q.$ti.c
while(q.l()){o=q.d
if(o==null)o=p.a(o)
for(n=this.c.a.h(0,o).f,m=n.length,l=0;l<n.length;n.length===m||(0,A.k)(n),++l){k=n[l]
if(k.b===-2)continue
J.bL(r.ac(k.a,new A.hs()),o)}}j=A.J(s)
for(s=new A.M(r,r.r,r.e,r.$ti.j("M<2>")),q=t.s;s.l();){p=s.d
o=J.af(p)
if(o.gm(p)===1){j.k(0,o.gu(p))
continue}for(p=o.gt(p),i=null,h=null,g=null,f=-1,e=-1/0,d=1/0;p.l();){c=p.gp()
o=this.c.a.h(0,c)
o.toString
b=a2.h(0,c)
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
return A.bW(a0,0,A.cw(1500,"count",t.S),A.q(a0).c).ap(0)}return j},
bY(d2,d3,d4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0=this,d1=null
t.L.a(d3)
t.Q.a(d4)
s=d0.c.c.h(0,d2).b
r=d0.c.r.h(0,d2)
if(r==null)r=A.J(t.N)
q=d0.R(d2,10,!1).H()
p=new A.hx(q)
o=d0.aI(A.d([s],t.s),r)
n=o.a
m=t.N
l=A.m(m,m)
for(k=A.i(d3),j=k.j("K<1,2>"),i=new A.K(d3,j).gt(0);i.l();){h=i.d
for(g=J.aa(h.b),f=h.a;g.l();)l.i(0,g.gp().a,f)}e=A.m(m,t.d)
d=A.m(m,t.i)
c=A.m(m,t.S)
for(j=new A.K(d3,j).gt(0);j.l();){h=j.d
for(i=h.b,g=J.a1(i),f=g.gt(i),b=0;f.l();)b=Math.max(b,A.lg(p.$1(f.gp())))
f=h.a
e.i(0,f,d0.aW(g.gu(i),b))
d.i(0,f,d0.av(i))
c.i(0,f,d0.c_(g.gu(i)))}j=d0.c.f.h(0,d2)
if(j==null)j=A.J(m)
j=A.aq(j,j.r,A.i(j).c)
i=j.$ti.c
a=0
while(j.l()){g=j.d
if(g==null)g=i.a(g)
for(g=d0.c.a.h(0,g).f,f=g.length,a0=0;a0<g.length;g.length===f||(0,A.k)(g),++a0){h=g[a0]
a+=h.c.a7(h.e)*h.d}}j=d0.a.b
i=j.ay
a1=i?A.mH(j.Q,a,1,j.ax,j.as):0
a2=d0.c.a.h(0,s).gaA()
g=A.dl(d0.cR(d2,o.c),m)
g.B(0,d4)
a3=A.d([],t.nE)
for(g=A.aq(g,g.r,A.i(g).c),f=q.d,a4=t.U,a5=j.ok,a6=a5>0,a7=g.$ti.c,a5/=200,a8=1-a5,a5=1+a5;g.l();){a9=g.d
if(a9==null)a9=a7.a(a9)
b0=d0.c.a.h(0,a9)
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
b4=Math.min(b4,b9*a5)}c0=A.m(m,a4)
for(a9=d0.c1(n,a9),b1=a9.length,c1=0,a0=0;a0<a9.length;a9.length===b1||(0,A.k)(a9),++a0){c2=a9[a0]
b2=c2.a
c3=l.h(0,b2)
if(c3!=null){c4=c0.ac(c3,new A.hw())
for(b2=e.h(0,c3),b8=b2.length,c5=0;c5<b2.length;b2.length===b8||(0,A.k)(b2),++c5){c6=b2[c5]
c7=c6.a
c8=c4.h(0,c7)
if(c8==null)c8=0
c4.i(0,c7,c8+d0.bX(c2,c6,p.$1(c2)))}}else if(c2.d===B.d)c1+=d0.bQ(c2,p.$1(c2))
else{b2=f.h(0,b2)
b2=b2==null?d1:b2.c
c1+=b2==null?0:b2}}a9=b0.Q
c9=(a9==null?b0.c-b0.e:a9)+b5-a2
a9=isFinite(b3)?b3+c9:d1
B.a.k(a3,new A.dn(0,c0,c1,a9,isFinite(b4)?b4+c9:d1))}m=k.j("ad<1>")
m=A.p(new A.ad(d3,m),m.j("j.E"))
return A.mT(new A.ev(m,e,d,c,A.d([new A.dp(a1,d1,d1,"zone")],t.jv),a3,A.fp(j.y,j.z),i))},
cY(a,b){return this.bY(a,b,B.wM)},
cD(c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1=this,c2=c1.a,c3=t.e.a(c2.a6(c4))
if(c3==null||!c1.c.c.E(c4))return c1.az(c4)
s=c1.c.r.h(0,c4)
if(s==null)s=A.J(t.N)
r=c1.bo(s)
if(r.a===0)return c1.az(c4)
q=c1.c.c.h(0,c4).b
p=A.d([],t.s)
B.a.B(p,c1.dc(c4,r))
o=c2.b
if(o.dy===B.a_){n=c1.cY(c4,r)
m=n.a
if(m){c1.ba(n)
l=c1.af(c4,!1)
k=t.N
j=A.J(k)
i=t.w
h=0
for(;;){if(h<4)g=!(l.w>=l.y-0.000001&&l.x<=l.z+0.000001)
else g=!1
if(!g)break
f=A.J(k)
g=A.d([],i)
e=l.gbx()
if(e!=null)g.push(e)
e=l.gdN()
if(e!=null)g.push(e)
e=g.length
d=0
for(;d<g.length;g.length===e||(0,A.k)(g),++d){c=c1.bm(c4,g[d])
if(c!=null)f.k(0,c)}if(f.dw(0,j.gaE(j)))break
g=A.et(k)
g.B(0,j)
g.B(0,f)
n=c1.bY(c4,r,g)
if(!n.a)break
c1.ba(n)
l=c1.af(c4,!1);++h
j=g}}else{B.a.k(c1.d.f,"lp_infeasible:"+c3.f)
l=c1.af(c4,!1)}}else{l=c1.af(c4,!1)
m=!1}l=c1.c7(c4,r,p,l)
if(!m&&o.ay){b=A.fp(o.y,o.z)
for(k=c1.e,i=A.i(r).j("ag<1,2>"),g=o.ax,e=o.Q,o=o.as,c2=c2.c,a=t.G,a0=t.N,a1=t.i,a2=0;a2<200;++a2){a3=l.gbx()
if(a3==null)break
a4=c1.bm(c4,a3)
if(a4==null)break
a5=c1.aP(q,a4,s)
a6=A.cF(a5,A.q(a5).c)
a5=A.m(a0,a1)
for(a7=l.at,a8=a7.length,d=0;d<a7.length;a7.length===a8||(0,A.k)(a7),++d){a9=a7[d]
a5.i(0,a9.a,a9.at)}for(a7=new A.ag(r,r.r,r.e,i),a8=9788.99803*l.d,b0=null,b1=null,b2=0;a7.l();){b3=a7.d
b4=b3.b
b5=J.a1(b4)
if(!b5.Z(b4,a6.gaE(a6)))continue
b6=a.a(b5.gu(b4))
b7=k.h(0,b6.f)
b6=c2.N(b7==null?b6.x:b7)
b6.toString
b8=c1.aO(b6,c2.ab(a.a(b5.gu(b4)).Q))
if(b8==null)continue
b9=a8*c1.aL(b4,b8,a5,a6)/Math.max(o,0.05)/1000*g*e-(b8.Q-b6.Q)*c1.av(b4)*b
if(b9>b2){b0=b3.a
b2=b9
b1=b8}}if(b0==null)break
k.i(0,b0,b1.a)
l=c1.af(c4,!1)}}c1.c4(q,s,r)
c1.bp(r)
c0=c1.af(c4,!0)
c2=A.dl(p,t.N)
c2.B(0,c0.ch)
c2=A.p(c2,A.i(c2).c)
return c0.cj(c2)},
bm(a,b){var s,r,q,p,o,n,m,l,k=this.c.f.h(0,a)
if(k==null)k=A.J(t.N)
k=A.aq(k,k.r,A.i(k).c)
s=b.a
r=b.b
q=k.$ti.c
while(k.l()){p=k.d
if(p==null)p=q.a(p)
for(o=this.c.a.h(0,p).f,n=o.length,m=0;m<n;++m){l=o[m]
if(l.a===s&&l.b===r)return p}}return null},
c4(b1,b2,b3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this
t.Q.a(b2)
t.L.a(b3)
s=t.N
r=A.m(s,s)
for(q=new A.K(b3,A.i(b3).j("K<1,2>")).gt(0);q.l();){p=q.d
for(o=J.aa(p.b),n=p.a;o.l();)r.i(0,o.gp().a,n)}m=A.S([b1,null],s,t.B)
l=A.d([b1],t.s)
k=A.d([],t.I)
for(j=0;j<l.length;j=i){i=j+1
h=l[j]
for(s=b0.c.a.h(0,h).w,q=s.length,g=0;g<s.length;s.length===q||(0,A.k)(s),++g){f=s[g]
if(!b2.A(0,f.a))continue
e=f.b
if(h===e)e=f.c
if(!m.E(e)){m.i(0,e,f)
B.a.k(k,f)
B.a.k(l,e)}}}for(s=t.g9,q=s.j("aL<t.E>"),o=b0.a.c,n=b0.e,d=A.i(m).j("K<1,2>"),c=s.j("t.E"),b=b0.f,a=0;a<5;++a){for(a0=new A.bn(k,s),a0=new A.aL(a0,a0.gm(0),q),a1=!1;a0.l();){a2=a0.d
if(a2==null)a2=c.a(a2)
a3=r.h(0,a2.a)
if(a3==null)continue
a4=new A.K(m,d).dB(0,new A.hz(a2))
a5=a2.b
a6=m.h(0,a4.a===a5?a2.c:a5)
if(a6==null)continue
a7=r.h(0,a6.a)
if(a7==null||a7===a3)continue
h=n.h(0,a2.f)
a2=o.N(h==null?a2.x:h)
a2.toString
h=n.h(0,a6.f)
a2=a2.f
if(a2>o.N(h==null?a6.x:h).f+1e-9){a8=o.ab(a6.Q)
for(a4=a8.length,a2-=1e-9,g=0;g<a4;++g){a9=a8[g]
if(a9.f>=a2){n.i(0,a7,a9.a)
b.T(0,a7)
a1=!0
break}}}}if(!a1)break}},
bp(a){var s,r,q,p,o,n,m
t.L.a(a)
for(s=new A.K(a,A.i(a).j("K<1,2>")).gt(0),r=this.a,q=this.e;s.l();){p=s.d
o=p.a
n=q.h(0,o)
if(n==null)continue
m=r.a6(o)
if(m instanceof A.aE)m.f=n
if(m instanceof A.aj)m.e=n
for(o=J.aa(p.b);o.l();)o.gp().x=n}},
cM(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5=this,b6=b5.f
if(b6.a===0)return 0
s=t.N
r=A.J(s)
for(q=b5.c.c,q=new A.M(q,q.r,q.e,A.i(q).j("M<2>"));q.l();)r.k(0,q.d.b)
q=b5.c.d
p=A.i(q).j("am<2>")
o=A.dl(new A.am(q,p),p.j("j.E"))
s=A.J(s)
for(q=b5.c.r,q=new A.M(q,q.r,q.e,A.i(q).j("M<2>"));q.l();){p=q.d
for(p=p.gt(p);p.l();)s.k(0,A.C(p.gp()))}n=b5.aI(r,s).c
m=b5.aI(o,b5.c.x).c
for(s=new A.K(b6,A.i(b6).j("K<1,2>")).gt(0),r=b5.a,q=r.e,p=t.n,l=t.f,k=t.bw,j=t.pa,i=j.j("t.E"),h=t.s,g=0;s.l();){f=s.d
e=r.a6(f.a)
if(e!=null)d=!(e instanceof A.aE||e instanceof A.aj||e instanceof A.aA)
else d=!0
if(d)continue
d=b5.c.b
c=A.q(d)
b=c.j("B<1>")
a=A.p(new A.B(d,c.j("u(1)").a(new A.hm(e)),b),b.j("j.E"))
B.a.am(a,new A.hn())
if(a.length===0)continue
a0=B.a.gu(a).e===B.h?m:n
d=A.d([B.a.gu(a).b],h)
for(c=a.length,a1=0;a1<a.length;a.length===c||(0,A.k)(a),++a1)d.push(a[a1].c)
a2=A.p(new A.r(d,k.a(new A.ho(a0)),j),i)
if(B.a.Z(a2,new A.hp()))continue
for(d=a2.length,a3=!0,a4=!0,a5=1;a5<d;++a5){c=a2[a5]
c.toString
b=a2[a5-1]
b.toString
if(c<b)a3=!1
if(c>b)a4=!1}if(a3===a4)continue
a6=f.b
l.a(e)
a7=e.gm(e)
if(a3)a8=a6
else{d=J.nn(a6)
a8=A.p(d,d.$ti.j("t.E"))}a9=A.d([],p)
for(d=J.af(a8),b0=0,a5=0;a5<d.gm(a8)-1;++a5){b0+=d.h(a8,a5).b*a7
B.a.k(a9,b0)}b1=A.qa(e,a9,new A.hq(b5))
if(b1.length<2)continue
b2=B.a.cn(q,e)
B.a.dR(q,b2)
for(a5=0;a5<b1.length;++a5){b3=b1[a5]
b4=d.h(a8,Math.min(a5,d.gm(a8)-1)).a
if(b3 instanceof A.aE)b3.f=b4.a
if(b3 instanceof A.aj)b3.e=b4.a
B.a.dF(q,b2+a5,b3)}++g}b6.V(0)
b5.e.V(0)
b5.c=A.kZ(r).bq()
return g},
aM(a,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this,b=t.U
b.a(a)
b.a(a0)
b=c.a
s=b.b
s=A.lQ(A.fu(s.c),s.b)
r=A.m(t.N,t.b)
q=A.d([],t.lp)
p=new A.ee(s,r,q)
for(s=c.c.w,s=A.aq(s,s.r,A.i(s).c),o=s.$ti.c,n=t.v;s.l();){m=s.d
if(m==null)m=o.a(m)
l=c.c.a.h(0,m)
if(l.y){k=l.z
k.toString
j=n.a(b.a6(k))
i=a.h(0,j.a)
if(i==null)i=0
k=l.Q
h=k==null
g=h?l.c-l.e:k
if(h)k=l.c-l.e
r.i(0,m,new A.bk(m,B.T,g,k+j.y+i,null,1,0))
continue}k=l.Q
f=new A.bk(m,B.S,k==null?l.c-l.e:k,null,null,1,0)
r.i(0,m,f)
c.bM(p,f,l,!0)}for(b=c.c.c,b=new A.K(b,A.i(b).j("K<1,2>")).gt(0);b.l();){e=b.d
d=r.h(0,e.b.a)
if(d==null)continue
s=d.d
o=a0.h(0,e.a)
d.d=s+(o==null?0:o)}for(b=c.c.e,b=new A.K(b,A.i(b).j("K<1,2>")).gt(0);b.l();){e=b.d
d=r.h(0,e.b)
if(d==null)continue
s=d.d
o=a0.h(0,e.a)
d.d=s+(o==null?0:o)}for(b=c.c.x,b=A.aq(b,b.r,A.i(b).c),s=b.$ti.c;b.l();){r=b.d
if(r==null)r=s.a(r)
r=c.c.ah(r)
r.toString
B.a.k(q,c.ca(r))}return p},
gaV(){var s=t.lF,r=s.j("B<j.E>")
s=A.p(new A.B(new A.cq(this.a.e,s),s.j("u(j.E)").a(new A.hI(this)),r),r.j("j.E"))
return s},
cg(e3,e4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=null,e1=A.d([],t.s),e2=d9.gaV()
if(e2.length===0)return new A.b2(e3.a,e3.b,!1,B.dx,B.dy,B.bf,B.be,B.dD,0,e3.e,0)
s=t.N
r=t.i
q=A.m(s,r)
p=A.m(s,r)
for(o=e3.c,o=A.aq(o,o.r,A.i(o).c),n=o.$ti.c;o.l();){m=o.d
if(m==null)m=n.a(m)
if(d9.ak(m)==null)continue
l=d9.be(m)
q.i(0,m,l.a)
p.i(0,m,l.b)}r=A.m(s,r)
for(o=e2.length,k=0;k<e2.length;e2.length===o||(0,A.k)(e2),++k){j=e2[k]
n=j.e?0:j.f
r.i(0,j.a,n)}i=d9.aM(r,q).H()
o=A.q(e2)
n=o.j("B<1>")
h=A.p(new A.B(e2,o.j("u(1)").a(new A.hN()),n),n.j("j.E"))
g=new A.hO(d9,q,p)
if(h.length!==0){f=g.$1(i)
for(o=h.length,k=0;k<h.length;h.length===o||(0,A.k)(h),++k)r.i(0,h[k].a,f)
i=d9.aM(r,q).H()}else f=0
o=i.a
if(!o)B.a.k(e1,"not_converged")
e=A.d([],t.eZ)
for(n=new A.az(q,q.r,q.e,q.$ti.j("az<1>")),m=i.c,d=d9.d,c=d.d,d=d.c;n.l();){b=n.d
a=d9.ak(b)
if(a==null)a=""
a0=m.h(0,a)
a1=c.h(0,b)
a2=a1==null
a3=a2?e0:a1.c
if(a3==null){a3=d.h(0,b)
a3=a3==null?e0:a3.b
a4=a3}else a4=a3
if(a4==null)a4=b
if(a0==null){B.a.k(e1,"valve_unreachable:"+b)
continue}a3=q.h(0,b)
a3.toString
a5=a0.b
a6=p.h(0,b)
a6.toString
B.a.k(e,new A.aQ(b,a4,a3,a5,a6,d9.c.a.h(0,a).b))
a2=!a2
if(a2)a1.dx=a5
a3=p.h(0,b)
a3.toString
if(a5<a3-0.01)B.a.k(e1,a2?"pivot_pressure_deficit:"+b:"valve_pressure_deficit:"+b)}a7=A.d([],t.iF)
for(n=e2.length,d=i.d,c=d9.b,a8=0,k=0;k<e2.length;e2.length===n||(0,A.k)(e2),++k){j=e2[k]
a2=j.a
a3=d9.c.d.h(0,a2)
a3.toString
for(a5=d9.c.a.h(0,a3).w,a6=a5.length,a9=0,b0=0;b0<a5.length;a5.length===a6||(0,A.k)(a5),++b0){b1=a5[b0]
b2=d.h(0,b1.a)
if(b2==null)continue
b3=b2.a
a9+=b1.b===a3?b3:-b3}a8+=a9
a5=r.h(0,a2)
a5.toString
a6=j.e
if(a6)b4=f
else{b3=g.$1(i)
if(typeof b3!=="number")return A.cz(b3)
b4=j.f+b3}b3=j.c
if(b3.length===0)b3=c.$1("name.supply")
a3=d9.c.a.h(0,a3)
b5=a3.Q
a3=b5==null?a3.c-a3.e:b5
b5=j.r
b6=j.w
B.a.k(a7,new A.cn(a2,b3,a9,a5,b4,a3,a6,j.f,b5,b6,j.x))
if(b6>0&&a9>b6+1e-9)B.a.k(e1,"supply_flow_exceeded:"+a2)
if(b5>0&&b4>b5+0.000001)B.a.k(e1,"supply_head_exceeded:"+a2)}b7=A.d([],t.A)
b8=A.d([],t.c)
for(r=d9.c.x,r=A.aq(r,r.r,A.i(r).c),n=r.$ti.c,c=d9.a,a2=c.c,a3=d9.e;r.l();){a5=r.d
if(a5==null)a5=n.a(a5)
a6=d9.c.ah(a5)
a6.toString
b2=d.h(0,a5)
if(b2==null)continue
b3=a6.b
b5=d9.c.a.h(0,b3)
b5.toString
b6=a6.c
b9=d9.c.a.h(0,b6)
b9.toString
c0=m.h(0,b3).a
c1=m.h(0,b6).a
b3=a6.d
b6=a6.f
if(b3===B.d){c2=a3.h(0,b6)
c3=a2.N(c2==null?a6.x:c2)
c4=d9.au(a6)
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
B.a.k(b7,new A.bb(a5,b6,a6.r,a6.cx,a6.cy,c8,d1,a6.w,c4,d3,d4,b3,c5,d5,c0-c6,c1-c7,c9,e0,c5>d9.aw(a6)+0.000001))
if(c5>d9.aw(a6)+0.000001)B.a.k(e1,"velocity_exceeded:"+b6)
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
b5=c9==null?b5.c-b5.e:c9
c9=b9.Q
b9=c9==null?b9.c-b9.e:c9
B.a.k(b8,new A.bO(b6,a5,c6,c7,c8,c0-b5,c1-b9,b2.d.b))
if(b3===B.b9){c3=a2.aG(a6.ch)
if(c3!=null)a5=c6>c3.y+1e-9||c6<=0
else a5=!1
if(a5)B.a.k(e1,"pump_out_of_range:"+b6)}}}d6=e4>0?e3.e/e4:1
r=c.b
d7=r.at*d6
for(n=a7.length,m=r.Q,r=r.as,d8=0,k=0;k<n;++k){c4=a7[k]
if(c4.r&&c4.e>0)d8+=9788.99803*c4.c*c4.e/Math.max(r,0.05)/1000*d7*m}for(n=b8.length,k=0;k<b8.length;b8.length===n||(0,A.k)(b8),++k){c4=b8[k]
d=c4.e
if(d>0){c3=a2.aG(d9.c.ah(c4.b).ch)
c=c3==null?e0:c3.w
if(c==null)c=r
d8+=9788.99803*c4.c*d/Math.max(c,0.05)/1000*d7*m}}s=A.cF(e1,s)
s=A.p(s,A.i(s).c)
return new A.b2(e3.a,e3.b,o,a7,e,b7,b8,s,a8,e3.e,d8)},
cl(){var s,r,q=this,p=q.a.f
if(p.length!==0)return p
p=q.b.$1("name.allZones")
s=q.c.c
s=A.dl(new A.ad(s,A.i(s).j("ad<1>")),t.N)
r=q.c.e
s.B(0,new A.ad(r,A.i(r).j("ad<1>")))
return A.d([A.m6(1,"auto",p,0,s)],t.cD)},
cX(d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8=this,c9=null,d0={}
t.L.a(d1)
t.k6.a(d2)
s=c8.gaV()
r=t.N
q=A.m(r,t.v)
for(p=s.length,o=0;o<s.length;s.length===p||(0,A.k)(s),++o){n=s[o]
m=c8.c.d.h(0,n.a)
m.toString
q.i(0,m,n)}d0.a=d0.b=null
l=c8.aI(new A.ad(q,q.$ti.j("ad<1>")),c8.c.x)
d0.b=l.a
d0.a=l.b
p=A.m(r,r)
for(m=A.i(d1),k=m.j("K<1,2>"),j=new A.K(d1,k).gt(0);j.l();){i=j.d
for(h=J.aa(i.b),g=i.a;h.l();)p.i(0,h.gp().a,g)}f=A.d([],t.lH)
e=A.d([],t.gN)
for(j=d2.length,h=t.i,o=0;o<d2.length;d2.length===j||(0,A.k)(d2),++o){d=A.m(r,h)
for(g=d2[o].c,c=A.i(g),b=new A.Q(g,g.r,c.j("Q<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
if(c8.ak(g)==null)continue
d.i(0,g,c8.be(g).a)}B.a.k(e,d)
g=A.m(r,h)
for(c=s.length,a=0;a<s.length;s.length===c||(0,A.k)(s),++a){n=s[a]
b=n.e?0:n.f
g.i(0,n.a,b)}B.a.k(f,c8.aM(g,d).H())}a0=A.m(r,t.d)
a1=A.m(r,h)
j=t.S
a2=A.m(r,j)
for(k=new A.K(d1,k).gt(0);k.l();){i=k.d
for(h=f.length,g=i.b,c=J.a1(g),a3=0,o=0;o<f.length;f.length===h||(0,A.k)(f),++o){a4=f[o]
for(b=c.gt(g),a5=a4.d;b.l();){a6=a5.h(0,b.gp().a)
a6=a6==null?c9:a6.a
a3=Math.max(a3,Math.abs(a6==null?0:a6))}}h=i.a
a0.i(0,h,c8.aW(c.gu(g),a3))
a1.i(0,h,c8.av(g))
a2.i(0,h,c8.c_(c.gu(g)))}a7=A.d([],t.jv)
a8=A.m(r,j)
for(r=c8.a.b,k=r.ay,j=r.at,h=r.Q,g=r.as,c=d3>0,a9=0;a9<d2.length;++a9){b0=c?d2[a9].e/d3:1
for(b=s.length,a5=a9,a6=j*b0,o=0;o<s.length;s.length===b||(0,A.k)(s),++o){n=s[o]
b1=n.a
b2=c8.c.d.h(0,b1)
b2.toString
for(b3=c8.c.a.h(0,b2).w,b4=b3.length,b5=0,a=0;a<b3.length;b3.length===b4||(0,A.k)(b3),++a){b6=b3[a]
if(!(a9<f.length))return A.b(f,a9)
b7=f[a9].d.h(0,b6.a)
if(b7==null)continue
b8=b7.a
b5+=b6.b===b2?b8:-b8}b2=n.e
b9=b2&&k?9788.99803*Math.max(b5,0)/Math.max(g,0.05)/1000*a6*h:0
a8.i(0,b1+"|"+a5,a7.length)
b1=b2?c9:n.f
b2=b2&&n.r>0?n.r:c9
if(!(a9<d2.length))return A.b(d2,a9)
B.a.k(a7,new A.dp(b9,b1,b2,n.c+"|"+d2[a9].b))}}c0=A.d([],t.nE)
for(j=c8.d,h=j.c,j=j.d,a9=0;a9<d2.length;++a9){if(!(a9<f.length))return A.b(f,a9)
a4=f[a9]
c1=new A.ht(d0,c8,q,p,a0,new A.hv(a4),a4,c0,a8,a9)
for(g=d2[a9].c,c=A.i(g),b=new A.Q(g,g.r,c.j("Q<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
c2=c8.ak(g)
if(c2==null)continue
c3=j.h(0,g)
if(c3!=null){c1.$4(c2,c3.r,c9,0)
continue}c4=h.h(0,g)
if(c4==null)continue
c1.$4(c2,c4.r,c9,0)}for(g=c8.c.w,c=A.i(g),b=new A.Q(g,g.r,c.j("Q<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
a5=c8.c.a.h(0,g).f
a6=a5.length
if(a6===0)continue
for(c5=-1/0,c6=1/0,c7=0,o=0;o<a6;++o){i=a5[o]
c5=Math.max(c5,i.f)
c6=Math.min(c6,i.r)
c7=Math.max(c7,i.x)}if(isFinite(c5))c1.$4(g,c5,isFinite(c6)?c6:c9,c7)}}q=m.j("ad<1>")
q=A.p(new A.ad(d1,q),q.j("j.E"))
return A.mT(new A.ev(q,a0,a1,a2,a7,c0,A.fp(r.y,r.z),k))},
cC(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5=this,d6=null,d7=d5.cl(),d8=t.i,d9=B.a.W(d7,0,new A.hV(),d8),e0=d5.bo(d5.c.x),e1=new A.hU(d5,d7,d9)
if(e0.a===0||d5.gaV().length===0){d8=d5.d.e
B.a.V(d8)
B.a.B(d8,e1.$0())
return}s=d5.gaV()
r=A.q(s)
q=new A.r(s,r.j("c(1)").a(new A.hW(d5)),r.j("r<1,c>")).ap(0)
for(r=A.i(e0),p=new A.K(e0,r.j("K<1,2>")).gt(0),o=t.G,n=d5.a,m=n.c,l=d5.e;p.l();){k=p.d
l.i(0,k.a,B.a.gu(m.ab(o.a(J.bM(k.b)).Q)).a)}for(r=r.j("ag<1,2>"),p=t.N,j=0;j<4;++j){i=A.m(p,d8)
for(h=d7.length,g=0;g<d7.length;d7.length===h||(0,A.k)(d7),++g){f=A.m(p,d8)
for(e=d7[g].c,d=A.i(e),c=new A.Q(e,e.r,d.j("Q<1>")),c.c=e.e,d=d.c;c.l();){e=c.d
if(e==null)e=d.a(e)
if(d5.ak(e)==null)continue
f.i(0,e,d5.be(e).a)}e=A.m(p,d8)
for(d=s.length,b=0;b<s.length;s.length===d||(0,A.k)(s),++b){a=s[b]
c=a.e?0:a.f
e.i(0,a.a,c)}a0=d5.aM(e,f).H()
for(e=new A.ag(e0,e0.r,e0.e,r),d=a0.d;e.l();){k=e.d
for(c=J.aa(k.b),a1=k.a;c.l();){a2=c.gp()
a3=i.h(0,a1)
if(a3==null)a3=0
a2=d.h(0,a2.a)
a2=a2==null?d6:a2.a
i.i(0,a1,Math.max(a3,Math.abs(a2==null?0:a2)))}}}for(h=new A.ag(e0,e0.r,e0.e,r),a4=!1;h.l();){k=h.d
e=J.bM(k.b)
d=k.a
c=i.h(0,d)
e=B.a.gu(d5.aW(e,c==null?0:c)).a
if(l.h(0,d)!==e){l.i(0,d,e)
a4=!0}}if(!a4)break}n=n.b
if(n.dy===B.a_){h=d5.c.x
e=A.i(h)
a5=new A.B(h,e.j("u(1)").a(new A.hX(d5)),e.j("B<1>")).gm(0)
h=d5.c.w.a
if(a5>=h&&h!==0)B.a.k(d5.d.f,"lp_loops_approx")
a6=d5.cX(e0,d7,d9)
a7=a6.a
if(a7)d5.ba(a6)
else B.a.k(d5.d.f,"lp_infeasible:"+A.y(d5.b.$1("menu.mainline")))}else a7=!1
a8=e1.$0()
if(B.a.Z(s,new A.hY()))for(h=d5.f,e=A.i(q),d=e.j("Q<1>"),e=e.c,a9=0;a9<400;++a9){for(c=a8.length,b0=d6,b1=b0,g=0;g<c;++g){b2=a8[g]
for(a1=b2.e,a2=a1.length,b=0;b<a2;++b){b3=a1[b]
a3=b3.e-b3.d
if(a3>0.01)a3=b0==null||a3>b0.e-b0.d
else a3=!1
if(a3){b0=b3
b1=b2}}}if(b1==null||b0==null)break
c=d5.ak(b0.a)
c.toString
b4=A.J(o)
for(a1=new A.Q(q,q.r,d),a1.c=q.e;a1.l();){a2=a1.d
if(a2==null)a2=e.a(a2)
b5=d5.aP(a2,c,d5.c.x)
a2=b5.length
if(a2!==0){a3=b4.a
a2=a3===0||a2<a3}else a2=!1
if(a2)b4=A.cF(b5,A.q(b5).c)}c=A.m(p,d8)
for(a1=b1.f,a2=a1.length,g=0;g<a1.length;a1.length===a2||(0,A.k)(a1),++g){b5=a1[g]
c.i(0,b5.a,b5.at)}for(a1=new A.ag(e0,e0.r,e0.e,r),b6=d6,b7=b6,b8=0;a1.l();){k=a1.d
a2=k.b
a3=J.a1(a2)
if(!a3.Z(a2,b4.gaE(b4)))continue
b9=o.a(a3.gu(a2))
c0=l.h(0,b9.f)
b9=m.N(c0==null?b9.x:c0)
b9.toString
c1=d5.aO(b9,m.ab(o.a(a3.gu(a2)).Q))
if(c1==null)continue
c2=d5.aL(a2,c1,c,b4)/Math.max((c1.Q-b9.Q)*d5.av(a2),0.000001)
if(c2>b8){b7=k.a
b8=c2
b6=c1}}if(b7==null){B.a.k(d5.d.f,"mainline_cannot_meet_pressure")
break}l.i(0,b7,b6.a)
h.T(0,b7)
a8=e1.$0()}if(!a7&&n.ay){c3=A.fp(n.y,n.z)
for(h=n.at,e=n.Q,n=n.as,d=d9>0,c=A.i(q),a1=c.j("Q<1>"),c=c.c,a9=0;a9<300;++a9){for(a2=new A.ag(e0,e0.r,e0.e,r),b6=d6,b7=b6,c4=0;a2.l();){k=a2.d
a3=k.b
b9=J.a1(a3)
c5=o.a(b9.gu(a3))
c0=l.h(0,c5.f)
c5=m.N(c0==null?c5.x:c0)
c5.toString
c1=d5.aO(c5,m.ab(o.a(b9.gu(a3)).Q))
if(c1==null)continue
for(c6=a8.length,c7=0,g=0;g<a8.length;a8.length===c6||(0,A.k)(a8),++g){b2=a8[g]
c8=b2.e
if(c8.length===0)continue
c8=d5.ak(B.a.L(c8,new A.hZ()).a)
c8.toString
b4=A.J(o)
for(c9=new A.Q(q,q.r,a1),c9.c=q.e;c9.l();){d0=c9.d
if(d0==null)d0=c.a(d0)
b5=d5.aP(d0,c8,d5.c.x)
d0=b5.length
if(d0!==0){d1=b4.a
d0=d1===0||d0<d1}else d0=!1
if(d0)b4=A.cF(b5,A.q(b5).c)}if(!b9.Z(a3,b4.gaE(b4)))continue
c8=A.m(p,d8)
for(c9=b2.f,d0=c9.length,b=0;b<c9.length;c9.length===d0||(0,A.k)(c9),++b){b5=c9[b]
c8.i(0,b5.a,b5.at)}d2=d5.aL(a3,c1,c8,b4)
d3=d?b2.y/d9:1
c7+=9788.99803*b2.x*d2/Math.max(n,0.05)/1000*(h*d3)*e}d4=c7-(c1.Q-c5.Q)*d5.av(a3)*c3
if(d4>c4){b7=k.a
c4=d4
b6=c1}}if(b7==null)break
l.i(0,b7,b6.a)
a8=e1.$0()}}for(d8=A.aq(q,q.r,A.i(q).c),r=d8.$ti.c;d8.l();){p=d8.d
if(p==null)p=r.a(p)
d5.c4(p,d5.c.x,e0)}d5.bp(e0)
d8=d5.d.e
B.a.V(d8)
B.a.B(d8,e1.$0())},
c8(a,b){return new A.bZ(this.d9(a,b),t.iG)},
d9(a,b){var s=this
return function(){var r=a,q=b
var p=0,o=1,n=[],m,l,k,j,i,h,g,f,e
return function $async$c8(c,d,a0){if(d===1){n.push(a0)
p=o}for(;;)switch(p){case 0:e=s.d
e.y.B(0,s.c.z)
B.a.B(e.f,s.c.y)
e.b=q||r?s.a.b.dy.b:"analysis"
e=s.c.c,e=new A.az(e,e.r,e.e,A.i(e).j("az<1>")),m=0
case 2:if(!e.l()){p=3
break}l=e.d;++m
p=4
return c.b=new A.aR([new A.hC(s,q,l),B.aO,l,m]),1
case 4:p=2
break
case 3:e=B.a.gt(s.a.e),l=new A.bH(e,t.bo),k=t.m9
case 5:if(!l.l()){p=6
break}j=k.a(e.gp())
i=s.c
h=j.a
if(!i.e.E(h)){p=5
break}++m
p=7
return c.b=new A.aR([new A.hD(s,j),B.aO,h,m]),1
case 7:p=5
break
case 6:g=new A.hA(s)
p=8
return c.b=new A.aR([new A.hE(s,r,g),B.cX,null,0]),1
case 8:p=s.f.a!==0?9:10
break
case 9:f={}
f.a=0
p=11
return c.b=new A.aR([new A.hF(f,s),B.P,null,0]),1
case 11:p=f.a>0?12:13
break
case 12:e=s.c.c,e=new A.az(e,e.r,e.e,A.i(e).j("az<1>")),m=0
case 14:if(!e.l()){p=15
break}l=e.d;++m
p=16
return c.b=new A.aR([new A.hG(s,l),B.P,l,m]),1
case 16:p=14
break
case 15:p=17
return c.b=new A.aR([g,B.P,null,0]),1
case 17:case 13:case 10:p=18
return c.b=new A.aR([new A.hH(s),B.cY,null,0]),1
case 18:p=19
return c.b=new A.aR([s.gdj(),B.cZ,null,0]),1
case 19:p=20
return c.b=new A.aR([s.gdg(),B.aP,null,0]),1
case 20:return 0
case 1:return c.c=n.at(-1),3}}}},
d1(a){var s,r,q,p,o,n,m,l=this,k=l.az(a)
if(k.ge_())return k
s=l.c.r.h(0,a)
r=l.bo(s==null?A.J(t.N):s)
if(r.a===0)return k
q=A.d([],t.s)
for(s=new A.K(r,A.i(r).j("K<1,2>")).gt(0),p=l.a.c,o=l.e;s.l();){n=s.d
m=p.N(J.bM(n.b).x)
if(m!=null)o.i(0,n.a,m.a)}l.c7(a,r,q,l.af(a,!1))
l.bp(r)
k=l.az(a)
s=A.dl(q,t.N)
s.B(0,k.ch)
s=A.p(s,A.i(s).c)
return k.cj(s)},
aY(a,b,c,d){return this.dq(t.dn.a(a),b,c,t.ga.a(d))},
dq(a,b,c,d){var s=0,r=A.mA(t.nJ),q,p=this,o,n,m,l,k,j,i,h,g
var $async$aY=A.mF(function(e,f){if(e===1)return A.mr(f,r)
for(;;)switch(s){case 0:h=p.c.c.a
g=h+4
o=p.c8(b,c),n=o.$ti,o=new A.cv(o.a(),n.j("cv<1>")),n=n.c,m=0,l=!1
case 3:if(!o.l()){s=4
break}k=o.b
j=(k==null?n.a(k):k).a
i=j[1]
if(i===B.P&&!l){g+=p.c.c.a+2
l=!0}a.$1(new A.c7(i,m,g,j[2],j[3],p.c.c.a))
s=5
return A.mq(d.$0(),$async$aY)
case 5:j[0].$0();++m
s=3
break
case 4:a.$1(new A.c7(B.aP,g,g,null,0,h))
q=p.d
s=1
break
case 1:return A.ms(q,r)}})
return A.mt($async$aY,r)},
de(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=d9.d.w
B.a.V(e0)
b7=d9.a
b8=t.hP
b9=A.p(new A.cq(b7.e,b8),b8.j("j.E"))
s=b9
if(J.as(s)===0||b7.b.go<=0)return e0
b8=t.N
c0=A.m(b8,t.i)
for(c1=s,c2=c1.length,c3=0;c3<c1.length;c1.length===c2||(0,A.k)(c1),++c3){c4=c1[c3]
c0.i(0,c4.a,c4.y)}r=c0
for(c0=s,c1=c0.length,c2=b7.c,c4=b7.b,c5=c4.go,c6=c5*3.141592653589793,c3=0;c3<c0.length;c0.length===c1||(0,A.k)(c0),++c3){c7=c0[c3]
c8=c2.ad(c7.e)
if(c8==null)continue
if(c7.y<=0){c9=c8.f/1000
c7.y=c6*c9*c9/4}}q=d9.c
try{c0=A.kZ(b7).bq()
d9.c=c0
for(c0=c0.c,c0=new A.az(c0,c0.r,c0.e,A.i(c0).j("az<1>")),c4=c4.id,c1=t.s,c6=t.e;c0.l();){p=c0.d
o=c6.a(b7.a6(p))
if(o==null)continue
d0=d9.c.f.h(0,p)
n=d0==null?A.J(b8):d0
m=A.d([],c1)
l=0
k=A.J(b8)
for(c7=n,c9=A.i(c7),d1=new A.Q(c7,c7.r,c9.j("Q<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
j=c7==null?c9.a(c7):c7
for(c7=d9.c.a.h(0,j).f,d2=c7.length,c3=0;c3<c7.length;c7.length===d2||(0,A.k)(c7),++c3){i=c7[c3]
if(i.b===-2){J.bL(m,j)
J.bL(k,i.a)}}}l=k.a
if(J.as(m)===0)continue
h=null
g=null
c7=d9.c.c.h(0,p)
c7.toString
f=c7
h=f.a
g=f.b
e=new A.hM(d9,m)
d=0
c=20
b=d9.R(p,c,!0).H()
a=0
for(;;){c7=e.$1(b)
if(typeof c7!=="number")return c7.bD()
if(c7<c4){c7=a
if(typeof c7!=="number")return c7.bD()
c7=c7<12}else c7=!1
if(!c7)break
c7=c
if(typeof c7!=="number")return c7.aq()
c=c7*2
b=d9.R(p,c,!0).H()
c7=a
if(typeof c7!=="number")return c7.aj()
a=c7+1}a0=0
for(;;){c7=a0
if(typeof c7!=="number")return c7.bD()
if(!(c7<30))break
c7=d
c9=c
if(typeof c7!=="number")return c7.aj()
if(typeof c9!=="number")return A.cz(c9)
a1=(c7+c9)/2
b=d9.R(p,a1,!0).H()
c7=e.$1(b)
if(typeof c7!=="number")return c7.e3()
if(c7>=c4)c=a1
else d=a1
c7=c
c9=d
if(typeof c7!=="number")return c7.U()
if(typeof c9!=="number")return A.cz(c9)
if(c7-c9<0.001)break
c7=a0
if(typeof c7!=="number")return c7.aj()
a0=c7+1}a2=c
b=d9.R(p,a2,!0).H()
a3=0
for(c7=n,c9=A.i(c7),d1=new A.Q(c7,c7.r,c9.j("Q<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
a4=c7==null?c9.a(c7):c7
c7=d9.c.a.h(0,a4)
c7.toString
a5=c7
a6=b.c.h(0,a4)
if(a6==null)continue
for(c7=a5.f,d2=c7.length,c3=0;c3<c7.length;c7.length===d2||(0,A.k)(c7),++c3){a7=c7[c3]
d3=a3
d4=a7.c
d5=a6.a
d6=a5
d7=d6.Q
d6=d7==null?d6.c-d6.e:d7
d6=d4.a7(Math.max(d5-(d6+a7.x),0))
d5=a7.d
if(typeof d3!=="number")return d3.aj()
a3=d3+d6*d5}}a8=0
c7=d9.c.r.h(0,p)
if(c7==null)c7=A.J(b8)
c9=A.i(c7)
d1=new A.Q(c7,c7.r,c9.j("Q<1>"))
d1.c=c7.e
c9=c9.c
while(d1.l()){c7=d1.d
a9=c7==null?c9.a(c7):c7
c7=d9.c.ah(a9)
c7.toString
b0=c7
if(b0.y==null)continue
b1=b.d.h(0,a9)
if(b1!=null){c7=a8
d2=b1.a
d3=d9.au(b0)
a8=Math.max(A.lg(c7),Math.abs(d2)/(3.141592653589793*d3*d3/4))}}b2=c2.a2(o.e)
c7=b2
d8=c7==null?null:c7.r.b2(a3)
b3=d8==null?0:d8
c7=d9.c.a.h(0,g)
c7.toString
b4=c7
c7=d9.c.a.h(0,h)
c7.toString
b5=c7
c7=o.f
c9=a3
d1=a2
d2=b3
if(typeof d1!=="number")return d1.aj()
if(typeof d2!=="number")return A.cz(d2)
d3=b4
d4=d3.Q
d3=d4==null?d3.c-d3.e:d4
d4=b5
d5=d4.Q
d4=d5==null?d4.c-d4.e:d5
B.a.k(e0,new A.cb(p,c7,c9,a2,d1+d2+(d3-d4),l,e.$1(b),a8,c5,b.a))}}finally{for(b7=s,b8=b7.length,c3=0;c3<b7.length;b7.length===b8||(0,A.k)(b7),++c3){b6=b7[c3]
c0=J.fw(r,b6.a)
c0.toString
b6.y=c0}d9.c=q}return e0},
dk(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=this.d,b2=b1.x
B.a.V(b2)
s=this.a
r=s.b
if(!r.k1)return b2
q=A.m(t.N,t.ft)
p=new A.hT(q)
for(o=b1.c,n=A.i(o).j("M<2>"),m=new A.M(o,o.r,o.e,n);m.l();){l=m.d
for(k=l.at,j=k.length,l=l.b,i=0;i<k.length;k.length===j||(0,A.k)(k),++i)p.$2(k[i],l)}for(m=b1.e,l=m.length,i=0;i<m.length;m.length===l||(0,A.k)(m),++i){h=m[i]
for(k=h.f,j=k.length,g=h.b,f=0;f<k.length;k.length===j||(0,A.k)(k),++f)p.$2(k[f],g)}for(l=new A.K(q,q.$ti.j("K<1,2>")).gt(0),e=r.k2,r=t.f,k=s.c,b1=b1.f;l.l();){d=l.d
c=d.b
b=c.a
a=k.N(b.y)
if(a==null)continue
j=d.a
a0=s.a6(j)
a1=r.b(a0)?a0.gm(a0):b.w
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
B.a.k(b2,new A.bC(j,c.b,g,a2,a3,a6,a7,a8,e,a5))
if(a8>0&&a7+a6>a8+0.000001)B.a.k(b1,"surge_rating_exceeded:"+j)}return b2},
dh(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=this,b7=null,b8="bom.pipes",b9="bom.outlets",c0="un",c1="bom.pivots",c2=t.N,c3=A.m(c2,t.q),c4=new A.hP(c3)
for(s=b6.c.b,r=s.length,q=b6.a,p=q.c,o=b6.e,n=0;n<s.length;s.length===r||(0,A.k)(s),++n){m=s[n]
if(m.d!==B.d)continue
l=p.ad(m.y)
if(l!=null){c4.$8$code$supplier("bom.tapes",l.b,"m",m.w,l.cx,l.a,l.d,l.c)
continue}k=o.h(0,m.f)
j=p.N(k==null?m.x:k)
if(j!=null)c4.$8$code$supplier(b8,j.b,"m",m.w,j.Q,j.a,j.d,j.c)}for(s=q.e,r=s.length,o=b6.b,i=b6.d,h=i.d,n=0;n<s.length;s.length===r||(0,A.k)(s),++n){g=s[n]
if(b6.c.z.A(0,g.a))continue
A:{f=g instanceof A.aX
e=f?g:b7
if(f){d=p.a0(e.f)
if(d!=null){f=d.b
c=d.aB(e.r)
c=c==null?b7:c.b
if(c==null)c=""
c4.$8$code$supplier(b9,f+" \u2014 "+c,c0,1,d.r,d.a,d.d,d.c)}break A}f=g instanceof A.aj
d=f?g:b7
if(f){j=p.a0(d.r)
if(j!=null){f=j.b
c=j.aB(d.w)
c=c==null?b7:c.b
if(c==null)c=""
c4.$8$code$supplier(b9,f+" \u2014 "+c,c0,d.gb3(),j.r,j.a,j.d,j.c)}break A}f=g instanceof A.b6
b=f?g:b7
if(f){d=p.a2(b.e)
if(d!=null)c4.$8$code$supplier("bom.valves",d.b,c0,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.aW
a=f?g:b7
if(f){d=p.a2(a.e)
if(d!=null)c4.$8$code$supplier("bom.devices",d.b,c0,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.bm
a0=f?g:b7
if(f){d=p.aG(a0.e)
if(d!=null)c4.$8$code$supplier("bom.pumps",d.b,c0,1,d.z,d.a,d.d,d.c)
break A}f=g instanceof A.b_
a0=f?g:b7
if(f){a1=h.h(0,a0.a)
f=a1==null
a2=f?b7:a1.as
if(a2==null)a2=a0.dX().length
a3=a0.c
c=(a3.length!==0?a3:o.$1("tool.pivot"))+" \u2014 "
a4=A.y(a0.z===B.C?o.$1("pivot.kindPivot"):o.$1("pivot.kindLinear"))
a5=a0.x
c4.$6(c1,c+a4+" "+B.b.a1(a5)+" m, "+a2+" "+A.y(o.$1("pivot.towers")),c0,1,a0.id,b7)
c4.$6(c1,c+A.y(o.$1("pivot.towersItem"))+" ("+B.b.a1(a0.as)+" m)",c0,a2,a0.r,b7)
a6=p.N(a0.at)
if(a6!=null)c4.$8$code$supplier(b8,a6.b,"m",a5,a6.Q,a6.a,a6.d,a6.c)
a7=f?b7:a1.gcE()
if(a7==null){f=a0.d
a7=f>0?B.b.a1(a5/f):0}a8=p.a0(a0.e)
f=a7>0
if(f){a4=a8==null
a5=a4?b7:a8.b
a5=A.y(a5==null?o.$1("pivot.sprinklersItem"):a5)
a9=a4?b7:a8.r
if(a9==null)a9=0
b0=a4?b7:a8.a
b1=a4?b7:a8.d
if(b1==null)b1=""
a4=a4?b7:a8.c
if(a4==null)a4=""
c4.$8$code$supplier(c1,c+a5,c0,a7,a9,b0,b1,a4)}b2=p.a2(a0.f)
if(b2!=null&&f)c4.$8$code$supplier(c1,c+b2.b,c0,a7,b2.y,b2.a,b2.d,b2.c)
if(a0.cx>0)c4.$6(c1,c+A.y(o.$1("pivot.endGunItem")),c0,1,0,b7)
break A}break A}}s=i.r
B.a.V(s)
B.a.B(s,new A.am(c3,c3.$ti.j("am<2>")))
r=q.b
if(r.k3){b3=A.q8(q,b6.c,b6.gd7(),o)
B.a.B(s,b3.a)
b4=A.J(c2)
for(c2=b3.b,q=c2.length,p=i.f,n=0;n<c2.length;c2.length===q||(0,A.k)(c2),++n){a=c2[n]
b5=A.mO(a.a,a.b,a.c,o)
if(b4.k(0,b5))B.a.k(p,"fitting_missing:"+b5)}}B.a.am(s,new A.hQ())
c2=t.i
q=B.a.W(s,0,new A.hR(),c2)
i.z=q
i.Q=q*A.fp(r.y,r.z)
i.as=B.a.W(i.e,0,new A.hS(),c2)
return s}}
A.hr.prototype={
$2(a,b){return A.T(a)+t.cQ.a(b).gdO()},
$S:69}
A.hy.prototype={
$1(a){return t.o.a(a).a},
$S:64}
A.hK.prototype={
$0(){return A.d([],t.I)},
$S:50}
A.hJ.prototype={
$2(a,b){return A.T(a)+t.G.a(b).w},
$S:75}
A.hL.prototype={
$1(a){return A.ft(t.p.a(a).f/1000,this.b)<=this.a.aw(this.c)+1e-9},
$S:6}
A.hl.prototype={
$2(a,b){var s,r
A.C(a)
t.x.a(b)
s=this.a
r=J.a1(b)
s.e.i(0,a,r.gu(b).a.a)
s=s.f
if(r.gm(b)>1)s.i(0,a,b)
else s.T(0,a)},
$S:40}
A.hs.prototype={
$0(){return A.d([],t.s)},
$S:38}
A.hx.prototype={
$1(a){var s=this.a.d.h(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:7}
A.hw.prototype={
$0(){return A.m(t.N,t.i)},
$S:29}
A.hz.prototype={
$1(a){return t.j5.a(a).b===this.a},
$S:31}
A.hm.prototype={
$1(a){t.G.a(a)
return a.f===this.a.a&&a.d===B.d},
$S:1}
A.hn.prototype={
$2(a,b){var s=t.G
return B.c.S(s.a(a).r,s.a(b).r)},
$S:33}
A.ho.prototype={
$1(a){return this.a.h(0,A.C(a))},
$S:34}
A.hp.prototype={
$1(a){return A.mo(a)==null},
$S:35}
A.hq.prototype={
$0(){return"e"+this.a.a.r++},
$S:36}
A.hI.prototype={
$1(a){var s=this.a,r=t.v.a(a).a
if(s.c.d.E(r)){s=s.c
r=s.w.A(0,s.d.h(0,r))
s=r}else s=!1
return s},
$S:8}
A.hN.prototype={
$1(a){return t.v.a(a).e},
$S:8}
A.hO.prototype={
$1(a){var s,r,q,p,o,n,m,l
for(s=this.b,s=new A.az(s,s.r,s.e,A.i(s).j("az<1>")),r=this.c,q=a.c,p=this.a,o=-1/0;s.l();){n=s.d
m=p.ak(n)
l=q.h(0,m==null?"":m)
if(l==null)continue
n=r.h(0,n)
n.toString
o=Math.max(o,n-l.b)}return isFinite(o)?o:0},
$S:28}
A.hv.prototype={
$1(a){var s=this.a.d.h(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:7}
A.ht.prototype={
$4(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this,a2=a1.a,a3=a2.a.h(0,a4)
if(a3==null)return
s=a1.c.h(0,a3)
s.toString
r=A.m(t.N,t.U)
for(q=a1.b,a2=q.c1(a2.b,a4),p=a2.length,o=a1.r.d,n=a1.d,m=a1.f,l=a1.e,k=0,j=0;j<a2.length;a2.length===p||(0,A.k)(a2),++j){i=a2[j]
h=i.a
g=n.h(0,h)
if(g!=null){f=r.ac(g,new A.hu())
for(h=l.h(0,g),e=h.length,d=0;d<h.length;h.length===e||(0,A.k)(h),++d){c=h[d]
b=c.a
a=f.h(0,b)
if(a==null)a=0
f.i(0,b,a+q.bX(i,c,m.$1(i)))}}else if(i.d===B.d)k+=q.bQ(i,m.$1(i))
else{h=o.h(0,h)
h=h==null?null:h.c
k+=h==null?0:h}}a0=q.c.a.h(0,a4).gaA()+a7-(q.c.a.h(0,a3).gaA()+s.y)
a2=a1.x.h(0,s.a+"|"+a1.y)
a2.toString
s=a6!=null?a6+a0:null
B.a.k(a1.w,new A.dn(a2,r,k,a5+a0,s))},
$S:39}
A.hu.prototype={
$0(){return A.m(t.N,t.i)},
$S:29}
A.hV.prototype={
$2(a,b){return A.T(a)+t.k.a(b).e},
$S:27}
A.hU.prototype={
$0(){var s,r,q,p,o,n=A.d([],t.lT)
for(s=this.b,r=s.length,q=this.a,p=this.c,o=0;o<s.length;s.length===r||(0,A.k)(s),++o)n.push(q.cg(s[o],p))
return n},
$S:41}
A.hW.prototype={
$1(a){var s
t.v.a(a)
s=this.a.c.d.h(0,a.a)
s.toString
return s},
$S:42}
A.hX.prototype={
$1(a){var s
A.C(a)
s=this.a.c.ah(a)
return(s==null?null:s.d)===B.d},
$S:43}
A.hY.prototype={
$1(a){return!t.v.a(a).e},
$S:8}
A.hZ.prototype={
$2(a,b){var s=t.nN
s.a(a)
s.a(b)
return a.e-a.d>=b.e-b.d?a:b},
$S:44}
A.hC.prototype={
$0(){var s=this.a,r=this.c,q=this.b?s.cD(r):s.az(r)
s.d.c.i(0,r,q)
return q},
$S:0}
A.hD.prototype={
$0(){var s=this.a,r=this.b,q=s.cf(r)
s.d.d.i(0,r.a,q)
return q},
$S:0}
A.hA.prototype={
$0(){var s,r,q,p=this.a,o=p.cl(),n=B.a.W(o,0,new A.hB(),t.i),m=p.d.e
B.a.V(m)
s=A.d([],t.lT)
for(r=o.length,q=0;q<o.length;o.length===r||(0,A.k)(o),++q)s.push(p.cg(o[q],n))
B.a.B(m,s)},
$S:0}
A.hB.prototype={
$2(a,b){return A.T(a)+t.k.a(b).e},
$S:27}
A.hE.prototype={
$0(){if(this.b)this.a.cC()
else this.c.$0()},
$S:0}
A.hF.prototype={
$0(){var s,r,q=this.b,p=q.cM()
this.a.a=p
if(p>0){s=q.d
r=s.y
if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.bj()}r.B(0,q.c.z)
s.c.V(0)}},
$S:0}
A.hG.prototype={
$0(){var s=this.a,r=this.b,q=s.d1(r)
s.d.c.i(0,r,q)
return q},
$S:0}
A.hH.prototype={
$0(){this.a.de()},
$S:0}
A.hM.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h=1/0
for(q=this.b,p=q.length,o=this.a,n=a.c,m=0;m<q.length;q.length===p||(0,A.k)(q),++m){s=q[m]
r=n.h(0,s)
if(r==null)continue
l=h
k=r.a
j=o.c.a.h(0,s)
i=j.Q
j=i==null?j.c-j.e:i
h=Math.min(A.lg(l),k-j)}return isFinite(h)?h:0},
$S:28}
A.hT.prototype={
$2(a,b){var s=this.a,r=a.b,q=s.h(0,r)
if(q==null||a.as>q.a.as)s.i(0,r,new A.A(a,b))},
$S:45}
A.hP.prototype={
$8$code$supplier(a,b,c,d,e,f,g,h){var s=a+"|"+b,r=this.a,q=r.h(0,s)
if(q!=null)q.d+=d
else r.i(0,s,new A.ak(a,b,c,d,e,f,g,h))},
$6(a,b,c,d,e,f){return this.$8$code$supplier(a,b,c,d,e,f,"","")},
$S:46}
A.hQ.prototype={
$2(a,b){var s,r=t.q
r.a(a)
r.a(b)
r=a.a
s=b.a
return r===s?B.k.S(a.b,b.b):B.k.S(r,s)},
$S:47}
A.hR.prototype={
$2(a,b){A.T(a)
t.q.a(b)
return a+b.d*b.e},
$S:48}
A.hS.prototype={
$2(a,b){return A.T(a)+t.ju.a(b).z},
$S:49}
A.db.prototype={
gco(){return this.a.b+"|"+B.b.ae(this.b,1)+"|"+B.b.ae(this.c,1)}}
A.i4.prototype={}
A.kd.prototype={
$1(a){return a===B.b.by(a)?""+B.b.a1(a):B.b.ae(a,1)},
$S:14}
A.kG.prototype={
$4$qty$size2(a,b,c,d){var s=new A.db(a,b,d),r=this.a,q=r.h(0,s.gco()),p=s.gco(),o=q==null?null:q.b
r.i(0,p,new A.A(s,(o==null?0:o)+c))},
$2(a,b){return this.$4$qty$size2(a,b,1,0)},
$3$qty(a,b,c){return this.$4$qty$size2(a,b,c,0)},
$3$size2(a,b,c){return this.$4$qty$size2(a,b,1,c)},
$S:51}
A.kI.prototype={
$1(a){var s,r
t.G.a(a)
s=this.a.ad(a.y)
if(s!=null)return s.e
r=this.b.$1(a)
r=r==null?null:r.e
return r==null?0:r},
$S:7}
A.kF.prototype={
$2(a,b){var s=a.cx,r=a.cy
return a.b===b?r.U(0,s).gcp():s.U(0,r).gcp()},
$S:52}
A.kx.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.d){s=this.a.$1(a)
if(typeof s!=="number")return s.cB()
s=s>0}else s=!1
return s},
$S:1}
A.ky.prototype={
$1(a){return!this.a.A(0,t.G.a(a).f)},
$S:1}
A.kz.prototype={
$1(a){return this.a.A(0,t.G.a(a).f)},
$S:1}
A.kA.prototype={
$1(a){return t.G.a(a).d!==B.d},
$S:1}
A.kH.prototype={
$2(a,b){return this.a.h(0,B.b.ae(a.a,3)+"|"+B.b.ae(a.b,3)+"|"+b.b)},
$S:53}
A.kD.prototype={
$2(a,b){return a!=null&&B.a.Z(a.w,new A.kE(b,this.a))},
$S:54}
A.kE.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.d){s=a.f
s=s!==this.a&&!this.b.A(0,s)}else s=!1
return s},
$S:1}
A.kB.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.kC.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.kw.prototype={
$1(a){var s
A:{if(B.w===a||B.J===a){s="bom.takeoffs"
break A}if(B.m===a){s="bom.risers"
break A}s="bom.fittings"
break A}return s},
$S:55}
A.cj.prototype={
G(){return"LpSense."+this.b}}
A.ci.prototype={}
A.ii.prototype={}
A.cG.prototype={}
A.bx.prototype={
G(){return"LpStatus."+this.b}}
A.kJ.prototype={
$2(a,b){var s,r
A.a0(a)
A.T(b)
if(a>=0&&a<this.a){s=this.b
if(!(a>=0&&a<s.length))return A.b(s,a)
r=s[a]
s.$flags&2&&A.a9(s)
s[a]=r+b*this.c}},
$S:56}
A.kL.prototype={
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
$S:57}
A.kK.prototype={
$2(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a,d=e.length
if(!(a>=0&&a<d))return A.b(e,a)
s=e[a]
r=s.length
if(!(b>=0&&b<r))return A.b(s,b)
q=s[b]
for(p=f.b,o=s.$flags|0,n=0;n<p;++n){if(!(n<r))return A.b(s,n)
m=s[n]
o&2&&A.a9(s)
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
i&2&&A.a9(m)
m[n]=h-j*g}}B.a.i(f.d,a,b)},
$S:9}
A.kM.prototype={
$2(b0,b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this
t.nO.a(b1)
s=a9.b
r=s.$1(b0)
for(q=a9.a,p=a9.c,o=a9.f,n=a9.w,m=n.length,l=b0.length,k=a9.r,j=a9.e,i=a9.x,h=a9.d,g=0,f=1/0,e=!1;q.a<p;f=a8){for(d=r.length,c=h,b=-1,a=0;a<j;++a){if(b1.A(0,a))continue
if(!(a<d))return A.b(r,a)
a0=r[a]
if(a0>c){if(e){b=a
break}c=a0
b=a}}if(b<0)return B.L
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
a1=a3}}if(a1<0)return B.dH
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
e=!1}}return B.bi},
$S:59}
A.dp.prototype={}
A.dn.prototype={}
A.ev.prototype={}
A.dm.prototype={}
A.kn.prototype={
$2(a,b){var s
A.C(a)
t.U.a(b)
s=this.a.h(0,a)
if(s==null)return
b.X(0,new A.km(s,this.b))},
$S:60}
A.km.prototype={
$2(a,b){var s,r,q
A.C(a)
A.T(b)
s=this.a.h(0,a)
if(s!=null){r=this.b
q=r.h(0,s)
r.i(0,s,(q==null?0:q)-b)}},
$S:61}
A.ko.prototype={
$2(a,b){var s=t.ca
s.a(a)
return B.b.S(s.a(b).a.f,a.a.f)},
$S:62}
A.k2.prototype={
$2(a,b){return A.T(a)+t.ca.a(b).b},
$S:63}
A.bQ.prototype={
G(){return"GLinkKind."+this.b}}
A.b7.prototype={
gdO(){return this.c.a7(this.e)*this.d}}
A.aV.prototype={
gaA(){var s=this.Q
return s==null?this.c-this.e:s}}
A.G.prototype={
gm(a){return this.w}}
A.iz.prototype={
ah(a){var s,r,q,p
for(s=this.b,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null}}
A.il.prototype={
gb4(){var s=this.c
return s===$?this.c=this.a.b.x:s},
gct(){var s,r=this,q=r.d
if(q===$){s=r.a.di()
r.d!==$&&A.qe()
r.d=s
q=s}return q},
bV(a){var s=this.gb4()*4
return(B.b.J(a.a/s)*73856093^B.b.J(a.b/s)*19349663)>>>0},
aD(a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=a0.a,e=g.gb4(),d=e*4,c=B.b.J(f/d),b=a0.b,a=B.b.J(b/d)
for(d=g.f,s=null,r=1/0,q=-1;q<=1;++q)for(p=(c+q)*73856093,o=-1;o<=1;++o){n=d.h(0,(p^(a+o)*19349663)>>>0)
if(n==null)continue
for(m=J.aa(n);m.l();){l=m.gp()
if(l.d!==a1)continue
k=l.b
j=k.a-f
k=k.b-b
i=Math.sqrt(j*j+k*k)
if(i<=e&&i<r){r=i
s=l}}}f=s==null
if(!f||!a2)return f?$.n6():s
f=g.r++
h=A.kT(g.gct().aZ(a0),"n"+f,a0,a1)
g.e.a.i(0,h.a,h)
J.bL(d.ac(g.bV(a0),new A.io()),h)
return h},
an(a,b){return this.aD(a,b,!0)},
bq(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8="outlet_spec_missing:",f9=f6.e
f9.Q=f6.gct()
s=f6.a
r=s.c
s=s.e
q=A.q(s)
p=q.j("B<1>")
o=A.p(new A.B(s,q.j("u(1)").a(new A.ip()),p),p.j("j.E"))
q=t.C
n=A.d([],q)
p=t.N
m=A.m(p,t.V)
for(l=o.length,k=0;k<o.length;o.length===l||(0,A.k)(o),++k)m.i(0,o[k].a,A.d([],q))
j=new A.iv()
i=new A.ix()
h=new A.iw(f6,o,i,j,m)
for(l=s.length,g=t.dr,k=0;k<s.length;s.length===l||(0,A.k)(s),++k){f=s[k]
e=f instanceof A.aX
d=e?f:f7
if(e){h.$2(d.d,A.d([d.e],g))
continue}e=f instanceof A.cg
c=e?f:f7
if(e){h.$2(c.d,A.d([c.e],g))
continue}e=f instanceof A.b6
b=e?f:f7
if(e){h.$2(b.d,B.B)
continue}e=f instanceof A.bm
a=e?f:f7
if(e){h.$2(a.d,A.d([a.w],g))
continue}e=f instanceof A.aW
a0=e?f:f7
if(e){h.$2(a0.d,A.d([a0.f],g))
continue}e=f instanceof A.aH
a1=e?f:f7
if(e){h.$2(a1.d,A.d([B.h],g))
continue}e=f instanceof A.b_
a=e?f:f7
if(e){h.$2(a.w,A.d([B.h],g))
continue}continue}for(l=o.length,k=0;e=o.length,k<e;o.length===l||(0,A.k)(o),++k){f=o[k]
a2=j.$1(f)
e=J.af(a2)
if(e.gm(a2)<2)continue
a3=f.a
h.$3$exclude(e.gu(a2),A.d([i.$1(f)],g),a3)
h.$3$exclude(e.gM(a2),A.d([i.$1(f)],g),a3)}for(l=t.g,g=t.n,a3=t.i,a4=t.cQ,a5=f9.y,a6=f9.z,k=0;k<o.length;o.length===e||(0,A.k)(o),++k){f=o[k]
a7=i.$1(f)
a8=j.$1(f)
if(J.as(a8)<2){a6.k(0,f.a)
continue}a9=f.a
b0=m.h(0,a9)
b0.toString
a2=A.eu(a8,!0,l)
if(b0.length!==0){b1=A.d([],g)
for(b2=b0.length,b3=0;b3<b0.length;b0.length===b2||(0,A.k)(b0),++b3){a1=b0[b3]
for(b4=a1.a,b5=a1.b,b6=0,b7=1/0,b8=0,b9=1;b9<a2.length;++b9){c0=b9-1
c1=A.lh(a1,a2[c0],a2[b9])
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
b6+=Math.sqrt(c4*c4+c3*c3)}B.a.k(b1,b8)}c7=A.n1(a2,b1)
a2=A.d([J.bM(B.a.gu(c7))],q)
for(b0=c7.length,b3=0;b3<c7.length;c7.length===b0||(0,A.k)(c7),++b3)B.a.B(a2,J.lu(c7[b3],1))}B.a.B(n,a2)
A:{b0=f instanceof A.aE
a=b0?f:f7
if(b0){c8=r.N(a.f)
c9=a7===B.f?B.i:B.j
b0=c8==null
b2=b0?f7:c8.a
b0=a.r||b0
f6.cL(a9,a2,a7,b0,a.w,b2,c9)
break A}b0=f instanceof A.aj
a1=b0?f:f7
if(b0){d0=r.a0(a1.r)
b0=d0==null
d1=b0?f7:d0.aB(a1.w)
if(b0||d1==null){B.a.k(a5,f8+a9)
a6.k(0,a9)
continue}c8=r.N(a1.e)
d2=A.aT(a2)
d3=a1.gb3()
d4=a1.z
d4=d4>0?d4:a1.y
b0=a1.x
d5=f6.ce(d1,b0)
d6=d5.a
d7=d5.b
b2=A.d([],g)
for(b4=a1.y,b9=0;b9<d3;++b9)b2.push(d4+b9*b4)
d8=f6.bZ(b2,d2)
d9=A.m(a3,a4)
for(b2=d8.length,b4=d1.c,b5=d1.w,c0=a1.as,c3=d0.x,c4=a1.at,c3=c0+c3+c4,c0=d1.b,b3=0;b3<d8.length;d8.length===b2||(0,A.k)(d8),++b3){c6=d8[b3]
d9.i(0,c6.a,new A.b7(a9,c6.c,b4,c6.b,b0,d6,d7,b5,c3,c0))}b0=c8==null
b2=b0?f7:c8.a
f6.cK(a9,a2,a7,d9,a1.f||b0,c4,0,b2,B.p)
break A}b0=f instanceof A.aA
e0=b0?f:f7
if(b0){c8=r.ad(e0.e)
if(c8==null){B.a.k(a5,"tape_spec_missing:"+a9)
a6.k(0,a9)
continue}d2=A.aT(a2)
b0=c8.r
d3=B.b.J(d2/b0)
b2=A.d([],g)
for(b9=1;b9<=d3;++b9)b2.push(b9*b0)
d8=f6.bZ(b2,d2)
b0=c8.z
b2=e0.f
d6=Math.max(b0,b2*(1-c8.at/100))
d7=Math.min(c8.Q,b2*(1+c8.ax/100))
d9=A.m(a3,a4)
for(b0=d8.length,b4=c8.w,b5=c8.y,c0=e0.x,c3=c8.b,b3=0;b3<d8.length;d8.length===b0||(0,A.k)(d8),++b3){c4=d8[b3]
d9.i(0,c4.a,new A.b7(a9,c4.c,b4,c4.b,b2,d6,d7,b5,c0,c3))}b0=c8.a
b2=c8.x
f6.bJ(a9,a2,a7,d9,!1,c0,e0.y,b2,f7,b0,B.p)
break A}break A}}for(q=[0,1],m=f9.c,l=f9.d,g=f9.e,k=0;k<2;++k){e1=q[k]
for(e=s.length,a3=e1===0,b3=0;b3<s.length;s.length===e||(0,A.k)(s),++b3){f=s[b3]
a4=f instanceof A.bm
if(a3===(a4||f instanceof A.aW))continue
B:{a9=f instanceof A.aX
d=a9?f:f7
if(a9){d0=r.a0(d.f)
a4=d0==null
d1=a4?f7:d0.aB(d.r)
if(a4||d1==null){B.a.k(a5,f8+f.a)
continue}d3=f6.aD(d.d,d.e,!1)
if(d3.a.length===0){a6.k(0,f.a)
continue}a4=d.w
e2=f6.ce(d1,a4)
a9=f.a
d3.r.k(0,a9)
B.a.k(d3.f,new A.b7(a9,-1,d1.c,1,a4,e2.a,e2.b,d1.w,d.z+d0.x,d1.b))
break B}a9=f instanceof A.cg
c=a9?f:f7
if(a9){d3=f6.an(c.d,c.e)
d3.r.k(0,f.a)
a4=c.f
if(a4!=null)d3.Q=a4
break B}a9=f instanceof A.b_
a=a9?f:f7
if(a9){d3=f6.aD(a.w,B.h,!1)
a4=d3.a
if(a4.length===0){a6.k(0,f.a)
continue}a9=f.a
d3.r.k(0,a9)
g.i(0,a9,a4)
break B}a9=f instanceof A.aH
a1=a9?f:f7
if(a9){d3=f6.an(a1.d,B.h)
a4=f.a
d3.r.k(0,a4)
d3.y=!0
d3.z=a4
l.i(0,a4,d3.a)
if(d3.w.length===0)a6.k(0,a4)
break B}a9=f instanceof A.b6
b=a9?f:f7
if(a9){a4=b.d
e3=f6.an(a4,B.h)
e4=f6.an(a4,B.f)
a9=f.a
e3.r.k(0,a9)
e4.r.k(0,a9)
b0=e3.a
b2=e4.a
b4=b.e
f6.aQ(new A.G("cv_"+a9,b0,b2,B.R,B.h,a9,0,0,f7,f7,!1,B.i,0,b.x,0,b4,f7,1,a4,a4,0))
m.i(0,a9,new A.A(b0,b2))
if(e4.w.length<=1)B.a.k(a5,"valve_no_zone_pipes:"+a9)
break B}a9={}
a9.a=null
if(a4){a9.a=f
b0=f}else b0=f7
if(a4){c8=r.aG(b0.e)
if(c8==null){B.a.k(a5,"pump_spec_missing:"+f.a)
continue}f6.bU(f.a,b0.d,b0.w,new A.iq(a9,f,c8))
break B}a4={}
a4.a=null
a9=f instanceof A.aW
if(a9){a4.a=f
b0=f}else b0=f7
if(a9){c8=r.a2(b0.e)
if(c8==null){B.a.k(a5,"valve_spec_missing:"+f.a)
continue}a9=c8.e
f6.bU(f.a,b0.d,b0.f,new A.ir(a4,f,a9===B.a0,c8))
break B}break B}}}for(q=f9.a,e=new A.M(q,q.r,q.e,A.i(q).j("M<2>"));e.l();){a3=e.d
for(a4=a3.w,a9=a4.length,c5=0,k=0;k<a9;++k)c5=Math.max(c5,a4[k].at)
a3.e=c5}for(e=new A.K(m,A.i(m).j("K<1,2>")).gt(0),a3=f9.f,a4=f9.r,a9=t.s;e.l();){e5=e.d
e6=e5.a
e7=e5.b.b
e8=A.J(p)
e9=A.J(p)
f0=A.d([e7],a9)
e8.k(0,e7)
while(b0=f0.length,b0!==0){if(0>=b0)return A.b(f0,-1)
f1=f0.pop()
d3=q.h(0,f1)
b0=d3.x
if(b0!=null&&b0!==e6){f2=A.d([e6,b0],a9)
B.a.a4(f2)
f3="zone_overlap:"+f2[0]+":"+f2[1]
if(!B.a.A(a5,f3))B.a.k(a5,f3)}d3.x=e6
for(b0=d3.w,b2=b0.length,k=0;k<b0.length;b0.length===b2||(0,A.k)(b0),++k){f4=b0[k]
if(f4.d===B.R)continue
if(f4.e!==B.f)continue
e9.k(0,f4.a)
f4.dx=e6
d=f4.b
if(f1===d)d=f4.c
if(e8.k(0,d))B.a.k(f0,d)}}a3.i(0,e6,e8)
a4.i(0,e6,e9)}p=A.p(new A.am(l,A.i(l).j("am<2>")),p)
l=f9.w
l.B(0,p)
for(e=f9.x;a3=p.length,a3!==0;){if(0>=a3)return A.b(p,-1)
f1=p.pop()
for(a3=q.h(0,f1).w,a4=a3.length,k=0;k<a3.length;a3.length===a4||(0,A.k)(a3),++k){f4=a3[k]
if(f4.e!==B.h||f4.d===B.R)continue
e.k(0,f4.a)
d=f4.b
if(f1===d)d=f4.c
if(l.k(0,d))B.a.k(p,d)}}for(q=s.length,k=0;k<s.length;s.length===q||(0,A.k)(s),++k){f=s[k]
if(!A.nI(f))continue
p=f.a
if(a6.A(0,p))continue
C:{if(f instanceof A.b6){f5=m.h(0,p)
if(!l.A(0,(f5==null?B.e2:f5).a))a6.k(0,p)
break C}e=f instanceof A.aE
if(e)a3=f.e===B.h
else a3=!1
if(a3){if(!f6.bw(p).Z(0,new A.is(f6)))a6.k(0,p)
break C}if(e||f instanceof A.aj||f instanceof A.aA){if(!f6.bw(p).Z(0,new A.it()))a6.k(0,p)
break C}e=f instanceof A.aX
d=e?f:f7
if(e){e=d.d
a3=d.e
d3=f6.aD(e,a3,!1)
e=d3.a
if(e.length===0)a6.k(0,p)
else if(a3===B.f?d3.x==null:!l.A(0,e))a6.k(0,p)
break C}if(f instanceof A.bm||f instanceof A.aW){if(!f6.bw(p).Z(0,new A.iu(f6)))a6.k(0,p)
break C}if(f instanceof A.b_){d3=g.h(0,p)
if(d3==null||!l.A(0,d3))a6.k(0,p)
break C}break C}}return f9},
bw(a){var s=this.e.b,r=A.q(s)
return new A.B(s,r.j("u(1)").a(new A.iy(a)),r.j("B<1>"))},
ce(a,b){var s=a.c.dD(b,a.y,a.x)
return new A.A(Math.max(s.a,a.e),Math.min(s.b,a.f))},
bZ(a,b){var s,r,q,p,o,n,m,l,k,j
t.bd.a(a)
s=a.length
if(s===0)return A.d([],t.nV)
r=this.b
q=B.b.ao(s/(r===$?this.b=Math.max(2,this.a.b.fy):r))
p=A.d([],t.nV)
for(o=0;s=a.length,o<s;o=n){n=o+q
m=Math.min(n,s)
l=m-o
for(k=o,j=0;k<m;++k){if(!(k>=0&&k<s))return A.b(a,k)
j+=a[k]}B.a.k(p,new A.a(Math.min(j/l,b),l,o))}return p},
aQ(a){var s=this.e
B.a.k(s.b,a)
s=s.a
B.a.k(s.h(0,a.b).w,a)
B.a.k(s.h(0,a.c).w,a)},
cL(a,b,c,d,e,f,g){var s,r,q,p,o,n,m,l,k,j,i
t.V.a(b)
for(s=a+"_",r=1;r<b.length;++r){q=r-1
p=this.an(b[q],c)
if(!(r<b.length))return A.b(b,r)
o=this.an(b[r],c)
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
this.aQ(new A.G(s+q,n,m,B.d,c,a,q,i,f,null,d,g,0,e,0,null,null,1,j,b[r],0))}},
bJ(a,b,a0,a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.V.a(b)
t.nh.a(a1)
s=A.ah([0,A.aT(b)],t.i)
for(r=0,q=1;q<b.length;++q){p=b[q-1]
o=b[q]
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)
s.k(0,r)}s.B(0,new A.ad(a1,A.i(a1).j("ad<1>")))
m=A.p(s,s.$ti.c)
B.a.a4(m)
for(p=m.length,o=a+"_",l=null,k=0,j=0,i=0,h=0;h<m.length;m.length===p||(0,A.k)(m),++h,k=g,l=e){g=m[h]
f=A.ks(b,g)
n=l!=null
e=n&&g-k<this.gb4()?l:this.an(f,a0)
e.r.k(0,a)
d=a1.h(0,g)
if(d!=null){B.a.k(e.f,d)
i+=d.d}if(n&&l.a!==e.a){c=j+1
this.aQ(new A.G(o+j,l.a,e.a,B.d,a0,a,c-1,g-k,a6,a7,a2,a8,a5*i,a3,0,null,null,1,A.ks(b,k),f,i))
j=c
i=0}}if(a4>0&&l!=null)B.a.k(l.f,new A.b7(a,-2,new A.bP(a4,0,0,0),1,1,0,1/0,0,0,"flush"))},
cK(a,b,c,d,e,f,g,h,i){return this.bJ(a,b,c,d,e,f,0,g,h,null,i)},
bU(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this
t.fC.a(a7)
s=a3.aD(a5,a6,!1)
r=s.a
if(r.length===0){a3.e.z.k(0,a4)
return}s.r.k(0,a4)
q=s.w
p=A.eu(q,!0,t.G)
o=p.length
n=null
if(o>=2){m=a3.cV(a6)
for(l=1/0,k=0;k<p.length;p.length===o||(0,A.k)(p),++k){j=p[k]
i=j.b
h=m.h(0,r===i?j.c:i)
if(h==null)h=1/0
if(h<l){l=h
n=j}}}else if(o===1)n=s.y?null:B.a.gu(p)
g=A.kT(s.c,"n"+a3.r++,a5,a6)
o=a3.e
i=o.a
f=g.a
i.i(0,f,g)
J.bL(a3.f.ac(a3.bV(a5),new A.im()),g)
g.r.k(0,a4)
for(e=p.length,d=g.w,o=o.b,k=0;k<p.length;p.length===e||(0,A.k)(p),++k){j=p[k]
if(j===n)continue
c=B.a.cn(o,j)
b=j.b
a=b===r?f:b
a0=j.c
a1=a0===r?f:a0
a2=new A.G(j.a,a,a1,j.d,j.e,j.f,j.r,j.w,j.x,j.y,j.z,j.Q,j.as,j.at,j.ax,j.ay,j.ch,j.CW,j.cx,j.cy,j.db)
B.a.i(o,c,a2)
B.a.T(q,j)
b=i.h(0,r===b?a0:b).w
B.a.T(b,j)
B.a.k(b,a2)
B.a.k(d,a2)}a3.aQ(a7.$2(r,f))},
cV(a){var s,r,q,p,o,n,m,l,k,j,i=A.m(t.N,t.i),h=A.d([],t.s)
if(a===B.h){for(s=this.e,r=s.d,r=new A.M(r,r.r,r.e,A.i(r).j("M<2>"));r.l();){q=r.d
i.i(0,q,0)
B.a.k(h,q)}for(s=s.a,s=new A.M(s,s.r,s.e,A.i(s).j("M<2>"));s.l();){r=s.d
if(r.y&&!i.E(r.a)){r=r.a
i.i(0,r,0)
B.a.k(h,r)}}}else for(s=this.e.c,s=new A.M(s,s.r,s.e,A.i(s).j("M<2>"));s.l();){r=s.d.b
i.i(0,r,0)
B.a.k(h,r)}for(s=this.e.a,p=0;p<h.length;p=o){o=p+1
n=h[p]
for(r=s.h(0,n).w,q=r.length,m=0;m<r.length;r.length===q||(0,A.k)(r),++m){l=r[m]
if(l.d===B.R)continue
k=l.b
if(n===k)k=l.c
if(!i.E(k)){j=i.h(0,n)
j.toString
i.i(0,k,j+1)
B.a.k(h,k)}}}return i}}
A.io.prototype={
$0(){return A.d([],t.go)},
$S:23}
A.ip.prototype={
$1(a){t.h.a(a)
return a instanceof A.aE||a instanceof A.aj||a instanceof A.aA},
$S:65}
A.iv.prototype={
$1(a){return t.f.a(a).gP()},
$S:66}
A.ix.prototype={
$1(a){var s=A.nH(a)
return s==null?B.f:s},
$S:67}
A.iw.prototype={
$3$exclude(a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this
t.lv.a(a3)
for(s=a1.b,r=s.length,q=a2.a,p=a2.b,o=a1.a,n=a1.e,m=a1.d,l=a1.c,k=0;k<s.length;s.length===r||(0,A.k)(s),++k){j=s[k]
i=j.a
if(i===a4)continue
if(!B.a.A(a3,l.$1(j)))continue
h=m.$1(j)
for(g=J.af(h),f=1;f<g.gm(h);++f){e=f-1
d=A.lh(a2,g.h(h,e),g.h(h,f))
c=d.a
b=d.b
a=c.a-q
a0=c.b-p
a0=Math.sqrt(a*a+a0*a0)
a=o.gb4()
if(a0<=a&&b>1e-9&&b<0.999999999){e=g.h(h,e)
a0=e.a-q
e=e.b-p
if(Math.sqrt(a0*a0+e*e)>a){e=g.h(h,f)
a0=e.a-q
e=e.b-p
a=Math.sqrt(a0*a0+e*e)>a
e=a}else e=!1
if(e){e=n.h(0,i)
e.toString
B.a.k(e,c)}}}}},
$2(a,b){return this.$3$exclude(a,b,null)},
$S:68}
A.iq.prototype={
$2(a,b){var s=this.b.a,r=this.a.a,q=r.d
return A.lI(q,q,!1,0,0,s,a,"pump_"+s,B.b9,0,0,null,this.c.a,r.w,0,0,r.f,null,b,B.i,null)},
$S:22}
A.ir.prototype={
$2(a,b){var s,r=this,q=r.b.a,p=r.c,o=p?B.d6:B.d5,n=r.a.a,m=r.d
if(p){p=n.r
p=p>0?p:m.z}else p=0
s=n.d
return A.lI(s,s,!1,0,0,q,a,"dev_"+q,o,0,0,null,null,n.f,0,p,1,null,b,B.i,m.a)},
$S:22}
A.is.prototype={
$1(a){return this.a.e.x.A(0,t.G.a(a).a)},
$S:1}
A.it.prototype={
$1(a){return t.G.a(a).dx!=null},
$S:1}
A.iu.prototype={
$1(a){t.G.a(a)
return this.a.e.x.A(0,a.a)||a.dx!=null},
$S:1}
A.iy.prototype={
$1(a){return t.G.a(a).f===this.a},
$S:1}
A.im.prototype={
$0(){return A.d([],t.go)},
$S:23}
A.ck.prototype={
G(){return"PivotKind."+this.b}}
A.iM.prototype={
gci(){var s=this,r=s.c+s.ax
return s.a===B.C?3.141592653589793*r*r*(B.b.a_(s.db,1,360)/360):r*Math.max(s.d,0)},
gbE(){var s=this.ch
return s<=0?0:this.gci()*this.ay/1000/(s*3600)},
gcw(){var s=this.e
return s<=0?0:Math.max(1,B.b.J(this.c/s))}}
A.cl.prototype={
n(){var s=this
return A.S(["i",s.a,"d",s.b,"q",s.c,"h",s.d,"dz",s.e],t.N,t.z)}}
A.bz.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"i",r.a)
q.i(0,"r0",r.b)
q.i(0,"r1",r.c)
q.i(0,"n",r.d)
q.i(0,"q",r.e)
q.i(0,"h",r.f)
s=r.r
if(s.length!==0)q.i(0,"noz",s)
return q}}
A.cL.prototype={
gcE(){return B.a.W(this.b,0,new A.iJ(),t.S)},
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.c)
o.i(0,"kind",p.d.b)
o.i(0,"q",p.e)
o.i(0,"qg",p.f)
o.i(0,"hin",p.r)
o.i(0,"hf",p.w)
o.i(0,"dz",p.x)
o.i(0,"hend",p.y)
o.i(0,"hp",p.z)
o.i(0,"hm",p.Q)
o.i(0,"n",p.as)
s=p.at
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.iK()),q),q.j("t.E"))
o.i(0,"towers",s)
o.i(0,"area",p.ax)
o.i(0,"depth",p.ay)
o.i(0,"hours",p.ch)
o.i(0,"iavg",p.CW)
o.i(0,"ipeak",p.cx)
o.i(0,"v",p.cy)
o.i(0,"warn",p.db)
s=p.dx
if(s!=null)o.i(0,"havail",s)
s=p.b
if(s.length!==0){r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.iL()),q),q.j("t.E"))
o.i(0,"spans",s)}return o}}
A.iJ.prototype={
$2(a,b){return A.a0(a)+t.fR.a(b).d},
$S:70}
A.iK.prototype={
$1(a){return t.oz.a(a).n()},
$S:71}
A.iL.prototype={
$1(a){return t.fR.a(a).n()},
$S:72}
A.k6.prototype={
$1(a){return 0},
$S:21}
A.kh.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=B.b.a1(a2*10),a0=b.a,a1=a0.h(0,a)
if(a1!=null)return a1
s=b.b
r=-1/0
if(s.a===B.C){q=B.b.a_(s.db,1,360)*3.141592653589793/180
p=Math.max(8,B.b.a1(b.c*q/6.283185307179586))
for(s=b.e,o=b.f,n=o.a,o=o.b,m=b.r,l=q/2,k=q>=6.283185306179586,j=b.d,i=0;i<=p;++i){h=k?0:l
g=j+q*i/p-h
h=s.$1(new A.z(n+a2*Math.cos(g),o+a2*Math.sin(g)))
if(typeof h!=="number")return h.U()
r=Math.max(r,h-m)}}else{o=b.d
n=Math.cos(o)
o=Math.sin(o)
m=-o
s=s.d
p=Math.max(4,B.b.a1(s/25))
for(l=b.f,k=l.a,j=k+n*a2,l=l.b,o=l+o*a2,h=b.e,i=0;i<=p;++i){f=s*i/p
e=m*f
f=n*f
d=h.$1(new A.z(j+e,o+f))
f=h.$1(new A.z(k+e,l+f))
if(typeof d!=="number")return d.U()
if(typeof f!=="number")return A.cz(f)
r=Math.max(r,d-f)}}c=isFinite(r)?Math.max(r,0):0
a0.i(0,a,c)
return c},
$S:21}
A.bb.prototype={
n(){var s,r,q=this,p=A.m(t.N,t.z)
p.i(0,"link",q.a)
p.i(0,"ent",q.b)
p.i(0,"seg",q.c)
s=q.d
r=t.n
p.i(0,"a",A.d([s.a,s.b],r))
s=q.e
p.i(0,"b",A.d([s.a,s.b],r))
p.i(0,"za",q.f)
p.i(0,"zb",q.r)
p.i(0,"len",q.w)
p.i(0,"d",q.x)
s=q.y
if(s!=null)p.i(0,"spec",s)
p.i(0,"name",q.z)
p.i(0,"q",q.Q)
p.i(0,"v",q.as)
p.i(0,"hf",q.at)
p.i(0,"p0",q.ax)
p.i(0,"p1",q.ay)
p.i(0,"pn",q.ch)
s=q.CW
if(s!=null)p.i(0,"zone",s)
if(q.cx)p.i(0,"ov",!0)
return p},
gm(a){return this.w}}
A.au.prototype={
n(){var s=this,r=s.c
return A.S(["ent",s.a,"i",s.b,"p",A.d([r.a,r.b],t.n),"z",s.d,"h",s.e,"q",s.f,"qn",s.r,"n",s.w,"lo",s.x,"hi",s.y,"label",s.z],t.N,t.z)}}
A.bO.prototype={
n(){var s=this
return A.S(["ent",s.a,"link",s.b,"q",s.c,"hf",s.d,"hp",s.e,"pu",s.f,"pd",s.r,"st",s.w],t.N,t.z)}}
A.cS.prototype={
ge_(){var s=this
return s.w>=s.y-0.000001&&s.x<=s.z+0.000001},
gbx(){var s=this.ax
return s.length===0?null:B.a.L(s,new A.js())},
gdN(){var s=this.ax
return s.length===0?null:B.a.L(s,new A.jr())},
cj(a){var s=this
t.fm.a(a)
return A.l5(s.z,s.y,s.dx,s.c,s.ay,s.e,s.cy,s.fr,s.x,s.w,s.Q,s.ax,s.dy,s.db,s.at,s.r,s.d,s.as,s.CW,s.a,s.f,s.cx,a,s.b)},
n(){var s,r,q=this,p=q.as.n(),o=q.at,n=A.q(o),m=n.j("r<1,h<c,@>>")
o=A.p(new A.r(o,n.j("h<c,@>(1)").a(new A.jt()),m),m.j("t.E"))
n=q.ax
m=A.q(n)
s=m.j("r<1,h<c,@>>")
n=A.p(new A.r(n,m.j("h<c,@>(1)").a(new A.ju()),s),s.j("t.E"))
m=q.ay
s=A.q(m)
r=s.j("r<1,h<c,@>>")
m=A.p(new A.r(m,s.j("h<c,@>(1)").a(new A.jv()),r),r.j("t.E"))
return A.S(["valve",q.a,"name",q.b,"conv",q.c,"q",q.d,"hd",q.e,"hv",q.f,"hreq",q.r,"pmin",q.w,"pmax",q.x,"lo",q.y,"hi",q.z,"pn",q.Q,"uni",p,"pipes",o,"outlets",n,"devices",m,"warn",q.ch,"zv",q.CW,"valveName",q.cx,"n",q.cy,"cost",q.db,"energy",q.dx,"ocu",q.dy,"epp",q.fr],t.N,t.z)}}
A.js.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e<=b.e?a:b},
$S:20}
A.jr.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e>=b.e?a:b},
$S:20}
A.jt.prototype={
$1(a){return t.h4.a(a).n()},
$S:10}
A.ju.prototype={
$1(a){return t.o.a(a).n()},
$S:76}
A.jv.prototype={
$1(a){return t.n6.a(a).n()},
$S:19}
A.cn.prototype={
n(){var s=this
return A.S(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"z",s.f,"calc",s.r,"dh",s.w,"mh",s.x,"dq",s.y,"mq",s.z],t.N,t.z)}}
A.aQ.prototype={
n(){var s=this,r=s.f
return A.S(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"p",A.d([r.a,r.b],t.n)],t.N,t.z)}}
A.b2.prototype={
n(){var s,r,q,p=this,o=p.d,n=A.q(o),m=n.j("r<1,h<c,@>>")
o=A.p(new A.r(o,n.j("h<c,@>(1)").a(new A.j6()),m),m.j("t.E"))
n=p.e
m=A.q(n)
s=m.j("r<1,h<c,@>>")
n=A.p(new A.r(n,m.j("h<c,@>(1)").a(new A.j7()),s),s.j("t.E"))
m=p.f
s=A.q(m)
r=s.j("r<1,h<c,@>>")
m=A.p(new A.r(m,s.j("h<c,@>(1)").a(new A.j8()),r),r.j("t.E"))
s=p.r
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.j9()),q),q.j("t.E"))
return A.S(["id",p.a,"name",p.b,"conv",p.c,"supplies",o,"valves",n,"pipes",m,"devices",s,"warn",p.w,"q",p.x,"dur",p.y,"energy",p.z],t.N,t.z)}}
A.j6.prototype={
$1(a){return t.ep.a(a).n()},
$S:78}
A.j7.prototype={
$1(a){return t.nN.a(a).n()},
$S:79}
A.j8.prototype={
$1(a){return t.h4.a(a).n()},
$S:10}
A.j9.prototype={
$1(a){return t.n6.a(a).n()},
$S:19}
A.ak.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"cat",r.a)
q.i(0,"desc",r.b)
q.i(0,"unit",r.c)
q.i(0,"qty",r.d)
q.i(0,"cost",r.e)
s=r.f
if(s!=null)q.i(0,"spec",s)
s=r.r
if(s.length!==0)q.i(0,"code",s)
s=r.w
if(s.length!==0)q.i(0,"sup",s)
return q}}
A.cb.prototype={
n(){var s=this
return A.S(["valve",s.a,"name",s.b,"q",s.c,"hd",s.d,"hreq",s.e,"n",s.f,"hend",s.r,"vmax",s.w,"vf",s.x,"conv",s.y],t.N,t.z)}}
A.bC.prototype={
n(){var s=this
return A.S(["ent",s.a,"ctx",s.b,"name",s.c,"v",s.d,"a",s.e,"dh",s.f,"hs",s.r,"pn",s.w,"tc",s.x,"tcrit",s.y],t.N,t.z)}}
A.e8.prototype={
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"timestamp",p.a.bB())
o.i(0,"method",p.b)
s=p.c
r=A.i(s).j("am<2>")
q=t.P
r=A.kY(new A.am(s,r),r.j("h<c,@>(j.E)").a(new A.hf()),r.j("j.E"),q)
s=A.p(r,A.i(r).j("j.E"))
o.i(0,"zones",s)
s=p.d
if(s.a!==0){r=A.i(s).j("am<2>")
q=A.kY(new A.am(s,r),r.j("h<c,@>(j.E)").a(new A.hg()),r.j("j.E"),q)
s=A.p(q,A.i(q).j("j.E"))
o.i(0,"pivots",s)}s=p.e
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.hh()),q),q.j("t.E"))
o.i(0,"systemFlows",s)
o.i(0,"messages",p.f)
s=p.r
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.hi()),q),q.j("t.E"))
o.i(0,"bom",s)
s=p.w
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.hj()),q),q.j("t.E"))
o.i(0,"flushing",s)
s=p.x
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.hk()),q),q.j("t.E"))
o.i(0,"surge",s)
s=p.y
s=A.p(s,A.i(s).c)
o.i(0,"unconnected",s)
o.i(0,"capital",p.z)
o.i(0,"annualCapital",p.Q)
o.i(0,"annualEnergy",p.as)
return o}}
A.hf.prototype={
$1(a){return t.kV.a(a).n()},
$S:80}
A.hg.prototype={
$1(a){return t.oY.a(a).n()},
$S:81}
A.hh.prototype={
$1(a){return t.ju.a(a).n()},
$S:82}
A.hi.prototype={
$1(a){return t.q.a(a).n()},
$S:83}
A.hj.prototype={
$1(a){return t.lG.a(a).n()},
$S:84}
A.hk.prototype={
$1(a){return t.eu.a(a).n()},
$S:85}
A.bP.prototype={
a7(a){if(a<=0)return 0
return this.a*Math.pow(a,this.b)},
cq(a){if(a<=0||this.c===0)return 0
return this.c*Math.pow(a,this.d)},
al(a){var s=Math.max(a,0.000001),r=this.b
if(r===0)return 1e-9
return this.a*r*Math.pow(s,r-1)},
dD(a,b,c){var s=this.b
if(s<=0.01)return B.e8
s=1/s
return new A.A(a*Math.pow(1-c,s),a*Math.pow(1+b,s))},
n(){var s=this
return A.S(["k",s.a,"x",s.b,"ra",s.c,"rb",s.d],t.N,t.z)}}
A.kf.prototype={
$2(a,b){return A.T(a)+A.T(b)},
$S:3}
A.kg.prototype={
$2(a,b){return A.T(a)+Math.abs(A.T(b)-this.a)},
$S:3}
A.cc.prototype={
G(){return"FrictionMethod."+this.b}}
A.bh.prototype={
b2(a){var s
if(a===0)return 0
s=this.a*Math.pow(Math.abs(a),this.b)+this.c
return a<0?-s:s},
al(a){var s=this.b
return Math.max(s*this.a*Math.pow(Math.max(Math.abs(a),1e-9),s-1),1e-9)},
n(){return A.S(["k",this.a,"n",this.b,"c",this.c],t.N,t.z)}}
A.de.prototype={
G(){return"HNodeKind."+this.b}}
A.bk.prototype={}
A.bR.prototype={
G(){return"HLinkKind."+this.b}}
A.cE.prototype={
G(){return"LinkStatus."+this.b}}
A.dd.prototype={
gm(a){return this.f}}
A.iA.prototype={}
A.eF.prototype={}
A.es.prototype={}
A.cJ.prototype={}
A.ee.prototype={
H(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7,f8=this,f9=A.d([],t.s),g0=f8.b,g1=A.i(g0).j("am<2>"),g2=A.p(new A.am(g0,g1),g1.j("j.E"))
g1=t.N
s=A.m(g1,t.S)
for(r=g2.length,q=0,p=0;p<g2.length;g2.length===r||(0,A.k)(g2),++p){o=g2[p]
if(o.b===B.S){n=q+1
s.i(0,o.a,q)
q=n}}r=A.q(g2)
if(!new A.B(g2,r.j("u(1)").a(new A.i6()),r.j("B<1>")).gt(0).l())B.a.k(f9,"no_fixed_head_node")
r=t.i
m=A.m(g1,r)
for(l=g2.length,p=0;p<g2.length;g2.length===l||(0,A.k)(g2),++p){o=g2[p]
if(o.b===B.T){k=o.e
if(k==null)k=o.c}else k=o.c+10
m.i(0,o.a,k)}j=A.d([],t.n)
for(l=f8.c,k=l.length,p=0;p<l.length;l.length===k||(0,A.k)(l),++p){i=l[p]
switch(i.d.a){case 0:case 3:case 2:h=i.e
B.a.k(j,3.141592653589793*h*h/4)
break
case 1:h=i.z
if(h!=null){h=isFinite(h.gbA())?h.gbA()/2:0.01
h=Math.max(h,0.0001)}else h=0.01
B.a.k(j,h)
break
case 4:B.a.k(j,0)
break}h=i.d
g=h===B.K
if(g)i.ay=B.x
h=h===B.d7
if(h)i.ay=B.l
if(!h&&!g)i.ay=B.n}k=A.m(g1,r)
for(h=g2.length,p=0;p<g2.length;g2.length===h||(0,A.k)(g2),++p)k.i(0,g2[p].a,0)
f=A.m(g1,t.y)
h=l.length
e=A.b9(h,1,!1,r)
g=l.length
d=A.b9(g,0,!1,r)
r=f8.a.a
b=r===B.b8
r=r===B.ag
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
else{a6=f8.c2(i,a3)
o=r?1.852:2
a7=Math.max(Math.abs(a3),1e-7)
a8=i.x
if(a8>0){a9=i.e
b0=3.141592653589793*a9*a9/4
b1=a8/(19.6133*b0*b0)}else b1=0
b2=o*a6*Math.pow(a7,o-1)+2*b1*a7
if(b&&a7>0.000001)b2+=(f8.c2(i,a7*1.01)-a6)/(a7*0.01)*Math.pow(a7,o)
b3=a6*Math.pow(a7,o)+b1*a7*a7
a4=Math.max(b2,1e-12)
a5=a3<0?-b3:b3}break
case 3:b4=i.Q
if(b4==null)b4=B.a1
if(i.ay===B.l)a5=1e8*a3
else{a4=Math.max(b4.al(a3),1e-9)
a5=b4.b2(a3)}break
case 2:b4=i.Q
a8=i.ay
if(a8===B.l)a5=1e8*a3
else if(a8===B.n){a8=b4!=null
a4=a8?Math.max(b4.al(a3),1e-9):0.01
a5=a8?b4.b2(a3):0.01*a3}else{a4=1/0
a5=0}break
case 1:b5=i.z
if(b5==null||i.ay===B.l)a5=1e8*a3
else if(a3<=0)a5=1e8*a3
else{b6=b5.gbA()
if(isFinite(b6)&&a3>b6){b7=Math.max(-b5.al(b6),0.000001)
a5=-b5.bt(b6)+(a3-b6)*b7
a4=b7}else{a4=Math.max(-b5.al(a3),0.000001)
a5=-b5.bt(a3)}}break
default:a4=null
a5=null}B.a.i(e,a2,a4)
B.a.i(d,a2,a5)}b8=A.od(q)
for(a8=g2.length,a9=b8.c,b9=a9.length,c0=b8.b,c1=!1,p=0;p<g2.length;g2.length===a8||(0,A.k)(g2),++p){o=g2[p]
c2=o.a
c3=s.h(0,c2)
if(c3==null)continue
c4=o.d
c5=o.f
if(c5!=null&&o.r>0){c6=o.c+o.w
c7=m.h(0,c2)
c7.toString
c8=c7-c6
c9=c8>0
d0=f.h(0,c2)
if(d0!=null&&d0!==c9)c1=!0
f.i(0,c2,c9)
if(!c9){if(c3>>>0!==c3||c3>=c0.length)return A.b(c0,c3)
c7=c0[c3]
d1=c7.h(0,c3)
c7.i(0,c3,(d1==null?0:d1)+1e-12)
if(c3>>>0!==c3||c3>=b9)return A.b(a9,c3)
B.a.i(a9,c3,a9[c3]+1e-12*c6)
k.i(0,c2,0)}else{b5=Math.max(c8,0.000001)
d2=c5.a7(b5)*o.r
d3=1/Math.max(c5.al(b5)*o.r,1e-9)
if(c3>>>0!==c3||c3>=c0.length)return A.b(c0,c3)
c7=c0[c3]
d1=c7.h(0,c3)
if(d1==null)d1=0
c7.i(0,c3,d1+1/d3)
if(c3>>>0!==c3||c3>=b9)return A.b(a9,c3)
B.a.i(a9,c3,a9[c3]+(-d2+b5/d3+c6/d3))
k.i(0,c2,d2)}}if(c3>>>0!==c3||c3>=b9)return A.b(a9,c3)
B.a.i(a9,c3,a9[c3]-c4)}for(a2=0;a2<l.length;++a2){i=l[a2]
a8=i.b
d4=s.h(0,a8)
c2=i.c
d5=s.h(0,c2)
if(i.d===B.K&&i.ay===B.x){a8=g0.h(0,c2).c
if(d5!=null){if(d5>>>0!==d5||d5>=c0.length)return A.b(c0,d5)
c2=c0[d5]
c7=c2.h(0,d5)
c2.i(0,d5,(c7==null?0:c7)+1e8)
if(d5>>>0!==d5||d5>=b9)return A.b(a9,d5)
B.a.i(a9,d5,a9[d5]+1e8*(a8+i.as))
a8=a9[d5]
if(!(a2<j.length))return A.b(j,a2)
B.a.i(a9,d5,a8+j[a2])}if(d4!=null){if(d4>>>0!==d4||d4>=b9)return A.b(a9,d4)
a8=a9[d4]
if(!(a2<j.length))return A.b(j,a2)
B.a.i(a9,d4,a8+-j[a2])}continue}if(!(a2<h))return A.b(e,a2)
d6=1/e[a2]
if(!(a2<j.length))return A.b(j,a2)
a3=j[a2]
if(!(a2<g))return A.b(d,a2)
a5=d[a2]
c7=d4==null
d1=!c7
if(d1){if(d4>>>0!==d4||d4>=c0.length)return A.b(c0,d4)
d7=c0[d4]
d8=d7.h(0,d4)
d7.i(0,d4,(d8==null?0:d8)+d6)
if(d4>>>0!==d4||d4>=b9)return A.b(a9,d4)
B.a.i(a9,d4,a9[d4]+(-a3+a5*d6))
if(d5==null){d7=a9[d4]
c2=m.h(0,c2)
c2.toString
B.a.i(a9,d4,d7+c2*d6)}}c2=d5!=null
if(c2){if(d5>>>0!==d5||d5>=c0.length)return A.b(c0,d5)
d7=c0[d5]
d8=d7.h(0,d5)
d7.i(0,d5,(d8==null?0:d8)+d6)
if(d5>>>0!==d5||d5>=b9)return A.b(a9,d5)
B.a.i(a9,d5,a9[d5]+(a3-a5*d6))
if(c7){c7=a9[d5]
a8=m.h(0,a8)
a8.toString
B.a.i(a9,d5,c7+a8*d6)}}if(d1&&c2){a8=-d6
if(d4>>>0!==d4||d4>=c0.length)return A.b(c0,d4)
c2=c0[d4]
c7=c2.h(0,d5)
c2.i(0,d5,(c7==null?0:c7)+a8)
if(d4!==d5){if(d5>>>0!==d5||d5>=c0.length)return A.b(c0,d5)
c2=c0[d5]
c7=c2.h(0,d4)
c2.i(0,d4,(c7==null?0:c7)+a8)}}}d9=b8.H()
for(a8=g2.length,a9=d9.length,p=0;p<g2.length;g2.length===a8||(0,A.k)(g2),++p){b9=g2[p].a
c3=s.h(0,b9)
if(c3!=null){if(c3>>>0!==c3||c3>=a9)return A.b(d9,c3)
e0=d9[c3]
if(isFinite(e0))m.i(0,b9,e0)}}for(e1=0,e2=0,a2=0;a2<l.length;++a2){i=l[a2]
a8=m.h(0,i.b)
a8.toString
a9=i.c
b9=m.h(0,a9)
b9.toString
if(i.d===B.K&&i.ay===B.x){a8=g0.h(0,a9).d
b9=k.h(0,a9)
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
B.a.i(j,a2,e6)}e7=e2>0?e1/e2:0
if(e1<1e-9)e7=0
for(e8=c1,a2=0;a2<l.length;++a2){i=l[a2]
a8=i.d
if(a8===B.ah&&i.y){a9=m.h(0,i.b)
a9.toString
b9=m.h(0,i.c)
b9.toString
e9=a9-b9
f0=i.ay===B.l
f1=!0
if(!f0){if(!(a2<j.length))return A.b(j,a2)
a9=j[a2]<-0.000001||e9<-0.0001}else a9=!1
if(a9){i.ay=B.l
e8=f1}else if(f0&&e9>0.0001){i.ay=B.n
B.a.i(j,a2,1e-7)
e8=f1}}if(a8===B.K){a8=i.c
f2=g0.h(0,a8).c+i.as
a9=m.h(0,i.b)
a9.toString
a8=m.h(0,a8)
a8.toString
f3=i.ay
switch(f3.a){case 2:if(!(a2<j.length))return A.b(j,a2)
if(j[a2]<-0.000001){i.ay=B.l
a8=B.l}else if(a9<f2-0.0001){i.ay=B.n
a8=B.n}else a8=f3
break
case 0:if(!(a2<j.length))return A.b(j,a2)
if(j[a2]<-0.000001){i.ay=B.l
a8=B.l}else if(a9>f2+0.0001){i.ay=B.x
a8=B.x}else a8=f3
break
case 1:b9=a9>a8+0.0001
if(b9&&a9<f2-0.0001){i.ay=B.n
a8=B.n}else if(b9&&a8<f2-0.0001){i.ay=B.x
a8=B.x}else a8=f3
break
default:a8=f3}if(a8!==f3)e8=!0
if(a8===B.l)B.a.i(j,a2,0)}}if(e7<0.00001&&!e8&&a>1){c=!0
break}if(e7>a0*1.5&&a>3)a1=Math.max(0.3,a1*0.7)
else if(a1<1)a1=Math.min(1,a1*1.2);++a
a0=e7}if(!c)B.a.k(f9,"not_converged")
f4=A.m(g1,t.oX)
for(g0=g2.length,p=0;p<g2.length;g2.length===g0||(0,A.k)(g2),++p){o=g2[p]
r=o.a
k=m.h(0,r)
k.toString
h=o.f
if(h!=null&&o.r>0)h.a7(Math.max(k-o.c-o.w,0))
f4.i(0,r,new A.eF(k,k-o.c))}f5=A.m(g1,t.g_)
for(a2=0;a2<l.length;++a2){i=l[a2]
if(!(a2<j.length))return A.b(j,a2)
f6=j[a2]
g0=m.h(0,i.b)
g0.toString
g1=m.h(0,i.c)
g1.toString
f7=i.d===B.ba&&i.z!=null&&f6>0?i.z.bt(f6):0
f5.i(0,i.a,new A.es(f6,g0-g1,i.ay,f7))}return new A.cJ(c,f4,f5)},
c2(a,b){var s,r,q=this.a
switch(q.a.a){case 0:return 10.67*a.f/(Math.pow(a.r,1.852)*Math.pow(a.e,4.871))
case 1:s=a.e
r=3.141592653589793*s*s/4
return A.mL(a.w/s,A.ft(s,Math.max(Math.abs(b),1e-7))*s/q.b)*a.f/(s*2*9.80665*r*r)}}}
A.i6.prototype={
$1(a){return t.b.a(a).b===B.T},
$S:87}
A.cN.prototype={
bt(a){var s=this,r=s.d,q=a/r
return r*r*(s.a*q*q+s.b*q+s.c)},
al(a){var s=this.d
return s*(2*this.a*(a/s)+this.b)},
gbA(){var s,r,q,p,o=this,n=o.a
if(n===0){n=o.b
return n<0?-o.c/n:1/0}s=o.b
r=s*s-4*n*o.c
if(r<0)return 1/0
s=-s
n=2*n
q=t.ee
p=A.p(new A.B(A.d([(s-Math.sqrt(r))/n,(s+Math.sqrt(r))/n],t.n),t.eq.a(new A.iX()),q),q.j("j.E"))
B.a.a4(p)
return p.length===0?1/0:B.a.gu(p)*o.d},
n(){var s=this
return A.S(["a",s.a,"b",s.b,"c",s.c,"w",s.d],t.N,t.z)}}
A.iX.prototype={
$1(a){return A.T(a)>0},
$S:4}
A.iW.prototype={
$1(a){t.aL.a(a)
return a.a>=0&&a.b>=0},
$S:89}
A.j0.prototype={
H(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5={},b6=b4.a
if(b6===0)return B.bd
s=b4.b
r=A.q(s)
q=r.j("r<1,h<f,e>>")
p=A.p(new A.r(s,r.j("h<f,e>(1)").a(new A.j1()),q),q.j("t.E"))
s=t.i
o=A.eu(b4.c,!0,s)
n=A.b9(b6,!1,!1,t.y)
r=t.X
m=A.d([],r)
l=A.d([],t.l0)
q=t.S
k=J.ek(b6,q)
for(j=0;j<b6;++j){if(!(j<p.length))return A.b(p,j)
i=p[j]
i=i.gm(i)
if(!(j<p.length))return A.b(p,j)
k[j]=i-(p[j].E(j)?1:0)}h=A.m(q,t.nO)
for(j=0;j<b6;++j){if(!(j<k.length))return A.b(k,j)
h.ac(k[j],new A.j2()).k(0,j)}b5.a=0
g=new A.j3(b5,b4,h,n)
f=new A.j4(b5,h,k)
for(i=t.n,e=0;e<b6;++e){d=g.$0()
if(d<0)break
B.a.i(n,d,!0)
if(d>>>0!==d||d>=p.length)return A.b(p,d)
c=p[d]
b=c.h(0,d)
if(Math.abs(b==null?0:b)<1e-300)c.i(0,d,1e-30)
a=c.h(0,d)
a.toString
a0=A.d([],r)
a1=A.d([],i)
for(a2=c.gb_(),a2=a2.gt(a2);a2.l();){a3=a2.gp()
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
B.a.i(o,j,a3-a7*o[d])
if(!(j<p.length))return A.b(p,j)
a8=p[j]
a8.T(0,d)
for(a2=-a7,a9=0;a9<a0.length;++a9){b0=a0[a9]
if(!(a9<a1.length))return A.b(a1,a9)
a3=a1[a9]
a4=a8.h(0,b0)
if(a4==null)a4=0
a8.i(0,b0,a4+a2*a3)}a2=a8.gm(a8)
f.$2(j,a2-(a8.E(j)?1:0))}B.a.k(m,d)
a2=A.m(q,s)
for(a6=0;a6<a0.length;++a6){a3=a0[a6]
if(!(a6<a1.length))return A.b(a1,a6)
a2.i(0,a3,a1[a6])}a2.i(0,d,a)
B.a.k(l,a2)}a6=A.b9(b6,0,!1,s)
for(b1=m.length-1;b1>=0;--b1){if(!(b1<m.length))return A.b(m,b1)
d=m[b1]
if(!(b1<l.length))return A.b(l,b1)
c=l[b1]
if(!(d>=0&&d<o.length))return A.b(o,d)
b2=o[d]
for(s=new A.ag(c,c.r,c.e,A.i(c).j("ag<1,2>"));s.l();){b3=s.d
r=b3.a
if(r!==d){q=b3.b
if(!(r>=0&&r<b6))return A.b(a6,r)
b2-=q*a6[r]}}s=c.h(0,d)
s.toString
B.a.i(a6,d,b2/s)}return a6}}
A.j1.prototype={
$1(a){return A.nX(t.jq.a(a),t.S,t.i)},
$S:90}
A.j2.prototype={
$0(){return A.J(t.S)},
$S:18}
A.j3.prototype={
$0(){var s,r,q,p,o,n,m,l=this
for(s=l.a,r=l.b.a,q=r+1,p=l.c;;){o=p.h(0,s.a)
if(o!=null&&o.ga8(o)){n=o.gu(o)
o.T(0,n)
return n}if(++s.a>q){for(s=l.d,q=s.length,m=0;m<r;++m){if(!(m<q))return A.b(s,m)
if(!s[m])return m}return-1}}},
$S:92}
A.j4.prototype={
$2(a,b){var s,r=this.b,q=this.c
if(!(a>=0&&a<q.length))return A.b(q,a)
s=r.h(0,q[a])
if(s!=null)s.T(0,a)
B.a.i(q,a,b)
r.ac(b,new A.j5()).k(0,a)
r=this.a
if(b<r.a)r.a=b},
$S:9}
A.j5.prototype={
$0(){return A.J(t.S)},
$S:18}
A.dE.prototype={
n(){var s=this
return A.S(["count",s.a,"mean",s.b,"min",s.c,"max",s.d,"cu",s.e,"du",s.f,"eu",s.r,"us",s.w,"qvar",s.x,"cv",s.y],t.N,t.z)}}
A.jm.prototype={
$1(a){return isFinite(A.T(a))},
$S:4}
A.jn.prototype={
$2(a,b){return A.T(a)+A.T(b)},
$S:3}
A.jo.prototype={
$2(a,b){return A.T(a)+Math.abs(A.T(b)-this.a)},
$S:3}
A.jp.prototype={
$2(a,b){return A.T(a)+A.T(b)},
$S:3}
A.jq.prototype={
$2(a,b){var s
A.T(a)
s=A.T(b)-this.a
return a+s*s},
$S:3}
A.aY.prototype={
G(){return"PipeMaterial."+this.b}}
A.i5.prototype={
n(){var s=this
return A.S(["zone",s.a,"north",s.b,"e0",s.c,"n0",s.d],t.N,t.z)}}
A.aZ.prototype={
G(){return"PipeUsage."+this.b}}
A.H.prototype={
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
o.i(0,"nominalMm",p.e)
o.i(0,"idMm",p.f)
o.i(0,"material",p.r.b)
o.i(0,"c",p.w)
o.i(0,"roughMm",p.x)
o.i(0,"ratingM",p.y)
o.i(0,"wallMm",p.z)
o.i(0,"cost",p.Q)
s=p.as
r=A.i(s)
q=r.j("ca<1,c>")
s=A.p(new A.ca(s,r.j("c(1)").a(new A.iI()),q),q.j("j.E"))
o.i(0,"usage",s)
o.i(0,"enabled",p.at)
s=p.c
if(s.length!==0)o.i(0,"sup",s)
s=p.d
if(s.length!==0)o.i(0,"code",s)
return o}}
A.iI.prototype={
$1(a){return t.W.a(a).b},
$S:93}
A.iH.prototype={
$1(a){return A.ac(B.dh,A.C(a),t.W)},
$S:94}
A.ba.prototype={
G(){return"OutletKind."+this.b}}
A.D.prototype={
n(){var s=this
return A.S(["id",s.a,"name",s.b,"curve",s.c.n(),"arc",s.d,"minH",s.e,"maxH",s.f,"defH",s.r,"cv",s.w,"tolB",s.x,"tolA",s.y],t.N,t.z)}}
A.a3.prototype={
aB(a){var s=this.f
if(s.length===0)return null
return B.a.ag(s,new A.iD(a),new A.iE(this))},
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
o.i(0,"kind",p.e.b)
s=p.f
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.iF()),q),q.j("t.E"))
o.i(0,"nozzles",s)
o.i(0,"cost",p.r)
o.i(0,"inletMm",p.w)
o.i(0,"riser",p.x)
o.i(0,"enabled",p.y)
s=p.c
if(s.length!==0)o.i(0,"sup",s)
s=p.d
if(s.length!==0)o.i(0,"code",s)
return o}}
A.iD.prototype={
$1(a){return t.mP.a(a).a===this.a},
$S:95}
A.iE.prototype={
$0(){return B.a.gu(this.a.f)},
$S:96}
A.iF.prototype={
$1(a){return t.mP.a(a).n()},
$S:97}
A.iC.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j=null,i=t.P
i.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
i=A.lH(i.a(a.h(0,"curve")))
q=A.w(a.h(0,"arc"))
if(q==null)q=j
if(q==null)q=360
p=A.w(a.h(0,"minH"))
if(p==null)p=j
if(p==null)p=5
o=A.w(a.h(0,"maxH"))
if(o==null)o=j
if(o==null)o=60
n=A.w(a.h(0,"defH"))
if(n==null)n=j
if(n==null)n=20
m=A.w(a.h(0,"cv"))
if(m==null)m=j
if(m==null)m=0.03
l=A.w(a.h(0,"tolB"))
if(l==null)l=j
if(l==null)l=0.05
k=A.w(a.h(0,"tolA"))
if(k==null)k=j
return new A.D(s,r,i,q,p,o,n,m,l,k==null?0.05:k)},
$S:98}
A.aP.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"id",r.a)
q.i(0,"name",r.b)
q.i(0,"nominalMm",r.e)
q.i(0,"idMm",r.f)
q.i(0,"spacing",r.r)
q.i(0,"emitter",r.w.n())
q.i(0,"barbK",r.x)
q.i(0,"cv",r.y)
q.i(0,"minH",r.z)
q.i(0,"maxH",r.Q)
q.i(0,"inletH",r.as)
q.i(0,"tolB",r.at)
q.i(0,"tolA",r.ax)
q.i(0,"ratingM",r.ay)
q.i(0,"roughMm",r.ch)
q.i(0,"c",r.CW)
q.i(0,"cost",r.cx)
q.i(0,"enabled",r.cy)
s=r.c
if(s.length!==0)q.i(0,"sup",s)
s=r.d
if(s.length!==0)q.i(0,"code",s)
return q}}
A.aG.prototype={
G(){return"ValveKind."+this.b}}
A.P.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"id",r.a)
q.i(0,"name",r.b)
q.i(0,"kind",r.e.b)
q.i(0,"sizeMm",r.f)
q.i(0,"loss",r.r.n())
q.i(0,"minQ",r.w)
q.i(0,"maxQ",r.x)
q.i(0,"cost",r.y)
q.i(0,"setting",r.z)
q.i(0,"enabled",r.Q)
s=r.c
if(s.length!==0)q.i(0,"sup",s)
s=r.d
if(s.length!==0)q.i(0,"code",s)
return q}}
A.aN.prototype={
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
s=p.f
r=A.q(s)
q=r.j("r<1,o<e>>")
s=A.p(new A.r(s,r.j("o<e>(1)").a(new A.iZ()),q),q.j("t.E"))
o.i(0,"points",s)
o.i(0,"eff",p.w)
o.i(0,"minQ",p.x)
o.i(0,"maxQ",p.y)
o.i(0,"cost",p.z)
o.i(0,"enabled",p.Q)
s=p.c
if(s.length!==0)o.i(0,"sup",s)
s=p.d
if(s.length!==0)o.i(0,"code",s)
s=p.e
if(s>0)o.i(0,"kw",s)
return o}}
A.iZ.prototype={
$1(a){t.aL.a(a)
return A.d([a.a,a.b],t.n)},
$S:99}
A.iY.prototype={
$1(a){var s=J.af(a)
return new A.A(A.ar(s.h(a,0)),A.ar(s.h(a,1)))},
$S:150}
A.a6.prototype={
G(){return"FittingKind."+this.b}}
A.W.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"id",r.a)
q.i(0,"name",r.b)
q.i(0,"kind",r.e.b)
q.i(0,"sizeMm",r.f)
s=r.r
if(s>0)q.i(0,"size2Mm",s)
q.i(0,"cost",r.w)
q.i(0,"enabled",r.x)
s=r.c
if(s.length!==0)q.i(0,"sup",s)
s=r.d
if(s.length!==0)q.i(0,"code",s)
s=r.y
if(s.length!==0)q.i(0,"mat",s)
return q}}
A.fA.prototype={
dz(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
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
N(a){var s
if(a==null)s=null
else{s=this.a
s=new A.ab(s,A.q(s).j("ab<1,H?>"))
s=s.ag(s,new A.fS(a),new A.fT())}return s},
a0(a){var s
if(a==null)s=null
else{s=this.b
s=new A.ab(s,A.q(s).j("ab<1,a3?>"))
s=s.ag(s,new A.fQ(a),new A.fR())}return s},
ad(a){var s
if(a==null)s=null
else{s=this.c
s=new A.ab(s,A.q(s).j("ab<1,aP?>"))
s=s.ag(s,new A.fY(a),new A.fZ())}return s},
a2(a){var s
if(a==null)s=null
else{s=this.d
s=new A.ab(s,A.q(s).j("ab<1,P?>"))
s=s.ag(s,new A.h5(a),new A.h6())}return s},
aG(a){var s
if(a==null)s=null
else{s=this.e
s=new A.ab(s,A.q(s).j("ab<1,aN?>"))
s=s.ag(s,new A.fW(a),new A.fX())}return s},
ab(a){var s=this.a,r=A.q(s),q=r.j("B<1>")
s=A.p(new A.B(s,r.j("u(1)").a(new A.fU(a)),q),q.j("j.E"))
B.a.am(s,new A.fV())
return s},
n(){var s,r,q,p,o,n=this,m=n.a,l=A.q(m),k=l.j("r<1,h<c,@>>")
m=A.p(new A.r(m,l.j("h<c,@>(1)").a(new A.h_()),k),k.j("t.E"))
l=n.b
k=A.q(l)
s=k.j("r<1,h<c,@>>")
l=A.p(new A.r(l,k.j("h<c,@>(1)").a(new A.h0()),s),s.j("t.E"))
k=n.c
s=A.q(k)
r=s.j("r<1,h<c,@>>")
k=A.p(new A.r(k,s.j("h<c,@>(1)").a(new A.h1()),r),r.j("t.E"))
s=n.d
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.h2()),q),q.j("t.E"))
r=n.e
q=A.q(r)
p=q.j("r<1,h<c,@>>")
r=A.p(new A.r(r,q.j("h<c,@>(1)").a(new A.h3()),p),p.j("t.E"))
q=n.f
p=A.q(q)
o=p.j("r<1,h<c,@>>")
q=A.p(new A.r(q,p.j("h<c,@>(1)").a(new A.h4()),o),o.j("t.E"))
return A.S(["pipes",m,"outlets",l,"tapes",k,"valves",s,"pumps",r,"fittings",q],t.N,t.z)}}
A.fS.prototype={
$1(a){return t.cV.a(a).a===this.a},
$S:101}
A.fT.prototype={
$0(){return null},
$S:2}
A.fQ.prototype={
$1(a){return t.h2.a(a).a===this.a},
$S:102}
A.fR.prototype={
$0(){return null},
$S:2}
A.fY.prototype={
$1(a){return t.lJ.a(a).a===this.a},
$S:103}
A.fZ.prototype={
$0(){return null},
$S:2}
A.h5.prototype={
$1(a){return t.kf.a(a).a===this.a},
$S:104}
A.h6.prototype={
$0(){return null},
$S:2}
A.fW.prototype={
$1(a){return t.gL.a(a).a===this.a},
$S:105}
A.fX.prototype={
$0(){return null},
$S:2}
A.fU.prototype={
$1(a){t.p.a(a)
return a.at&&a.as.A(0,this.a)},
$S:6}
A.fV.prototype={
$2(a,b){var s=t.p
return B.b.S(s.a(a).f,s.a(b).f)},
$S:106}
A.h_.prototype={
$1(a){return t.p.a(a).n()},
$S:107}
A.h0.prototype={
$1(a){return t.fa.a(a).n()},
$S:108}
A.h1.prototype={
$1(a){return t.gs.a(a).n()},
$S:109}
A.h2.prototype={
$1(a){return t.e4.a(a).n()},
$S:110}
A.h3.prototype={
$1(a){return t.dz.a(a).n()},
$S:111}
A.h4.prototype={
$1(a){return t.kN.a(a).n()},
$S:112}
A.fK.prototype={
$1(a){return A.o2(t.P.a(a))},
$S:113}
A.fL.prototype={
$1(a){return A.o0(t.P.a(a))},
$S:114}
A.fM.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=null,a1=t.P
a1.a(a2)
s=A.C(a2.h(0,"id"))
r=A.C(a2.h(0,"name"))
q=A.v(a2.h(0,"sup"))
if(q==null)q=""
p=A.v(a2.h(0,"code"))
if(p==null)p=""
o=A.w(a2.h(0,"nominalMm"))
if(o==null)o=a0
if(o==null)o=16
n=A.ar(a2.h(0,"idMm"))
m=A.ar(a2.h(0,"spacing"))
a1=A.lH(a1.a(a2.h(0,"emitter")))
l=A.w(a2.h(0,"barbK"))
if(l==null)l=a0
if(l==null)l=0.4
k=A.w(a2.h(0,"cv"))
if(k==null)k=a0
if(k==null)k=0.03
j=A.w(a2.h(0,"minH"))
if(j==null)j=a0
if(j==null)j=4
i=A.w(a2.h(0,"maxH"))
if(i==null)i=a0
if(i==null)i=15
h=A.w(a2.h(0,"inletH"))
if(h==null)h=a0
if(h==null)h=10
g=A.w(a2.h(0,"tolB"))
if(g==null)g=a0
if(g==null)g=30
f=A.w(a2.h(0,"tolA"))
if(f==null)f=a0
if(f==null)f=20
e=A.w(a2.h(0,"ratingM"))
if(e==null)e=a0
if(e==null)e=25
d=A.w(a2.h(0,"roughMm"))
if(d==null)d=a0
if(d==null)d=0.002
c=A.w(a2.h(0,"c"))
if(c==null)c=a0
if(c==null)c=140
b=A.w(a2.h(0,"cost"))
if(b==null)b=a0
if(b==null)b=0
a=A.X(a2.h(0,"enabled"))
return A.cR(l,p,b,k,h,a1,m,a!==!1,c,s,n,i,j,r,o,e,d,q,f,g)},
$S:115}
A.fN.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e=t.P
e.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
q=A.v(a.h(0,"sup"))
if(q==null)q=""
p=A.v(a.h(0,"code"))
if(p==null)p=""
o=A.ac(B.dr,A.C(a.h(0,"kind")),t.bn)
n=A.ar(a.h(0,"sizeMm"))
e=e.a(a.h(0,"loss"))
m=A.ar(e.h(0,"k"))
l=A.w(e.h(0,"n"))
if(l==null)l=f
if(l==null)l=2
e=A.w(e.h(0,"c"))
if(e==null)e=f
if(e==null)e=0
k=A.w(a.h(0,"minQ"))
if(k==null)k=f
if(k==null)k=0
j=A.w(a.h(0,"maxQ"))
if(j==null)j=f
if(j==null)j=1
i=A.w(a.h(0,"cost"))
if(i==null)i=f
if(i==null)i=0
h=A.w(a.h(0,"setting"))
if(h==null)h=f
if(h==null)h=0
g=A.X(a.h(0,"enabled"))
return new A.P(s,r,q,p,o,n,new A.bh(m,l,e),k,j,i,h,g!==!1)},
$S:116}
A.fO.prototype={
$1(a){return A.o9(t.P.a(a))},
$S:117}
A.fP.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j
t.P.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
q=A.ac(B.dC,A.C(a.h(0,"kind")),t.na)
p=A.ar(a.h(0,"sizeMm"))
o=A.w(a.h(0,"size2Mm"))
if(o==null)o=null
if(o==null)o=0
n=A.w(a.h(0,"cost"))
if(n==null)n=null
if(n==null)n=0
m=A.X(a.h(0,"enabled"))
l=A.v(a.h(0,"sup"))
if(l==null)l=""
k=A.v(a.h(0,"code"))
if(k==null)k=""
j=A.v(a.h(0,"mat"))
if(j==null)j=""
return new A.W(s,r,l,k,q,p,o,n,m!==!1,j)},
$S:118}
A.fC.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}s=b
break A}return s},
$S:26}
A.fD.prototype={
$4$radiusM(a,b,c,d){var s=d>0,r=s?0.35:0,q=Math.pow(b,c),p=s?d/Math.pow(b,r):0
s=s?r:0
return new A.bP(a*27777777777777776e-23/q,c,p,s)},
$3(a,b,c){return this.$4$radiusM(a,b,c,0)},
$S:120}
A.fB.prototype={
$2(a,b){return new A.bh(A.q4(b/1000,a),2,0)},
$S:121}
A.fI.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}s=b
break A}return s},
$S:26}
A.fE.prototype={
$1(a){return t.p.a(a).e},
$S:25}
A.fH.prototype={
$1(a){return a===B.b.by(a)?""+B.b.a1(a):B.b.ae(a,1)},
$S:14}
A.fJ.prototype={
$2(a,b){return B.b.by(a*(0.25+b/40))},
$S:3}
A.fF.prototype={
$1(a){return t.p.a(a).as.A(0,B.p)},
$S:6}
A.fG.prototype={
$1(a){return t.p.a(a).e},
$S:25}
A.aD.prototype={
G(){return"HydraulicScope."+this.b}}
A.L.prototype={
G(){return"EntityType."+this.b}}
A.E.prototype={
D(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"type",r.gC().b)
q.i(0,"id",r.a)
q.i(0,"layer",r.b)
s=r.c
if(s.length!==0)q.i(0,"name",s)
return q}}
A.i2.prototype={
$0(){var s=t.O.a(this.a.h(0,"pts"))
if(s==null)s=[]
s=J.aC(s,new A.i3(),t.g)
s=A.p(s,s.$ti.j("t.E"))
return s},
$S:123}
A.i3.prototype={
$1(a){return A.bB(t.j.a(a))},
$S:124}
A.i1.prototype={
$0(){return A.bB(t.j.a(this.a.h(0,"p")))},
$S:125}
A.i0.prototype={
$2(a,b){var s=A.w(this.a.h(0,a))
if(s==null)s=null
return s==null?b:s},
$1(a){return this.$2(a,0)},
$S:126}
A.bc.prototype={}
A.a4.prototype={
gm(a){return A.aT(this.gP())},
dr(a){var s,r,q,p,o,n,m=this
for(s=a.a,r=a.b,q=1/0,p=1;p<J.as(m.gP());++p){o=A.lh(a,J.fw(m.gP(),p-1),J.fw(m.gP(),p)).a
n=s-o.a
o=r-o.b
q=Math.min(q,Math.sqrt(n*n+o*o))}return J.as(m.gP())===1?J.lq(J.bM(m.gP()),a).gm(0):q}}
A.k3.prototype={
$1(a){t.g.a(a)
return A.d([a.a,a.b],t.n)},
$S:127}
A.ch.prototype={
gC(){return B.aS},
gm(a){return this.d.U(0,this.e).gm(0)},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d,q=t.n
s.i(0,"a",A.d([r.a,r.b],q))
r=this.e
s.i(0,"b",A.d([r.a,r.b],q))
return s}}
A.cM.prototype={
gm(a){var s,r=this.d,q=A.aT(r)
if(this.e&&J.as(r)>2){s=J.a1(r)
r=J.lq(s.gM(r),t.g.a(s.gu(r))).gm(0)}else r=0
return q+r},
gC(){return B.aT},
n(){var s=A.V(this.D(),t.N,t.z)
s.i(0,"pts",A.c0(this.d))
s.i(0,"closed",this.e)
return s},
gP(){return this.d}}
A.e3.prototype={
gC(){return B.aZ},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d
s.i(0,"p",A.d([r.a,r.b],t.n))
s.i(0,"r",this.e)
return s}}
A.d2.prototype={
gC(){return B.b0},
gm(a){return this.e*Math.abs(this.r)},
dQ(){var s,r,q,p,o,n,m=this,l=m.r,k=Math.max(2,B.b.ao(32*Math.abs(l)/6.283185307179586)),j=A.d([],t.C)
for(s=m.d,r=m.e,q=m.f,p=s.a,s=s.b,o=0;o<=k;++o){n=q+l*o/k
j.push(new A.z(p+r*Math.cos(n),s+r*Math.sin(n)))}return j},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"r",s.e)
r.i(0,"s",s.f)
r.i(0,"w",s.r)
return r}}
A.cP.prototype={
gC(){return B.b1},
gm(a){return A.aT(A.pG(this.d,this.e,8))},
n(){var s=A.V(this.D(),t.N,t.z)
s.i(0,"pts",A.c0(this.d))
s.i(0,"closed",this.e)
return s},
gP(){return this.d}}
A.ed.prototype={
gC(){return B.b2},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c0(s.d))
r.i(0,"ang",s.e)
r.i(0,"sp",s.f)
r.i(0,"solid",s.r)
return r},
gP(){return this.d}}
A.aF.prototype={
G(){return"SymbolKind."+this.b}}
A.eP.prototype={
gC(){return B.b3},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"kind",s.e.b)
r.i(0,"size",s.f)
r.i(0,"rot",s.r)
return r}}
A.eS.prototype={
gC(){return B.b4},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"text",s.e)
r.i(0,"h",s.f)
r.i(0,"rot",s.r)
return r}}
A.ea.prototype={
gC(){return B.b5},
gm(a){return this.d.U(0,this.e).gm(0)},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d,p=t.n
r.i(0,"a",A.d([q.a,q.b],p))
q=s.e
r.i(0,"b",A.d([q.a,q.b],p))
r.i(0,"off",s.f)
return r}}
A.dZ.prototype={
gC(){return B.b6},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d,p=t.n
r.i(0,"v",A.d([q.a,q.b],p))
q=s.e
r.i(0,"a",A.d([q.a,q.b],p))
q=s.f
r.i(0,"b",A.d([q.a,q.b],p))
r.i(0,"r",s.r)
return r}}
A.eM.prototype={
gC(){return B.aU},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d,q=t.n
s.i(0,"c",A.d([r.a,r.b],q))
r=this.e
s.i(0,"p",A.d([r.a,r.b],q))
return s}}
A.cD.prototype={
gC(){return B.aV},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c0(s.d))
r.i(0,"text",s.e)
r.i(0,"h",s.f)
return r},
gP(){return this.d}}
A.ef.prototype={
gC(){return B.aW},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"w",s.e)
r.i(0,"h",s.f)
r.i(0,"rot",s.r)
r.i(0,"op",s.w)
r.i(0,"mime",s.x)
q=s.y
if(q!=null){t.fn.j("bN.S").a(q)
r.i(0,"data",B.cK.gbs().br(q))}q=s.z
if(q.length!==0)r.i(0,"src",q)
return r}}
A.c6.prototype={
gC(){return B.aX},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c0(s.d))
r.i(0,"z",s.e)
if(s.f)r.i(0,"gen",!0)
return r},
gP(){return this.d}}
A.dA.prototype={
gC(){return B.aY},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d
s.i(0,"p",A.d([r.a,r.b],t.n))
s.i(0,"z",this.e)
return s}}
A.aE.prototype={
gC(){return B.a2},
n(){var s,r=this,q=A.V(r.D(),t.N,t.z)
q.i(0,"pts",A.c0(r.d))
q.i(0,"scope",r.e.b)
s=r.f
if(s!=null)q.i(0,"spec",s)
q.i(0,"auto",r.r)
q.i(0,"depth",r.w)
return q},
gP(){return this.d}}
A.aj.prototype={
gC(){return B.a3},
gb3(){var s=this,r=A.aT(s.d),q=s.z,p=q>0
if(r<(p?q:s.y)-1e-9)return 0
return B.b.J((r-(p?q:s.y))/s.y+1e-9)+1},
n(){var s,r=this,q=A.V(r.D(),t.N,t.z)
q.i(0,"pts",A.c0(r.d))
s=r.e
if(s!=null)q.i(0,"spec",s)
q.i(0,"auto",r.f)
q.i(0,"outlet",r.r)
s=r.w
if(s!=null)q.i(0,"nozzle",s)
q.i(0,"head",r.x)
q.i(0,"sp",r.y)
q.i(0,"off",r.z)
q.i(0,"arc",r.Q)
q.i(0,"riser",r.as)
q.i(0,"depth",r.at)
return q},
gP(){return this.d}}
A.aA.prototype={
gC(){return B.a4},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c0(s.d))
r.i(0,"spec",s.e)
r.i(0,"inlet",s.f)
r.i(0,"reg",s.r)
r.i(0,"submin",s.w)
r.i(0,"depth",s.x)
r.i(0,"flush",s.y)
return r},
gP(){return this.d}}
A.aX.prototype={
gC(){return B.a5},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"scope",s.e.b)
r.i(0,"outlet",s.f)
q=s.r
if(q!=null)r.i(0,"nozzle",q)
r.i(0,"head",s.w)
r.i(0,"arc",s.x)
r.i(0,"rot",s.y)
r.i(0,"riser",s.z)
q=s.Q
if(q.length!==0)r.i(0,"zone",q)
return r}}
A.b6.prototype={
gC(){return B.a6},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"zone",s.f)
r.i(0,"rot",s.r)
q=s.w
if(q!=null)r.i(0,"fixed",q)
r.i(0,"depth",s.x)
return r}}
A.aH.prototype={
gC(){return B.a7},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"calc",s.e)
r.i(0,"dh",s.f)
r.i(0,"mh",s.r)
r.i(0,"dq",s.w)
r.i(0,"mq",s.x)
r.i(0,"wl",s.y)
return r}}
A.bm.prototype={
gC(){return B.a8},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"speed",s.f)
r.i(0,"rot",s.r)
r.i(0,"scope",s.w.b)
return r}}
A.aW.prototype={
gC(){return B.a9},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"scope",s.f.b)
r.i(0,"set",s.r)
r.i(0,"rot",s.w)
return r}}
A.cg.prototype={
gC(){return B.aa},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"scope",s.e.b)
q=s.f
if(q!=null)r.i(0,"z",q)
return r}}
A.b_.prototype={
dX(){var s,r,q,p,o,n,m,l=this,k=l.as
if(k<=0)return B.dt
s=Math.max(1,B.b.J(l.x/k))
r=A.d([],t.C)
for(q=l.w,p=l.y*3.141592653589793/180,o=q.a,q=q.b,n=1;n<=s;++n){m=n*k
r.push(new A.z(o+Math.cos(p)*m,q+Math.sin(p)*m))}return r},
gC(){return B.ab},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.w
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"r",s.x)
r.i(0,"ang",s.y)
r.i(0,"kind",s.z.b)
q=s.Q
if(q>0)r.i(0,"travel",q)
r.i(0,"span",s.as)
q=s.at
if(q!=null)r.i(0,"spec",q)
r.i(0,"idmm",s.ax)
r.i(0,"c",s.ay)
r.i(0,"hp",s.ch)
r.i(0,"hend",s.CW)
q=s.cx
if(q>0)r.i(0,"qg",q)
q=s.cy
if(q>0)r.i(0,"hg",q)
r.i(0,"throw",s.db)
r.i(0,"depth",s.dx)
r.i(0,"hours",s.dy)
r.i(0,"ww",s.fr)
r.i(0,"hm",s.fx)
q=s.fy
if(q>0)r.i(0,"imax",q)
q=s.go
if(q!==360)r.i(0,"sector",q)
q=s.id
if(q>0)r.i(0,"cost",q)
q=s.k1
if(q.length!==0)r.i(0,"zone",q)
r.i(0,"ssp",s.d)
q=s.e
if(q!=null)r.i(0,"sspec",q)
q=s.f
if(q!=null)r.i(0,"rspec",q)
q=s.r
if(q>0)r.i(0,"tcost",q)
return r}}
A.cB.prototype={
gC(){return B.b_},
n(){var s,r=this,q=A.V(r.D(),t.N,t.z)
q.i(0,"pts",A.c0(r.d))
q.i(0,"depth",r.e)
q.i(0,"eff",r.f)
q.i(0,"crop",r.r)
s=r.w
if(s>0)q.i(0,"epp",s)
if(r.x)q.i(0,"wb",!0)
q.i(0,"eto",r.y)
q.i(0,"kc",r.z)
q.i(0,"awc",r.Q)
q.i(0,"root",r.as)
q.i(0,"mad",r.at)
s=r.ax
if(s>0)q.i(0,"psp",s)
s=r.ay
if(s>0)q.i(0,"rsp",s)
s=r.ch
if(s!==1)q.i(0,"wf",s)
return q},
gP(){return this.d}}
A.eW.prototype={}
A.eZ.prototype={}
A.f_.prototype={}
A.f3.prototype={}
A.f6.prototype={}
A.f7.prototype={}
A.f9.prototype={}
A.fa.prototype={}
A.fb.prototype={}
A.fc.prototype={}
A.fd.prototype={}
A.ff.prototype={}
A.fg.prototype={}
A.fh.prototype={}
A.fk.prototype={}
A.fl.prototype={}
A.fm.prototype={}
A.fn.prototype={}
A.z.prototype={
aj(a,b){return new A.z(this.a+b.a,this.b+b.b)},
U(a,b){return new A.z(this.a-b.a,this.b-b.b)},
aq(a,b){return new A.z(this.a*b,this.b*b)},
gm(a){var s=this.a,r=this.b
return Math.sqrt(s*s+r*r)},
gcp(){var s=this.gm(0)
return s===0?B.an:new A.z(this.a/s,this.b/s)},
ck(a){return this.a*a.a+this.b*a.b},
n(){return A.S(["x",this.a,"y",this.b],t.N,t.z)},
Y(a,b){if(b==null)return!1
return b instanceof A.z&&b.a===this.a&&b.b===this.b},
gK(a){return A.cK(this.a,this.b,B.e,B.e)},
q(a){return"Pt("+B.b.ae(this.a,3)+", "+B.b.ae(this.b,3)+")"}}
A.e2.prototype={}
A.kO.prototype={
$1(a){A.T(a)
return a>1e-9&&a<A.aT(this.a)-1e-9},
$S:4}
A.kP.prototype={
$1(a){return A.aT(t.V.a(a))>1e-9},
$S:128}
A.k7.prototype={
$1(a){var s=this.b,r=this.c,q=J.af(s)
return this.a?q.h(s,B.c.b6(B.c.b6(a,r)+r,r)):q.h(s,B.c.a_(a,0,r-1))},
$S:129}
A.k8.prototype={
$3(a,b,c){return a+Math.pow(b.U(0,c).gm(0),0.5)},
$S:130}
A.ay.prototype={
n(){var s=this
return A.S(["name",s.a,"color",s.b,"visible",s.c,"locked",s.d],t.N,t.z)}}
A.cm.prototype={
G(){return"SizingMethod."+this.b}}
A.ha.prototype={
n(){var s=this
return A.S(["units",s.a.n(),"method",s.b.b,"temp",s.c,"vZone",s.d,"vMain",s.e,"vLat",s.f,"minorPct",s.r,"minor",s.w,"tol",s.x,"interest",s.y,"term",s.z,"kwh",s.Q,"eff",s.as,"hours",s.at,"zoneHours",s.ax,"trade",s.ay,"latSizes",s.ch,"subSizes",s.CW,"cScale",s.cx,"cOffset",s.cy,"densify",s.db,"currency",s.dx,"sizing",s.dy.b,"mainSizes",s.fr,"epp",s.fx,"maxNodes",s.fy,"flushV",s.go,"flushH",s.id,"surge",s.k1,"closure",s.k2,"fittings",s.k3,"stick",s.k4,"zoneVar",s.ok,"terrain",s.p1.b],t.N,t.z)}}
A.hb.prototype={
$2(a,b){var s=A.w(this.a.h(0,a))
if(s==null)s=null
return s==null?b:s},
$S:131}
A.b1.prototype={
n(){var s=this,r=s.c
r=A.p(r,A.i(r).c)
return A.S(["id",s.a,"name",s.b,"valves",r,"start",s.d,"dur",s.e],t.N,t.z)}}
A.iO.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"uid",r.a)
q.i(0,"created",r.b.bB())
s=r.c
if(s!=null)q.i(0,"modified",s.bB())
q.i(0,"name",r.d)
q.i(0,"client",r.e)
q.i(0,"site",r.f)
q.i(0,"designer",r.r)
q.i(0,"notes",r.w)
s=r.x
if(s!=null)q.i(0,"georef",s.n())
return q}}
A.iN.prototype={
a6(a){var s,r,q,p
for(s=this.e,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null},
di(){var s,r,q,p=this.b,o=A.d([],t.pn),n=new A.eR(p.db,p.p1,o,A.m(t.S,t.J))
for(p=this.e,s=p.length,r=0;r<p.length;p.length===s||(0,A.k)(p),++r){q=p[r]
if(q instanceof A.c6&&!q.f)n.dd(q.d,q.e)
if(q instanceof A.dA){B.a.k(o,new A.bE(q.d,q.e))
n.f=!0}}return n},
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"format","opencadirrigation")
o.i(0,"version",1)
o.i(0,"meta",p.a.n())
o.i(0,"params",p.b.n())
o.i(0,"catalog",p.c.n())
s=J.aC(p.d,new A.iT(),t.P)
s=A.p(s,s.$ti.j("t.E"))
o.i(0,"layers",s)
s=p.e
r=A.q(s)
q=r.j("h<c,@>(1)").a(new A.iU())
r=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,q,r),r.j("t.E"))
o.i(0,"entities",s)
s=p.f
r=A.q(s)
q=r.j("r<1,h<c,@>>")
s=A.p(new A.r(s,r.j("h<c,@>(1)").a(new A.iV()),q),q.j("t.E"))
o.i(0,"systemFlows",s)
o.i(0,"nextId",p.r)
s=p.w
if(s!=="DRAWING")o.i(0,"currentLayer",s)
return o}}
A.iT.prototype={
$1(a){return t.df.a(a).n()},
$S:132}
A.iU.prototype={
$1(a){return t.h.a(a).n()},
$S:13}
A.iV.prototype={
$1(a){return t.k.a(a).n()},
$S:133}
A.iP.prototype={
$1(a){var s,r,q,p
t.P.a(a)
s=A.C(a.h(0,"name"))
r=A.a0(a.h(0,"color"))
q=A.X(a.h(0,"visible"))
p=A.X(a.h(0,"locked"))
return new A.ay(s,r,q!==!1,p===!0)},
$S:134}
A.iQ.prototype={
$1(a){t.er.a(a)
return a.length===0?A.m_():a},
$S:135}
A.iR.prototype={
$1(a){return A.nK(t.P.a(a))},
$S:136}
A.iS.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
q=t.O.a(a.h(0,"valves"))
if(q==null)q=[]
q=J.nk(q,t.N)
q=q.ap(q)
p=A.w(a.h(0,"start"))
if(p==null)p=null
if(p==null)p=0
o=A.w(a.h(0,"dur"))
if(o==null)o=null
return A.m6(o==null?1:o,s,r,p,q)},
$S:137}
A.kN.prototype={
$1(a){A.T(a)
return a>0.000001&&a<this.a-0.000001},
$S:4}
A.co.prototype={
G(){return"TerrainMethod."+this.b}}
A.bE.prototype={}
A.eR.prototype={
gdV(){var s,r,q,p,o,n,m,l=this,k=l.r
if(k==null||l.f){s=l.c
r=s.length
q=r>12e3?B.b.ao(r/12e3):1
p=A.d([],t.kb)
for(o=0;o<r;o+=q){if(!(o>=0&&o<s.length))return A.b(s,o)
n=s[o]
m=n.a
p.push(new A.a(m.a,m.b,n.b))}k=l.r=A.ol(p)
if(l.f)l.c5()}return k},
dd(a,b){var s,r,q,p,o=this
t.V.a(a)
s=J.af(a)
if(s.gF(a))return
if(s.gm(a)===1){B.a.k(o.c,new A.bE(t.g.a(s.gu(a)),b))
o.f=!0
return}r=A.aT(a)
q=Math.max(1,B.b.ao(r/o.a))
for(s=o.c,p=0;p<=q;++p){B.a.k(s,new A.bE(A.ks(a,r*p/q),b))
o.f=!0}o.f=!0},
c5(){var s,r,q,p,o=this,n=o.d
n.V(0)
s=o.c
if(s.length===0){o.f=!1
return}r=A.q(s)
q=A.nt(new A.r(s,r.j("z(1)").a(new A.jb()),r.j("r<1,z>")))
o.e=Math.max(0.001,Math.max(q.c-q.a,q.d-q.b)/Math.max(1,Math.sqrt(s.length)))
for(p=0;p<s.length;++p){r=s[p].a
J.bL(n.ac((B.b.J(r.a/o.e)*73856093^B.b.J(r.b/o.e)*19349663)>>>0,new A.jc()),p)}o.f=!1},
cm(a,b,c){var s,r=this
if(r.c.length===0)return b
if(r.b===B.aG){s=r.gdV().aZ(a)
if(s!=null)return s}return r.dE(a,b,c)},
aZ(a){return this.cm(a,0,8)},
dE(a8,a9,b0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this,a7=a6.c
if(a7.length===0)return a9
if(a6.f)a6.c5()
s=A.d([],t.ip)
r=a8.a
q=B.b.J(r/a6.e)
p=a8.b
o=B.b.J(p/a6.e)
for(n=a6.d,m=0;m<=64;){for(l=-m,k=m>0,j=l;j<=m;++j)for(i=(q+j)*73856093,h=Math.abs(j)!==m,g=l;g<=m;++g){if(k&&h&&Math.abs(g)!==m)continue
f=n.h(0,(i^(o+g)*19349663)>>>0)
if(f==null)continue
for(e=J.aa(f);e.l();){d=e.gp()
if(d>>>0!==d||d>=a7.length)return A.b(a7,d)
c=a7[d].a
b=c.a-r
c=c.b-p
B.a.k(s,new A.A(Math.sqrt(b*b+c*c),d))}}if(s.length>=b0&&m>=1)break;++m}if(s.length===0)for(a=0;a<a7.length;++a){n=a7[a].a
k=n.a-r
n=n.b-p
B.a.k(s,new A.A(Math.sqrt(k*k+n*n),a))}B.a.am(s,new A.jd())
a0=A.bW(s,0,A.cw(b0,"count",t.S),t.mT).cv(0)
if(B.a.gu(a0).a<1e-9){r=B.a.gu(a0).b
if(!(r>=0&&r<a7.length))return A.b(a7,r)
return a7[r].b}for(r=a0.length,p=a7.length,a1=0,a2=0,a3=0;a3<r;++a3){n=a0[a3]
a4=n.a
a=n.b
a5=1/(a4*a4)
if(!(a>=0&&a<p))return A.b(a7,a)
a1+=a5*a7[a].b
a2+=a5}return a2===0?a9:a1/a2}}
A.jb.prototype={
$1(a){return t.jH.a(a).a},
$S:139}
A.jc.prototype={
$0(){return A.d([],t.X)},
$S:16}
A.jd.prototype={
$2(a,b){var s=t.mT
return B.b.S(s.a(a).a,s.a(b).a)},
$S:141}
A.bX.prototype={}
A.je.prototype={
cW(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=b.e
a.V(0)
s=b.d
if(s.length===0)return
r=b.a
b.r=B.a.L(r,B.G)
q=b.b
b.w=B.a.L(q,B.G)
b.f=Math.max(0.000001,Math.max(B.a.L(r,B.q)-b.r,B.a.L(q,B.q)-b.w)/Math.max(4,Math.sqrt(s.length)))
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
for(d=B.b.J((h-b.r)/b.f);d<=B.b.J((g-b.r)/b.f);++d)for(c=B.b.J((f-b.w)/b.f),n=d*73856093;c<=B.b.J((e-b.w)/b.f);++c)J.bL(a.ac((n^c*19349663)>>>0,new A.jf()),p)}},
dL(a){var s,r,q,p=this,o=p.d
if(o.length===0)return-1
s=p.e.h(0,(B.b.J((a.a-p.r)/p.f)*73856093^B.b.J((a.b-p.w)/p.f)*19349663)>>>0)
if(s==null)return-1
for(r=J.aa(s);r.l();){q=r.gp()
if(q>>>0!==q||q>=o.length)return A.b(o,q)
if(p.bN(o[q],a)!=null)return q}return-1},
bN(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g=this.a,f=a.a,e=g.length
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
aZ(a){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.dL(a)
if(h<0)return null
s=i.d
if(!(h<s.length))return A.b(s,h)
r=s[h]
q=i.bN(r,a)
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
A.jh.prototype={
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
$S:142}
A.jg.prototype={
$1(a){var s,r,q,p,o,n=this,m=n.a
if(!(a>=0&&a<m.length))return A.b(m,a)
s=n.c
r=n.d
q=r-1
p=B.c.a_(B.b.J((m[a]-n.b)/s*r),0,q)
m=n.e
if(!(a<m.length))return A.b(m,a)
o=B.c.a_(B.b.J((m[a]-n.f)/s*r),0,q)
m=o*r
return(o&1)===0?m+p:m+(q-p)},
$S:143}
A.ji.prototype={
$2(a,b){var s
A.a0(a)
A.a0(b)
s=this.a
return J.ls(s.$1(a),s.$1(b))},
$S:144}
A.jj.prototype={
$2(a,b){var s=a<b?a*4194304+b:b*4194304+a,r=this.a,q=r.h(0,s)
if(q==null){r.i(0,s,1)
B.a.k(this.b,new A.A(a,b))}else r.i(0,s,q+1)},
$S:9}
A.jf.prototype={
$0(){return A.d([],t.X)},
$S:16}
A.bl.prototype={
G(){return"LengthUnit."+this.b}}
A.bi.prototype={
G(){return"FlowUnit."+this.b}}
A.bA.prototype={
G(){return"PressureUnit."+this.b}}
A.c8.prototype={
G(){return"DiameterUnit."+this.b}}
A.eU.prototype={
n(){var s=this
return A.S(["length",s.a.b,"flow",s.b.b,"pressure",s.c.b,"diameter",s.d.b],t.N,t.z)},
gm(a){return this.a}}
A.kq.prototype={
$1(a){var s=A.mp(a).data
if(s==null||!(typeof s==="string"))return
A.kt(t.P.a(B.aN.dl(A.C(s),null)),new A.kp(this.a))},
$S:145}
A.kp.prototype={
$1(a){return this.a.postMessage(B.aN.dt(t.P.a(a),null))},
$S:146};(function aliases(){var s=J.bT.prototype
s.cG=s.q})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._static_0,p=hunkHelpers._instance_1i,o=hunkHelpers._instance_1u,n=hunkHelpers._instance_0u,m=hunkHelpers.installInstanceTearOff,l=hunkHelpers.installStaticTearOff
s(J,"pa","nT",147)
r(A,"pD","os",5)
r(A,"pE","ot",5)
r(A,"pF","ou",5)
q(A,"mJ","px",0)
p(A.bp.prototype,"gaE","A",140)
r(A,"pI","p0",24)
q(A,"pK","po",149)
var k
o(k=A.e9.prototype,"gd7","aU",77)
n(k,"gdj","dk",74)
n(k,"gdg","dh",73)
m(A.eR.prototype,"gds",0,1,null,["$3$fallback$neighbours","$1"],["cm","aZ"],138,0,0)
l(A,"q3",2,null,["$1$2","$2"],["mV",function(a,b){return A.mV(a,b,t.H)}],17,0)
l(A,"q2",2,null,["$1$2","$2"],["mU",function(a,b){return A.mU(a,b,t.H)}],17,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.I,null)
q(A.I,[A.kV,J.ei,A.dx,J.c3,A.j,A.d5,A.O,A.j_,A.aL,A.dq,A.dG,A.dz,A.d9,A.bH,A.U,A.b3,A.d6,A.cs,A.bU,A.ax,A.jk,A.iB,A.da,A.dP,A.a2,A.ie,A.az,A.M,A.ag,A.en,A.jR,A.bd,A.f2,A.jW,A.jU,A.eX,A.cv,A.b5,A.cr,A.ae,A.eY,A.fi,A.dU,A.f8,A.Q,A.F,A.bN,A.e7,A.jB,A.jA,A.jP,A.bs,A.c9,A.f0,A.eG,A.dB,A.jC,A.dc,A.ai,A.an,A.fj,A.cQ,A.i7,A.hc,A.hd,A.c7,A.e9,A.db,A.i4,A.ci,A.ii,A.cG,A.dp,A.dn,A.ev,A.dm,A.b7,A.aV,A.G,A.iz,A.il,A.iM,A.cl,A.bz,A.cL,A.bb,A.au,A.bO,A.cS,A.cn,A.aQ,A.b2,A.ak,A.cb,A.bC,A.e8,A.bP,A.bh,A.bk,A.dd,A.iA,A.eF,A.es,A.cJ,A.ee,A.cN,A.j0,A.dE,A.i5,A.H,A.D,A.a3,A.aP,A.P,A.aN,A.W,A.fA,A.E,A.bc,A.a4,A.z,A.e2,A.ay,A.ha,A.b1,A.iO,A.iN,A.bE,A.eR,A.bX,A.je,A.eU])
q(J.ei,[J.el,J.dg,J.di,J.dh,J.dj,J.ce,J.cf])
q(J.di,[J.bT,J.n,A.cH,A.dt])
q(J.bT,[J.eH,J.cp,J.bS])
r(J.ej,A.dx)
r(J.ia,J.n)
q(J.ce,[J.df,J.em])
q(A.j,[A.bY,A.x,A.by,A.B,A.dy,A.cq,A.dJ,A.bZ])
q(A.bY,[A.c4,A.dV])
r(A.dI,A.c4)
r(A.dH,A.dV)
r(A.ab,A.dH)
q(A.O,[A.er,A.bF,A.eo,A.eV,A.eN,A.f1,A.dk,A.e0,A.bf,A.dF,A.eT,A.dC,A.e6])
q(A.x,[A.t,A.d8,A.ad,A.am,A.K])
q(A.t,[A.dD,A.r,A.bn,A.f5])
r(A.ca,A.by)
r(A.i_,A.dy)
q(A.b3,[A.cU,A.cV,A.cu])
r(A.A,A.cU)
r(A.a,A.cV)
q(A.cu,[A.cW,A.aR])
r(A.br,A.d6)
q(A.bU,[A.d7,A.dO])
r(A.c5,A.d7)
q(A.ax,[A.eh,A.e4,A.e5,A.eQ,A.ki,A.kk,A.jx,A.jw,A.jZ,A.jL,A.ij,A.h8,A.h9,A.he,A.ku,A.kv,A.hy,A.hL,A.hx,A.hz,A.hm,A.ho,A.hp,A.hI,A.hN,A.hO,A.hv,A.ht,A.hW,A.hX,A.hY,A.hM,A.hP,A.kd,A.kG,A.kI,A.kx,A.ky,A.kz,A.kA,A.kE,A.kB,A.kC,A.kw,A.kL,A.ip,A.iv,A.ix,A.iw,A.is,A.it,A.iu,A.iy,A.iK,A.iL,A.k6,A.kh,A.jt,A.ju,A.jv,A.j6,A.j7,A.j8,A.j9,A.hf,A.hg,A.hh,A.hi,A.hj,A.hk,A.i6,A.iX,A.iW,A.j1,A.jm,A.iI,A.iH,A.iD,A.iF,A.iC,A.iZ,A.iY,A.fS,A.fQ,A.fY,A.h5,A.fW,A.fU,A.h_,A.h0,A.h1,A.h2,A.h3,A.h4,A.fK,A.fL,A.fM,A.fN,A.fO,A.fP,A.fC,A.fD,A.fI,A.fE,A.fH,A.fF,A.fG,A.i3,A.i0,A.k3,A.kO,A.kP,A.k7,A.k8,A.iT,A.iU,A.iV,A.iP,A.iQ,A.iR,A.iS,A.kN,A.jb,A.jh,A.jg,A.kq,A.kp])
r(A.cd,A.eh)
r(A.dv,A.bF)
q(A.eQ,[A.eO,A.cC])
q(A.a2,[A.bw,A.f4])
q(A.e5,[A.ib,A.kj,A.k_,A.k5,A.jM,A.ih,A.ik,A.jQ,A.i8,A.hr,A.hJ,A.hl,A.hn,A.hV,A.hZ,A.hB,A.hT,A.hQ,A.hR,A.hS,A.kF,A.kH,A.kD,A.kJ,A.kK,A.kM,A.kn,A.km,A.ko,A.k2,A.iq,A.ir,A.iJ,A.js,A.jr,A.kf,A.kg,A.j4,A.jn,A.jo,A.jp,A.jq,A.fV,A.fB,A.fJ,A.hb,A.jd,A.ji,A.jj])
q(A.dt,[A.ew,A.cI])
q(A.cI,[A.dK,A.dM])
r(A.dL,A.dK)
r(A.dr,A.dL)
r(A.dN,A.dM)
r(A.ds,A.dN)
q(A.dr,[A.ex,A.ey])
q(A.ds,[A.ez,A.eA,A.eB,A.eC,A.eD,A.du,A.eE])
r(A.cX,A.f1)
q(A.e4,[A.jy,A.jz,A.jV,A.jD,A.jH,A.jG,A.jF,A.jE,A.jK,A.jJ,A.jI,A.jT,A.k4,A.hK,A.hs,A.hw,A.hq,A.hu,A.hU,A.hC,A.hD,A.hA,A.hE,A.hF,A.hG,A.hH,A.io,A.im,A.j2,A.j3,A.j5,A.iE,A.fT,A.fR,A.fZ,A.h6,A.fX,A.i2,A.i1,A.jc,A.jf])
r(A.fe,A.dU)
r(A.bp,A.dO)
q(A.bN,[A.d4,A.ep])
q(A.e7,[A.fz,A.fy,A.id,A.ic])
r(A.eq,A.dk)
r(A.jO,A.jP)
q(A.bf,[A.dw,A.eg])
q(A.f0,[A.bg,A.cj,A.bx,A.bQ,A.ck,A.cc,A.de,A.bR,A.cE,A.aY,A.aZ,A.ba,A.aG,A.a6,A.aD,A.L,A.aF,A.cm,A.co,A.bl,A.bi,A.bA,A.c8])
q(A.E,[A.ch,A.fc,A.e3,A.d2,A.ff,A.f3,A.fk,A.fm,A.ea,A.dZ,A.eM,A.f7,A.ef,A.eZ,A.fg,A.fb,A.fh,A.fl,A.fa,A.f_,A.fn,A.fd,A.f9,A.f6,A.b_,A.eW])
r(A.cM,A.fc)
r(A.cP,A.ff)
r(A.ed,A.f3)
r(A.eP,A.fk)
r(A.eS,A.fm)
r(A.cD,A.f7)
r(A.c6,A.eZ)
r(A.dA,A.fg)
r(A.aE,A.fb)
r(A.aj,A.fh)
r(A.aA,A.fl)
r(A.aX,A.fa)
r(A.b6,A.f_)
r(A.aH,A.fn)
r(A.bm,A.fd)
r(A.aW,A.f9)
r(A.cg,A.f6)
r(A.cB,A.eW)
s(A.dV,A.F)
s(A.dK,A.F)
s(A.dL,A.U)
s(A.dM,A.F)
s(A.dN,A.U)
s(A.eW,A.a4)
s(A.eZ,A.a4)
s(A.f_,A.bc)
s(A.f3,A.a4)
s(A.f6,A.bc)
s(A.f7,A.a4)
s(A.f9,A.bc)
s(A.fa,A.bc)
s(A.fb,A.a4)
s(A.fc,A.a4)
s(A.fd,A.bc)
s(A.ff,A.a4)
s(A.fg,A.bc)
s(A.fh,A.a4)
s(A.fk,A.bc)
s(A.fl,A.a4)
s(A.fm,A.bc)
s(A.fn,A.bc)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{f:"int",e:"double",aw:"num",c:"String",u:"bool",an:"Null",o:"List",I:"Object",h:"Map",a_:"JSObject"},mangledNames:{},types:["~()","u(G)","an()","e(e,e)","u(e)","~(~())","u(H)","e(G)","u(aH)","~(f,f)","h<c,@>(bb)","~(I?,I?)","f(c?)","h<c,@>(E)","c(e)","an(@)","o<f>()","0^(0^,0^)<aw>","b0<f>()","h<c,@>(bO)","au(au,au)","e(e)","G(c,c)","o<aV>()","@(@)","e(H)","c(c,c,c)","e(e,b1)","e(cJ)","h<c,e>()","an(~())","u(ai<c,G?>)","@(@,c)","f(G,G)","f?(c)","u(f?)","c()","@(c)","o<c>()","~(c,e,e?,e)","~(c,o<+(H,e)>)","o<b2>()","c(aH)","u(c)","aQ(aQ,aQ)","~(bb,c)","~(c,c,c,e,e,c?{code:c,supplier:c})","f(ak,ak)","e(e,ak)","e(e,b2)","o<G>()","~(a6,e{qty:e,size2:e})","z(G,c)","aV?(z,aD)","u(aV?,c)","c(a6)","~(f,e)","bu(bu)","~(@)","bx(bu,b0<f>)","~(c,h<c,e>)","~(c,e)","f(+(H,e),+(H,e))","e(e,+(H,e))","c(au)","u(E)","o<z>(E)","aD(E)","~(z,j<aD>{exclude:c?})","e(e,b7)","f(f,bz)","h<c,@>(cl)","h<c,@>(bz)","o<ak>()","o<bC>()","e(e,G)","h<c,@>(au)","H?(G)","h<c,@>(cn)","h<c,@>(aQ)","h<c,@>(cS)","h<c,@>(cL)","h<c,@>(b2)","h<c,@>(ak)","h<c,@>(cb)","h<c,@>(bC)","an(@,bV)","u(bk)","~(f,@)","u(+(e,e))","h<f,e>(h<f,e>)","~(c7)","f()","c(aZ)","aZ(@)","u(D)","D()","h<c,@>(D)","D(@)","o<e>(+(e,e))","c(c)","u(H?)","u(a3?)","u(aP?)","u(P?)","u(aN?)","f(H,H)","h<c,@>(H)","h<c,@>(a3)","h<c,@>(aP)","h<c,@>(P)","h<c,@>(aN)","h<c,@>(W)","H(@)","a3(@)","aP(@)","P(@)","aN(@)","W(@)","~(c,c)","bP(e,e,e{radiusM:e})","bh(e,e)","~(@,@)","o<z>()","z(@)","z()","e(c[e])","o<e>(z)","u(o<z>)","z(f)","e(e,z,z)","e(c,e)","h<c,@>(ay)","h<c,@>(b1)","ay(@)","o<ay>(o<ay>)","E(@)","b1(@)","e(z{fallback:e,neighbours:f})","z(bE)","u(I?)","f(+(e,f),+(e,f))","~(bX)","f(f)","f(f,f)","an(a_)","~(h<c,@>)","f(@,@)","an(I,bV)","bj<~>()","+(e,e)(@)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.A&&a.b(c.a)&&b.b(c.b),"3;":(a,b,c)=>d=>d instanceof A.a&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;":a=>b=>b instanceof A.cW&&A.mY(a,b.a),"4;run,stage,zoneId,zoneIndex":a=>b=>b instanceof A.aR&&A.mY(a,b.a)}}
A.oS(v.typeUniverse,JSON.parse('{"eH":"bT","cp":"bT","bS":"bT","ql":"cH","el":{"u":[],"N":[]},"dg":{"N":[]},"di":{"a_":[]},"bT":{"a_":[]},"n":{"o":["1"],"x":["1"],"a_":[],"j":["1"]},"ej":{"dx":[]},"ia":{"n":["1"],"o":["1"],"x":["1"],"a_":[],"j":["1"]},"c3":{"R":["1"]},"ce":{"e":[],"aw":[],"aJ":["aw"]},"df":{"e":[],"f":[],"aw":[],"aJ":["aw"],"N":[]},"em":{"e":[],"aw":[],"aJ":["aw"],"N":[]},"cf":{"c":[],"aJ":["c"],"iG":[],"N":[]},"bY":{"j":["2"]},"d5":{"R":["2"]},"c4":{"bY":["1","2"],"j":["2"],"j.E":"2"},"dI":{"c4":["1","2"],"bY":["1","2"],"x":["2"],"j":["2"],"j.E":"2"},"dH":{"F":["2"],"o":["2"],"bY":["1","2"],"x":["2"],"j":["2"]},"ab":{"dH":["1","2"],"F":["2"],"o":["2"],"bY":["1","2"],"x":["2"],"j":["2"],"F.E":"2","j.E":"2"},"er":{"O":[]},"x":{"j":["1"]},"t":{"x":["1"],"j":["1"]},"dD":{"t":["1"],"x":["1"],"j":["1"],"j.E":"1","t.E":"1"},"aL":{"R":["1"]},"by":{"j":["2"],"j.E":"2"},"ca":{"by":["1","2"],"x":["2"],"j":["2"],"j.E":"2"},"dq":{"R":["2"]},"r":{"t":["2"],"x":["2"],"j":["2"],"j.E":"2","t.E":"2"},"B":{"j":["1"],"j.E":"1"},"dG":{"R":["1"]},"dy":{"j":["1"],"j.E":"1"},"i_":{"dy":["1"],"x":["1"],"j":["1"],"j.E":"1"},"dz":{"R":["1"]},"d8":{"x":["1"],"j":["1"],"j.E":"1"},"d9":{"R":["1"]},"cq":{"j":["1"],"j.E":"1"},"bH":{"R":["1"]},"bn":{"t":["1"],"x":["1"],"j":["1"],"j.E":"1","t.E":"1"},"A":{"cU":[],"b3":[]},"a":{"cV":[],"b3":[]},"cW":{"cu":[],"b3":[]},"aR":{"cu":[],"b3":[]},"d6":{"h":["1","2"]},"br":{"d6":["1","2"],"h":["1","2"]},"dJ":{"j":["1"],"j.E":"1"},"cs":{"R":["1"]},"d7":{"bU":["1"],"b0":["1"],"x":["1"],"j":["1"]},"c5":{"d7":["1"],"bU":["1"],"b0":["1"],"x":["1"],"j":["1"]},"eh":{"ax":[],"bv":[]},"cd":{"ax":[],"bv":[]},"dv":{"bF":[],"O":[]},"eo":{"O":[]},"eV":{"O":[]},"dP":{"bV":[]},"ax":{"bv":[]},"e4":{"ax":[],"bv":[]},"e5":{"ax":[],"bv":[]},"eQ":{"ax":[],"bv":[]},"eO":{"ax":[],"bv":[]},"cC":{"ax":[],"bv":[]},"eN":{"O":[]},"bw":{"a2":["1","2"],"lO":["1","2"],"h":["1","2"],"a2.K":"1","a2.V":"2"},"ad":{"x":["1"],"j":["1"],"j.E":"1"},"az":{"R":["1"]},"am":{"x":["1"],"j":["1"],"j.E":"1"},"M":{"R":["1"]},"K":{"x":["ai<1,2>"],"j":["ai<1,2>"],"j.E":"ai<1,2>"},"ag":{"R":["ai<1,2>"]},"cU":{"b3":[]},"cV":{"b3":[]},"cu":{"b3":[]},"en":{"oa":[],"iG":[]},"cH":{"a_":[],"N":[]},"dt":{"a_":[]},"ew":{"a_":[],"N":[]},"cI":{"aK":["1"],"a_":[]},"dr":{"F":["e"],"o":["e"],"aK":["e"],"x":["e"],"a_":[],"j":["e"],"U":["e"]},"ds":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"]},"ex":{"F":["e"],"o":["e"],"aK":["e"],"x":["e"],"a_":[],"j":["e"],"U":["e"],"N":[],"F.E":"e","U.E":"e"},"ey":{"bu":[],"F":["e"],"o":["e"],"aK":["e"],"x":["e"],"a_":[],"j":["e"],"U":["e"],"N":[],"F.E":"e","U.E":"e"},"ez":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"eA":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"eB":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"eC":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"eD":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"du":{"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"eE":{"l4":[],"F":["f"],"o":["f"],"aK":["f"],"x":["f"],"a_":[],"j":["f"],"U":["f"],"N":[],"F.E":"f","U.E":"f"},"f1":{"O":[]},"cX":{"bF":[],"O":[]},"cv":{"R":["1"]},"bZ":{"j":["1"],"j.E":"1"},"b5":{"O":[]},"ae":{"bj":["1"]},"dU":{"m9":[]},"fe":{"dU":[],"m9":[]},"bp":{"bU":["1"],"lP":["1"],"b0":["1"],"x":["1"],"j":["1"]},"Q":{"R":["1"]},"a2":{"h":["1","2"]},"bU":{"b0":["1"],"x":["1"],"j":["1"]},"dO":{"bU":["1"],"b0":["1"],"x":["1"],"j":["1"]},"f4":{"a2":["c","@"],"h":["c","@"],"a2.K":"c","a2.V":"@"},"f5":{"t":["c"],"x":["c"],"j":["c"],"j.E":"c","t.E":"c"},"d4":{"bN":["o<f>","c"],"bN.S":"o<f>"},"dk":{"O":[]},"eq":{"O":[]},"ep":{"bN":["I?","c"],"bN.S":"I?"},"bs":{"aJ":["bs"]},"e":{"aw":[],"aJ":["aw"]},"c9":{"aJ":["c9"]},"f":{"aw":[],"aJ":["aw"]},"o":{"x":["1"],"j":["1"]},"aw":{"aJ":["aw"]},"b0":{"x":["1"],"j":["1"]},"c":{"aJ":["c"],"iG":[]},"f0":{"Z":[]},"e0":{"O":[]},"bF":{"O":[]},"bf":{"O":[]},"dw":{"O":[]},"eg":{"O":[]},"dF":{"O":[]},"eT":{"O":[]},"dC":{"O":[]},"e6":{"O":[]},"eG":{"O":[]},"dB":{"O":[]},"fj":{"bV":[]},"cQ":{"og":[]},"bg":{"Z":[]},"cj":{"Z":[]},"bx":{"Z":[]},"bQ":{"Z":[]},"ck":{"Z":[]},"cc":{"Z":[]},"de":{"Z":[]},"bR":{"Z":[]},"cE":{"Z":[]},"aY":{"Z":[]},"aZ":{"Z":[]},"ba":{"Z":[]},"aG":{"Z":[]},"a6":{"Z":[]},"aD":{"Z":[]},"L":{"Z":[]},"aF":{"Z":[]},"aj":{"a4":[],"E":[]},"aA":{"a4":[],"E":[]},"aX":{"E":[]},"aH":{"E":[]},"b_":{"E":[]},"cB":{"a4":[],"E":[]},"ch":{"E":[]},"cM":{"a4":[],"E":[]},"e3":{"E":[]},"d2":{"E":[]},"cP":{"a4":[],"E":[]},"ed":{"a4":[],"E":[]},"eP":{"E":[]},"eS":{"E":[]},"ea":{"E":[]},"dZ":{"E":[]},"eM":{"E":[]},"cD":{"a4":[],"E":[]},"ef":{"E":[]},"c6":{"a4":[],"E":[]},"dA":{"E":[]},"aE":{"a4":[],"E":[]},"b6":{"E":[]},"bm":{"E":[]},"aW":{"E":[]},"cg":{"E":[]},"cm":{"Z":[]},"co":{"Z":[]},"bl":{"Z":[]},"bi":{"Z":[]},"bA":{"Z":[]},"c8":{"Z":[]},"nQ":{"o":["f"],"x":["f"],"j":["f"]},"l4":{"o":["f"],"x":["f"],"j":["f"]},"oo":{"o":["f"],"x":["f"],"j":["f"]},"nO":{"o":["f"],"x":["f"],"j":["f"]},"om":{"o":["f"],"x":["f"],"j":["f"]},"nP":{"o":["f"],"x":["f"],"j":["f"]},"on":{"o":["f"],"x":["f"],"j":["f"]},"nN":{"o":["e"],"x":["e"],"j":["e"]},"bu":{"o":["e"],"x":["e"],"j":["e"]}}'))
A.oR(v.typeUniverse,JSON.parse('{"dV":2,"cI":1,"dO":1,"e7":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",h:"SHP: {r} registros, {n} entidades ({crs})",n:"{k}: {p} marcadores, {n} entidades ({crs})"}
var t=(function rtii(){var s=A.Y
return{mu:s("cB"),t:s("b5"),fn:s("d4"),q:s("ak"),bP:s("aJ<@>"),cs:s("bs"),nJ:s("e8"),n6:s("bO"),ks:s("c8"),jS:s("c9"),Y:s("x<@>"),cQ:s("b7"),h:s("E"),od:s("L"),fz:s("O"),na:s("a6"),kN:s("W"),kI:s("bu"),mf:s("bi"),lG:s("cb"),m1:s("cc"),Z:s("bv"),G:s("G"),fC:s("G(c,c)"),cr:s("aV"),b:s("bk"),E:s("aD"),id:s("cd<e>"),lv:s("j<aD>"),bq:s("j<c>"),e7:s("j<@>"),o6:s("n<ak>"),c:s("n<bO>"),hz:s("n<b7>"),u:s("n<E>"),e0:s("n<db>"),eK:s("n<W>"),p4:s("n<cb>"),I:s("n<G>"),go:s("n<aV>"),lp:s("n<dd>"),dr:s("n<aD>"),j8:s("n<ay>"),gv:s("n<o<z>>"),iA:s("n<o<e>>"),cH:s("n<ci>"),nE:s("n<dn>"),jv:s("n<dp>"),ot:s("n<cj>"),gN:s("n<h<c,e>>"),l0:s("n<h<f,e>>"),lH:s("n<cJ>"),nB:s("n<D>"),iv:s("n<aX>"),w:s("n<au>"),dO:s("n<a3>"),A:s("n<bb>"),D:s("n<H>"),eN:s("n<bz>"),i5:s("n<cl>"),C:s("n<z>"),fH:s("n<aN>"),an:s("n<+(H,e)>"),dD:s("n<+(c,bP)>"),fU:s("n<+(e,e)>"),ip:s("n<+(e,f)>"),hD:s("n<+(f,f)>"),kb:s("n<+(e,e,e)>"),nV:s("n<+(e,f,f)>"),h0:s("n<aj>"),s:s("n<c>"),iF:s("n<cn>"),cu:s("n<bC>"),cD:s("n<b1>"),lT:s("n<b2>"),kU:s("n<aP>"),pn:s("n<bE>"),ae:s("n<bX>"),eZ:s("n<aQ>"),bD:s("n<P>"),n:s("n<e>"),dG:s("n<@>"),X:s("n<f>"),T:s("dg"),m:s("a_"),dY:s("bS"),dX:s("aK<@>"),df:s("ay"),hu:s("bl"),g_:s("es"),e5:s("o<G>"),g2:s("o<aV>"),er:s("o<ay>"),ms:s("o<au>"),d:s("o<H>"),V:s("o<z>"),x:s("o<+(H,e)>"),bF:s("o<c>"),k6:s("o<b1>"),bd:s("o<e>"),j:s("o<@>"),J:s("o<f>"),j5:s("ai<c,G?>"),U:s("h<c,e>"),P:s("h<c,@>"),dV:s("h<c,f>"),nh:s("h<e,b7>"),av:s("h<@,@>"),jq:s("h<f,e>"),L:s("h<c,o<G>>"),c8:s("h<c,G?>"),pa:s("r<c,f?>"),oX:s("eF"),mP:s("D"),a:s("an"),K:s("I"),hF:s("ba"),o:s("au"),fa:s("a3"),f7:s("aY"),h4:s("bb"),p:s("H"),W:s("aZ"),m9:s("b_"),n7:s("ck"),oY:s("cL"),fR:s("bz"),oz:s("cl"),f:s("a4"),c4:s("bA"),g:s("z"),dz:s("aN"),lZ:s("qn"),aK:s("+()"),kh:s("+(db,e)"),ft:s("+(bb,c)"),ca:s("+(H,e)"),kM:s("+(c,c)"),aL:s("+(e,e)"),mT:s("+(e,f)"),g9:s("bn<G>"),hZ:s("b0<G>"),Q:s("b0<c>"),nO:s("b0<f>"),fA:s("cm"),l:s("bV"),N:s("c"),ep:s("cn"),eu:s("bC"),ai:s("aF"),k:s("b1"),ju:s("b2"),gs:s("aP"),oW:s("co"),jH:s("bE"),aJ:s("N"),do:s("bF"),cx:s("cp"),nN:s("aQ"),bn:s("aG"),e4:s("P"),v:s("aH"),ji:s("B<o<z>>"),ee:s("B<e>"),hP:s("cq<aA>"),lF:s("cq<aH>"),jc:s("bH<cB>"),bo:s("bH<b_>"),kV:s("cS"),_:s("ae<@>"),cU:s("ae<~>"),iG:s("bZ<+run,stage,zoneId,zoneIndex(~(),bg,c?,f)>"),y:s("u"),eV:s("u(o<z>)"),iW:s("u(I)"),eq:s("u(e)"),i:s("e"),z:s("@"),mY:s("@()"),mq:s("@(I)"),ng:s("@(I,bV)"),S:s("f"),e:s("b6?"),gK:s("bj<an>?"),ga:s("bj<~>()?"),B:s("G?"),mU:s("a_?"),fm:s("o<c>?"),O:s("o<@>?"),md:s("h<c,c>?"),dZ:s("h<c,@>?"),iD:s("I?"),h2:s("a3?"),cV:s("H?"),gL:s("aN?"),bl:s("c?"),lJ:s("aP?"),kf:s("P?"),F:s("cr<@,@>?"),R:s("f8?"),o9:s("u?"),jX:s("e?"),aV:s("f?"),bw:s("f?(c)"),jh:s("aw?"),dn:s("~(c7)?"),H:s("aw"),r:s("~"),M:s("~()"),lc:s("~(c,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.d8=J.ei.prototype
B.a=J.n.prototype
B.c=J.df.prototype
B.b=J.ce.prototype
B.k=J.cf.prototype
B.d9=J.bS.prototype
B.da=J.di.prototype
B.bn=J.eH.prototype
B.aH=J.cp.prototype
B.cJ=new A.e2(1/0,1/0,-1/0,-1/0)
B.q=new A.cd(A.q2(),t.id)
B.G=new A.cd(A.q3(),t.id)
B.cM=new A.fz()
B.cK=new A.d4()
B.cL=new A.fy()
B.cN=new A.c9()
B.cO=new A.d9(A.Y("d9<0&>"))
B.aL=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.cP=function() {
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
B.cU=function(getTagFallback) {
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
B.cQ=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.cT=function(hooks) {
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
B.cS=function(hooks) {
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
B.cR=function(hooks) {
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
B.aM=function(hooks) { return hooks; }

B.aN=new A.ep()
B.cV=new A.eG()
B.e=new A.j_()
B.u=new A.fe()
B.cW=new A.fj()
B.aO=new A.bg(0,"zones")
B.cX=new A.bg(1,"mainline")
B.P=new A.bg(2,"splits")
B.cY=new A.bg(3,"flushing")
B.cZ=new A.bg(4,"surge")
B.aP=new A.bg(5,"bom")
B.a1=new A.bh(0,2,0)
B.aQ=new A.bh(0.001,2,0)
B.aS=new A.L(0,"line")
B.aT=new A.L(1,"polyline")
B.aU=new A.L(10,"radialDimension")
B.aV=new A.L(11,"leader")
B.aW=new A.L(12,"image")
B.aX=new A.L(13,"contour")
B.aY=new A.L(14,"spotHeight")
B.a2=new A.L(15,"pipe")
B.a3=new A.L(16,"sprayline")
B.a4=new A.L(17,"tape")
B.a5=new A.L(18,"outlet")
B.a6=new A.L(19,"controlValve")
B.aZ=new A.L(2,"circle")
B.a7=new A.L(20,"waterSupply")
B.a8=new A.L(21,"pump")
B.a9=new A.L(22,"misc")
B.aa=new A.L(23,"junction")
B.b_=new A.L(24,"area")
B.ab=new A.L(25,"pivot")
B.b0=new A.L(3,"arc")
B.b1=new A.L(4,"spline")
B.b2=new A.L(5,"hatch")
B.b3=new A.L(6,"symbol")
B.b4=new A.L(7,"text")
B.b5=new A.L(8,"dimension")
B.b6=new A.L(9,"angularDimension")
B.Q=new A.a6(0,"coupler")
B.ac=new A.a6(1,"elbow90")
B.m=new A.a6(10,"riser")
B.ad=new A.a6(2,"elbow45")
B.H=new A.a6(3,"tee")
B.ae=new A.a6(4,"cross")
B.v=new A.a6(5,"reducer")
B.I=new A.a6(6,"endCap")
B.af=new A.a6(7,"adapter")
B.w=new A.a6(8,"takeOff")
B.J=new A.a6(9,"tapeEnd")
B.d4=new A.dc("Not an OpenCADIrrigation project",null,null)
B.ag=new A.cc(0,"hazenWilliams")
B.b8=new A.cc(1,"darcyWeisbach")
B.d=new A.bQ(0,"pipe")
B.R=new A.bQ(1,"controlValve")
B.b9=new A.bQ(2,"pump")
B.d5=new A.bQ(3,"device")
B.d6=new A.bQ(4,"prv")
B.ah=new A.bR(0,"pipe")
B.ba=new A.bR(1,"pump")
B.K=new A.bR(2,"prv")
B.bb=new A.bR(3,"device")
B.d7=new A.bR(4,"closed")
B.S=new A.de(0,"junction")
B.T=new A.de(1,"reservoir")
B.f=new A.aD(0,"zone")
B.h=new A.aD(1,"mainline")
B.db=new A.ic(null)
B.dc=new A.id(null)
B.n=new A.cE(0,"open")
B.l=new A.cE(1,"closed")
B.x=new A.cE(2,"active")
B.p=new A.aZ(0,"lateral")
B.i=new A.aZ(1,"zone")
B.j=new A.aZ(2,"mainline")
B.dh=s([B.p,B.i,B.j],A.Y("n<aZ>"))
B.V=new A.ba(0,"sprinkler")
B.ak=new A.ba(1,"microSprinkler")
B.al=new A.ba(2,"dripper")
B.dM=new A.ba(3,"bubbler")
B.bk=new A.ba(4,"gun")
B.bl=new A.ba(5,"demandPoint")
B.di=s([B.V,B.ak,B.al,B.dM,B.bk,B.bl],A.Y("n<ba>"))
B.aR=new A.c8(0,"mm")
B.d_=new A.c8(1,"inch")
B.dj=s([B.aR,B.d_],A.Y("n<c8>"))
B.o=new A.aY(3e9,0,"pvc")
B.y=new A.aY(9e8,1,"pehd")
B.am=new A.aY(3e8,2,"peld")
B.bm=new A.aY(2e11,3,"steel")
B.dN=new A.aY(17e10,4,"ductileIron")
B.dP=new A.aY(7e10,5,"aluminium")
B.dO=new A.aY(3e10,6,"concrete")
B.dk=s([B.o,B.y,B.am,B.bm,B.dN,B.dP,B.dO],A.Y("n<aY>"))
B.dl=s([B.ag,B.b8],A.Y("n<cc>"))
B.B=s([B.f,B.h],t.dr)
B.C=new A.ck(0,"pivot")
B.dQ=new A.ck(1,"linear")
B.dm=s([B.C,B.dQ],A.Y("n<ck>"))
B.dn=s([B.aS,B.aT,B.aZ,B.b0,B.b1,B.b2,B.b3,B.b4,B.b5,B.b6,B.aU,B.aV,B.aW,B.aX,B.aY,B.a2,B.a3,B.a4,B.a5,B.a6,B.a7,B.a8,B.a9,B.aa,B.b_,B.ab],A.Y("n<L>"))
B.a_=new A.cm(0,"lp")
B.wN=new A.cm(1,"greedy")
B.dp=s([B.a_,B.wN],A.Y("n<cm>"))
B.aG=new A.co(0,"tin")
B.wX=new A.co(1,"idw")
B.dq=s([B.aG,B.wX],A.Y("n<co>"))
B.F=new A.aG(0,"control")
B.a0=new A.aG(1,"prv")
B.aI=new A.aG(2,"isolation")
B.aJ=new A.aG(3,"check")
B.cG=new A.aG(4,"backflow")
B.aK=new A.aG(5,"filter")
B.cH=new A.aG(6,"meter")
B.cI=new A.aG(7,"airRelease")
B.x9=new A.aG(8,"other")
B.dr=s([B.F,B.a0,B.aI,B.aJ,B.cG,B.aK,B.cH,B.cI,B.x9],A.Y("n<aG>"))
B.wO=new A.aF(0,"northArrow")
B.wP=new A.aF(1,"tree")
B.wQ=new A.aF(2,"building")
B.wR=new A.aF(3,"tank")
B.wS=new A.aF(4,"well")
B.wT=new A.aF(5,"valveBox")
B.wU=new A.aF(6,"pumpHouse")
B.wV=new A.aF(7,"gate")
B.wW=new A.aF(8,"filterStation")
B.ds=s([B.wO,B.wP,B.wQ,B.wR,B.wS,B.wT,B.wU,B.wV,B.wW],A.Y("n<aF>"))
B.be=s([],t.c)
B.du=s([],t.I)
B.dw=s([],t.nB)
B.dv=s([],t.w)
B.bf=s([],t.A)
B.bg=s([],t.D)
B.dt=s([],t.C)
B.dx=s([],t.iF)
B.dy=s([],t.eZ)
B.bd=s([],t.n)
B.xa=s([],t.dD)
B.bc=new A.bl(0,"m")
B.dd=new A.bl(1,"mm")
B.de=new A.bl(2,"cm")
B.df=new A.bl(3,"ft")
B.dg=new A.bl(4,"inch")
B.dz=s([B.bc,B.dd,B.de,B.df,B.dg],A.Y("n<bl>"))
B.bo=new A.bA(0,"mH2O")
B.dR=new A.bA(1,"kPa")
B.dS=new A.bA(2,"bar")
B.dT=new A.bA(3,"psi")
B.dA=s([B.bo,B.dR,B.dS,B.dT],A.Y("n<bA>"))
B.b7=new A.bi(0,"lph")
B.d0=new A.bi(1,"lpm")
B.d1=new A.bi(2,"lps")
B.d2=new A.bi(3,"m3h")
B.d3=new A.bi(4,"gpm")
B.dB=s([B.b7,B.d0,B.d1,B.d2,B.d3],A.Y("n<bi>"))
B.dC=s([B.Q,B.ac,B.ad,B.H,B.ae,B.v,B.I,B.af,B.w,B.J,B.m],A.Y("n<a6>"))
B.dD=s(["no_water_supply"],t.s)
B.dE=s(["pt","en","es"],t.s)
B.dF=s(["IMAGES","DRAWING","HATCHES","SYMBOLS","TEXT","DIMENSIONS","CONTOURS","SPOT_HEIGHTS","ZONE_PIPES","MAINLINE_PIPES","SPRAYLINES","TAPES","OUTLETS","WETTED_RADII","CONTROL_VALVES","WATER_SUPPLY","PUMPS","MISC_HYDRAULIC","JUNCTIONS","PIVOTS","AREAS","LABELS"],t.s)
B.U=new A.cj(0,"le")
B.ai=new A.cj(1,"eq")
B.bh=new A.cj(2,"ge")
B.L=new A.bx(0,"optimal")
B.dG=new A.bx(1,"infeasible")
B.dH=new A.bx(2,"unbounded")
B.bi=new A.bx(3,"iterationLimit")
B.aj={}
B.bj=new A.br(B.aj,[],A.Y("br<c,o<+(H,e)>>"))
B.dL={"app.title":0,ok:1,cancel:2,apply:3,close:4,auto:5,clear:6,"menu.file":7,"menu.edit":8,"menu.view":9,"menu.draw":10,"menu.zone":11,"menu.mainline":12,"menu.design":13,"menu.reports":14,"menu.tools":15,"menu.help":16,"file.new":17,"file.open":18,"file.save":19,"file.exportDxf":20,"file.exportDrawing":21,"file.exportReport":22,"file.georef":23,"file.newTab":24,"file.closeTab":25,"tab.new":26,"tab.close":27,"edit.clipCopy":28,"edit.clipCut":29,"edit.paste":30,"msg.copied":31,"msg.cut":32,"msg.pipeCut":33,"msg.pasted":34,"msg.nothingSelected":35,"msg.clipboardEmpty":36,"msg.unknownCommand":37,"status.command":38,"help.shortcuts":39,"sc.title":40,"sc.intro":41,"sc.file":42,"sc.edit":43,"sc.view":44,"sc.commands":45,"sc.hydraulic":46,"sc.switchTab":47,"sc.cancel":48,"sc.finish":49,"sc.undoPoint":50,"sc.repeat":51,"sc.zoom":52,"sc.pan":53,"sc.panHold":54,"sc.reports":55,"sc.gridDisplay":56,"sc.angleLock":57,"sc.autoRun":58,"sc.toggles":59,"sc.designCmds":60,"exp.dxf":61,"exp.dwg":62,"exp.pdf":63,"exp.svg":64,"exp.kml":65,"exp.kmz":66,"exp.geojson":67,"exp.csv":68,"exp.txt":69,"exp.xlsx":70,"exp.reportPdf":71,"msg.exported":72,"msg.needResults":73,"msg.nothingToExport":74,"msg.georefSet":75,"geo.title":76,"geo.explain":77,"geo.modeLatLon":78,"geo.modeUtm":79,"geo.lat":80,"geo.lon":81,"geo.zone":82,"geo.north":83,"geo.easting":84,"geo.northing":85,"geo.current":86,"geo.none":87,"geo.remove":88,"geo.invalid":89,"plot.title":90,"plot.page":91,"plot.orientation":92,"plot.landscape":93,"plot.portrait":94,"plot.scale":95,"plot.scaleAuto":96,"plot.wetted":97,"plot.labels":98,"plot.legend":99,"plot.reports":100,"plot.export":101,"plot.fits":102,"pdf.date":103,"pdf.scale":104,"pdf.sheet":105,"pdf.origin":106,"pdf.summary":107,"pdf.crs":108,"pdf.local":109,"pdf.legend":110,"pdf.subtitle":111,"pdf.reportTitle":112,"pdf.generated":113,"pdf.page":114,"pdf.cont":115,"pdf.noResults":116,"pdf.params":117,"layer.DRAWING":118,"layer.TEXT":119,"layer.DIMENSIONS":120,"layer.CONTOURS":121,"layer.SPOT_HEIGHTS":122,"layer.ZONE_PIPES":123,"layer.MAINLINE_PIPES":124,"layer.SPRAYLINES":125,"layer.TAPES":126,"layer.OUTLETS":127,"layer.WETTED_RADII":128,"layer.CONTROL_VALVES":129,"layer.WATER_SUPPLY":130,"layer.PUMPS":131,"layer.MISC_HYDRAULIC":132,"layer.JUNCTIONS":133,"layer.AREAS":134,"layer.LABELS":135,"file.details":136,"edit.undo":137,"edit.redo":138,"edit.delete":139,"edit.selectAll":140,"edit.copy":141,"view.zoomAll":142,"view.zoomIn":143,"view.zoomOut":144,"view.grid":145,"view.labels":146,"view.wetted":147,"view.overlay.none":148,"view.overlay.velocity":149,"view.overlay.pressure":150,"view.overlay.sizes":151,"view.layers":152,"view.language":153,"lang.pt":154,"lang.en":155,"lang.es":156,"design.params":157,"design.management":158,"design.check":159,"design.zone":160,"design.analyze":161,"design.mainline":162,"design.all":163,"design.clear":164,"design.progress.title":165,"design.progress.start":166,"design.progress.zones":167,"design.progress.mainline":168,"design.progress.splits":169,"design.progress.flushing":170,"design.progress.surge":171,"design.progress.bom":172,"design.progress.bg":173,"design.progress.hint":174,"design.catalog":175,"design.block":176,"design.autohead":177,"reports.zone":178,"reports.pipes":179,"reports.outlets":180,"reports.mainline":181,"reports.bom":182,"reports.water":183,"reports.hgl":184,"reports.messages":185,"tools.lateral":186,"tools.pump":187,"tools.hammer":188,"tools.units":189,"help.about":190,"help.tutorial":191,"tool.select":192,"tool.pan":193,"tool.line":194,"tool.polyline":195,"tool.rect":196,"tool.circle":197,"tool.text":198,"tool.dimension":199,"tool.contour":200,"tool.spot":201,"tool.area":202,"tool.zonePipe":203,"tool.mainPipe":204,"tool.sprayline":205,"tool.tape":206,"tool.outlet":207,"tool.valve":208,"tool.supply":209,"tool.pump":210,"tool.misc":211,"tool.junction":212,"tool.block":213,"tool.autohead":214,"tool.measure":215,"hint.select":216,"hint.pan":217,"hint.line":218,"hint.polyline":219,"hint.rect":220,"hint.circle":221,"hint.text":222,"hint.dimension":223,"hint.contour":224,"hint.spot":225,"hint.area":226,"hint.pipe":227,"hint.point":228,"hint.block":229,"hint.measure":230,"status.ready":231,"status.snap":232,"status.grid":233,"status.ortho":234,"status.entities":235,"props.title":236,"props.none":237,"props.multi":238,"props.layer":239,"props.name":240,"props.pipe":241,"props.auto":242,"props.depth":243,"props.outlet":244,"props.nozzle":245,"props.head":246,"props.spacing":247,"props.offset":248,"props.arc":249,"props.riser":250,"props.tape":251,"props.inlet":252,"props.regulated":253,"props.submainMin":254,"props.valve":255,"props.zone":256,"props.fixedHead":257,"props.calc":258,"props.designHead":259,"props.maxHead":260,"props.designFlow":261,"props.maxFlow":262,"props.waterLevel":263,"props.pump":264,"props.speed":265,"props.misc":266,"props.setting":267,"props.elevation":268,"props.elevationDem":269,"props.text":270,"props.textHeight":271,"props.radius":272,"props.closed":273,"props.netDepth":274,"props.efficiency":275,"props.crop":276,"props.length":277,"props.area":278,"props.outlets":279,"props.scope":280,"props.results":281,"props.orientation":282,"props.rotation":283,"props.dimOffset":284,"props.zoomTo":285,"props.halfSpacing":286,"props.downstream":287,"props.required":288,"props.valveLoss":289,"props.emitterMinMax":290,"props.allowed":291,"props.uniformity":292,"props.defaults":293,"scope.zone":294,"scope.mainline":295,"result.flow":296,"result.velocity":297,"result.loss":298,"result.pressure":299,"result.pStart":300,"result.pEnd":301,"result.min":302,"result.max":303,"msg.saved":304,"msg.loaded":305,"msg.designDone":306,"msg.unconnected":307,"msg.allConnected":308,"msg.designBusy":309,"msg.designStale":310,"msg.noValves":311,"msg.deleted":312,"msg.imported":313,"msg.error":314,"msg.unsavedConfirm":315,"msg.noResults":316,"msg.noAreas":317,"msg.selectForHgl":318,"msg.noMessages":319,"msg.unconnectedItem":320,"imp.dwg":321,"imp.skipped":322,"imp.kml":323,"imp.dxf":324,"dwg.notDwg":325,"dwg.corrupt":326,"kmz.noKml":327,"rep.zone":328,"rep.valve":329,"rep.emitters":330,"rep.flow":331,"rep.pDown":332,"rep.valveLoss":333,"rep.pRequired":334,"rep.pMin":335,"rep.pMax":336,"rep.allowMin":337,"rep.allowMax":338,"rep.varAllow":339,"rep.varActual":340,"rep.pipeCost":341,"rep.warnings":342,"rep.context":343,"rep.entity":344,"rep.segment":345,"rep.pipe":346,"rep.innerDiam":347,"rep.length":348,"rep.q":349,"rep.velocity":350,"rep.hf":351,"rep.pStart":352,"rep.pEnd":353,"rep.zStart":354,"rep.zEnd":355,"rep.pn":356,"rep.emitter":357,"rep.n":358,"rep.qTotal":359,"rep.qMean":360,"rep.flowName":361,"rep.item":362,"rep.pAvailable":363,"rep.status":364,"rep.energyYear":365,"rep.supply":366,"rep.pump":367,"rep.device":368,"rep.calculated":369,"rep.fixed":370,"rep.deficit":371,"rep.ok":372,"rep.pumpHead":373,"rep.category":374,"rep.description":375,"rep.unit":376,"rep.quantity":377,"rep.unitCost":378,"rep.total":379,"rep.totalRow":380,"rep.annualCapital":381,"rep.annualEnergy":382,"rep.annualTotal":383,"rep.area":384,"rep.grossDepth":385,"rep.volume":386,"rep.rate":387,"rep.hoursDay":388,"hgl.legend":389,"csv.zones":390,"csv.flows":391,"csv.bom":392,"bom.pipes":393,"bom.tapes":394,"bom.outlets":395,"bom.valves":396,"bom.devices":397,"bom.pumps":398,"name.zone":399,"name.supply":400,"name.allZones":401,"name.submain":402,"name.stub":403,"name.lateral":404,"name.area":405,"name.newProject":406,"name.text":407,"name.flow":408,"name.report":409,"ex.name":410,"ex.client":411,"ex.site":412,"ex.boundary":413,"ex.title":414,"ex.zoneA":415,"ex.zoneB":416,"ex.blockA":417,"ex.blockB":418,"ex.citrus":419,"ex.grape":420,"ex.riser":421,"ex.branchA":422,"ex.branchB":423,"ex.well":424,"ex.flow1":425,"ex.flow2":426,"dlg.project":427,"dlg.client":428,"dlg.site":429,"dlg.designer":430,"dlg.notes":431,"dlg.hydraulics":432,"dlg.frictionFormula":433,"dlg.hw":434,"dlg.dw":435,"dlg.waterTemp":436,"dlg.vLateral":437,"dlg.vZone":438,"dlg.vMain":439,"dlg.minorPct":440,"dlg.connectTol":441,"dlg.applyMinor":442,"dlg.cScale":443,"dlg.cOffset":444,"dlg.sizing":445,"dlg.maxSubmainSizes":446,"dlg.densify":447,"dlg.economics":448,"dlg.tradeCapital":449,"dlg.interest":450,"dlg.term":451,"dlg.energyCost":452,"dlg.pumpEff":453,"dlg.hoursMain":454,"dlg.hoursZone":455,"dlg.currency":456,"dlg.metric":457,"dlg.us":458,"dlg.length":459,"dlg.flow":460,"dlg.pressure":461,"dlg.diameter":462,"dlg.allTogether":463,"dlg.oneAtATime":464,"dlg.addFlow":465,"dlg.name":466,"dlg.startHour":467,"dlg.durationHours":468,"dlg.noFlows":469,"dlg.sprayBlock":470,"dlg.dripBlock":471,"dlg.laterals":472,"dlg.emitterSpacing":473,"dlg.lateralPipe":474,"dlg.lateralSpacing":475,"dlg.lateralDirection":476,"dlg.submainValve":477,"dlg.submainPosition":478,"dlg.submainStart":479,"dlg.submainCentre":480,"dlg.submainEnd":481,"dlg.submainPipe":482,"dlg.valvePosition":483,"dlg.posStart":484,"dlg.posCentre":485,"dlg.posEnd":486,"dlg.stub":487,"dlg.spacingPct":488,"dlg.direction":489,"dlg.square":490,"dlg.triangular":491,"dlg.gridSummary":492,"dlg.tapeLateral":493,"dlg.emitterLateral":494,"dlg.slope":495,"dlg.tolBelow":496,"dlg.tolAbove":497,"dlg.results":498,"dlg.emittersCount":499,"dlg.inletFlow":500,"dlg.totalLoss":501,"dlg.endPressure":502,"dlg.pMinMax":503,"dlg.pVariation":504,"dlg.maxVelocity":505,"dlg.uniformity4":506,"dlg.qvar":507,"dlg.maxLength":508,"dlg.staticHead":509,"dlg.speed":510,"dlg.mainPipe":511,"dlg.hoursYear":512,"dlg.operatingPoint":513,"dlg.pumpCannot":514,"dlg.head":515,"dlg.velocityMain":516,"dlg.hydraulicPower":517,"dlg.shaftPower":518,"dlg.annualEnergy":519,"dlg.shutoffRunout":520,"dlg.velocity":521,"dlg.closureTime":522,"dlg.staticPressure":523,"dlg.resultJoukowsky":524,"dlg.celerity":525,"dlg.maxSurge":526,"dlg.criticalTime":527,"dlg.estSurge":528,"dlg.totalPressure":529,"dlg.pipeClass":530,"cat.pipes":531,"cat.outlets":532,"cat.tapes":533,"cat.valves":534,"cat.pumps":535,"cat.use":536,"cat.name":537,"cat.dn":538,"cat.idmm":539,"cat.c":540,"cat.pn":541,"cat.costM":542,"cat.outlet":543,"cat.nozzle":544,"cat.k":545,"cat.x":546,"cat.pMin":547,"cat.pMax":548,"cat.pDefault":549,"cat.cv":550,"cat.tol":551,"cat.cost":552,"cat.spacing":553,"cat.qNom":554,"cat.kd":555,"cat.type":556,"cat.kLoss":557,"cat.n":558,"cat.qMax":559,"cat.points":560,"cat.eff":561,"cat.hint":562,"mat.pvc":563,"mat.pehd":564,"mat.peld":565,"mat.steel":566,"mat.ductileIron":567,"mat.aluminium":568,"mat.concrete":569,"warn.not_converged":570,"warn.cannot_meet_pressure_window":571,"warn.mainline_cannot_meet_pressure":572,"warn.no_water_supply":573,"warn.outlet_over_pressure":574,"warn.outlet_under_pressure":575,"warn.pressure_rating_exceeded":576,"warn.pump_out_of_range":577,"warn.supply_flow_exceeded":578,"warn.supply_head_exceeded":579,"warn.valve_flow_out_of_range":580,"warn.valve_missing":581,"warn.valve_pressure_deficit":582,"warn.valve_unreachable":583,"warn.velocity_exceeded":584,"warn.zone_empty":585,"warn.zone_overlap":586,"warn.valve_no_zone_pipes":587,"warn.outlet_spec_missing":588,"warn.tape_spec_missing":589,"warn.pump_spec_missing":590,"warn.valve_spec_missing":591,"warn.no_fixed_head_node":592,"warn.page_missing":593,"about.text":594,"tool.arc":595,"tool.spline":596,"tool.hatch":597,"tool.symbol":598,"tool.dimAngular":599,"tool.dimRadial":600,"tool.leader":601,"tool.rotate":602,"tool.mirror":603,"tool.scale":604,"tool.offset":605,"tool.trim":606,"tool.extend":607,"tool.cutPipe":608,"tool.profile":609,"hint.arc":610,"hint.spline":611,"hint.hatch":612,"hint.symbol":613,"hint.dimAngular":614,"hint.dimRadial":615,"hint.leader":616,"hint.rotate":617,"hint.mirror":618,"hint.scale":619,"hint.offset":620,"hint.trim":621,"hint.extend":622,"hint.cutPipe":623,"hint.profile":624,"edit.transform":625,"edit.array":626,"edit.feed":627,"arr.title":628,"arr.rect":629,"arr.polar":630,"arr.rows":631,"arr.cols":632,"arr.dx":633,"arr.dy":634,"arr.angle":635,"arr.count":636,"arr.center":637,"arr.total":638,"arr.rotateItems":639,"arr.selection":640,"msg.layerLocked":641,"msg.noIntersection":642,"msg.selectLateral":643,"msg.feedComputed":644,"msg.arrayDone":645,"view.overlay.minMax":646,"view.baseMap":647,"view.baseMap.none":648,"view.baseMap.streets":649,"view.baseMap.satellite":650,"view.baseMapNeedsGeo":651,"view.grips":652,"zone.feedEnvelope":653,"layer.current":654,"layer.lock":655,"layer.add":656,"layer.rename":657,"layer.delete":658,"layer.color":659,"layer.name":660,"layer.exists":661,"layer.hint":662,"props.batch":663,"props.mixed":664,"props.symbolKind":665,"props.symbolSize":666,"props.hatchAngle":667,"props.hatchSpacing":668,"props.hatchSolid":669,"props.opacity":670,"props.imageWidth":671,"props.imageHeight":672,"props.source":673,"props.emittersPerPlant":674,"props.waterBalance":675,"props.eto":676,"props.kc":677,"props.kcPreset":678,"props.awc":679,"props.rootDepth":680,"props.mad":681,"props.wettedFraction":682,"props.plantSpacing":683,"props.rowSpacing":684,"props.etc":685,"props.interval":686,"props.offsetDistance":687,"props.copyOnTransform":688,"props.mirrorKeep":689,"props.splitOnInsert":690,"props.splineClosed":691,"props.angle":692,"props.leaderText":693,"props.dimRadius":694,"props.locked":695,"props.flushingFlow":696,"props.envelope":697,"props.envelopeBest":698,"props.envelopeRange":699,"props.envelopeNone":700,"sym.northArrow":701,"sym.tree":702,"sym.building":703,"sym.tank":704,"sym.well":705,"sym.valveBox":706,"sym.pumpHouse":707,"sym.gate":708,"sym.filterStation":709,"crop.citrus":710,"crop.grape":711,"crop.coffee":712,"crop.banana":713,"crop.mango":714,"crop.apple":715,"crop.tomato":716,"crop.maize":717,"crop.sugarcane":718,"crop.vegetables":719,"crop.turf":720,"crop.pasture":721,"crop.custom":722,"reports.flushing":723,"reports.surge":724,"reports.crop":725,"reports.schedule":726,"reports.profile":727,"rep.code":728,"rep.tapes":729,"rep.vFlush":730,"rep.celerity":731,"rep.surge":732,"rep.pStatic":733,"rep.pTotal":734,"rep.tCritical":735,"rep.raw":736,"rep.interval":737,"rep.netEvent":738,"rep.grossEvent":739,"rep.hoursEvent":740,"rep.overlapCu":741,"sch.date":742,"sch.flow":743,"sch.zones":744,"sch.start":745,"sch.end":746,"sch.duration":747,"prof.distance":748,"prof.elevation":749,"prof.hint":750,"prof.slope":751,"fit.coupler":752,"fit.elbow90":753,"fit.elbow45":754,"fit.tee":755,"fit.cross":756,"fit.reducer":757,"fit.endCap":758,"fit.adapter":759,"fit.takeOff":760,"fit.tapeEnd":761,"fit.riser":762,"bom.fittings":763,"bom.takeoffs":764,"bom.risers":765,"cat.fittings":766,"cat.kind":767,"cat.size2":768,"cat.supplier":769,"cat.code":770,"cat.add":771,"cat.duplicate":772,"cat.remove":773,"cat.import":774,"cat.export":775,"cat.exportCsv":776,"cat.reset":777,"cat.setDefault":778,"cat.importHint":779,"cat.removeConfirm":780,"cat.inUse":781,"msg.catalogImported":782,"msg.catalogDefaultSaved":783,"msg.catalogReset":784,"warn.lp_infeasible":785,"warn.fitting_missing":786,"warn.surge_rating_exceeded":787,"warn.schedule_no_area":788,"warn.schedule_over_24h":789,"file.importDrawing":790,"imp.points":791,"imp.shp":792,"imp.image":793,"imp.imageGeo":794,"imp.err.points_empty":795,"imp.err.points_no_columns":796,"imp.err.shp_bad_header":797,"imp.err.shp_zip_no_shp":798,"imp.err.image_zip_no_image":799,"imp.err.image_unreadable":800,"file.georefImage":801,"gimg.title":802,"gimg.explain":803,"gimg.keepAspect":804,"dlg.sizingMethod":805,"dlg.lp":806,"dlg.greedy":807,"dlg.maxLateralSizes":808,"dlg.maxMainlineSizes":809,"dlg.epp":810,"dlg.maxNodes":811,"dlg.zoneVar":812,"dlg.flushing":813,"dlg.flushV":814,"dlg.flushH":815,"dlg.checkSurge":816,"dlg.closure":817,"dlg.bom":818,"dlg.fittings":819,"dlg.stick":820,"design.pumpSelect":821,"design.dem3d":822,"pump.title":823,"pump.duty":824,"pump.supply":825,"pump.candidates":826,"pump.hAtDuty":827,"pump.margin":828,"pump.opPoint":829,"pump.power":830,"pump.parallel":831,"pump.energy":832,"pump.insert":833,"pump.replace":834,"pump.noSupply":835,"pump.unsuitable":836,"msg.pumpApplied":837,"dem.title":838,"dem.exaggeration":839,"dem.hint":840,"dem.noData":841,"dem.range":842,"file.recent":843,"file.noRecent":844,"file.versions":845,"file.autosave":846,"rec.title":847,"rec.text":848,"rec.restore":849,"rec.discard":850,"rec.later":851,"rec.item":852,"msg.recovered":853,"ver.title":854,"ver.none":855,"ver.restore":856,"ver.item":857,"msg.versionRestored":858,"mgmt.flows":859,"mgmt.schedule":860,"mgmt.apply":861,"mgmt.export":862,"mgmt.days":863,"mgmt.dayStart":864,"mgmt.keepStart":865,"mgmt.maxDaily":866,"mgmt.needResults":867,"mgmt.perFlow":868,"sc.editCmds":869,"sc.gripRemove":870,"sc.gripInsert":871,"sc.touch":872,"tool.pivot":873,"hint.pivot":874,"tool.alignImage":875,"hint.alignImage":876,"align.step1":877,"align.step2":878,"align.step3":879,"align.step4":880,"align.keepScale":881,"msg.alignDone":882,"msg.alignSelectFirst":883,"msg.profileCleared":884,"elev.title":885,"elev.contourTitle":886,"elev.spotTitle":887,"elev.value":888,"elev.interval":889,"elev.autoIncrement":890,"elev.ask":891,"elev.explainContour":892,"elev.explainSpot":893,"menu.terrain":894,"terrain.onlineDem":895,"terrain.generateContours":896,"terrain.method":897,"terrain.tin":898,"terrain.idw":899,"terrain.clearProfile":900,"terrain.stats":901,"terrain.none":902,"dlg.terrainMethod":903,"dem.online.title":904,"dem.online.explain":905,"dem.online.source":906,"dem.online.spacing":907,"dem.online.extent":908,"dem.online.replace":909,"dem.online.useView":910,"dem.online.run":911,"dem.online.progress":912,"dem.online.done":913,"dem.online.needGeo":914,"dem.online.error":915,"dem.online.empty":916,"cgen.title":917,"cgen.explain":918,"cgen.interval":919,"cgen.replace":920,"cgen.preview":921,"cgen.done":922,"cgen.run":923,"prof.clear":924,"prof.ground":925,"prof.pipe":926,"prof.hgl":927,"prof.lowest":928,"prof.highest":929,"prof.howTo":930,"prof.noTerrain":931,"prof.station":932,"prof.pressure":933,"prof.pathLabel":934,"reports.pivots":935,"rep.pivot":936,"rep.type":937,"rep.towers":938,"rep.pAvail":939,"rep.rise":940,"rep.depthCycle":941,"rep.hoursCycle":942,"rep.appRatePeak":943,"pivot.kindPivot":944,"pivot.kindLinear":945,"pivot.towers":946,"bom.pivots":947,"warn.pivot_pressure_deficit":948,"warn.pivot_app_rate":949,"warn.pivot_no_flow":950,"warn.pivot_no_end_pressure":951,"props.pivotKind":952,"props.pivotRadius":953,"props.pivotSpan":954,"props.pivotTravel":955,"props.pivotPipe":956,"props.pivotPipeId":957,"props.pivotC":958,"props.pivotHeight":959,"props.pivotEndP":960,"props.pivotGunQ":961,"props.pivotGunP":962,"props.pivotThrow":963,"props.pivotDepth":964,"props.pivotHours":965,"props.pivotWidth":966,"props.pivotLoss":967,"props.pivotMaxRate":968,"props.pivotSector":969,"props.pivotCost":970,"props.pivotAngle":971,"props.pivotResults":972,"props.pivotArea":973,"props.pivotInlet":974,"props.contourInterval":975,"props.derived":976,"check.title":977,"check.explain":978,"check.summary":979,"check.ok":980,"check.run":981,"check.sev.error":982,"check.sev.warning":983,"check.sev.info":984,"check.no_hydraulics":985,"check.no_supply":986,"check.no_valves":987,"check.unconnected":988,"check.zone_no_emitters":989,"check.duplicate_zone_name":990,"check.mainline_dead_end":991,"check.zone_dead_end":992,"check.zero_length":993,"check.tiny_segment":994,"check.duplicate_item":995,"check.pipes_cross":996,"check.spec_missing":997,"check.supply_no_head":998,"check.pivot_unconnected":999,"check.no_terrain":1000,"check.looped_mainline":1001,"check.area_no_emitters":1002,"design.checkFull":1003,"cat.packs":1004,"cat.packsExplain":1005,"cat.packAdd":1006,"cat.packAdded":1007,"cat.packItems":1008,"cat.exportXlsx":1009,"cat.importAny":1010,"mob.menu":1011,"mob.done":1012,"mob.cancel":1013,"mob.props":1014,"mob.tools":1015,"mob.hint":1016,"mob.group.nav":1017,"mob.group.draw":1018,"mob.group.edit":1019,"mob.group.terrain":1020,"mob.group.zone":1021,"mob.group.main":1022,"mob.selection":1023,"mob.project":1024,"mob.file":1025,"mob.view":1026,"mob.help":1027,"sc.mobile":1028,"dlg.followGuide":1029,"hist.title":1030,"hist.hint":1031,"hist.start":1032,"hist.edit":1033,"hist.add":1034,"hist.addMany":1035,"hist.delete":1036,"hist.move":1037,"hist.rotate":1038,"hist.scale":1039,"hist.mirror":1040,"hist.transform":1041,"hist.copy":1042,"hist.array":1043,"hist.block":1044,"hist.grid":1045,"hist.props":1046,"hist.import":1047,"hist.design":1048,"hist.contours":1049,"hist.dem":1050,"hist.paste":1051,"hist.elevation":1052,"hist.align":1053,"hist.layer":1054,"plot.bomOnSheet":1055,"pdf.bom":1056,"pdf.qty":1057,"pdf.bomMore":1058,"imp.demTiff":1059,"reports.pivotSpans":1060,"rep.span":1061,"rep.rFrom":1062,"rep.rTo":1063,"rep.sprinklers":1064,"rep.qSprinkler":1065,"rep.pMid":1066,"rep.nozzleSuggested":1067,"props.pivotSprSpacing":1068,"props.pivotSprinkler":1069,"props.pivotRegulator":1070,"props.pivotTowerCost":1071,"pivot.towersItem":1072,"pivot.sprinklersItem":1073,"pivot.endGunItem":1074,"props.contourSmooth":1075,"dem.online.maxPoints":1076,"pump.motor":1077,"warn.lp_loops_approx":1078,"cat.packsBundled":1079,"cat.packsLoaded":1080,"cat.packImport":1081,"cat.packUrl":1082,"cat.packLoad":1083,"cat.packLoading":1084,"cat.packLoaded":1085,"cat.packLoadError":1086,"cat.packExport":1087,"cat.packExportTitle":1088,"cat.packExportExplain":1089,"cat.packBrand":1090,"cat.packName":1091,"cat.packDescription":1092,"cat.packSource":1093,"cat.packExported":1094,"cat.packFormat":1095,"cat.packFrom":1096,"imp.err.catalog_json_unknown":1097,"imp.err.catalog_index_not_pack":1098,"imp.err.catalog_index_unknown":1099,"imp.err.catalog_pack_version":1100,"dem.online.coord":1101,"dem.online.coordHint":1102,"dem.online.coordExplain":1103,"dem.online.useCoord":1104,"dem.online.areaSize":1105,"dem.online.coordInvalid":1106,"dem.online.contours":1107,"dem.online.contourInterval":1108,"dem.online.doneContours":1109,"msg.georefAt":1110,"file.examples":1111,"help.welcome":1112,"welcome.title":1113,"welcome.body":1114,"welcome.examples":1115,"welcome.examplesHint":1116,"welcome.tutorial":1117,"welcome.skip":1118,"exg.orchard.title":1119,"exg.orchard.sub":1120,"exg.orchard.tags":1121,"exg.garden.title":1122,"exg.garden.sub":1123,"exg.garden.tags":1124,"exg.sportsField.title":1125,"exg.sportsField.sub":1126,"exg.sportsField.tags":1127,"exg.rowCrop.title":1128,"exg.rowCrop.sub":1129,"exg.rowCrop.tags":1130,"exg.pivot.title":1131,"exg.pivot.sub":1132,"exg.pivot.tags":1133,"ex.shift":1134,"ex.g.name":1135,"ex.g.client":1136,"ex.g.site":1137,"ex.g.title":1138,"ex.g.lot":1139,"ex.g.house":1140,"ex.g.front":1141,"ex.g.back":1142,"ex.g.bed":1143,"ex.g.zone1":1144,"ex.g.zone2":1145,"ex.g.zone3":1146,"ex.g.supply":1147,"ex.g.grass":1148,"ex.g.shrubs":1149,"ex.g.main":1150,"ex.g.street":1151,"ex.f.name":1152,"ex.f.client":1153,"ex.f.site":1154,"ex.f.title":1155,"ex.f.pitch":1156,"ex.f.row":1157,"ex.f.tank":1158,"ex.f.pumpHouse":1159,"ex.f.grass":1160,"ex.f.main":1161,"ex.c.name":1162,"ex.c.client":1163,"ex.c.site":1164,"ex.c.title":1165,"ex.c.block":1166,"ex.c.tomato":1167,"ex.c.reservoir":1168,"ex.c.trunk":1169,"ex.c.west":1170,"ex.c.east":1171,"ex.c.road":1172,"ex.c.field":1173,"ex.p.name":1174,"ex.p.client":1175,"ex.p.site":1176,"ex.p.title":1177,"ex.p.pivot":1178,"ex.p.well":1179,"ex.p.maize":1180,"ex.p.adductor":1181,"ex.p.field":1182,"ex.p.boundary":1183,"exg.greenhouse.title":1184,"exg.greenhouse.sub":1185,"exg.greenhouse.tags":1186,"exg.nursery.title":1187,"exg.nursery.sub":1188,"exg.nursery.tags":1189,"exg.coffee.title":1190,"exg.coffee.sub":1191,"exg.coffee.tags":1192,"exg.bananas.title":1193,"exg.bananas.sub":1194,"exg.bananas.tags":1195,"exg.sugarcane.title":1196,"exg.sugarcane.sub":1197,"exg.sugarcane.tags":1198,"exg.gravity.title":1199,"exg.gravity.sub":1200,"exg.gravity.tags":1201,"exg.pasture.title":1202,"exg.pasture.sub":1203,"exg.pasture.tags":1204,"exg.golf.title":1205,"exg.golf.sub":1206,"exg.golf.tags":1207,"exg.sectorPivot.title":1208,"exg.sectorPivot.sub":1209,"exg.sectorPivot.tags":1210,"exg.linear.title":1211,"exg.linear.sub":1212,"exg.linear.tags":1213,"ex.gh.name":1214,"ex.gh.client":1215,"ex.gh.site":1216,"ex.gh.title":1217,"ex.gh.lot":1218,"ex.gh.tunnel":1219,"ex.gh.crop":1220,"ex.gh.tank":1221,"ex.gh.main":1222,"ex.nu.name":1223,"ex.nu.client":1224,"ex.nu.site":1225,"ex.nu.title":1226,"ex.nu.lot":1227,"ex.nu.bed":1228,"ex.nu.crop":1229,"ex.nu.tank":1230,"ex.nu.main":1231,"ex.cf.name":1232,"ex.cf.client":1233,"ex.cf.site":1234,"ex.cf.title":1235,"ex.cf.block":1236,"ex.cf.coffee":1237,"ex.cf.well":1238,"ex.cf.main":1239,"ex.cf.boundary":1240,"ex.ba.name":1241,"ex.ba.client":1242,"ex.ba.site":1243,"ex.ba.title":1244,"ex.ba.block":1245,"ex.ba.banana":1246,"ex.ba.well":1247,"ex.ba.field":1248,"ex.ba.road":1249,"ex.ba.main":1250,"ex.sc.name":1251,"ex.sc.client":1252,"ex.sc.site":1253,"ex.sc.title":1254,"ex.sc.block":1255,"ex.sc.cane":1256,"ex.sc.field":1257,"ex.sc.road":1258,"ex.sc.reservoir":1259,"ex.sc.trunk":1260,"ex.sc.west":1261,"ex.sc.east":1262,"ex.gr.name":1263,"ex.gr.client":1264,"ex.gr.site":1265,"ex.gr.title":1266,"ex.gr.block":1267,"ex.gr.crop":1268,"ex.gr.reservoir":1269,"ex.gr.prv":1270,"ex.gr.field":1271,"ex.gr.main":1272,"ex.gr.west":1273,"ex.gr.east":1274,"ex.pa.name":1275,"ex.pa.client":1276,"ex.pa.site":1277,"ex.pa.title":1278,"ex.pa.paddock":1279,"ex.pa.grass":1280,"ex.pa.fence":1281,"ex.pa.road":1282,"ex.pa.reservoir":1283,"ex.pa.main":1284,"ex.go.name":1285,"ex.go.client":1286,"ex.go.site":1287,"ex.go.title":1288,"ex.go.tee":1289,"ex.go.fairway":1290,"ex.go.fairwayZone":1291,"ex.go.green":1292,"ex.go.bunker":1293,"ex.go.pond":1294,"ex.go.turf":1295,"ex.go.pumpHouse":1296,"ex.go.main":1297,"ex.sp.name":1298,"ex.sp.client":1299,"ex.sp.site":1300,"ex.sp.title":1301,"ex.sp.pivot":1302,"ex.sp.soy":1303,"ex.sp.pond":1304,"ex.sp.farm":1305,"ex.sp.field":1306,"ex.sp.boundary":1307,"ex.sp.road":1308,"ex.sp.adductor":1309,"ex.li.name":1310,"ex.li.client":1311,"ex.li.site":1312,"ex.li.title":1313,"ex.li.machine":1314,"ex.li.wheat":1315,"ex.li.canal":1316,"ex.li.intake":1317,"ex.li.field":1318,"ex.li.boundary":1319,"ex.li.main":1320}
B.jS=new A.a("OpenCADIrrigation","OpenCADIrrigation","OpenCADIrrigation")
B.m_=new A.a("OK","OK","Aceptar")
B.bF=new A.a("Cancelar","Cancel","Cancelar")
B.hQ=new A.a("Aplicar","Apply","Aplicar")
B.jC=new A.a("Fechar","Close","Cerrar")
B.vW=new A.a("Autom\xe1tico","Automatic","Autom\xe1tico")
B.c_=new A.a("Limpar","Clear","Limpiar")
B.ap=new A.a("Arquivo","File","Archivo")
B.bM=new A.a("Editar","Edit","Editar")
B.ck=new A.a("Ver","View","Ver")
B.bK=new A.a("Desenhar","Draw","Dibujar")
B.D=new A.a("Zona","Zone","Zona")
B.t=new A.a("Linha principal","Mainline","L\xednea principal")
B.cq=new A.a("Projeto","Design","Dise\xf1o")
B.k6=new A.a("Relat\xf3rios","Reports","Informes")
B.bP=new A.a("Ferramentas","Tools","Herramientas")
B.bz=new A.a("Ajuda","Help","Ayuda")
B.bu=new A.a("Novo projeto","New project","Nuevo proyecto")
B.eI=new A.a("Abrir projeto\u2026","Open project\u2026","Abrir proyecto\u2026")
B.lV=new A.a("Salvar projeto","Save project","Guardar proyecto")
B.fo=new A.a("Exportar DXF","Export DXF","Exportar DXF")
B.fQ=new A.a("Exportar desenho","Export drawing","Exportar dibujo")
B.fC=new A.a("Exportar relat\xf3rio","Export report","Exportar informe")
B.pI=new A.a("Georrefer\xeancia\u2026","Georeference\u2026","Georreferencia\u2026")
B.fA=new A.a("Nova aba de projeto","New project tab","Nueva pesta\xf1a de proyecto")
B.ex=new A.a("Fechar aba","Close tab","Cerrar pesta\xf1a")
B.uN=new A.a("Nova aba (Ctrl+Alt+N)","New tab (Ctrl+Alt+N)","Nueva pesta\xf1a (Ctrl+Alt+N)")
B.q9=new A.a("Fechar aba (Ctrl+Alt+W)","Close tab (Ctrl+Alt+W)","Cerrar pesta\xf1a (Ctrl+Alt+W)")
B.iz=new A.a("Copiar","Copy","Copiar")
B.n6=new A.a("Recortar","Cut","Cortar")
B.bG=new A.a("Colar","Paste","Pegar")
B.uZ=new A.a("{n} itens copiados","{n} items copied","{n} elementos copiados")
B.vG=new A.a("{n} itens recortados","{n} items cut","{n} elementos cortados")
B.pD=new A.a("Tubo cortado em 2 trechos","Pipe cut into 2 pieces","Tuber\xeda cortada en 2 tramos")
B.ms=new A.a("{n} itens colados","{n} items pasted","{n} elementos pegados")
B.bL=new A.a("Nada selecionado","Nothing selected","Nada seleccionado")
B.fT=new A.a("\xc1rea de transfer\xeancia vazia","Clipboard is empty","Portapapeles vac\xedo")
B.tv=new A.a("Comando desconhecido: {cmd} (veja Ajuda \u2192 Atalhos de teclado)","Unknown command: {cmd} (see Help \u2192 Keyboard shortcuts)","Comando desconocido: {cmd} (vea Ayuda \u2192 Atajos de teclado)")
B.iw=new A.a("Comando","Command","Comando")
B.fm=new A.a("Atalhos de teclado\u2026","Keyboard shortcuts\u2026","Atajos de teclado\u2026")
B.eZ=new A.a("Atalhos de teclado","Keyboard shortcuts","Atajos de teclado")
B.kL=new A.a("Com o desenho em foco, digite o alias do comando e pressione Enter ou Espa\xe7o, como no AutoCAD (ex.: L \u23ce linha, PL \u23ce polilinha, ZE \u23ce enquadrar, E \u23ce apagar). Esc limpa o comando digitado. As combina\xe7\xf5es com Ctrl e as teclas F funcionam em qualquer parte da tela.","With the drawing focused, type the command alias and press Enter or Space, as in AutoCAD (e.g. L \u23ce line, PL \u23ce polyline, ZE \u23ce zoom extents, E \u23ce erase). Esc clears the typed command. Ctrl combinations and F keys work anywhere.","Con el dibujo enfocado, escriba el alias del comando y pulse Enter o Espacio, como en AutoCAD (p. ej. L \u23ce l\xednea, PL \u23ce polil\xednea, ZE \u23ce encuadrar, E \u23ce borrar). Esc limpia el comando. Las combinaciones con Ctrl y las teclas F funcionan en toda la pantalla.")
B.m0=new A.a("Arquivo e abas","File and tabs","Archivo y pesta\xf1as")
B.iK=new A.a("Edi\xe7\xe3o","Editing","Edici\xf3n")
B.q7=new A.a("Vista e desenho","View and drawing","Vista y dibujo")
B.fM=new A.a("Comandos (alias \u23ce)","Commands (alias \u23ce)","Comandos (alias \u23ce)")
B.hL=new A.a("Ferramentas hidr\xe1ulicas (alias \u23ce)","Hydraulic tools (alias \u23ce)","Herramientas hidr\xe1ulicas (alias \u23ce)")
B.qD=new A.a("Alternar aba de projeto","Switch project tab","Cambiar pesta\xf1a de proyecto")
B.lr=new A.a("Cancelar / voltar a selecionar","Cancel / back to select","Cancelar / volver a seleccionar")
B.ju=new A.a("Concluir polilinha / executar comando","Finish polyline / run command","Terminar polil\xednea / ejecutar comando")
B.oS=new A.a("Remover \xfaltimo ponto / apagar letra do comando","Remove last point / delete command letter","Quitar \xfaltimo punto / borrar letra del comando")
B.oQ=new A.a("Repetir \xfaltima ferramenta (Enter ao selecionar)","Repeat last tool (Enter while selecting)","Repetir \xfaltima herramienta (Enter al seleccionar)")
B.hB=new A.a("Aproximar / afastar","Zoom in / out","Acercar / alejar")
B.oz=new A.a("Deslocar vista","Pan view","Desplazar vista")
B.l_=new A.a("Mover vista (segurar; ou bot\xe3o do meio do mouse)","Pan (hold; or middle mouse button)","Mover vista (mantener; o bot\xf3n central del rat\xf3n)")
B.rl=new A.a("Mostrar/ocultar relat\xf3rios","Show/hide reports","Mostrar/ocultar informes")
B.oH=new A.a("Mostrar/ocultar grade","Show/hide grid","Mostrar/ocultar cuadr\xedcula")
B.ol=new A.a("Travar a linha em 0\xb0/45\xb0/90\xb0 enquanto desenha (segurar)","Lock the line to 0\xb0/45\xb0/90\xb0 while drawing (hold)","Bloquear la l\xednea en 0\xb0/45\xb0/90\xb0 mientras dibuja (mantener)")
B.hr=new A.a("Alias digitado executa sozinho ap\xf3s uma pausa (ou Enter/Espa\xe7o)","A typed alias runs by itself after a pause (or Enter/Space)","El alias escrito se ejecuta solo tras una pausa (o Intro/Espacio)")
B.qH=new A.a("Snap / orto / grade vis\xedvel / snap \xe0 grade","Snap / ortho / grid display / grid snap","Snap / orto / cuadr\xedcula visible / snap a cuadr\xedcula")
B.j_=new A.a("Projetar tudo / verificar conex\xf5es / relat\xf3rios","Design all / check connectivity / reports","Dise\xf1ar todo / verificar conexiones / informes")
B.f4=new A.a("DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)")
B.iT=new A.a("DWG (AutoCAD 2000, bin\xe1rio)","DWG (AutoCAD 2000, binary)","DWG (AutoCAD 2000, binario)")
B.nT=new A.a("PDF (prancha para impress\xe3o)\u2026","PDF (plot sheet)\u2026","PDF (l\xe1mina para impresi\xf3n)\u2026")
B.nm=new A.a("SVG (figura vetorial: web, Inkscape)","SVG (vector figure: web, Inkscape)","SVG (figura vectorial: web, Inkscape)")
B.nt=new A.a("KML (Google Earth)","KML (Google Earth)","KML (Google Earth)")
B.mD=new A.a("KMZ (Google Earth, compactado)","KMZ (Google Earth, zipped)","KMZ (Google Earth, comprimido)")
B.qF=new A.a("GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)")
B.mR=new A.a("CSV (planilha)","CSV (spreadsheet)","CSV (hoja de c\xe1lculo)")
B.eR=new A.a("TXT (texto)","TXT (plain text)","TXT (texto)")
B.uW=new A.a("XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)")
B.oO=new A.a("PDF (documento)","PDF (document)","PDF (documento)")
B.rY=new A.a("Exportado: {f}","Exported: {f}","Exportado: {f}")
B.kl=new A.a("Execute o projeto (F5) antes de exportar o relat\xf3rio","Run the design (F5) before exporting the report","Ejecute el dise\xf1o (F5) antes de exportar el informe")
B.m1=new A.a("O desenho est\xe1 vazio","The drawing is empty","El dibujo est\xe1 vac\xedo")
B.md=new A.a("Georrefer\xeancia definida: {crs}","Georeference set: {crs}","Georreferencia definida: {crs}")
B.r1=new A.a("Georrefer\xeancia do projeto","Project georeference","Georreferencia del proyecto")
B.og=new A.a("Para exportar em KML, KMZ ou GeoJSON o desenho precisa de uma posi\xe7\xe3o no mundo. Informe a coordenada da origem do desenho (x = 0, y = 0). Projetos importados de KML/KMZ j\xe1 v\xeam georreferenciados.","To export KML, KMZ or GeoJSON the drawing needs a position on Earth. Enter the coordinate of the drawing origin (x = 0, y = 0). Projects imported from KML/KMZ are already georeferenced.","Para exportar en KML, KMZ o GeoJSON el dibujo necesita una posici\xf3n en el mundo. Indique la coordenada del origen del dibujo (x = 0, y = 0). Los proyectos importados de KML/KMZ ya vienen georreferenciados.")
B.pv=new A.a("Latitude / longitude (WGS84)","Latitude / longitude (WGS84)","Latitud / longitud (WGS84)")
B.tp=new A.a("UTM (WGS84)","UTM (WGS84)","UTM (WGS84)")
B.lp=new A.a("Latitude (\xb0)","Latitude (\xb0)","Latitud (\xb0)")
B.ru=new A.a("Longitude (\xb0)","Longitude (\xb0)","Longitud (\xb0)")
B.rX=new A.a("Fuso UTM (1\u201360)","UTM zone (1\u201360)","Huso UTM (1\u201360)")
B.jy=new A.a("Hemisf\xe9rio norte","Northern hemisphere","Hemisferio norte")
B.op=new A.a("Este (m)","Easting (m)","Este (m)")
B.ja=new A.a("Norte (m)","Northing (m)","Norte (m)")
B.hN=new A.a("Atual: {crs} \xb7 origem E {e} m, N {n} m","Current: {crs} \xb7 origin E {e} m, N {n} m","Actual: {crs} \xb7 origen E {e} m, N {n} m")
B.hu=new A.a("Projeto ainda sem georrefer\xeancia","Project not georeferenced yet","Proyecto a\xfan sin georreferencia")
B.c7=new A.a("Remover","Remove","Quitar")
B.ne=new A.a("Coordenadas inv\xe1lidas","Invalid coordinates","Coordenadas no v\xe1lidas")
B.jG=new A.a("Exportar PDF (prancha)","Export PDF (plot sheet)","Exportar PDF (l\xe1mina)")
B.nq=new A.a("Formato do papel","Paper size","Tama\xf1o de papel")
B.qV=new A.a("Orienta\xe7\xe3o","Orientation","Orientaci\xf3n")
B.mo=new A.a("Paisagem","Landscape","Horizontal")
B.nd=new A.a("Retrato","Portrait","Vertical")
B.pO=new A.a("Escala 1 :","Scale 1 :","Escala 1 :")
B.eQ=new A.a("Ajustar \xe0 folha","Fit to sheet","Ajustar a la hoja")
B.aF=new A.a("Raios molhados","Wetted radii","Radios mojados")
B.tB=new A.a("R\xf3tulos e resultados","Labels and results","Etiquetas y resultados")
B.rh=new A.a("Legenda de camadas","Layer legend","Leyenda de capas")
B.mr=new A.a("Anexar p\xe1ginas de relat\xf3rio","Append report pages","Adjuntar p\xe1ginas de informe")
B.jp=new A.a("Exportar","Export","Exportar")
B.wH=new A.a("Escala autom\xe1tica: 1:{n}","Automatic scale: 1:{n}","Escala autom\xe1tica: 1:{n}")
B.bJ=new A.a("Data","Date","Fecha")
B.jk=new A.a("Escala","Scale","Escala")
B.jI=new A.a("Folha","Sheet","Hoja")
B.m5=new A.a("Origem","Origin","Origen")
B.me=new A.a("Zonas / emissores","Zones / outlets","Zonas / emisores")
B.oi=new A.a("Coordenadas","Coordinates","Coordenadas")
B.vj=new A.a("Locais (m)","Local (m)","Locales (m)")
B.le=new A.a("Legenda","Legend","Leyenda")
B.rm=new A.a("Projeto de irriga\xe7\xe3o pressurizada","Pressurised irrigation design","Dise\xf1o de riego presurizado")
B.o7=new A.a("Relat\xf3rio de dimensionamento hidr\xe1ulico","Hydraulic design report","Informe de dise\xf1o hidr\xe1ulico")
B.qf=new A.a("Gerado por OpenCADIrrigation em {d}","Generated by OpenCADIrrigation on {d}","Generado por OpenCADIrrigation el {d}")
B.ws=new A.a("P\xe1gina {i} de {n}","Page {i} of {n}","P\xe1gina {i} de {n}")
B.nK=new A.a("(continua\xe7\xe3o)","(continued)","(continuaci\xf3n)")
B.eg=new A.a("Sem resultados de dimensionamento: execute o projeto para incluir as tabelas hidr\xe1ulicas.","No design results: run the design to include the hydraulic tables.","Sin resultados de dise\xf1o: ejecute el dise\xf1o para incluir las tablas hidr\xe1ulicas.")
B.ri=new A.a("Par\xe2metros de projeto","Design parameters","Par\xe1metros de dise\xf1o")
B.iY=new A.a("Desenho","Drawing","Dibujo")
B.X=new A.a("Texto","Text","Texto")
B.iC=new A.a("Cotas","Dimensions","Cotas")
B.qE=new A.a("Curvas de n\xedvel","Contours","Curvas de nivel")
B.oK=new A.a("Pontos cotados","Spot heights","Puntos acotados")
B.j5=new A.a("Tubos de zona","Zone pipes","Tuber\xedas de zona")
B.i9=new A.a("Linha principal","Mainline pipes","L\xednea principal")
B.jh=new A.a("Laterais com emissores","Spraylines","Laterales con emisores")
B.v8=new A.a("Fitas gotejadoras","Drip tapes","Cintas de goteo")
B.A=new A.a("Emissores","Outlets","Emisores")
B.us=new A.a("V\xe1lvulas de controle","Control valves","V\xe1lvulas de control")
B.rp=new A.a("Fontes de \xe1gua","Water supplies","Fuentes de agua")
B.ar=new A.a("Bombas","Pumps","Bombas")
B.cj=new A.a("Acess\xf3rios hidr\xe1ulicos","Hydraulic devices","Accesorios hidr\xe1ulicos")
B.fr=new A.a("N\xf3s","Junctions","Nudos")
B.hC=new A.a("\xc1reas irrigadas","Irrigated areas","\xc1reas regadas")
B.cC=new A.a("R\xf3tulos","Labels","Etiquetas")
B.qI=new A.a("Detalhes do projeto\u2026","Project details\u2026","Detalles del proyecto\u2026")
B.iZ=new A.a("Desfazer","Undo","Deshacer")
B.n8=new A.a("Refazer","Redo","Rehacer")
B.k9=new A.a("Excluir sele\xe7\xe3o","Delete selection","Eliminar selecci\xf3n")
B.uM=new A.a("Selecionar tudo","Select all","Seleccionar todo")
B.j6=new A.a("Duplicar sele\xe7\xe3o","Duplicate selection","Duplicar selecci\xf3n")
B.ib=new A.a("Enquadrar tudo","Zoom all","Encuadrar todo")
B.tT=new A.a("Aproximar","Zoom in","Acercar")
B.lX=new A.a("Afastar","Zoom out","Alejar")
B.bV=new A.a("Grade","Grid","Cuadr\xedcula")
B.nh=new A.a("Sem resultados","No results overlay","Sin resultados")
B.p0=new A.a("Colorir por velocidade","Colour by velocity","Colorear por velocidad")
B.wG=new A.a("Colorir por press\xe3o","Colour by pressure","Colorear por presi\xf3n")
B.fl=new A.a("Mostrar di\xe2metros","Show diameters","Mostrar di\xe1metros")
B.bE=new A.a("Camadas","Layers","Capas")
B.kr=new A.a("Idioma","Language","Idioma")
B.p3=new A.a("Portugu\xeas","Portuguese","Portugu\xe9s")
B.lM=new A.a("Ingl\xeas","English","Ingl\xe9s")
B.w1=new A.a("Espanhol","Spanish","Espa\xf1ol")
B.ww=new A.a("Par\xe2metros de projeto\u2026","Design parameters\u2026","Par\xe1metros de dise\xf1o\u2026")
B.tz=new A.a("Turnos de opera\xe7\xe3o (management)\u2026","System flows (management)\u2026","Turnos de operaci\xf3n\u2026")
B.q0=new A.a("Verifica\xe7\xe3o do projeto (Design Check)\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o (Design Check)\u2026")
B.oU=new A.a("Dimensionar zonas (LP/velocidade)","Size zones (LP/velocity)","Dimensionar zonas (LP/velocidad)")
B.pa=new A.a("Analisar (tamanhos atuais)","Analyse (existing sizes)","Analizar (tama\xf1os actuales)")
B.ot=new A.a("Dimensionar linha principal","Size mainline","Dimensionar l\xednea principal")
B.hd=new A.a("Projetar tudo","Design all","Dise\xf1ar todo")
B.lZ=new A.a("Limpar resultados","Clear results","Limpiar resultados")
B.hA=new A.a("Calculando o projeto\u2026","Designing the system\u2026","Calculando el dise\xf1o\u2026")
B.jT=new A.a("Montando a rede hidr\xe1ulica","Building the hydraulic network","Armando la red hidr\xe1ulica")
B.kh=new A.a("Zona {i} de {n}","Zone {i} of {n}","Zona {i} de {n}")
B.lj=new A.a("Linha principal e turnos de opera\xe7\xe3o","Mainline and system flows","L\xednea principal y turnos de operaci\xf3n")
B.k8=new A.a("Reanalisando trechos telescopados","Re-analysing telescoped pipes","Reanalizando tramos telescopados")
B.pw=new A.a("An\xe1lise de lavagem (flushing)","Flushing analysis","An\xe1lisis de lavado (flushing)")
B.fw=new A.a("Verifica\xe7\xe3o de golpe de ar\xedete","Water hammer check","Verificaci\xf3n de golpe de ariete")
B.Y=new A.a("Lista de materiais","Bill of materials","Lista de materiales")
B.v4=new A.a("Calculando em segundo plano: navegue \xe0 vontade; edi\xe7\xf5es esperam o fim.","Running in the background: navigate freely; edits wait until it finishes.","Calculando en segundo plano: navega libremente; las ediciones esperan al final.")
B.uS=new A.a("O navegador pode ficar lento enquanto o c\xe1lculo roda.","The browser may be slow while the calculation runs.","El navegador puede ir lento mientras corre el c\xe1lculo.")
B.vR=new A.a("Cat\xe1logo de componentes\u2026","Component catalog\u2026","Cat\xe1logo de componentes\u2026")
B.pE=new A.a("Bloco de laterais\u2026","Lateral block\u2026","Bloque de laterales\u2026")
B.ny=new A.a("Aspersores autom\xe1ticos (grade)\u2026","Auto sprinklers (grid)\u2026","Aspersores autom\xe1ticos (malla)\u2026")
B.eM=new A.a("Resumo das zonas","Zone summary","Resumen de zonas")
B.at=new A.a("Tubos","Pipes","Tuber\xedas")
B.t2=new A.a("Linha principal / duty","Mainline / duty","L\xednea principal / demanda")
B.et=new A.a("Requisitos h\xeddricos","Water requirements","Requerimientos h\xeddricos")
B.w3=new A.a("Linha piezom\xe9trica","Hydraulic grade line","L\xednea piezom\xe9trica")
B.ly=new A.a("Mensagens","Messages","Mensajes")
B.l0=new A.a("Calculadora de lateral\u2026","Lateral calculator\u2026","Calculadora de lateral\u2026")
B.t9=new A.a("Bomba e curva do sistema\u2026","Pump & system curve\u2026","Bomba y curva del sistema\u2026")
B.ut=new A.a("Golpe de ar\xedete\u2026","Water hammer\u2026","Golpe de ariete\u2026")
B.f2=new A.a("Unidades\u2026","Units\u2026","Unidades\u2026")
B.mj=new A.a("Sobre","About","Acerca de")
B.rM=new A.a("Tutorial interativo","Interactive tutorial","Tutorial interactivo")
B.nC=new A.a("Selecionar","Select","Seleccionar")
B.pK=new A.a("Mover vista","Pan","Mover vista")
B.rR=new A.a("Linha","Line","L\xednea")
B.f3=new A.a("Polilinha","Polyline","Polil\xednea")
B.oZ=new A.a("Ret\xe2ngulo","Rectangle","Rect\xe1ngulo")
B.j7=new A.a("C\xedrculo","Circle","C\xedrculo")
B.iB=new A.a("Cota","Dimension","Cota")
B.nO=new A.a("Curva de n\xedvel","Contour","Curva de nivel")
B.p8=new A.a("Cota de ponto","Spot height","Cota de punto")
B.aC=new A.a("\xc1rea irrigada","Irrigated area","\xc1rea regada")
B.ic=new A.a("Tubo de zona","Zone pipe","Tuber\xeda de zona")
B.uO=new A.a("Tubo principal","Mainline pipe","Tuber\xeda principal")
B.fF=new A.a("Lateral (sprayline)","Sprayline (lateral)","Lateral (sprayline)")
B.bX=new A.a("Fita/tubo gotejador","Drip tape / dripline","Cinta/tuber\xeda de goteo")
B.W=new A.a("Emissor","Outlet","Emisor")
B.iS=new A.a("V\xe1lvula de controle","Control valve","V\xe1lvula de control")
B.kK=new A.a("Fonte de \xe1gua","Water supply","Fuente de agua")
B.aq=new A.a("Bomba","Pump","Bomba")
B.tn=new A.a("Acess\xf3rio hidr\xe1ulico","Misc. hydraulic","Accesorio hidr\xe1ulico")
B.mc=new A.a("Jun\xe7\xe3o","Junction","Nudo")
B.co=new A.a("Bloco de laterais","Lateral block","Bloque de laterales")
B.bt=new A.a("Grade de aspersores","Sprinkler grid","Malla de aspersores")
B.lx=new A.a("Medir","Measure","Medir")
B.ez=new A.a("Clique para selecionar, arraste para mover ou janela; Shift adiciona; Del exclui","Click to select, drag to move or window; Shift adds; Del deletes","Clic para seleccionar, arrastre para mover o ventana; Shift a\xf1ade; Supr elimina")
B.qY=new A.a("Arraste para mover a vista; roda do mouse para zoom","Drag to pan; mouse wheel zooms","Arrastre para mover la vista; rueda del rat\xf3n para zoom")
B.rF=new A.a("Clique no primeiro ponto, depois no segundo","Click first point, then second","Clic en el primer punto y luego en el segundo")
B.l4=new A.a("Clique nos v\xe9rtices; Enter/duplo clique termina; Esc cancela","Click vertices; Enter/double-click ends; Esc cancels","Clic en los v\xe9rtices; Intro/doble clic termina; Esc cancela")
B.u_=new A.a("Clique nos dois cantos opostos","Click two opposite corners","Clic en dos esquinas opuestas")
B.f0=new A.a("Clique no centro, depois no raio","Click centre, then radius","Clic en el centro y luego en el radio")
B.rZ=new A.a("Clique na posi\xe7\xe3o do texto","Click text position","Clic en la posici\xf3n del texto")
B.rJ=new A.a("Clique nos dois pontos e depois na posi\xe7\xe3o da linha de cota","Click two points, then the dimension line position","Clic en dos puntos y luego en la posici\xf3n de la l\xednea de cota")
B.oV=new A.a("Clique os v\xe9rtices da curva de n\xedvel; Enter (ou Concluir) termina e pede a eleva\xe7\xe3o; Esc cancela","Click the contour vertices; Enter (or Done) finishes and asks for the elevation; Esc cancels","Clic en los v\xe9rtices de la curva de nivel; Intro (o Terminar) termina y pide la elevaci\xf3n; Esc cancela")
B.l5=new A.a("Clique onde fica a cota; a eleva\xe7\xe3o \xe9 pedida a cada ponto","Click where the spot height goes; the elevation is asked for each point","Clic donde va la cota; la elevaci\xf3n se pide en cada punto")
B.vk=new A.a("Clique nos v\xe9rtices do pol\xedgono; Enter fecha","Click polygon vertices; Enter closes","Clic en los v\xe9rtices del pol\xedgono; Intro cierra")
B.ln=new A.a("Clique nos v\xe9rtices do tubo; Enter/duplo clique termina; conecta automaticamente","Click pipe vertices; Enter/double-click ends; connects automatically","Clic en los v\xe9rtices de la tuber\xeda; Intro/doble clic termina; conecta autom\xe1ticamente")
B.ul=new A.a("Clique sobre um tubo ou jun\xe7\xe3o para conectar","Click on a pipe or junction to connect","Clic sobre una tuber\xeda o nudo para conectar")
B.eN=new A.a("Clique nos v\xe9rtices do bloco; Enter conclui e abre as op\xe7\xf5es","Click block vertices; Enter finishes and opens options","Clic en los v\xe9rtices del bloque; Intro termina y abre las opciones")
B.lq=new A.a("Clique em dois pontos","Click two points","Clic en dos puntos")
B.my=new A.a("Pronto","Ready","Listo")
B.nD=new A.a("Snap","Snap","Snap")
B.m6=new A.a("Orto","Ortho","Orto")
B.o6=new A.a("ent.","ent.","ent.")
B.aD=new A.a("Propriedades","Properties","Propiedades")
B.qe=new A.a("{n} itens selecionados","{n} items selected","{n} elementos seleccionados")
B.ik=new A.a("Camada","Layer","Capa")
B.aw=new A.a("Nome","Name","Nombre")
B.cs=new A.a("Tubo","Pipe","Tuber\xeda")
B.t0=new A.a("Dimensionar automaticamente","Computer sized","Dimensionar autom\xe1ticamente")
B.kx=new A.a("Profundidade (m)","Depth (m)","Profundidad (m)")
B.bD=new A.a("Bocal","Nozzle","Boquilla")
B.v1=new A.a("Press\xe3o nominal","Nominal pressure","Presi\xf3n nominal")
B.tu=new A.a("Espa\xe7amento","Spacing","Espaciamiento")
B.vh=new A.a("Deslocamento do 1\xba emissor","First outlet offset","Desplazamiento del 1.\xba emisor")
B.t8=new A.a("Arco (\xb0)","Arc (\xb0)","Arco (\xb0)")
B.qu=new A.a("Altura da haste (m)","Riser height (m)","Altura del tubo de subida (m)")
B.qz=new A.a("Fita/tubo gotejador","Tape / dripline","Cinta/tuber\xeda de goteo")
B.ql=new A.a("Press\xe3o de entrada","Inlet pressure","Presi\xf3n de entrada")
B.n9=new A.a("Regulada","Regulated","Regulada")
B.q_=new A.a("Press\xe3o m\xedn. no submain","Submain min. pressure","Presi\xf3n m\xedn. en el submain")
B.bv=new A.a("V\xe1lvula","Valve","V\xe1lvula")
B.jM=new A.a("Press\xe3o a jusante fixa (vazio = calcular)","Fixed downstream pressure (blank = calculate)","Presi\xf3n aguas abajo fija (vac\xedo = calcular)")
B.u6=new A.a("Calcular press\xe3o necess\xe1ria","Calculate required pressure","Calcular presi\xf3n necesaria")
B.wD=new A.a("Press\xe3o de projeto","Design pressure","Presi\xf3n de dise\xf1o")
B.wJ=new A.a("Press\xe3o m\xe1xima","Maximum pressure","Presi\xf3n m\xe1xima")
B.po=new A.a("Vaz\xe3o de projeto","Design flow","Caudal de dise\xf1o")
B.jH=new A.a("Vaz\xe3o m\xe1xima","Maximum flow","Caudal m\xe1ximo")
B.w_=new A.a("N\xedvel de \xe1gua relativo ao solo (m)","Water level relative to ground (m)","Nivel de agua respecto al suelo (m)")
B.c3=new A.a("Rota\xe7\xe3o relativa","Relative speed","Velocidad relativa")
B.cA=new A.a("Acess\xf3rio","Device","Accesorio")
B.mE=new A.a("Press\xe3o regulada (PRV)","Regulated pressure (PRV)","Presi\xf3n regulada (PRV)")
B.aE=new A.a("Eleva\xe7\xe3o (m)","Elevation (m)","Elevaci\xf3n (m)")
B.pz=new A.a("Eleva\xe7\xe3o (m; 0 = do terreno)","Elevation (m; 0 = from DEM)","Elevaci\xf3n (m; 0 = del terreno)")
B.eX=new A.a("Altura do texto (m)","Text height (m)","Altura del texto (m)")
B.fp=new A.a("Raio (m)","Radius (m)","Radio (m)")
B.jB=new A.a("Fechado","Closed","Cerrado")
B.fe=new A.a("L\xe2mina l\xedquida (mm/dia)","Net depth (mm/day)","L\xe1mina neta (mm/d\xeda)")
B.hb=new A.a("Efici\xeancia","Efficiency","Eficiencia")
B.iE=new A.a("Cultura","Crop","Cultivo")
B.bH=new A.a("Comprimento","Length","Longitud")
B.az=new A.a("\xc1rea","Area","\xc1rea")
B.kH=new A.a("Escopo","Scope","\xc1mbito")
B.c8=new A.a("Resultados","Results","Resultados")
B.vb=new A.a("Orienta\xe7\xe3o (\xb0)","Orientation (\xb0)","Orientaci\xf3n (\xb0)")
B.kZ=new A.a("Rota\xe7\xe3o (\xb0)","Rotation (\xb0)","Rotaci\xf3n (\xb0)")
B.mC=new A.a("Afastamento da cota","Dimension offset","Desplazamiento de la cota")
B.wy=new A.a("Enquadrar","Zoom to","Encuadrar")
B.vt=new A.a("1\xba emissor a meio espa\xe7amento","First outlet at half spacing","1.\xba emisor a medio espaciamiento")
B.ev=new A.a("P a jusante","Downstream P","P aguas abajo")
B.cv=new A.a("P requerida","Required P","P requerida")
B.wx=new A.a("Perda na v\xe1lvula","Valve loss","P\xe9rdida en la v\xe1lvula")
B.py=new A.a("Emissor m\xedn/m\xe1x","Outlet min/max","Emisor m\xedn/m\xe1x")
B.wC=new A.a("Admiss\xedvel","Allowable","Admisible")
B.vY=new A.a("CU / DU / EU","CU / DU / EU","CU / DU / EU")
B.r3=new A.a("valores padr\xe3o","defaults","valores predeterminados")
B.au=new A.a("Vaz\xe3o","Flow","Caudal")
B.os=new A.a("Velocidade","Velocity","Velocidad")
B.u7=new A.a("Perda de carga","Head loss","P\xe9rdida de carga")
B.av=new A.a("Press\xe3o","Pressure","Presi\xf3n")
B.i4=new A.a("Press\xe3o in\xedcio","Start pressure","Presi\xf3n inicio")
B.wf=new A.a("Press\xe3o fim","End pressure","Presi\xf3n final")
B.qa=new A.a("M\xedn","Min","M\xedn")
B.kb=new A.a("M\xe1x","Max","M\xe1x")
B.hG=new A.a("Projeto salvo","Project saved","Proyecto guardado")
B.or=new A.a("Projeto carregado","Project loaded","Proyecto cargado")
B.hU=new A.a("Projeto conclu\xeddo: {z} zonas, {f} turnos","Design finished: {z} zones, {f} system flows","Dise\xf1o terminado: {z} zonas, {f} turnos")
B.rz=new A.a("{n} itens n\xe3o conectados (marcados em vermelho)","{n} unconnected items (marked in red)","{n} elementos sin conectar (marcados en rojo)")
B.hY=new A.a("Todos os itens est\xe3o conectados","All items are connected","Todos los elementos est\xe1n conectados")
B.l3=new A.a("C\xe1lculo em andamento: aguarde para editar o projeto.","Design running: wait for it to finish before editing.","C\xe1lculo en curso: espera a que termine para editar.")
B.rc=new A.a("O projeto mudou durante o c\xe1lculo; resultados descartados. Rode o c\xe1lculo de novo.","The project changed while the design ran; results discarded. Run the design again.","El proyecto cambi\xf3 durante el c\xe1lculo; resultados descartados. Ejecuta el c\xe1lculo de nuevo.")
B.td=new A.a("Nenhuma v\xe1lvula de controle no projeto","No control valve in the design","No hay v\xe1lvulas de control en el dise\xf1o")
B.rA=new A.a("{n} itens exclu\xeddos","{n} items deleted","{n} elementos eliminados")
B.kt=new A.a("Importado","Imported","Importado")
B.m8=new A.a("Erro: {e}","Error: {e}","Error: {e}")
B.uI=new A.a("O projeto atual tem altera\xe7\xf5es n\xe3o salvas. Continuar?","The current project has unsaved changes. Continue?","El proyecto actual tiene cambios sin guardar. \xbfContinuar?")
B.ki=new A.a("Execute Projeto \u25b6 para gerar resultados","Run Design \u25b6 to generate results","Ejecute Dise\xf1o \u25b6 para generar resultados")
B.oM=new A.a("Desenhe \xe1reas irrigadas (ferramenta \xc1rea) para calcular tempos de irriga\xe7\xe3o","Draw irrigated areas (Area tool) to compute irrigation times","Dibuje \xe1reas regadas (herramienta \xc1rea) para calcular tiempos de riego")
B.ts=new A.a("Selecione um tubo, lateral ou v\xe1lvula","Select a pipe, lateral or valve","Seleccione una tuber\xeda, lateral o v\xe1lvula")
B.pF=new A.a("Sem mensagens","No messages","Sin mensajes")
B.r8=new A.a("N\xe3o conectado","Not connected","Sin conectar")
B.pl=new A.a("DWG {v}: {n} entidades, {l} camadas","DWG {v}: {n} entities, {l} layers","DWG {v}: {n} entidades, {l} capas")
B.vF=new A.a(", {n} objetos ignorados",", {n} objects skipped",", {n} objetos omitidos")
B.uu=new A.a(u.n,"{k}: {p} placemarks, {n} entities ({crs})",u.n)
B.pV=new A.a("DXF: {n} entidades","DXF: {n} entities","DXF: {n} entidades")
B.wi=new A.a("N\xe3o \xe9 um arquivo DWG reconhecido","Not a recognised DWG file","No es un archivo DWG reconocido")
B.pJ=new A.a("Estrutura do DWG n\xe3o encontrada (arquivo danificado ou variante n\xe3o suportada)","DWG structure not found (damaged file or unsupported variant)","Estructura del DWG no encontrada (archivo da\xf1ado o variante no compatible)")
B.jF=new A.a("KMZ sem arquivo .kml","KMZ without a .kml file","KMZ sin archivo .kml")
B.fL=new A.a("P jusante","Downstream P","P aguas abajo")
B.oh=new A.a("Perda v\xe1lv.","Valve loss","P\xe9rdida v\xe1lv.")
B.cz=new A.a("P m\xedn","Min P","P m\xedn")
B.cb=new A.a("P m\xe1x","Max P","P m\xe1x")
B.w2=new A.a("Adm. m\xedn","Allow. min","Adm. m\xedn")
B.rD=new A.a("Adm. m\xe1x","Allow. max","Adm. m\xe1x")
B.te=new A.a("Var. adm. %","Allow. var. %","Var. adm. %")
B.wk=new A.a("Var. real %","Actual var. %","Var. real %")
B.tO=new A.a("Custo tubos","Pipe cost","Costo tuber\xedas")
B.hW=new A.a("Avisos","Warnings","Avisos")
B.iy=new A.a("Contexto","Context","Contexto")
B.ji=new A.a("Entidade","Entity","Entidad")
B.ks=new A.a("Seg.","Seg.","Seg.")
B.iP=new A.a("DI","ID","DI")
B.bY=new A.a("L","L","L")
B.mI=new A.a("Q","Q","Q")
B.l9=new A.a("V (m/s)","V (m/s)","V (m/s)")
B.rw=new A.a("hf","hf","hf")
B.eS=new A.a("P in\xedcio","Start P","P inicio")
B.eo=new A.a("P fim","End P","P fin")
B.pq=new A.a("Z in\xedcio","Start Z","Z inicio")
B.k_=new A.a("Z fim","End Z","Z fin")
B.mi=new A.a("PN","PN","PN")
B.lL=new A.a("N","N","N")
B.vc=new A.a("Q total","Total Q","Q total")
B.wr=new A.a("Q m\xe9dio","Mean Q","Q medio")
B.ax=new A.a("Turno","System flow","Turno")
B.kw=new A.a("Item","Item","Elemento")
B.he=new A.a("P dispon\xedvel","Available P","P disponible")
B.oL=new A.a("Situa\xe7\xe3o","Status","Estado")
B.cm=new A.a("Energia/ano","Energy/year","Energ\xeda/a\xf1o")
B.as=new A.a("Fonte","Supply","Fuente")
B.pW=new A.a("calculada","calculated","calculada")
B.qR=new A.a("fixa","fixed","fija")
B.vI=new A.a("d\xe9ficit","deficit","d\xe9ficit")
B.uc=new A.a("ok","ok","ok")
B.h1=new A.a("H bomba","Pump H","H bomba")
B.mh=new A.a("Categoria","Category","Categor\xeda")
B.ue=new A.a("Descri\xe7\xe3o","Description","Descripci\xf3n")
B.rV=new A.a("Un.","Unit","Ud.")
B.mT=new A.a("Quantidade","Quantity","Cantidad")
B.qA=new A.a("Unit\xe1rio","Unit cost","Unitario")
B.o0=new A.a("Total","Total","Total")
B.nR=new A.a("TOTAL","TOTAL","TOTAL")
B.uV=new A.a("Custo anualizado (capital)","Annualised cost (capital)","Costo anualizado (capital)")
B.r2=new A.a("Custo anual de energia","Annual energy cost","Costo anual de energ\xeda")
B.w7=new A.a("Custo anual total","Total annual cost","Costo anual total")
B.q4=new A.a("L\xe2mina bruta (mm/d)","Gross depth (mm/d)","L\xe1mina bruta (mm/d)")
B.ep=new A.a("Volume (m\xb3/d)","Volume (m\xb3/d)","Volumen (m\xb3/d)")
B.eG=new A.a("Taxa (mm/h)","Rate (mm/h)","Tasa (mm/h)")
B.jV=new A.a("Horas/dia","Hours/day","Horas/d\xeda")
B.lK=new A.a("HGL (azul) \xb7 terreno (marrom) \xb7 faixa admiss\xedvel (verde)","HGL (blue) \xb7 ground (brown) \xb7 allowable band (green)","LP (azul) \xb7 terreno (marr\xf3n) \xb7 banda admisible (verde)")
B.pb=new A.a("ZONAS","ZONES","ZONAS")
B.v6=new A.a("TURNOS","SYSTEM FLOWS","TURNOS")
B.vM=new A.a("LISTA DE MATERIAIS","BILL OF MATERIALS","LISTA DE MATERIALES")
B.km=new A.a("Fitas/tubos gotejadores","Drip tapes/lines","Cintas/tuber\xedas de goteo")
B.cp=new A.a("V\xe1lvulas","Valves","V\xe1lvulas")
B.q2=new A.a("Todas as zonas","All zones","Todas las zonas")
B.nI=new A.a("Submain","Submain","Submain")
B.o1=new A.a("Trecho","Stub","Tramo")
B.uU=new A.a("relatorio","report","informe")
B.ow=new A.a("Exemplo pomar","Orchard example","Ejemplo huerto")
B.z=new A.a("Fazenda Exemplo","Example Farm","Finca Ejemplo")
B.h0=new A.a("Blocos A e B","Blocks A and B","Bloques A y B")
B.j0=new A.a("Divisa","Boundary","Lindero")
B.rf=new A.a("Pomar \u2014 exemplo OpenCADIrrigation","Orchard \u2014 OpenCADIrrigation example","Huerto \u2014 ejemplo OpenCADIrrigation")
B.ll=new A.a("Zona A","Zone A","Zona A")
B.lm=new A.a("Zona B","Zone B","Zona B")
B.t7=new A.a("Bloco A","Block A","Bloque A")
B.qU=new A.a("Bloco B","Block B","Bloque B")
B.c9=new A.a("Citros","Citrus","C\xedtricos")
B.ci=new A.a("Uva","Grapes","Uva")
B.jL=new A.a("Recalque","Rising main","Impulsi\xf3n")
B.tm=new A.a("Ramal A","Branch A","Ramal A")
B.vP=new A.a("Ramal B","Branch B","Ramal B")
B.N=new A.a("Po\xe7o","Well","Pozo")
B.wb=new A.a("Turno 1 \u2014 Zona A","Flow 1 \u2014 Zone A","Turno 1 \u2014 Zona A")
B.nN=new A.a("Turno 2 \u2014 Zona B","Flow 2 \u2014 Zone B","Turno 2 \u2014 Zona B")
B.mx=new A.a("Projeto","Project","Proyecto")
B.iu=new A.a("Cliente","Client","Cliente")
B.lh=new A.a("Local","Site","Lugar")
B.mw=new A.a("Projetista","Designer","Proyectista")
B.lT=new A.a("Notas","Notes","Notas")
B.p1=new A.a("Hidr\xe1ulica","Hydraulics","Hidr\xe1ulica")
B.kp=new A.a("F\xf3rmula de perda de carga","Head-loss formula","F\xf3rmula de p\xe9rdida de carga")
B.es=new A.a("Hazen-Williams","Hazen-Williams","Hazen-Williams")
B.qS=new A.a("Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)")
B.ed=new A.a("Temperatura da \xe1gua (\xb0C)","Water temperature (\xb0C)","Temperatura del agua (\xb0C)")
B.ec=new A.a("Vel. m\xe1x. lateral (m/s)","Max. lateral velocity (m/s)","Vel. m\xe1x. lateral (m/s)")
B.t4=new A.a("Vel. m\xe1x. zona (m/s)","Max. zone velocity (m/s)","Vel. m\xe1x. zona (m/s)")
B.hZ=new A.a("Vel. m\xe1x. linha principal (m/s)","Max. mainline velocity (m/s)","Vel. m\xe1x. l\xednea principal (m/s)")
B.jX=new A.a("Perdas localizadas (% do comprimento)","Minor losses (% of length)","P\xe9rdidas localizadas (% de la longitud)")
B.v_=new A.a("Toler\xe2ncia de conex\xe3o (m)","Connection tolerance (m)","Tolerancia de conexi\xf3n (m)")
B.kQ=new A.a("Aplicar perdas localizadas","Apply minor losses","Aplicar p\xe9rdidas localizadas")
B.rI=new A.a("Fator C: escala","C factor: scale","Factor C: escala")
B.ld=new A.a("Fator C: acr\xe9scimo","C factor: offset","Factor C: incremento")
B.o9=new A.a("Dimensionamento","Sizing","Dimensionamiento")
B.mf=new A.a("N\xba m\xe1x. de di\xe2metros no submain","Max. submain sizes","N.\xba m\xe1x. de di\xe1metros en el submain")
B.kV=new A.a("Densifica\xe7\xe3o do DEM (m)","DEM densification (m)","Densificaci\xf3n del MDT (m)")
B.fs=new A.a("Economia","Economics","Econom\xeda")
B.hM=new A.a("Balancear custo de capital vs. custo de energia","Trade capital cost vs. energy cost","Equilibrar costo de capital vs. costo de energ\xeda")
B.vK=new A.a("Juros (fra\xe7\xe3o/ano)","Interest (fraction/year)","Inter\xe9s (fracci\xf3n/a\xf1o)")
B.v2=new A.a("Prazo (anos)","Term (years)","Plazo (a\xf1os)")
B.oR=new A.a("Custo da energia ({c}/kWh)","Energy cost ({c}/kWh)","Costo de la energ\xeda ({c}/kWh)")
B.jf=new A.a("Efici\xeancia da bomba (fra\xe7\xe3o)","Pump efficiency (fraction)","Eficiencia de la bomba (fracci\xf3n)")
B.vl=new A.a("Horas de opera\xe7\xe3o/ano (linha principal)","Operating hours/year (mainline)","Horas de operaci\xf3n/a\xf1o (l\xednea principal)")
B.iU=new A.a("Horas/ano por zona","Hours/year per zone","Horas/a\xf1o por zona")
B.lD=new A.a("Moeda","Currency","Moneda")
B.ls=new A.a("M\xe9trico","Metric","M\xe9trico")
B.ml=new A.a("US","US","EE. UU.")
B.qo=new A.a("Di\xe2metro","Diameter","Di\xe1metro")
B.fa=new A.a("Todas juntas","All together","Todas juntas")
B.p4=new A.a("Uma por vez","One at a time","Una a la vez")
B.ro=new A.a("+ Turno","+ Flow","+ Turno")
B.qy=new A.a("In\xedcio (h)","Start (h)","Inicio (h)")
B.cu=new A.a("Dura\xe7\xe3o (h)","Duration (h)","Duraci\xf3n (h)")
B.up=new A.a("Sem turnos definidos: todas as zonas ser\xe3o consideradas operando juntas.","No system flows defined: all zones are assumed to run together.","Sin turnos definidos: se considera que todas las zonas funcionan juntas.")
B.uC=new A.a("Aspers\xe3o / microaspers\xe3o","Sprinkler / micro-sprinkler","Aspersi\xf3n / microaspersi\xf3n")
B.wd=new A.a("Gotejamento (fita/tubo)","Drip (tape/line)","Goteo (cinta/tuber\xeda)")
B.lb=new A.a("Laterais","Laterals","Laterales")
B.iH=new A.a("Espa\xe7amento entre emissores","Outlet spacing","Espaciamiento entre emisores")
B.ta=new A.a("Tubo da lateral","Lateral pipe","Tuber\xeda de la lateral")
B.iF=new A.a("Espa\xe7amento entre laterais","Lateral spacing","Espaciamiento entre laterales")
B.ko=new A.a("Dire\xe7\xe3o das laterais (\xb0)","Lateral direction (\xb0)","Direcci\xf3n de las laterales (\xb0)")
B.nS=new A.a("Submain e v\xe1lvula","Submain and valve","Submain y v\xe1lvula")
B.i7=new A.a("Posi\xe7\xe3o do submain","Submain position","Posici\xf3n del submain")
B.pL=new A.a("In\xedcio das laterais","Start of laterals","Inicio de las laterales")
B.qN=new A.a("Centro (laterais pareadas)","Centre (paired laterals)","Centro (laterales pareadas)")
B.qM=new A.a("Fim das laterais","End of laterals","Final de las laterales")
B.ek=new A.a("Tubo do submain","Submain pipe","Tuber\xeda del submain")
B.qc=new A.a("Posi\xe7\xe3o da v\xe1lvula","Valve position","Posici\xf3n de la v\xe1lvula")
B.bO=new A.a("In\xedcio","Start","Inicio")
B.ir=new A.a("Centro","Centre","Centro")
B.jE=new A.a("Fim","End","Final")
B.i_=new A.a("Trecho at\xe9 a v\xe1lvula (stub)","Stub to the valve","Tramo hasta la v\xe1lvula")
B.uK=new A.a("Espa\xe7amento (% do di\xe2metro molhado)","Spacing (% of wetted diameter)","Espaciamiento (% del di\xe1metro mojado)")
B.mm=new A.a("Dire\xe7\xe3o (\xb0)","Direction (\xb0)","Direcci\xf3n (\xb0)")
B.mS=new A.a("Quadrado","Square","Cuadrado")
B.o2=new A.a("Triangular","Triangular","Triangular")
B.q6=new A.a("Raio {r} m \u2192 espa\xe7amento {s} m; taxa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %","Radius {r} m \u2192 spacing {s} m; rate \u2248 {pr} mm/h; theoretical CU \u2248 {cu} %","Radio {r} m \u2192 espaciamiento {s} m; tasa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %")
B.mA=new A.a("Lateral com emissores","Lateral with outlets","Lateral con emisores")
B.ke=new A.a("Declividade (%; + desce)","Slope (%; + downhill)","Pendiente (%; + baja)")
B.hc=new A.a("Toler\xe2ncia abaixo (%)","Tolerance below (%)","Tolerancia por debajo (%)")
B.oe=new A.a("Toler\xe2ncia acima (%)","Tolerance above (%)","Tolerancia por encima (%)")
B.iJ=new A.a("Vaz\xe3o de entrada","Inlet flow","Caudal de entrada")
B.j2=new A.a("Perda de carga total","Total head loss","P\xe9rdida de carga total")
B.p2=new A.a("Press\xe3o no fim","End pressure","Presi\xf3n al final")
B.je=new A.a("Press\xe3o m\xedn / m\xe1x","Min / max pressure","Presi\xf3n m\xedn / m\xe1x")
B.rB=new A.a("Varia\xe7\xe3o de press\xe3o","Pressure variation","Variaci\xf3n de presi\xf3n")
B.rs=new A.a("Velocidade m\xe1x.","Max. velocity","Velocidad m\xe1x.")
B.mk=new A.a("CU / DU / EU / Us","CU / DU / EU / Us","CU / DU / EU / Us")
B.uJ=new A.a("qvar","qvar","qvar")
B.hh=new A.a("Comprimento m\xe1ximo (janela \xb1)","Maximum length (\xb1 window)","Longitud m\xe1xima (ventana \xb1)")
B.rL=new A.a("Altura est\xe1tica","Static head","Altura est\xe1tica")
B.k2=new A.a("Adutora","Delivery main","Conducci\xf3n")
B.hf=new A.a("Horas/ano","Hours/year","Horas/a\xf1o")
B.c2=new A.a("Ponto de opera\xe7\xe3o","Operating point","Punto de operaci\xf3n")
B.i5=new A.a("A bomba n\xe3o vence a altura est\xe1tica.","The pump cannot overcome the static head.","La bomba no supera la altura est\xe1tica.")
B.r9=new A.a("Altura manom\xe9trica","Total head","Altura manom\xe9trica")
B.kE=new A.a("Velocidade na adutora","Velocity in the main","Velocidad en la conducci\xf3n")
B.uF=new A.a("Pot\xeancia hidr\xe1ulica","Hydraulic power","Potencia hidr\xe1ulica")
B.rx=new A.a("Pot\xeancia no eixo (\u03b7 {e} %)","Shaft power (\u03b7 {e} %)","Potencia en el eje (\u03b7 {e} %)")
B.fJ=new A.a("Energia anual","Annual energy","Energ\xeda anual")
B.tU=new A.a("Shutoff / runout","Shutoff / runout","Shutoff / runout")
B.mO=new A.a("Velocidade (m/s)","Velocity (m/s)","Velocidad (m/s)")
B.ty=new A.a("Tempo de fechamento (s)","Closure time (s)","Tiempo de cierre (s)")
B.vu=new A.a("Press\xe3o est\xe1tica","Static pressure","Presi\xf3n est\xe1tica")
B.oa=new A.a("Resultado (Joukowsky)","Result (Joukowsky)","Resultado (Joukowsky)")
B.pP=new A.a("Celeridade","Wave celerity","Celeridad")
B.oT=new A.a("Sobrepress\xe3o m\xe1xima (fechamento instant\xe2neo)","Maximum surge (instantaneous closure)","Sobrepresi\xf3n m\xe1xima (cierre instant\xe1neo)")
B.l8=new A.a("Tempo cr\xedtico 2L/a","Critical time 2L/a","Tiempo cr\xedtico 2L/a")
B.ef=new A.a("Sobrepress\xe3o estimada (fechamento {s} s)","Estimated surge (closure {s} s)","Sobrepresi\xf3n estimada (cierre {s} s)")
B.p_=new A.a("Press\xe3o total","Total pressure","Presi\xf3n total")
B.jc=new A.a("Classe do tubo","Pipe class","Clase de la tuber\xeda")
B.bQ=new A.a("Fitas","Tapes","Cintas")
B.of=new A.a("Uso","Use","Uso")
B.iR=new A.a("DN","DN","DN")
B.oE=new A.a("DI mm","ID mm","DI mm")
B.ij=new A.a("C","C","C")
B.we=new A.a("PN (m)","PN (m)","PN (m)")
B.eF=new A.a("{c}/m","{c}/m","{c}/m")
B.ey=new A.a("k (L/h\xb7m^-x)","k (L/h\xb7m^-x)","k (L/h\xb7m^-x)")
B.wa=new A.a("x","x","x")
B.uz=new A.a("P padr\xe3o","Default P","P predeterminada")
B.ii=new A.a("CV","CV","CV")
B.re=new A.a("Tol \xb1%","Tol \xb1%","Tol \xb1%")
B.ps=new A.a("{c}","{c}","{c}")
B.uD=new A.a("Esp. m","Spacing m","Esp. m")
B.w8=new A.a("q nom L/h","q nom L/h","q nom L/h")
B.kY=new A.a("Kd","Kd","Kd")
B.ce=new A.a("Tipo","Type","Tipo")
B.iI=new A.a("K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)")
B.tW=new A.a("n","n","n")
B.fO=new A.a("Q m\xe1x m\xb3/h","Max Q m\xb3/h","Q m\xe1x m\xb3/h")
B.nJ=new A.a("Pontos (Q m\xb3/h @ H m)","Points (Q m\xb3/h @ H m)","Puntos (Q m\xb3/h @ H m)")
B.ma=new A.a("\u03b7","\u03b7","\u03b7")
B.nG=new A.a("Edite e pressione Enter em cada campo. Valores hidr\xe1ulicos internos em SI; vaz\xf5es em L/h ou m\xb3/h conforme indicado.","Edit and press Enter in each field. Internal hydraulic values are SI; flows in L/h or m\xb3/h as indicated.","Edite y pulse Intro en cada campo. Valores hidr\xe1ulicos internos en SI; caudales en L/h o m\xb3/h seg\xfan se indica.")
B.mn=new A.a("PVC","PVC","PVC")
B.mG=new A.a("PEAD/PE100","HDPE/PE100","PEAD/PE100")
B.mg=new A.a("PEBD","LDPE","PEBD")
B.qC=new A.a("A\xe7o","Steel","Acero")
B.el=new A.a("Ferro d\xfactil","Ductile iron","Fundici\xf3n d\xfactil")
B.hy=new A.a("Alum\xednio","Aluminium","Aluminio")
B.tH=new A.a("Concreto","Concrete","Hormig\xf3n")
B.ux=new A.a("C\xe1lculo n\xe3o convergiu","Calculation did not converge","El c\xe1lculo no convergi\xf3")
B.wq=new A.a("N\xe3o foi poss\xedvel atender a janela de press\xe3o com os tubos dispon\xedveis","Could not meet the pressure window with the available pipes","No se pudo cumplir la ventana de presi\xf3n con las tuber\xedas disponibles")
B.mb=new A.a("Linha principal n\xe3o consegue atender a press\xe3o das v\xe1lvulas","Mainline cannot meet the valve pressures","La l\xednea principal no puede cumplir la presi\xf3n de las v\xe1lvulas")
B.h4=new A.a("Nenhuma fonte de \xe1gua conectada","No water supply connected","Ninguna fuente de agua conectada")
B.pt=new A.a("Emissor acima da press\xe3o admiss\xedvel","Outlet above allowable pressure","Emisor por encima de la presi\xf3n admisible")
B.w5=new A.a("Emissor abaixo da press\xe3o admiss\xedvel","Outlet below allowable pressure","Emisor por debajo de la presi\xf3n admisible")
B.qb=new A.a("Press\xe3o acima da classe do tubo","Pressure above the pipe rating","Presi\xf3n por encima de la clase de la tuber\xeda")
B.uA=new A.a("Bomba fora da faixa de opera\xe7\xe3o","Pump outside its operating range","Bomba fuera del rango de operaci\xf3n")
B.tl=new A.a("Vaz\xe3o da fonte excedida","Supply flow exceeded","Caudal de la fuente excedido")
B.h5=new A.a("Press\xe3o m\xe1xima da fonte excedida","Supply maximum pressure exceeded","Presi\xf3n m\xe1xima de la fuente excedida")
B.jg=new A.a("Vaz\xe3o fora da faixa da v\xe1lvula","Flow outside the valve range","Caudal fuera del rango de la v\xe1lvula")
B.lz=new A.a("V\xe1lvula n\xe3o encontrada","Valve not found","V\xe1lvula no encontrada")
B.tM=new A.a("Press\xe3o insuficiente na v\xe1lvula","Insufficient pressure at the valve","Presi\xf3n insuficiente en la v\xe1lvula")
B.nH=new A.a("V\xe1lvula n\xe3o alcan\xe7ada pela linha principal","Valve not reached by the mainline","V\xe1lvula no alcanzada por la l\xednea principal")
B.pT=new A.a("Velocidade m\xe1xima excedida","Maximum velocity exceeded","Velocidad m\xe1xima excedida")
B.ry=new A.a("Zona sem tubos ou emissores","Zone without pipes or outlets","Zona sin tuber\xedas ni emisores")
B.r4=new A.a("Zonas conectadas entre si sem v\xe1lvula","Zones connected without a valve","Zonas conectadas entre s\xed sin v\xe1lvula")
B.fR=new A.a("V\xe1lvula sem tubos de zona","Valve without zone pipes","V\xe1lvula sin tuber\xedas de zona")
B.u0=new A.a("Emissor sem modelo no cat\xe1logo","Outlet without a catalog model","Emisor sin modelo en el cat\xe1logo")
B.kD=new A.a("Fita sem modelo no cat\xe1logo","Tape without a catalog model","Cinta sin modelo en el cat\xe1logo")
B.tw=new A.a("Bomba sem modelo no cat\xe1logo","Pump without a catalog model","Bomba sin modelo en el cat\xe1logo")
B.mJ=new A.a("Acess\xf3rio sem modelo no cat\xe1logo","Device without a catalog model","Accesorio sin modelo en el cat\xe1logo")
B.r7=new A.a("Rede sem fonte de carga fixa","Network without a fixed-head source","Red sin fuente de carga fija")
B.eT=new A.a("P\xe1gina de dados ausente no DWG","Missing data page in DWG","P\xe1gina de datos ausente en el DWG")
B.oy=new A.a("OpenCADIrrigation \u2014 CAD aberto para projeto de irriga\xe7\xe3o pressurizada.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lise de laterais passo a passo, dimensionamento por velocidade e por janela de press\xe3o com crit\xe9rio econ\xf4mico.\nProjeto aberto, roda no navegador.","OpenCADIrrigation \u2014 open CAD for pressurised irrigation design.\nHydraulic engine: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), step-by-step lateral analysis, velocity and pressure-window pipe sizing with economic trade-off.\nOpen project, runs in the browser.","OpenCADIrrigation \u2014 CAD abierto para el dise\xf1o de riego presurizado.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lisis de laterales paso a paso, dimensionamiento por velocidad y por ventana de presi\xf3n con criterio econ\xf3mico.\nProyecto abierto, funciona en el navegador.")
B.uR=new A.a("Arco (3 pontos)","Arc (3 points)","Arco (3 puntos)")
B.q1=new A.a("Spline (curva suave)","Spline (smooth curve)","Spline (curva suave)")
B.ka=new A.a("Hachura","Hatch","Sombreado")
B.c0=new A.a("S\xedmbolo","Symbol","S\xedmbolo")
B.kd=new A.a("Cota angular","Angular dimension","Cota angular")
B.wc=new A.a("Cota radial","Radial dimension","Cota radial")
B.eJ=new A.a("Chamada (leader)","Leader","Llamada (leader)")
B.ca=new A.a("Rotacionar","Rotate","Rotar")
B.qg=new A.a("Espelhar","Mirror","Simetr\xeda")
B.bN=new A.a("Escalar","Scale","Escalar")
B.oG=new A.a("Deslocar (offset)","Offset","Desfasar (offset)")
B.hP=new A.a("Aparar","Trim","Recortar")
B.jm=new A.a("Estender","Extend","Alargar")
B.wh=new A.a("Cortar tubo","Cut pipe","Cortar tuber\xeda")
B.ve=new A.a("Perfil de eleva\xe7\xe3o","Elevation profile","Perfil de elevaci\xf3n")
B.qG=new A.a("Clique no in\xedcio, em um ponto do arco e no fim","Click start, a point on the arc, then end","Clic en el inicio, un punto del arco y el final")
B.kN=new A.a("Clique nos pontos da curva; Enter termina","Click curve points; Enter ends","Clic en los puntos de la curva; Intro termina")
B.fi=new A.a("Clique nos v\xe9rtices da \xe1rea a hachurar; Enter fecha","Click the hatch boundary vertices; Enter closes","Clic en los v\xe9rtices del \xe1rea; Intro cierra")
B.nL=new A.a("Clique para inserir o s\xedmbolo (tipo e tamanho no painel)","Click to insert the symbol (kind and size in the panel)","Clic para insertar el s\xedmbolo (tipo y tama\xf1o en el panel)")
B.ej=new A.a("Clique no v\xe9rtice, nos dois lados e na posi\xe7\xe3o do arco","Click the vertex, both sides, then the arc position","Clic en el v\xe9rtice, los dos lados y la posici\xf3n del arco")
B.kn=new A.a("Clique no c\xedrculo (ou centro) e depois no ponto da cota","Click the circle (or centre) then the dimension point","Clic en el c\xedrculo (o centro) y luego en el punto de la cota")
B.eC=new A.a("Clique na ponta da seta e nos v\xe9rtices; Enter abre o texto","Click the arrow tip and the vertices; Enter opens the text","Clic en la punta de la flecha y los v\xe9rtices; Intro abre el texto")
B.vQ=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (Ctrl = copiar)","Selection: click base point, reference, then target (Ctrl = copy)","Selecci\xf3n: clic en el punto base, la referencia y el destino (Ctrl = copiar)")
B.kT=new A.a("Sele\xe7\xe3o: clique nos dois pontos da linha de espelho","Selection: click the two points of the mirror line","Selecci\xf3n: clic en los dos puntos del eje de simetr\xeda")
B.w0=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (fator = raz\xe3o)","Selection: click base point, reference, then target (factor = ratio)","Selecci\xf3n: clic en el punto base, la referencia y el destino (factor = raz\xf3n)")
B.vn=new A.a("Clique no objeto e depois no lado do deslocamento (dist\xe2ncia no painel)","Click the object then the offset side (distance in the panel)","Clic en el objeto y luego en el lado del desfase (distancia en el panel)")
B.tg=new A.a("Clique na parte a remover; a sele\xe7\xe3o define as arestas de corte","Click the part to remove; the selection defines the cutting edges","Clic en la parte a quitar; la selecci\xf3n define las aristas de corte")
B.ov=new A.a("Clique perto da extremidade a estender at\xe9 a pr\xf3xima aresta","Click near the end to extend to the next edge","Clic cerca del extremo a alargar hasta la siguiente arista")
B.la=new A.a("Clique no ponto do tubo/lateral onde cortar","Click the point of the pipe/lateral to cut","Clic en el punto de la tuber\xeda/lateral donde cortar")
B.nU=new A.a("Clique os pontos do caminho; Enter (ou Concluir) mostra o perfil na aba Perfil; Esc limpa a linha roxa","Click the path points; Enter (or Done) shows the profile in the Profile tab; Esc clears the purple line","Clic en los puntos del camino; Intro (o Terminar) muestra el perfil en la pesta\xf1a Perfil; Esc borra la l\xednea morada")
B.lC=new A.a("Modificar","Modify","Modificar")
B.uP=new A.a("Matriz (array)\u2026","Array\u2026","Matriz (array)\u2026")
B.wo=new A.a("Envelope do submain (laterais selecionadas)","Submain envelope (selected laterals)","Envolvente del submain (laterales seleccionadas)")
B.hX=new A.a("Matriz da sele\xe7\xe3o","Array of the selection","Matriz de la selecci\xf3n")
B.nQ=new A.a("Retangular","Rectangular","Rectangular")
B.mt=new A.a("Polar","Polar","Polar")
B.lg=new A.a("Linhas","Rows","Filas")
B.iv=new A.a("Colunas","Columns","Columnas")
B.ht=new A.a("Espa\xe7amento em X","Column spacing","Espaciamiento en X")
B.vD=new A.a("Espa\xe7amento em Y","Row spacing","Espaciamiento en Y")
B.q8=new A.a("\xc2ngulo da matriz (\xb0)","Array angle (\xb0)","\xc1ngulo de la matriz (\xb0)")
B.hp=new A.a("N\xfamero de itens","Number of items","N\xfamero de elementos")
B.ra=new A.a("Centro (X, Y)","Centre (X, Y)","Centro (X, Y)")
B.eU=new A.a("\xc2ngulo total (\xb0)","Total angle (\xb0)","\xc1ngulo total (\xb0)")
B.pA=new A.a("Rotacionar itens","Rotate items","Rotar elementos")
B.un=new A.a("{n} itens selecionados","{n} selected items","{n} elementos seleccionados")
B.pM=new A.a("A camada est\xe1 bloqueada","The layer is locked","La capa est\xe1 bloqueada")
B.en=new A.a("Nenhuma interse\xe7\xe3o encontrada","No intersection found","No se encontr\xf3 intersecci\xf3n")
B.vZ=new A.a("Selecione uma ou mais laterais (sprayline ou fita)","Select one or more laterals (sprayline or tape)","Seleccione una o m\xe1s laterales (sprayline o cinta)")
B.vA=new A.a("Envelope calculado para {n} laterais (verde = posi\xe7\xe3o admiss\xedvel)","Envelope computed for {n} laterals (green = allowable position)","Envolvente calculada para {n} laterales (verde = posici\xf3n admisible)")
B.qL=new A.a("{n} itens criados","{n} items created","{n} elementos creados")
B.n1=new A.a("Marcar press\xe3o m\xedn/m\xe1x por zona","Mark min/max pressure per zone","Marcar presi\xf3n m\xedn/m\xe1x por zona")
B.f_=new A.a("Mapa base","Base map","Mapa base")
B.lP=new A.a("Nenhum","None","Ninguno")
B.fK=new A.a("Ruas (OpenStreetMap)","Streets (OpenStreetMap)","Calles (OpenStreetMap)")
B.qq=new A.a("Sat\xe9lite (Esri World Imagery)","Satellite (Esri World Imagery)","Sat\xe9lite (Esri World Imagery)")
B.kk=new A.a("Defina a georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia) para mostrar o mapa base","Set the georeference (File \u2192 Georeference) to show the base map","Defina la georreferencia (Archivo \u2192 Georreferencia) para mostrar el mapa base")
B.nl=new A.a("Al\xe7as de edi\xe7\xe3o","Edit grips","Pinzamientos de edici\xf3n")
B.qm=new A.a("Envelope de posi\xe7\xe3o do submain","Allowable submain position","Posici\xf3n admisible del submain")
B.jn=new A.a("Camada atual","Current layer","Capa actual")
B.i6=new A.a("Bloquear","Lock","Bloquear")
B.tP=new A.a("Nova camada","New layer","Nueva capa")
B.na=new A.a("Renomear","Rename","Renombrar")
B.fg=new A.a("Excluir camada (itens v\xe3o para DRAWING)","Delete layer (items move to DRAWING)","Eliminar capa (los elementos van a DRAWING)")
B.iA=new A.a("Cor","Colour","Color")
B.hj=new A.a("Nome da camada","Layer name","Nombre de la capa")
B.uo=new A.a("J\xe1 existe uma camada com esse nome","A layer with that name already exists","Ya existe una capa con ese nombre")
B.kI=new A.a("Clique no olho para mostrar/ocultar, no cadeado para bloquear, na cor para alterar; duplo clique renomeia; o c\xedrculo marca a camada atual.","Click the eye to show/hide, the padlock to lock, the colour to change it; double-click renames; the dot marks the current layer.","Clic en el ojo para mostrar/ocultar, en el candado para bloquear, en el color para cambiarlo; doble clic renombra; el c\xedrculo marca la capa actual.")
B.iO=new A.a("Edi\xe7\xe3o em lote ({n} {type})","Batch edit ({n} {type})","Edici\xf3n en lote ({n} {type})")
B.qs=new A.a("(valores diferentes)","(mixed values)","(valores distintos)")
B.oJ=new A.a("Tamanho (m)","Size (m)","Tama\xf1o (m)")
B.hT=new A.a("\xc2ngulo da hachura (\xb0)","Hatch angle (\xb0)","\xc1ngulo del sombreado (\xb0)")
B.hl=new A.a("Espa\xe7amento da hachura (m)","Hatch spacing (m)","Espaciamiento del sombreado (m)")
B.kf=new A.a("Preenchimento s\xf3lido","Solid fill","Relleno s\xf3lido")
B.m3=new A.a("Opacidade","Opacity","Opacidad")
B.kG=new A.a("Largura (m)","Width (m)","Ancho (m)")
B.jz=new A.a("Altura (m)","Height (m)","Alto (m)")
B.hi=new A.a("Emissores por planta (0 = padr\xe3o do projeto)","Emitters per plant (0 = project default)","Emisores por planta (0 = valor del proyecto)")
B.kB=new A.a("Balan\xe7o h\xeddrico (ETo \xd7 Kc, solo)","Water balance (ETo \xd7 Kc, soil)","Balance h\xeddrico (ETo \xd7 Kc, suelo)")
B.iV=new A.a("ETo (mm/dia)","ETo (mm/day)","ETo (mm/d\xeda)")
B.kX=new A.a("Kc","Kc","Kc")
B.pk=new A.a("Kc por cultura (FAO-56)","Kc by crop (FAO-56)","Kc por cultivo (FAO-56)")
B.n4=new A.a("\xc1gua dispon\xedvel (mm/m)","Available water (mm/m)","Agua disponible (mm/m)")
B.rj=new A.a("Profundidade radicular (m)","Root depth (m)","Profundidad radicular (m)")
B.nz=new A.a("Fra\xe7\xe3o de esgotamento (MAD)","Allowed depletion (MAD)","Fracci\xf3n de agotamiento (MAD)")
B.oo=new A.a("Fra\xe7\xe3o molhada","Wetted fraction","Fracci\xf3n mojada")
B.m2=new A.a("Espa\xe7amento entre plantas (m)","Plant spacing (m)","Espaciamiento entre plantas (m)")
B.iW=new A.a("Espa\xe7amento entre linhas (m)","Row spacing (m)","Espaciamiento entre hileras (m)")
B.v3=new A.a("ETc (mm/dia)","ETc (mm/day)","ETc (mm/d\xeda)")
B.eh=new A.a("Intervalo (dias)","Interval (days)","Intervalo (d\xedas)")
B.rC=new A.a("Dist\xe2ncia do offset","Offset distance","Distancia del desfase")
B.u1=new A.a("Manter original (copiar)","Keep original (copy)","Mantener original (copiar)")
B.uY=new A.a("Manter original","Keep source","Mantener original")
B.uG=new A.a("Dividir tubo ao inserir sobre ele","Split pipe when inserted on it","Dividir tuber\xeda al insertar sobre ella")
B.tj=new A.a("Curva fechada","Closed curve","Curva cerrada")
B.oj=new A.a("\xc2ngulo (\xb0)","Angle (\xb0)","\xc1ngulo (\xb0)")
B.pR=new A.a("Texto da chamada","Leader text","Texto de la llamada")
B.fS=new A.a("Raio do arco de cota (m)","Dimension arc radius (m)","Radio del arco de cota (m)")
B.fj=new A.a("Camada bloqueada: edi\xe7\xe3o desativada","Locked layer: editing disabled","Capa bloqueada: edici\xf3n desactivada")
B.p5=new A.a("Vaz\xe3o de lavagem no fim (0 = autom\xe1tica)","End flushing flow (0 = automatic)","Caudal de lavado al final (0 = autom\xe1tico)")
B.vN=new A.a("Envelope do submain","Submain envelope","Envolvente del submain")
B.pS=new A.a("Melhor posi\xe7\xe3o: {f} % do in\xedcio (\u0394p {v})","Best position: {f} % from the start (\u0394p {v})","Mejor posici\xf3n: {f} % desde el inicio (\u0394p {v})")
B.j9=new A.a("Admiss\xedvel: {a} % a {b} %","Allowable: {a} % to {b} %","Admisible: {a} % a {b} %")
B.rS=new A.a("Nenhuma posi\xe7\xe3o atende \xe0 janela de press\xe3o","No position meets the pressure window","Ninguna posici\xf3n cumple la ventana de presi\xf3n")
B.mP=new A.a("Seta norte","North arrow","Flecha norte")
B.fW=new A.a("\xc1rvore","Tree","\xc1rbol")
B.o5=new A.a("Edifica\xe7\xe3o","Building","Edificaci\xf3n")
B.bT=new A.a("Reservat\xf3rio","Tank","Dep\xf3sito")
B.tb=new A.a("Caixa de v\xe1lvula","Valve box","Arqueta de v\xe1lvula")
B.uH=new A.a("Casa de bombas","Pump house","Caseta de bombeo")
B.qr=new A.a("Port\xe3o","Gate","Port\xf3n")
B.vs=new A.a("Esta\xe7\xe3o de filtragem","Filter station","Estaci\xf3n de filtrado")
B.cy=new A.a("Caf\xe9","Coffee","Caf\xe9")
B.bC=new A.a("Banana","Banana","Banano")
B.lt=new A.a("Manga","Mango","Mango")
B.rr=new A.a("Ma\xe7\xe3","Apple","Manzana")
B.cf=new A.a("Tomate","Tomato","Tomate")
B.bq=new A.a("Milho","Maize","Ma\xedz")
B.bB=new A.a("Cana-de-a\xe7\xfacar","Sugarcane","Ca\xf1a de az\xfacar")
B.bU=new A.a("Hortali\xe7as","Vegetables","Hortalizas")
B.bw=new A.a("Grama","Turf","C\xe9sped")
B.mp=new A.a("Pastagem","Pasture","Pasto")
B.ia=new A.a("Personalizado","Custom","Personalizado")
B.tR=new A.a("Lavagem (flushing)","Flushing","Lavado (flushing)")
B.p6=new A.a("Golpe de ar\xedete","Water hammer","Golpe de ariete")
B.uk=new A.a("Agronomia","Agronomy","Agronom\xeda")
B.wz=new A.a("Programa\xe7\xe3o","Schedule","Programaci\xf3n")
B.c4=new A.a("Perfil","Profile","Perfil")
B.ct=new A.a("C\xf3digo","Code","C\xf3digo")
B.rG=new A.a("V alvo (m/s)","Target V (m/s)","V objetivo (m/s)")
B.iq=new A.a("Celeridade","Celerity","Celeridad")
B.vv=new A.a("Sobrepress\xe3o","Surge","Sobrepresi\xf3n")
B.kU=new A.a("P m\xe1x regime","Max steady P","P m\xe1x r\xe9gimen")
B.lY=new A.a("P total","Total P","P total")
B.tY=new A.a("2L/a (s)","2L/a (s)","2L/a (s)")
B.hE=new A.a("AFD","RAW","ARA")
B.vz=new A.a("Intervalo (d)","Interval (d)","Intervalo (d)")
B.tx=new A.a("L\xedquida/evento","Net/event","Neta/evento")
B.qn=new A.a("Bruta/evento","Gross/event","Bruta/evento")
B.lJ=new A.a("Horas/evento","Hours/event","Horas/evento")
B.oN=new A.a("CU sobrep. %","Overlap CU %","CU solap. %")
B.ph=new A.a("Zonas","Zones","Zonas")
B.jD=new A.a("Fim","End","Fin")
B.tI=new A.a("Dist\xe2ncia","Distance","Distancia")
B.eA=new A.a("Use a ferramenta Perfil (PR) ou selecione um tubo/lateral para ver o perfil do terreno","Use the Profile tool (PR) or select a pipe/lateral to see the ground profile","Use la herramienta Perfil (PR) o seleccione una tuber\xeda/lateral para ver el perfil del terreno")
B.qZ=new A.a("Declividade m\xe9dia {s} %  \xb7  desn\xedvel {d} m  \xb7  comprimento {l}","Mean slope {s} %  \xb7  rise {d} m  \xb7  length {l}","Pendiente media {s} %  \xb7  desnivel {d} m  \xb7  longitud {l}")
B.lk=new A.a("Luva","Coupler","Manguito")
B.ug=new A.a("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0")
B.pj=new A.a("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0")
B.nx=new A.a("T\xea","Tee","Te")
B.iD=new A.a("Cruzeta","Cross","Cruz")
B.k5=new A.a("Redu\xe7\xe3o","Reducer","Reducci\xf3n")
B.uq=new A.a("Tamp\xe3o","End cap","Tap\xf3n")
B.hJ=new A.a("Adaptador","Adapter","Adaptador")
B.uQ=new A.a("Conector inicial de lateral","Lateral take-off","Conector inicial de lateral")
B.fz=new A.a("Final de linha","Line end","Final de l\xednea")
B.h2=new A.a("Haste / tubo de subida","Riser","Tubo de subida")
B.bs=new A.a("Conex\xf5es","Fittings","Conexiones")
B.iL=new A.a("Conectores de lateral","Lateral connectors","Conectores de lateral")
B.kJ=new A.a("Hastes e tubos de subida","Risers","Tubos de subida")
B.o_=new A.a("Tipo","Kind","Tipo")
B.tX=new A.a("DN 2","Size 2","DN 2")
B.jK=new A.a("Fornecedor","Supplier","Proveedor")
B.rk=new A.a("+ Adicionar","+ Add","+ A\xf1adir")
B.j3=new A.a("Duplicar","Duplicate","Duplicar")
B.w4=new A.a("Importar (JSON/CSV)\u2026","Import (JSON/CSV)\u2026","Importar (JSON/CSV)\u2026")
B.vg=new A.a("Exportar JSON","Export JSON","Exportar JSON")
B.i0=new A.a("Exportar CSV desta aba","Export CSV of this tab","Exportar CSV de esta pesta\xf1a")
B.eH=new A.a("Restaurar padr\xe3o","Restore default","Restaurar predeterminado")
B.qt=new A.a("Usar como padr\xe3o para novos projetos","Use as default for new projects","Usar como predeterminado en proyectos nuevos")
B.tD=new A.a("JSON no formato do cat\xe1logo (exportado daqui) ou CSV com cabe\xe7alho; colunas reconhecidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tubos); id, name, kind, sizeMm, size2Mm, cost (conex\xf5es); id, name, idMm, spacing, qLph, headM, x, cost (fitas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emissores).","JSON in the catalog format (exported from here) or CSV with a header; recognised columns: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (pipes); id, name, kind, sizeMm, size2Mm, cost (fittings); id, name, idMm, spacing, qLph, headM, x, cost (tapes); id, name, kind, sizeMm, k, n, maxQm3h, cost (valves); id, name, points (Q@H;\u2026), eff, cost (pumps); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (outlets).","JSON en el formato del cat\xe1logo (exportado desde aqu\xed) o CSV con encabezado; columnas reconocidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tuber\xedas); id, name, kind, sizeMm, size2Mm, cost (conexiones); id, name, idMm, spacing, qLph, headM, x, cost (cintas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emisores).")
B.wj=new A.a('Remover "{n}" do cat\xe1logo? Itens do projeto que o usam ficar\xe3o sem modelo.','Remove "{n}" from the catalog? Project items using it will lose their model.','\xbfQuitar "{n}" del cat\xe1logo? Los elementos del proyecto que lo usan quedar\xe1n sin modelo.')
B.pi=new A.a("em uso: {n}","in use: {n}","en uso: {n}")
B.hg=new A.a("Cat\xe1logo: {n} itens importados","Catalog: {n} items imported","Cat\xe1logo: {n} elementos importados")
B.qT=new A.a("Cat\xe1logo salvo como padr\xe3o para novos projetos","Catalog saved as default for new projects","Cat\xe1logo guardado como predeterminado para proyectos nuevos")
B.r0=new A.a("Cat\xe1logo padr\xe3o restaurado","Default catalog restored","Cat\xe1logo predeterminado restaurado")
B.nn=new A.a("LP sem solu\xe7\xe3o com os tubos habilitados (m\xe9todo guloso usado)","LP infeasible with the enabled pipes (greedy method used)","LP sin soluci\xf3n con las tuber\xedas habilitadas (se us\xf3 el m\xe9todo voraz)")
B.uh=new A.a("Conex\xe3o sem item no cat\xe1logo","Fitting without a catalog item","Conexi\xf3n sin elemento en el cat\xe1logo")
B.tq=new A.a("Golpe de ar\xedete acima da classe do tubo","Water hammer above the pipe class","Golpe de ariete por encima de la clase de la tuber\xeda")
B.u2=new A.a("Turno sem \xe1rea irrigada: dura\xe7\xe3o mantida","System flow without an irrigated area: duration kept","Turno sin \xe1rea regada: duraci\xf3n mantenida")
B.rK=new A.a("Programa\xe7\xe3o excede 24 h no dia","Schedule exceeds 24 h in a day","La programaci\xf3n supera 24 h en el d\xeda")
B.ob=new A.a("Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, imagens)\u2026","Import (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, images)\u2026","Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, im\xe1genes)\u2026")
B.rE=new A.a("Pontos: {n} cotas importadas{geo}","Points: {n} spot heights imported{geo}","Puntos: {n} cotas importadas{geo}")
B.ox=new A.a(u.h,"SHP: {r} records, {n} entities ({crs})",u.h)
B.rU=new A.a("Imagem {w}\xd7{h} px inserida na vista (ajuste com as al\xe7as ou Georreferenciar imagem)","Image {w}\xd7{h} px placed in the view (adjust with grips or Georeference image)","Imagen {w}\xd7{h} px insertada en la vista (ajuste con las pinzas o Georreferenciar imagen)")
B.tc=new A.a("Imagem georreferenciada {w}\xd7{h} px ({crs})","Georeferenced image {w}\xd7{h} px ({crs})","Imagen georreferenciada {w}\xd7{h} px ({crs})")
B.h_=new A.a("Arquivo de pontos vazio","Empty points file","Archivo de puntos vac\xedo")
B.qO=new A.a("N\xe3o foi poss\xedvel identificar as colunas X, Y (e Z)","Could not identify the X, Y (and Z) columns","No se pudieron identificar las columnas X, Y (y Z)")
B.n3=new A.a("Arquivo SHP inv\xe1lido","Invalid SHP file","Archivo SHP no v\xe1lido")
B.mK=new A.a("O ZIP n\xe3o cont\xe9m um arquivo .shp","The ZIP has no .shp file","El ZIP no contiene un archivo .shp")
B.pY=new A.a("O ZIP n\xe3o cont\xe9m imagem","The ZIP has no image","El ZIP no contiene imagen")
B.mH=new A.a("Imagem n\xe3o reconhecida","Image not recognised","Imagen no reconocida")
B.ni=new A.a("Georreferenciar imagem selecionada\u2026","Georeference selected image\u2026","Georreferenciar imagen seleccionada\u2026")
B.ui=new A.a("Georreferenciar imagem","Georeference image","Georreferenciar imagen")
B.uy=new A.a("Informe as coordenadas locais (m) do canto inferior esquerdo, o tamanho real e a rota\xe7\xe3o da imagem.","Enter the local coordinates (m) of the bottom-left corner, the real size and the rotation of the image.","Indique las coordenadas locales (m) de la esquina inferior izquierda, el tama\xf1o real y la rotaci\xf3n de la imagen.")
B.fE=new A.a("Manter propor\xe7\xe3o","Keep aspect ratio","Mantener proporci\xf3n")
B.fk=new A.a("M\xe9todo de dimensionamento","Sizing method","M\xe9todo de dimensionamiento")
B.oX=new A.a("Programa\xe7\xe3o linear (LP: custo de tubo + energia + topografia)","Linear programming (LP: pipe cost + energy + topography)","Programaci\xf3n lineal (LP: costo de tuber\xeda + energ\xeda + topograf\xeda)")
B.tJ=new A.a("Guloso (velocidade \u2192 janela de press\xe3o \u2192 economia)","Greedy (velocity \u2192 pressure window \u2192 economics)","Voraz (velocidad \u2192 ventana de presi\xf3n \u2192 econom\xeda)")
B.qv=new A.a("N\xba m\xe1x. de di\xe2metros por lateral","Max. sizes per lateral","N.\xba m\xe1x. de di\xe1metros por lateral")
B.kg=new A.a("N\xba m\xe1x. de di\xe2metros por tubo principal","Max. sizes per mainline pipe","N.\xba m\xe1x. de di\xe1metros por tuber\xeda principal")
B.qj=new A.a("Emissores por planta (EU)","Emitters per plant (EU)","Emisores por planta (EU)")
B.ie=new A.a("N\xf3s de emissores por lateral (m\xe1x.)","Emitter nodes per lateral (max.)","Nudos de emisores por lateral (m\xe1x.)")
B.r_=new A.a("Varia\xe7\xe3o m\xe1x. de press\xe3o na zona (%; 0 = s\xf3 toler\xe2ncia)","Max. zone pressure variation (%; 0 = tolerance only)","Variaci\xf3n m\xe1x. de presi\xf3n en la zona (%; 0 = solo tolerancia)")
B.fX=new A.a("Lavagem e golpe de ar\xedete","Flushing and water hammer","Lavado y golpe de ariete")
B.tN=new A.a("Velocidade de lavagem (m/s)","Flushing velocity (m/s)","Velocidad de lavado (m/s)")
B.l1=new A.a("Press\xe3o m\xedn. no fim da fita (m)","Min. pressure at the tape end (m)","Presi\xf3n m\xedn. al final de la cinta (m)")
B.vq=new A.a("Verificar golpe de ar\xedete (classe do tubo)","Check water hammer (pipe class)","Verificar golpe de ariete (clase de tuber\xeda)")
B.ff=new A.a("Tempo de fechamento de v\xe1lvula (s; 0 = instant\xe2neo)","Valve closure time (s; 0 = instantaneous)","Tiempo de cierre de v\xe1lvula (s; 0 = instant\xe1neo)")
B.ho=new A.a("Selecionar conex\xf5es automaticamente","Select fittings automatically","Seleccionar conexiones autom\xe1ticamente")
B.lU=new A.a("Comprimento da barra de tubo (m; luvas por barra, 0 = nenhuma)","Pipe stick length (m; couplers per stick, 0 = none)","Longitud de la barra de tuber\xeda (m; manguitos por barra, 0 = ninguno)")
B.pZ=new A.a("Selecionar bomba\u2026","Select pump\u2026","Seleccionar bomba\u2026")
B.hw=new A.a("Vista 3D do terreno\u2026","3D terrain view\u2026","Vista 3D del terreno\u2026")
B.o4=new A.a("Sele\xe7\xe3o autom\xe1tica de bomba","Automatic pump selection","Selecci\xf3n autom\xe1tica de bomba")
B.jZ=new A.a("Ponto de trabalho: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}","Duty: {q} at {h}  \xb7  static lift \u2248 {s}","Punto de trabajo: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}")
B.fB=new A.a("Bombas do cat\xe1logo ordenadas por adequa\xe7\xe3o e custo (compra + 5 anos de energia)","Catalog pumps ranked by suitability and cost (purchase + 5 years of energy)","Bombas del cat\xe1logo ordenadas por idoneidad y costo (compra + 5 a\xf1os de energ\xeda)")
B.oB=new A.a("H na vaz\xe3o","H at duty","H al caudal")
B.lu=new A.a("Margem","Margin","Margen")
B.px=new A.a("Pot\xeancia","Power","Potencia")
B.i3=new A.a("Em paralelo","In parallel","En paralelo")
B.pr=new A.a("Inserir na fonte","Insert at the supply","Insertar en la fuente")
B.vi=new A.a("Aplicar \xe0 bomba existente","Apply to the existing pump","Aplicar a la bomba existente")
B.nX=new A.a("Execute o projeto com uma fonte de \xe1gua de press\xe3o calculada para obter o ponto de trabalho.","Run the design with a calculated-pressure water supply to get the duty point.","Ejecute el dise\xf1o con una fuente de agua de presi\xf3n calculada para obtener el punto de trabajo.")
B.fd=new A.a("insuficiente","insufficient","insuficiente")
B.eq=new A.a("Bomba {n} aplicada; execute o projeto novamente","Pump {n} applied; run the design again","Bomba {n} aplicada; vuelva a ejecutar el dise\xf1o")
B.qB=new A.a("Vista 3D do terreno (DEM)","3D terrain view (DEM)","Vista 3D del terreno (MDT)")
B.nw=new A.a("Exagero vertical","Vertical exaggeration","Exageraci\xf3n vertical")
B.nr=new A.a("Arraste para girar; roda do mouse para aproximar. Tubos e laterais s\xe3o drapejados sobre o terreno.","Drag to rotate; mouse wheel zooms. Pipes and laterals are draped on the terrain.","Arrastre para girar; rueda del rat\xf3n para acercar. Las tuber\xedas y laterales se drapean sobre el terreno.")
B.kz=new A.a("Sem dados de eleva\xe7\xe3o: desenhe curvas de n\xedvel ou cotas, ou importe topografia.","No elevation data: draw contours or spot heights, or import a survey.","Sin datos de elevaci\xf3n: dibuje curvas de nivel o cotas, o importe topograf\xeda.")
B.q3=new A.a("Eleva\xe7\xe3o {a} a {b} m","Elevation {a} to {b} m","Elevaci\xf3n {a} a {b} m")
B.hF=new A.a("Projetos recentes","Recent projects","Proyectos recientes")
B.um=new A.a("(nenhum)","(none)","(ninguno)")
B.qQ=new A.a("Hist\xf3rico de vers\xf5es\u2026","Version history\u2026","Historial de versiones\u2026")
B.nA=new A.a("Salvar automaticamente no navegador","Autosave in the browser","Guardar autom\xe1ticamente en el navegador")
B.kA=new A.a("Recuperar projeto","Recover project","Recuperar proyecto")
B.qJ=new A.a("Foram encontrados projetos salvos automaticamente que n\xe3o foram salvos em arquivo. Deseja recuper\xe1-los?","Autosaved projects that were never saved to a file were found. Recover them?","Se encontraron proyectos guardados autom\xe1ticamente que no se guardaron en archivo. \xbfDesea recuperarlos?")
B.n7=new A.a("Recuperar","Recover","Recuperar")
B.iX=new A.a("Descartar","Discard","Descartar")
B.kF=new A.a("Depois","Later","Despu\xe9s")
B.mQ=new A.a("{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)")
B.vf=new A.a("{n} projetos recuperados","{n} projects recovered","{n} proyectos recuperados")
B.ub=new A.a('Vers\xf5es de "{name}"','Versions of "{name}"','Versiones de "{name}"')
B.uX=new A.a("Nenhuma vers\xe3o guardada ainda: cada Salvar cria uma vers\xe3o (at\xe9 10, no navegador).","No versions kept yet: every Save records a version (up to 10, in the browser).","A\xfan no hay versiones: cada Guardar crea una versi\xf3n (hasta 10, en el navegador).")
B.nb=new A.a("Restaurar","Restore","Restaurar")
B.rg=new A.a("v{v} \u2014 {when}","v{v} \u2014 {when}","v{v} \u2014 {when}")
B.lW=new A.a("Vers\xe3o {v} restaurada","Version {v} restored","Versi\xf3n {v} restaurada")
B.tF=new A.a("Turnos","System flows","Turnos")
B.u3=new A.a("Programa\xe7\xe3o do controlador","Controller programme","Programaci\xf3n del controlador")
B.mY=new A.a("Aplicar dura\xe7\xf5es calculadas aos turnos","Apply computed durations to the flows","Aplicar duraciones calculadas a los turnos")
B.u9=new A.a("Exportar programa\xe7\xe3o (CSV)","Export programme (CSV)","Exportar programaci\xf3n (CSV)")
B.rb=new A.a("Dias","Days","D\xedas")
B.vV=new A.a("In\xedcio do dia (h)","Day start (h)","Inicio del d\xeda (h)")
B.lB=new A.a("Usar os hor\xe1rios de in\xedcio dos turnos","Use the flows' own start hours","Usar las horas de inicio de los turnos")
B.vL=new A.a("M\xe1ximo de horas em um dia: {h}","Maximum hours in one day: {h}","M\xe1ximo de horas en un d\xeda: {h}")
B.fv=new A.a("Execute o projeto para calcular as dura\xe7\xf5es a partir das \xe1reas irrigadas.","Run the design to compute durations from the irrigated areas.","Ejecute el dise\xf1o para calcular las duraciones a partir de las \xe1reas regadas.")
B.wn=new A.a("{name}: {h} h por evento","{name}: {h} h per event","{name}: {h} h por evento")
B.t5=new A.a("Edi\xe7\xe3o (alias \u23ce)","Editing (alias \u23ce)","Edici\xf3n (alias \u23ce)")
B.em=new A.a("Remover v\xe9rtice (Ctrl + clique na al\xe7a)","Remove vertex (Ctrl + click on a grip)","Quitar v\xe9rtice (Ctrl + clic en la pinza)")
B.uL=new A.a("Inserir v\xe9rtice (arrastar a al\xe7a do meio do segmento)","Insert vertex (drag the segment midpoint grip)","Insertar v\xe9rtice (arrastrar la pinza del medio del segmento)")
B.pg=new A.a("Toque: pin\xe7a para zoom, dois dedos para mover, um dedo para desenhar","Touch: pinch to zoom, two fingers to pan, one finger to draw","T\xe1ctil: pellizco para zoom, dos dedos para mover, un dedo para dibujar")
B.wE=new A.a("Piv\xf4 central / lateral m\xf3vel","Centre pivot / linear move","Pivote central / lateral de avance")
B.f9=new A.a("Clique o ponto do piv\xf4 (entrada de \xe1gua, sobre a linha principal) e depois o fim da lateral; Esc cancela","Click the pivot point (water inlet, on the mainline) and then the end of the span; Esc cancels","Clic en el punto del pivote (entrada de agua, sobre la l\xednea principal) y luego el fin de la lateral; Esc cancela")
B.iN=new A.a("Alinhar por 2 pontos","Align by 2 points","Alinear por 2 puntos")
B.kO=new A.a("Com a imagem/objetos selecionados: clique o ponto A na origem, onde A deve ficar, o ponto B na origem e onde B deve ficar","With the image/objects selected: click point A on the source, where A must go, point B on the source and where B must go","Con la imagen/objetos seleccionados: clic en el punto A de origen, d\xf3nde debe quedar A, el punto B de origen y d\xf3nde debe quedar B")
B.rQ=new A.a("Ponto A na imagem/desenho a alinhar","Point A on the image/drawing to align","Punto A en la imagen/dibujo a alinear")
B.hv=new A.a("Onde o ponto A deve ficar (destino)","Where point A must go (target)","D\xf3nde debe quedar el punto A (destino)")
B.vw=new A.a("Ponto B na imagem/desenho a alinhar","Point B on the image/drawing to align","Punto B en la imagen/dibujo a alinear")
B.wF=new A.a("Onde o ponto B deve ficar (define escala e rota\xe7\xe3o)","Where point B must go (sets scale and rotation)","D\xf3nde debe quedar el punto B (define escala y rotaci\xf3n)")
B.fn=new A.a("Manter a escala (s\xf3 mover e girar)","Keep the scale (move and rotate only)","Mantener la escala (solo mover y girar)")
B.l6=new A.a("Alinhado: escala \xd7{s}, rota\xe7\xe3o {r}\xb0","Aligned: scale \xd7{s}, rotation {r}\xb0","Alineado: escala \xd7{s}, rotaci\xf3n {r}\xb0")
B.uT=new A.a("Selecione antes a imagem ou os objetos a alinhar","Select the image or the objects to align first","Seleccione antes la imagen o los objetos a alinear")
B.eV=new A.a("Caminho do perfil removido do desenho","Profile path removed from the drawing","Camino del perfil quitado del dibujo")
B.bW=new A.a("Eleva\xe7\xe3o","Elevation","Elevaci\xf3n")
B.ft=new A.a("Eleva\xe7\xe3o da curva de n\xedvel","Contour elevation","Elevaci\xf3n de la curva de nivel")
B.fV=new A.a("Eleva\xe7\xe3o da cota","Spot height elevation","Elevaci\xf3n de la cota")
B.c1=new A.a("Intervalo entre curvas (m)","Contour interval (m)","Intervalo entre curvas (m)")
B.tG=new A.a("Pr\xf3xima curva: somar o intervalo","Next contour: add the interval","Pr\xf3xima curva: sumar el intervalo")
B.jP=new A.a("Perguntar a eleva\xe7\xe3o ao terminar cada curva/cota","Ask for the elevation after each contour/spot","Preguntar la elevaci\xf3n al terminar cada curva/cota")
B.lQ=new A.a('Uma curva de n\xedvel liga pontos de mesma altitude. Informe a altitude desta curva. Com "somar o intervalo", a pr\xf3xima curva j\xe1 vem com a eleva\xe7\xe3o seguinte.','A contour joins points of the same altitude. Enter the altitude of this line. With "add the interval", the next contour comes with the following elevation.','Una curva de nivel une puntos de la misma altitud. Indique la altitud de esta curva. Con "sumar el intervalo", la pr\xf3xima curva ya viene con la elevaci\xf3n siguiente.')
B.lR=new A.a("Cota de ponto: altitude do terreno neste lugar (po\xe7o, casa de bombas, canto do talh\xe3o).","Spot height: ground altitude at this place (well, pump house, field corner).","Cota de punto: altitud del terreno en este lugar (pozo, casa de bombas, esquina de la parcela).")
B.cd=new A.a("Terreno","Terrain","Terreno")
B.qK=new A.a("Baixar eleva\xe7\xe3o da internet (MDT)\u2026","Download elevation from the internet (DEM)\u2026","Descargar elevaci\xf3n de internet (MDT)\u2026")
B.p9=new A.a("Gerar curvas de n\xedvel do modelo\u2026","Generate contours from the model\u2026","Generar curvas de nivel del modelo\u2026")
B.nv=new A.a("Interpola\xe7\xe3o do terreno","Terrain interpolation","Interpolaci\xf3n del terreno")
B.uv=new A.a("Triangula\xe7\xe3o (TIN / MDT)","Triangulation (TIN / DTM)","Triangulaci\xf3n (TIN / MDT)")
B.w6=new A.a("Inverso da dist\xe2ncia (IDW)","Inverse distance (IDW)","Inverso de la distancia (IDW)")
B.ee=new A.a("Limpar perfil do desenho","Clear profile from the drawing","Limpiar perfil del dibujo")
B.wu=new A.a("Modelo do terreno: {n} pontos, eleva\xe7\xe3o {a} a {b} m","Terrain model: {n} points, elevation {a} to {b} m","Modelo del terreno: {n} puntos, elevaci\xf3n {a} a {b} m")
B.f5=new A.a("Sem dados de eleva\xe7\xe3o","No elevation data","Sin datos de elevaci\xf3n")
B.lf=new A.a("Interpola\xe7\xe3o do terreno (MDT)","Terrain interpolation (DTM)","Interpolaci\xf3n del terreno (MDT)")
B.ng=new A.a("Eleva\xe7\xe3o da internet (MDT online)","Elevation from the internet (online DEM)","Elevaci\xf3n de internet (MDT en l\xednea)")
B.lA=new A.a("Baixa a altitude de uma grade de pontos sobre o projeto a partir de um modelo digital de eleva\xe7\xe3o p\xfablico e cria cotas de ponto. Precisa de georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia). Resolu\xe7\xe3o de 30\u201390 m: bom para o relevo geral, n\xe3o substitui um levantamento.","Downloads the altitude of a grid of points over the project from a public digital elevation model and creates spot heights. Needs a georeference (File \u2192 Georeference). 30\u201390 m resolution: good for the general relief, not a replacement for a survey.","Descarga la altitud de una malla de puntos sobre el proyecto desde un modelo digital de elevaci\xf3n p\xfablico y crea cotas de punto. Necesita georreferencia (Archivo \u2192 Georreferencia). Resoluci\xf3n de 30\u201390 m: buena para el relieve general, no sustituye un levantamiento.")
B.jJ=new A.a("Fonte","Source","Fuente")
B.hs=new A.a("Espa\xe7amento da grade (m)","Grid spacing (m)","Espaciado de la malla (m)")
B.eP=new A.a("\xc1rea {w} \xd7 {h} m \u2192 {n} pontos em {r} requisi\xe7\xf5es","Area {w} \xd7 {h} m \u2192 {n} points in {r} requests","\xc1rea {w} \xd7 {h} m \u2192 {n} puntos en {r} solicitudes")
B.qk=new A.a("Substituir cotas baixadas anteriormente","Replace previously downloaded spot heights","Reemplazar cotas descargadas antes")
B.mL=new A.a("Usar a \xe1rea vis\xedvel em vez dos limites do projeto","Use the visible area instead of the project extent","Usar el \xe1rea visible en lugar de los l\xedmites del proyecto")
B.i2=new A.a("Baixar","Download","Descargar")
B.oW=new A.a("Baixando {i} de {n}\u2026","Downloading {i} of {n}\u2026","Descargando {i} de {n}\u2026")
B.vU=new A.a("{n} cotas importadas ({s})","{n} spot heights imported ({s})","{n} cotas importadas ({s})")
B.fq=new A.a("Defina antes a georrefer\xeancia do projeto (Arquivo \u2192 Georrefer\xeancia): latitude/longitude de um ponto do desenho.","Set the project georeference first (File \u2192 Georeference): latitude/longitude of a drawing point.","Defina antes la georreferencia del proyecto (Archivo \u2192 Georreferencia): latitud/longitud de un punto del dibujo.")
B.h8=new A.a("Falha ao baixar eleva\xe7\xf5es: {e}","Failed to download elevations: {e}","Error al descargar elevaciones: {e}")
B.hq=new A.a("Desenhe algo (ou use a \xe1rea vis\xedvel) para definir a regi\xe3o.","Draw something (or use the visible area) to define the region.","Dibuje algo (o use el \xe1rea visible) para definir la regi\xf3n.")
B.by=new A.a("Gerar curvas de n\xedvel","Generate contours","Generar curvas de nivel")
B.j8=new A.a("Cria curvas de n\xedvel a partir do modelo digital do terreno (triangula\xe7\xe3o das cotas e curvas existentes). \xdatil depois de importar pontos ou baixar eleva\xe7\xe3o da internet. As curvas geradas s\xe3o s\xf3 desenho: n\xe3o alteram o modelo.","Creates contours from the digital terrain model (triangulation of the existing spot heights and contours). Useful after importing points or downloading elevation. Generated contours are drawing only: they do not change the model.","Crea curvas de nivel a partir del modelo digital del terreno (triangulaci\xf3n de las cotas y curvas existentes). \xdatil despu\xe9s de importar puntos o descargar elevaci\xf3n. Las curvas generadas son solo dibujo: no cambian el modelo.")
B.wv=new A.a("Intervalo (m)","Interval (m)","Intervalo (m)")
B.lw=new A.a("Remover curvas geradas anteriormente","Remove previously generated contours","Quitar curvas generadas antes")
B.mB=new A.a("{n} curvas entre {a} e {b} m","{n} contours between {a} and {b} m","{n} curvas entre {a} y {b} m")
B.fY=new A.a("{n} curvas de n\xedvel geradas","{n} contours generated","{n} curvas de nivel generadas")
B.jY=new A.a("Gerar","Generate","Generar")
B.nZ=new A.a("Terreno","Ground","Terreno")
B.vT=new A.a("Tubo (com profundidade)","Pipe (with depth)","Tuber\xeda (con profundidad)")
B.u8=new A.a("Linha piezom\xe9trica (press\xe3o + cota)","Hydraulic grade line (pressure + elevation)","L\xednea piezom\xe9trica (presi\xf3n + cota)")
B.mF=new A.a("Ponto mais baixo","Lowest point","Punto m\xe1s bajo")
B.v0=new A.a("Ponto mais alto","Highest point","Punto m\xe1s alto")
B.tV=new A.a("Como usar: Perfil (PR) \u2192 clique os pontos do caminho \u2192 Enter (ou Concluir). Ou selecione um tubo/lateral. A linha roxa no desenho \xe9 o caminho: Limpar (ou Esc com a ferramenta Perfil) a remove.","How to use: Profile (PR) \u2192 click the path points \u2192 Enter (or Done). Or select a pipe/lateral. The purple line on the drawing is the path: Clear (or Esc with the Profile tool) removes it.","C\xf3mo usar: Perfil (PR) \u2192 clic en los puntos del camino \u2192 Intro (o Terminar). O seleccione una tuber\xeda/lateral. La l\xednea morada en el dibujo es el camino: Limpiar (o Esc con la herramienta Perfil) la quita.")
B.jd=new A.a("Sem dados de eleva\xe7\xe3o: o perfil sai plano. Desenhe curvas de n\xedvel (CT) ou cotas (SP), importe topografia ou baixe eleva\xe7\xe3o da internet (Projeto \u2192 Terreno).","No elevation data: the profile is flat. Draw contours (CT) or spot heights (SP), import a survey or download elevation from the internet (Design \u2192 Terrain).","Sin datos de elevaci\xf3n: el perfil sale plano. Dibuje curvas de nivel (CT) o cotas (SP), importe topograf\xeda o descargue elevaci\xf3n de internet (Dise\xf1o \u2192 Terreno).")
B.pN=new A.a("Esta\xe7\xe3o","Station","Estaci\xf3n")
B.qx=new A.a("Piv\xf4s","Pivots","Pivotes")
B.j1=new A.a("Piv\xf4","Pivot","Pivote")
B.cg=new A.a("Torres","Towers","Torres")
B.vm=new A.a("P dispon\xedvel","P available","P disponible")
B.jb=new A.a("Desn\xedvel","Rise","Desnivel")
B.iQ=new A.a("L\xe2mina/ciclo","Depth/cycle","L\xe1mina/ciclo")
B.vE=new A.a("Horas/ciclo","Hours/cycle","Horas/ciclo")
B.lG=new A.a("Taxa aplic. pico","Peak app. rate","Tasa aplic. pico")
B.ay=new A.a("Piv\xf4 central","Centre pivot","Pivote central")
B.ns=new A.a("Lateral m\xf3vel (linear)","Linear move","Lateral de avance (linear)")
B.vo=new A.a("torres","towers","torres")
B.oD=new A.a("Piv\xf4s e laterais m\xf3veis","Pivots and linear moves","Pivotes y laterales de avance")
B.nW=new A.a("Press\xe3o insuficiente na entrada do piv\xf4","Not enough pressure at the pivot inlet","Presi\xf3n insuficiente en la entrada del pivote")
B.mz=new A.a("Taxa de aplica\xe7\xe3o na ponta acima do limite do solo","Application rate at the end above the soil limit","Tasa de aplicaci\xf3n en la punta por encima del l\xedmite del suelo")
B.tk=new A.a("Piv\xf4 sem vaz\xe3o (l\xe2mina ou horas por ciclo zeradas)","Pivot without flow (depth or hours per cycle are zero)","Pivote sin caudal (l\xe1mina u horas por ciclo en cero)")
B.fD=new A.a("Piv\xf4 sem press\xe3o de ponta definida","Pivot without an end pressure","Pivote sin presi\xf3n de punta definida")
B.jU=new A.a("Tipo de m\xe1quina","Machine type","Tipo de m\xe1quina")
B.iM=new A.a("Comprimento da lateral (m)","Span pipe length (m)","Longitud de la lateral (m)")
B.kj=new A.a("V\xe3o entre torres (m)","Span between towers (m)","Vano entre torres (m)")
B.jt=new A.a("Percurso da lateral m\xf3vel (m)","Linear travel length (m)","Recorrido de la lateral (m)")
B.uw=new A.a("Tubo dos v\xe3os (cat\xe1logo)","Span pipe (catalogue)","Tubo de los vanos (cat\xe1logo)")
B.oF=new A.a("Di\xe2metro interno do tubo (mm)","Pipe inner diameter (mm)","Di\xe1metro interior del tubo (mm)")
B.kC=new A.a("C de Hazen-Williams","Hazen-Williams C","C de Hazen-Williams")
B.wl=new A.a("Altura do tubo (m)","Pipe height (m)","Altura del tubo (m)")
B.hx=new A.a("Press\xe3o na ponta","End pressure","Presi\xf3n en la punta")
B.ky=new A.a("Vaz\xe3o do canh\xe3o final","End gun flow","Caudal del ca\xf1\xf3n final")
B.m9=new A.a("Press\xe3o do canh\xe3o final","End gun pressure","Presi\xf3n del ca\xf1\xf3n final")
B.oP=new A.a("Alcance al\xe9m da ponta (m)","Throw beyond the end (m)","Alcance m\xe1s all\xe1 de la punta (m)")
B.mN=new A.a("L\xe2mina bruta por ciclo (mm)","Gross depth per cycle (mm)","L\xe1mina bruta por ciclo (mm)")
B.vB=new A.a("Horas por ciclo (volta/passada)","Hours per cycle (revolution/pass)","Horas por ciclo (vuelta/pasada)")
B.pG=new A.a("Largura molhada na ponta (m)","Wetted width at the end (m)","Ancho mojado en la punta (m)")
B.kM=new A.a("Perdas da m\xe1quina (m)","Machine losses (m)","P\xe9rdidas de la m\xe1quina (m)")
B.iG=new A.a("Taxa m\xe1x. do solo (mm/h; 0 = n\xe3o verificar)","Soil max. rate (mm/h; 0 = no check)","Tasa m\xe1x. del suelo (mm/h; 0 = no verificar)")
B.eW=new A.a("Setor irrigado (\xb0)","Irrigated sector (\xb0)","Sector regado (\xb0)")
B.pn=new A.a("Custo da m\xe1quina","Machine cost","Costo de la m\xe1quina")
B.nu=new A.a("\xc2ngulo de desenho (\xb0)","Drawing angle (\xb0)","\xc1ngulo de dibujo (\xb0)")
B.nc=new A.a("Resultado","Result","Resultado")
B.ig=new A.a("Press\xe3o necess\xe1ria na entrada","Required inlet pressure","Presi\xf3n necesaria en la entrada")
B.rv=new A.a("Gerada do modelo (n\xe3o entra no MDT)","Generated from the model (not used by the DTM)","Generada del modelo (no entra al MDT)")
B.hm=new A.a("Verifica\xe7\xe3o do projeto (Design Check)","Design check","Verificaci\xf3n del dise\xf1o (Design Check)")
B.eD=new A.a("Varre o desenho procurando erros que impedem ou distorcem o c\xe1lculo hidr\xe1ulico: itens desconectados, tubos que se cruzam sem jun\xe7\xe3o, pontas soltas, zonas sem emissores, duplicados e dados de cat\xe1logo faltando. Clique num item para localiz\xe1-lo.","Sweeps the drawing for errors that stop or distort the hydraulic calculation: disconnected items, pipes crossing without a junction, dead ends, zones without emitters, duplicates and missing catalogue data. Click an item to locate it.","Recorre el dibujo buscando errores que impiden o distorsionan el c\xe1lculo hidr\xe1ulico: elementos desconectados, tuber\xedas que se cruzan sin nudo, extremos sueltos, zonas sin emisores, duplicados y datos de cat\xe1logo faltantes. Haga clic en un \xedtem para ubicarlo.")
B.tr=new A.a("{e} erro(s), {w} aviso(s), {i} nota(s)","{e} error(s), {w} warning(s), {i} note(s)","{e} error(es), {w} aviso(s), {i} nota(s)")
B.pd=new A.a("Nenhum erro encontrado: o projeto est\xe1 pronto para o c\xe1lculo (F5).","No errors found: the design is ready to run (F5).","No se encontraron errores: el dise\xf1o est\xe1 listo para calcular (F5).")
B.rN=new A.a("Verificar novamente","Run again","Verificar de nuevo")
B.jj=new A.a("Erro","Error","Error")
B.hV=new A.a("Aviso","Warning","Aviso")
B.lS=new A.a("Nota","Note","Nota")
B.jQ=new A.a("Nenhum item hidr\xe1ulico no desenho","No hydraulic items in the drawing","Ning\xfan elemento hidr\xe1ulico en el dibujo")
B.kW=new A.a("Falta a fonte de \xe1gua (WS)","Water supply missing (WS)","Falta la fuente de agua (WS)")
B.mV=new A.a("H\xe1 laterais/emissores mas nenhuma v\xe1lvula de controle (V)","There are laterals/outlets but no control valve (V)","Hay laterales/emisores pero ninguna v\xe1lvula de control (V)")
B.qw=new A.a("Item desconectado da rede","Item not connected to the network","Elemento desconectado de la red")
B.lO=new A.a("Zona sem emissores","Zone without emitters","Zona sin emisores")
B.qW=new A.a("V\xe1lvulas com o mesmo nome de zona","Valves with the same zone name","V\xe1lvulas con el mismo nombre de zona")
B.f1=new A.a("Ponta solta na linha principal (tubo sem sa\xedda)","Dead end on the mainline (pipe with no outlet)","Extremo suelto en la l\xednea principal (tuber\xeda sin salida)")
B.kv=new A.a("Tubo de zona terminando sem lateral","Zone pipe ending without a lateral","Tuber\xeda de zona que termina sin lateral")
B.jW=new A.a("Tubo de comprimento zero","Zero-length pipe","Tuber\xeda de longitud cero")
B.fN=new A.a("Segmento menor que a toler\xe2ncia de conex\xe3o","Segment shorter than the connection tolerance","Segmento menor que la tolerancia de conexi\xf3n")
B.u4=new A.a("Itens duplicados na mesma posi\xe7\xe3o","Duplicated items at the same position","Elementos duplicados en la misma posici\xf3n")
B.fx=new A.a("Tubos se cruzam sem jun\xe7\xe3o (n\xe3o est\xe3o conectados)","Pipes cross without a junction (not connected)","Tuber\xedas se cruzan sin nudo (no est\xe1n conectadas)")
B.m4=new A.a("Modelo do cat\xe1logo n\xe3o encontrado","Catalogue model not found","Modelo del cat\xe1logo no encontrado")
B.wm=new A.a("Fonte com press\xe3o fixa igual a zero","Supply with a fixed pressure of zero","Fuente con presi\xf3n fija igual a cero")
B.pQ=new A.a("Piv\xf4 fora da linha principal","Pivot not on the mainline","Pivote fuera de la l\xednea principal")
B.rt=new A.a("Sem dados de eleva\xe7\xe3o: o terreno \xe9 considerado plano","No elevation data: the ground is taken as flat","Sin datos de elevaci\xf3n: el terreno se considera plano")
B.fG=new A.a("Linha principal em anel (rede malhada) \u2014 resolvida pelo solver","Looped mainline (meshed network) \u2014 solved by the solver","L\xednea principal en anillo (red mallada) \u2014 resuelta por el solver")
B.qd=new A.a("\xc1rea sem emissores dentro","Area with no emitters inside","\xc1rea sin emisores dentro")
B.kS=new A.a("Verifica\xe7\xe3o do projeto\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o\u2026")
B.kq=new A.a("Cat\xe1logos de fabricantes\u2026","Manufacturer catalogues\u2026","Cat\xe1logos de fabricantes\u2026")
B.n_=new A.a("Produtos representativos com dados t\xedpicos de cat\xe1logo (vaz\xe3o, expoente, raio, faixa de press\xe3o). Os pre\xe7os ficam em zero: exporte para Excel, preencha com a tabela local e importe de volta. Confirme sempre na folha de dados do fabricante.","Representative products with typical catalogue data (flow, exponent, radius, pressure range). Prices are left at zero: export to Excel, fill in the local price list and import it back. Always confirm with the manufacturer data sheet.","Productos representativos con datos t\xedpicos de cat\xe1logo (caudal, exponente, radio, rango de presi\xf3n). Los precios quedan en cero: exporte a Excel, complete con la lista local e importe de vuelta. Confirme siempre con la hoja de datos del fabricante.")
B.vJ=new A.a("Adicionar","Add","A\xf1adir")
B.tE=new A.a("{n} itens adicionados de {b}","{n} items added from {b}","{n} \xedtems a\xf1adidos de {b}")
B.oC=new A.a("{n} itens","{n} items","{n} \xedtems")
B.r6=new A.a("Exportar Excel","Export Excel","Exportar Excel")
B.qP=new A.a("Importar (JSON, CSV, Excel)\u2026","Import (JSON, CSV, Excel)\u2026","Importar (JSON, CSV, Excel)\u2026")
B.eB=new A.a("Menu","Menu","Men\xfa")
B.ix=new A.a("Concluir","Done","Terminar")
B.v5=new A.a("Toque para desenhar \xb7 pin\xe7a para zoom \xb7 dois dedos para mover","Tap to draw \xb7 pinch to zoom \xb7 two fingers to pan","Toque para dibujar \xb7 pellizco para zoom \xb7 dos dedos para mover")
B.lN=new A.a("Navegar","Navigate","Navegar")
B.mv=new A.a("Principal","Mainline","Principal")
B.hz=new A.a("{n} selecionado(s)","{n} selected","{n} seleccionado(s)")
B.fu=new A.a("No celular: bot\xf5es Concluir/Cancelar substituem Enter/Esc; menu \u2630 re\xfane os menus","On a phone: Done/Cancel buttons replace Enter/Esc; the \u2630 menu gathers the menus","En el m\xf3vil: los botones Terminar/Cancelar reemplazan Intro/Esc; el men\xfa \u2630 re\xfane los men\xfas")
B.pH=new A.a("Laterais seguem a linha selecionada ({n}): laterais curvas","Laterals follow the selected line ({n}): curved laterals","Laterales siguen la l\xednea seleccionada ({n}): laterales curvas")
B.r5=new A.a("Hist\xf3rico","History","Historial")
B.ti=new A.a("Clique num passo para voltar (ou avan\xe7ar) no tempo; uma nova edi\xe7\xe3o descarta os passos \xe0 frente.","Click a step to go back (or forward) in time; a new edit discards the steps ahead.","Haga clic en un paso para volver (o avanzar) en el tiempo; una nueva edici\xf3n descarta los pasos siguientes.")
B.fh=new A.a("Estado inicial","Initial state","Estado inicial")
B.jR=new A.a("Edi\xe7\xe3o","Edit","Edici\xf3n")
B.uE=new A.a("Adicionar {n}","Add {n}","A\xf1adir {n}")
B.th=new A.a("Adicionar {n} itens","Add {n} items","A\xf1adir {n} elementos")
B.o8=new A.a("Excluir {n} item(ns)","Delete {n} item(s)","Eliminar {n} elemento(s)")
B.lF=new A.a("Mover","Move","Mover")
B.jl=new A.a("Espelhar","Mirror","Reflejar")
B.rT=new A.a("Transformar {n} item(ns)","Transform {n} item(s)","Transformar {n} elemento(s)")
B.nP=new A.a("Copiar {n} item(ns)","Copy {n} item(s)","Copiar {n} elemento(s)")
B.lv=new A.a("Matriz","Array","Matriz")
B.ku=new A.a("Importar","Import","Importar")
B.hD=new A.a("Projetar (dimensionar)","Design (size pipes)","Dise\xf1ar (dimensionar)")
B.vS=new A.a("Eleva\xe7\xe3o importada","Elevation imported","Elevaci\xf3n importada")
B.hO=new A.a("Alinhar","Align","Alinear")
B.n0=new A.a("Lista de materiais na prancha","Bill of materials on the sheet","Lista de materiales en la l\xe1mina")
B.nf=new A.a("Qtd.","Qty","Cant.")
B.fI=new A.a("\u2026 mais {n} itens (ver relat\xf3rio)","\u2026 {n} more items (see report)","\u2026 {n} \xedtems m\xe1s (ver informe)")
B.np=new A.a("GeoTIFF de eleva\xe7\xe3o: {n} cotas de {w}\xd7{h} px ({crs})","Elevation GeoTIFF: {n} spot heights from {w}\xd7{h} px ({crs})","GeoTIFF de elevaci\xf3n: {n} cotas de {w}\xd7{h} px ({crs})")
B.to=new A.a("V\xe3os do piv\xf4","Pivot spans","Vanos del pivote")
B.jx=new A.a("V\xe3o","Span","Vano")
B.ha=new A.a("R inicial","R start","R inicial")
B.w9=new A.a("R final","R end","R final")
B.hS=new A.a("Aspersores","Sprinklers","Aspersores")
B.ou=new A.a("q por aspersor","q per sprinkler","q por aspersor")
B.ew=new A.a("P no v\xe3o","P at span","P en el vano")
B.fy=new A.a("Bocal sugerido","Suggested nozzle","Boquilla sugerida")
B.fc=new A.a("Espa\xe7amento dos aspersores (m)","Sprinkler spacing (m)","Espaciado de los aspersores (m)")
B.q5=new A.a("Aspersor do piv\xf4 (cat\xe1logo)","Pivot sprinkler (catalogue)","Aspersor del pivote (cat\xe1logo)")
B.vX=new A.a("Regulador de press\xe3o (cat\xe1logo)","Pressure regulator (catalogue)","Regulador de presi\xf3n (cat\xe1logo)")
B.fZ=new A.a("Custo por torre","Cost per tower","Costo por torre")
B.pC=new A.a("Aspersores do piv\xf4","Pivot sprinklers","Aspersores del pivote")
B.mZ=new A.a("Canh\xe3o final","End gun","Ca\xf1\xf3n final")
B.k0=new A.a("Suavizar curva (spline pelos pontos)","Smooth contour (spline through the points)","Suavizar curva (spline por los puntos)")
B.kc=new A.a("M\xe1x. de pontos","Max. points","M\xe1x. de puntos")
B.lE=new A.a("Motor","Motor","Motor")
B.pc=new A.a("Linha principal em anel: o dimensionamento LP usa caminhos em \xe1rvore (aproxima\xe7\xe3o); a an\xe1lise final confere as press\xf5es","Looped mainline: LP sizing uses tree paths (approximation); the final analysis checks the pressures","L\xednea principal en anillo: el dimensionamiento LP usa caminos en \xe1rbol (aproximaci\xf3n); el an\xe1lisis final verifica las presiones")
B.mU=new A.a("Inclu\xeddos no app","Bundled with the app","Incluidos en la app")
B.i1=new A.a("Carregados agora","Loaded now","Cargados ahora")
B.jq=new A.a("Importar pacote (.oci.cat)\u2026","Import pack (.oci.cat)\u2026","Importar paquete (.oci.cat)\u2026")
B.vd=new A.a("URL de um pacote ou de um \xedndice (index.json)","URL of a pack or of an index (index.json)","URL de un paquete o de un \xedndice (index.json)")
B.k4=new A.a("Carregar da URL","Load from URL","Cargar de la URL")
B.uj=new A.a("Carregando\u2026","Loading\u2026","Cargando\u2026")
B.oc=new A.a("{n} pacote(s) carregado(s)","{n} pack(s) loaded","{n} paquete(s) cargado(s)")
B.js=new A.a("N\xe3o foi poss\xedvel carregar: {e}","Could not load: {e}","No se pudo cargar: {e}")
B.rq=new A.a("Exportar pacote .oci.cat\u2026","Export pack .oci.cat\u2026","Exportar paquete .oci.cat\u2026")
B.ur=new A.a("Exportar cat\xe1logo como pacote","Export catalogue as a pack","Exportar cat\xe1logo como paquete")
B.eO=new A.a("Gera um arquivo .oci.cat com os itens deste cat\xe1logo, para compartilhar ou publicar num reposit\xf3rio da comunidade. O formato (JSON aberto) est\xe1 documentado em catalogs/README.md.","Writes an .oci.cat file with the items of this catalogue, to share or publish in a community repository. The format (open JSON) is documented in catalogs/README.md.","Genera un archivo .oci.cat con los \xedtems de este cat\xe1logo, para compartir o publicar en un repositorio de la comunidad. El formato (JSON abierto) est\xe1 documentado en catalogs/README.md.")
B.jr=new A.a("Fabricante","Manufacturer","Fabricante")
B.i8=new A.a("Nome do pacote","Pack name","Nombre del paquete")
B.wI=new A.a("Descri\xe7\xe3o (linhas de produto)","Description (product lines)","Descripci\xf3n (l\xedneas de producto)")
B.nM=new A.a("Fonte (URL da folha de dados)","Source (data sheet URL)","Fuente (URL de la hoja de datos)")
B.oq=new A.a("Pacote {f} exportado ({n} itens)","Pack {f} exported ({n} items)","Paquete {f} exportado ({n} \xedtems)")
B.ua=new A.a("Pacotes s\xe3o arquivos JSON abertos (.oci.cat): fabricantes, revendas e a comunidade podem public\xe1-los num reposit\xf3rio e voc\xea os carrega por arquivo ou URL. Formato em catalogs/README.md.","Packs are open JSON files (.oci.cat): manufacturers, dealers and the community can publish them in a repository and you load them from a file or a URL. Format in catalogs/README.md.","Los paquetes son archivos JSON abiertos (.oci.cat): fabricantes, distribuidores y la comunidad pueden publicarlos en un repositorio y usted los carga desde un archivo o una URL. Formato en catalogs/README.md.")
B.pU=new A.a("de {o}","from {o}","de {o}")
B.qi=new A.a("O JSON n\xe3o \xe9 um cat\xe1logo nem um pacote .oci.cat","The JSON is neither a catalogue nor an .oci.cat pack","El JSON no es un cat\xe1logo ni un paquete .oci.cat")
B.tA=new A.a("Este arquivo \xe9 um \xedndice de pacotes, n\xe3o um pacote (carregue-o pela URL)","This file is a pack index, not a pack (load it by URL)","Este archivo es un \xedndice de paquetes, no un paquete (c\xe1rguelo por URL)")
B.ud=new A.a("O JSON n\xe3o \xe9 um \xedndice de pacotes","The JSON is not a pack index","El JSON no es un \xedndice de paquetes")
B.u5=new A.a("Pacote gravado por uma vers\xe3o mais nova do formato","Pack written by a newer format version","Paquete escrito por una versi\xf3n m\xe1s nueva del formato")
B.va=new A.a("Coordenada do local (lat, lon)","Site coordinate (lat, lon)","Coordenada del sitio (lat, lon)")
B.lo=new A.a("-22.9068, -43.1729 \xb7 link do Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 Google Maps link \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 enlace de Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W")
B.wA=new A.a("Sem desenho ainda? Cole a coordenada do terreno: a origem do projeto vai para l\xe1 e a eleva\xe7\xe3o \xe9 baixada num quadrado ao redor.","No drawing yet? Paste the site coordinate: the project origin goes there and the elevation is downloaded over a square around it.","\xbfSin dibujo todav\xeda? Pegue la coordenada del terreno: el origen del proyecto va all\xed y la elevaci\xf3n se descarga en un cuadrado alrededor.")
B.tQ=new A.a("Usar coordenada","Use coordinate","Usar coordenada")
B.nV=new A.a("Lado da \xe1rea (m)","Area side (m)","Lado del \xe1rea (m)")
B.hH=new A.a("Coordenada n\xe3o reconhecida","Coordinate not recognised","Coordenada no reconocida")
B.er=new A.a("Gerar curvas de n\xedvel ap\xf3s baixar","Generate contours after downloading","Generar curvas de nivel tras descargar")
B.f7=new A.a("Intervalo (m; 0 = autom\xe1tico)","Interval (m; 0 = automatic)","Intervalo (m; 0 = autom\xe1tico)")
B.wg=new A.a("{n} cotas importadas ({s}); {c} curvas de n\xedvel a cada {i} m","{n} spot heights imported ({s}); {c} contours every {i} m","{n} cotas importadas ({s}); {c} curvas de nivel cada {i} m")
B.tZ=new A.a("Georrefer\xeancia definida em {lat}, {lon} ({crs})","Georeference set at {lat}, {lon} ({crs})","Georreferencia definida en {lat}, {lon} ({crs})")
B.jo=new A.a("Exemplos","Examples","Ejemplos")
B.ih=new A.a("Boas-vindas e galeria de exemplos\u2026","Welcome and example gallery\u2026","Bienvenida y galer\xeda de ejemplos\u2026")
B.vH=new A.a("Bem-vindo ao OpenCADIrrigation","Welcome to OpenCADIrrigation","Bienvenido a OpenCADIrrigation")
B.eY=new A.a("CAD aberto para projeto de irriga\xe7\xe3o pressurizada, direto no navegador. Comece por um exemplo pronto ou fa\xe7a o tutorial interativo: cerca de 50 passos curtos em que voc\xea mesmo navega, desenha, monta a rede e projeta; cada passo reconhece quando voc\xea o completou e avan\xe7a sozinho. Leva uns 15 minutos e pode ser pulado a qualquer momento (Ajuda \u2192 Tutorial interativo reabre depois).","Open CAD for pressurised irrigation design, right in the browser. Start from a ready example or take the interactive tutorial: about 50 short steps in which you navigate, draw, build the network and design it yourself; each step recognises when you have completed it and moves on. It takes about 15 minutes and can be skipped at any time (Help \u2192 Interactive tutorial reopens it).","CAD abierto para dise\xf1o de riego presurizado, directamente en el navegador. Empiece por un ejemplo listo o haga el tutorial interactivo: unos 50 pasos cortos en los que usted mismo navega, dibuja, arma la red y dise\xf1a; cada paso reconoce cuando lo complet\xf3 y avanza solo. Tarda unos 15 minutos y puede omitirse en cualquier momento (Ayuda \u2192 Tutorial interactivo lo reabre).")
B.tL=new A.a("Comece por um exemplo","Start from an example","Empiece por un ejemplo")
B.jw=new A.a("Cada projeto abre pronto para calcular: pressione F5 ou \u25b6 e veja zonas, press\xf5es, di\xe2metros e lista de materiais. Arquivo \u2192 Exemplos reabre qualquer um deles.","Each project opens ready to design: press F5 or \u25b6 and see zones, pressures, pipe sizes and the bill of materials. File \u2192 Examples reopens any of them.","Cada proyecto se abre listo para calcular: pulse F5 o \u25b6 y vea zonas, presiones, di\xe1metros y lista de materiales. Archivo \u2192 Ejemplos reabre cualquiera de ellos.")
B.mW=new A.a("Iniciar tutorial","Start tutorial","Iniciar tutorial")
B.vr=new A.a("Come\xe7ar do zero","Start from scratch","Empezar de cero")
B.mu=new A.a("Pomar","Orchard","Huerto")
B.id=new A.a("Microaspers\xe3o em citros e gotejamento em uva, po\xe7o com bomba e filtro, terreno em declive.","Micro-sprinklers on citrus and drip on grapes, well with pump and filter, sloping ground.","Microaspersi\xf3n en c\xedtricos y goteo en uva, pozo con bomba y filtro, terreno en pendiente.")
B.jO=new A.a("2 zonas \xb7 1,1 ha \xb7 po\xe7o + bomba","2 zones \xb7 1.1 ha \xb7 well + pump","2 zonas \xb7 1,1 ha \xb7 pozo + bomba")
B.bA=new A.a("Jardim residencial","Residential garden","Jard\xedn residencial")
B.jv=new A.a("Sprays pop-up no gramado da frente, rotores nos fundos e gotejamento nos canteiros, ligados \xe0 rede p\xfablica com hidr\xf4metro e anti-refluxo.","Pop-up sprays on the front lawn, rotors at the back and drip in the beds, fed by the mains with a meter and a backflow preventer.","Difusores emergentes en el c\xe9sped frontal, rotores atr\xe1s y goteo en los canteros, conectados a la red p\xfablica con contador y antirretorno.")
B.pp=new A.a("3 zonas \xb7 640 m\xb2 \xb7 rede p\xfablica","3 zones \xb7 640 m\xb2 \xb7 mains supply","3 zonas \xb7 640 m\xb2 \xb7 red p\xfablica")
B.cr=new A.a("Campo de futebol","Football pitch","Campo de f\xfatbol")
B.hI=new A.a("Campo oficial 105 \xd7 68 m com aspersores de impacto em cinco linhas, reservat\xf3rio, bomba e turnos noturnos.","Full-size 105 \xd7 68 m pitch with impact sprinklers in five rows, reservoir, pump and night-time shifts.","Campo oficial de 105 \xd7 68 m con aspersores de impacto en cinco filas, dep\xf3sito, bomba y turnos nocturnos.")
B.vO=new A.a("5 zonas \xb7 40 aspersores \xb7 bomba","5 zones \xb7 40 sprinklers \xb7 pump","5 zonas \xb7 40 aspersores \xb7 bomba")
B.eE=new A.a("Lavoura gotejada","Drip row crop","Cultivo en hileras con goteo")
B.nj=new A.a("Quatro talh\xf5es de tomate com fita gotejadora, submains com v\xe1lvulas, filtro de tela, bomba e terreno em declive.","Four tomato blocks on drip tape, submains with valves, screen filter, pump and sloping ground.","Cuatro parcelas de tomate con cinta de goteo, submains con v\xe1lvulas, filtro de malla, bomba y terreno en pendiente.")
B.wB=new A.a("4 zonas \xb7 2,9 ha \xb7 filtro + bomba","4 zones \xb7 2.9 ha \xb7 filter + pump","4 zonas \xb7 2,9 ha \xb7 filtro + bomba")
B.t1=new A.a("Piv\xf4 de 300 m em milho alimentado por adutora, po\xe7o e bomba; relat\xf3rio de torres, v\xe3os e bocais.","A 300 m pivot on maize fed by a mainline, well and pump; tower, span and sprinkler report.","Pivote de 300 m en ma\xedz alimentado por conducci\xf3n, pozo y bomba; informe de torres, tramos y boquillas.")
B.hK=new A.a("1 piv\xf4 \xb7 28 ha \xb7 po\xe7o + bomba","1 pivot \xb7 28 ha \xb7 well + pump","1 pivote \xb7 28 ha \xb7 pozo + bomba")
B.h9=new A.a("Turno {n} \u2014 {z}","Shift {n} \u2014 {z}","Turno {n} \u2014 {z}")
B.hk=new A.a("Resid\xeancia Exemplo","Example Residence","Residencia Ejemplo")
B.h3=new A.a("Lote 16 \xd7 40 m","Lot 16 \xd7 40 m","Lote 16 \xd7 40 m")
B.qh=new A.a("Jardim residencial \u2014 exemplo OpenCADIrrigation","Residential garden \u2014 OpenCADIrrigation example","Jard\xedn residencial \u2014 ejemplo OpenCADIrrigation")
B.li=new A.a("Lote","Lot","Lote")
B.ip=new A.a("Casa","House","Casa")
B.j4=new A.a("Gramado da frente","Front lawn","C\xe9sped frontal")
B.rW=new A.a("Gramado dos fundos","Back lawn","C\xe9sped trasero")
B.io=new A.a("Canteiro","Bed","Cantero")
B.ei=new A.a("Zona 1 \u2014 sprays","Zone 1 \u2014 sprays","Zona 1 \u2014 difusores")
B.lc=new A.a("Zona 2 \u2014 rotores","Zone 2 \u2014 rotors","Zona 2 \u2014 rotores")
B.kR=new A.a("Zona 3 \u2014 gotejamento","Zone 3 \u2014 drip","Zona 3 \u2014 goteo")
B.on=new A.a("Rede p\xfablica","Mains supply","Red p\xfablica")
B.hR=new A.a("Arbustos","Shrubs","Arbustos")
B.nk=new A.a("Rua","Street","Calle")
B.cD=new A.a("Clube Exemplo","Example Club","Club Ejemplo")
B.fH=new A.a("Campo oficial 105 \xd7 68 m","Full-size pitch 105 \xd7 68 m","Campo oficial 105 \xd7 68 m")
B.h6=new A.a("Campo de futebol \u2014 exemplo OpenCADIrrigation","Football pitch \u2014 OpenCADIrrigation example","Campo de f\xfatbol \u2014 ejemplo OpenCADIrrigation")
B.il=new A.a("Campo","Pitch","Campo")
B.pe=new A.a("Linha {n}","Row {n}","Fila {n}")
B.Z=new A.a("Reservat\xf3rio","Reservoir","Dep\xf3sito")
B.c5=new A.a("Casa de bombas","Pump house","Casa de bombas")
B.bR=new A.a("Grama esportiva","Sports turf","C\xe9sped deportivo")
B.qp=new A.a("Lavoura gotejada","Drip row crop","Cultivo con goteo")
B.rn=new A.a("S\xedtio Exemplo","Example Farm","Finca Ejemplo")
B.v9=new A.a("Talh\xf5es 1 a 4","Blocks 1 to 4","Parcelas 1 a 4")
B.tC=new A.a("Lavoura de tomate gotejada \u2014 exemplo OpenCADIrrigation","Drip-irrigated tomato field \u2014 OpenCADIrrigation example","Cultivo de tomate con goteo \u2014 ejemplo OpenCADIrrigation")
B.O=new A.a("Talh\xe3o {n}","Block {n}","Parcela {n}")
B.ch=new A.a("Tronco","Trunk","Tronco")
B.aB=new A.a("Ramal oeste","West branch","Ramal oeste")
B.ao=new A.a("Ramal leste","East branch","Ramal este")
B.M=new A.a("Estrada","Road","Camino")
B.r=new A.a("Gleba","Field","Campo")
B.od=new A.a("Piv\xf4 1 \u2014 raio 300 m","Pivot 1 \u2014 300 m radius","Pivote 1 \u2014 radio 300 m")
B.fP=new A.a("Piv\xf4 central \u2014 exemplo OpenCADIrrigation","Centre pivot \u2014 OpenCADIrrigation example","Pivote central \u2014 ejemplo OpenCADIrrigation")
B.rH=new A.a("Piv\xf4 1","Pivot 1","Pivote 1")
B.E=new A.a("Adutora","Mainline","Conducci\xf3n")
B.cl=new A.a("\xc1rea do piv\xf4","Pivot area","\xc1rea del pivote")
B.cw=new A.a("Estufa de hortali\xe7as","Vegetable greenhouse","Invernadero de hortalizas")
B.oY=new A.a("Quatro t\xfaneis de piment\xe3o com tubo gotejador autocompensante, uma zona por t\xfanel, reservat\xf3rio, bomba pequena e filtro de discos.","Four pepper tunnels on pressure-compensating dripline, one zone per tunnel, tank, small pump and disc filter.","Cuatro t\xfaneles de pimiento con tuber\xeda de goteo autocompensante, una zona por t\xfanel, dep\xf3sito, bomba peque\xf1a y filtro de discos.")
B.fU=new A.a("4 zonas \xb7 1.800 m\xb2 \xb7 reservat\xf3rio + bomba","4 zones \xb7 1,800 m\xb2 \xb7 tank + pump","4 zonas \xb7 1.800 m\xb2 \xb7 dep\xf3sito + bomba")
B.bx=new A.a("Viveiro de mudas","Plant nursery","Vivero de plantas")
B.rd=new A.a("Tr\xeas canteiros de 12 \xd7 48 m com microaspersores suspensos em malha 4 \xd7 4 m, uma zona por canteiro, caixa d\u2019\xe1gua elevada, bomba pequena e filtro de discos.","Three 12 \xd7 48 m beds under overhead micro-sprinklers on a 4 \xd7 4 m grid, one zone per bed, elevated tank, small pump and disc filter.","Tres canteros de 12 \xd7 48 m con microaspersores suspendidos en malla de 4 \xd7 4 m, una zona por cantero, tanque elevado, bomba peque\xf1a y filtro de discos.")
B.h7=new A.a("3 zonas \xb7 108 microaspersores \xb7 bomba","3 zones \xb7 108 micro-sprinklers \xb7 pump","3 zonas \xb7 108 microaspersores \xb7 bomba")
B.bS=new A.a("Cafezal em curvas de n\xedvel","Coffee on contour lines","Cafetal en curvas de nivel")
B.p7=new A.a("Tr\xeas talh\xf5es de caf\xe9 em encosta com laterais curvas que seguem as curvas de n\xedvel (bloco guiado), tubo gotejador PC, po\xe7o e bomba no p\xe9 do morro.","Three coffee blocks on a hillside with curved laterals following the contours (guided block), PC dripline, well and pump at the foot of the slope.","Tres parcelas de caf\xe9 en ladera con laterales curvos que siguen las curvas de nivel (bloque guiado), tuber\xeda de goteo PC, pozo y bomba al pie de la pendiente.")
B.tf=new A.a("3 zonas \xb7 2,7 ha \xb7 po\xe7o + bomba","3 zones \xb7 2.7 ha \xb7 well + pump","3 zonas \xb7 2,7 ha \xb7 pozo + bomba")
B.cB=new A.a("Bananal","Banana plantation","Platanal")
B.pX=new A.a("Dois talh\xf5es de banana com microaspersores autocompensantes em 5 \xd7 5 m, po\xe7o com bomba submersa, filtro de discos e terreno em declive.","Two banana blocks under pressure-compensating micro-sprinklers at 5 \xd7 5 m, well with submersible pump, disc filter and sloping ground.","Dos parcelas de banano con microaspersores autocompensantes a 5 \xd7 5 m, pozo con bomba sumergible, filtro de discos y terreno en pendiente.")
B.qX=new A.a("2 zonas \xb7 1,2 ha \xb7 bomba submersa","2 zones \xb7 1.2 ha \xb7 submersible pump","2 zonas \xb7 1,2 ha \xb7 bomba sumergible")
B.c6=new A.a("Cana-de-a\xe7\xfacar subsuperficial","Subsurface drip sugarcane","Ca\xf1a de az\xfacar con goteo subterr\xe1neo")
B.l2=new A.a("Dois talh\xf5es de cana com tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, submains enterrados, reservat\xf3rio, bomba, filtro de tela e ventosa.","Two sugarcane blocks on 20 mm PC dripline buried 0.3 m deep, 180 m laterals, buried submains, reservoir, pump, screen filter and air valve.","Dos parcelas de ca\xf1a con tuber\xeda de goteo PC de 20 mm enterrada a 0,3 m, laterales de 180 m, submains enterrados, dep\xf3sito, bomba, filtro de malla y ventosa.")
B.it=new A.a("2 zonas \xb7 3,2 ha \xb7 filtro + bomba","2 zones \xb7 3.2 ha \xb7 filter + pump","2 zonas \xb7 3,2 ha \xb7 filtro + bomba")
B.br=new A.a("Gotejamento por gravidade","Gravity-fed drip","Goteo por gravedad")
B.fb=new A.a("Reservat\xf3rio 40 m acima de dois talh\xf5es de hortali\xe7as gotejados, sem bomba: registro, v\xe1lvula reguladora de press\xe3o e filtro de discos na adutora; curvas de n\xedvel da encosta.","A reservoir 40 m above two drip-irrigated vegetable blocks, no pump: gate valve, pressure reducing valve and disc filter on the mainline; hillside contours.","Dep\xf3sito 40 m por encima de dos parcelas de hortalizas con goteo, sin bomba: v\xe1lvula de compuerta, reguladora de presi\xf3n y filtro de discos en la conducci\xf3n; curvas de nivel de la ladera.")
B.eL=new A.a("2 zonas \xb7 1,2 ha \xb7 sem bomba","2 zones \xb7 1.2 ha \xb7 no pump","2 zonas \xb7 1,2 ha \xb7 sin bomba")
B.cx=new A.a("Pastagem em aspers\xe3o","Sprinkler-irrigated pasture","Pastura con aspersi\xf3n")
B.eu=new A.a("Tr\xeas piquetes de 72 \xd7 72 m com linhas de aspersores de impacto em 12 \xd7 18 m, submains com v\xe1lvulas, reservat\xf3rio, bomba e v\xe1lvula de reten\xe7\xe3o.","Three 72 \xd7 72 m paddocks with impact-sprinkler spray lines at 12 \xd7 18 m, submains with valves, reservoir, pump and check valve.","Tres potreros de 72 \xd7 72 m con l\xedneas de aspersores de impacto a 12 \xd7 18 m, submains con v\xe1lvulas, dep\xf3sito, bomba y v\xe1lvula de retenci\xf3n.")
B.f6=new A.a("3 zonas \xb7 1,6 ha \xb7 72 aspersores","3 zones \xb7 1.6 ha \xb7 72 sprinklers","3 zonas \xb7 1,6 ha \xb7 72 aspersores")
B.bI=new A.a("Buraco de golfe","Golf hole","Hoyo de golf")
B.uB=new A.a("Tee com sprays, fairway com rotores em malha triangular (duas zonas) e green com rotores no per\xedmetro, lago com bomba e turnos noturnos.","Tee with sprays, fairway with rotors on a triangular grid (two zones) and green with rotors around the edge, pond with pump and night-time shifts.","Tee con difusores, fairway con rotores en malla triangular (dos zonas) y green con rotores en el per\xedmetro, laguna con bomba y turnos nocturnos.")
B.f8=new A.a("4 zonas \xb7 64 emissores \xb7 lago + bomba","4 zones \xb7 64 heads \xb7 pond + pump","4 zonas \xb7 64 emisores \xb7 laguna + bomba")
B.nF=new A.a("Piv\xf4 setorial com canh\xe3o","Sector pivot with end gun","Pivote sectorial con ca\xf1\xf3n")
B.wt=new A.a("Piv\xf4 de 250 m em soja que gira 270\xb0, deixando livre o quadrante da sede, com canh\xe3o final de 12 m\xb3/h; lago, bomba de 30 cv e registro.","A 250 m pivot on soybean sweeping 270\xb0, leaving the farmstead quadrant free, with a 12 m\xb3/h end gun; pond, 30 hp pump and gate valve.","Pivote de 250 m en soja que gira 270\xb0, dejando libre el cuadrante del casco, con ca\xf1\xf3n final de 12 m\xb3/h; laguna, bomba de 30 CV y v\xe1lvula de compuerta.")
B.pu=new A.a("1 piv\xf4 \xb7 15,7 ha \xb7 lago + bomba","1 pivot \xb7 15.7 ha \xb7 pond + pump","1 pivote \xb7 15,7 ha \xb7 laguna + bomba")
B.cn=new A.a("Piv\xf4 linear","Linear move","Pivote lineal")
B.pB=new A.a("Lateral m\xf3vel de 392 m em trigo percorrendo 800 m ao longo de um canal, capta\xe7\xe3o com bomba de 30 cv e v\xe1lvula de reten\xe7\xe3o; relat\xf3rio de torres e bocais.","A 392 m lateral-move machine on wheat travelling 800 m along a canal, intake with a 30 hp pump and check valve; tower and sprinkler report.","Lateral de avance frontal de 392 m en trigo que recorre 800 m a lo largo de un canal, toma con bomba de 30 CV y v\xe1lvula de retenci\xf3n; informe de torres y boquillas.")
B.n2=new A.a("1 linear \xb7 32 ha \xb7 canal + bomba","1 linear \xb7 32 ha \xb7 canal + pump","1 lineal \xb7 32 ha \xb7 canal + bomba")
B.vp=new A.a("Hortifruti Exemplo","Example Growers","Hortalizas Ejemplo")
B.vx=new A.a("T\xfaneis 1 a 4","Tunnels 1 to 4","T\xfaneles 1 a 4")
B.oI=new A.a("Estufa de hortali\xe7as \u2014 exemplo OpenCADIrrigation","Vegetable greenhouse \u2014 OpenCADIrrigation example","Invernadero de hortalizas \u2014 ejemplo OpenCADIrrigation")
B.cc=new A.a("Terreno","Site","Terreno")
B.no=new A.a("T\xfanel {n}","Tunnel {n}","T\xfanel {n}")
B.vy=new A.a("Piment\xe3o","Bell pepper","Pimiento")
B.pf=new A.a("Viveiro Exemplo","Example Nursery","Vivero Ejemplo")
B.t_=new A.a("Canteiros 1 a 3","Beds 1 to 3","Canteros 1 a 3")
B.hn=new A.a("Viveiro de mudas \u2014 exemplo OpenCADIrrigation","Plant nursery \u2014 OpenCADIrrigation example","Vivero de plantas \u2014 ejemplo OpenCADIrrigation")
B.oA=new A.a("Canteiro {n}","Bed {n}","Cantero {n}")
B.lI=new A.a("Mudas","Seedlings","Plantines")
B.n5=new A.a("Caixa d\u2019\xe1gua","Tank","Tanque")
B.jN=new A.a("Encosta norte \u2014 talh\xf5es 1 a 3","North slope \u2014 blocks 1 to 3","Ladera norte \u2014 parcelas 1 a 3")
B.mX=new A.a("Cafezal em curvas de n\xedvel \u2014 exemplo OpenCADIrrigation","Coffee on contour lines \u2014 OpenCADIrrigation example","Cafetal en curvas de nivel \u2014 ejemplo OpenCADIrrigation")
B.aA=new A.a("Talh\xf5es 1 e 2","Blocks 1 and 2","Parcelas 1 y 2")
B.tt=new A.a("Bananal \u2014 exemplo OpenCADIrrigation","Banana plantation \u2014 OpenCADIrrigation example","Platanal \u2014 ejemplo OpenCADIrrigation")
B.lH=new A.a("Usina Exemplo","Example Mill","Ingenio Ejemplo")
B.om=new A.a("Cana-de-a\xe7\xfacar em gotejamento subsuperficial \u2014 exemplo OpenCADIrrigation","Subsurface drip sugarcane \u2014 OpenCADIrrigation example","Ca\xf1a de az\xfacar con goteo subterr\xe1neo \u2014 ejemplo OpenCADIrrigation")
B.wp=new A.a("S\xedtio Exemplo","Example Smallholding","Finca Ejemplo")
B.vC=new A.a("Gotejamento por gravidade \u2014 exemplo OpenCADIrrigation","Gravity-fed drip \u2014 OpenCADIrrigation example","Goteo por gravedad \u2014 ejemplo OpenCADIrrigation")
B.tK=new A.a("Reservat\xf3rio no alto","Hilltop reservoir","Dep\xf3sito en lo alto")
B.uf=new A.a("V\xe1lvula reguladora de press\xe3o","Pressure reducing valve","V\xe1lvula reguladora de presi\xf3n")
B.eK=new A.a("Piquetes 1 a 3","Paddocks 1 to 3","Potreros 1 a 3")
B.m7=new A.a("Pastagem em aspers\xe3o \u2014 exemplo OpenCADIrrigation","Sprinkler-irrigated pasture \u2014 OpenCADIrrigation example","Pastura con aspersi\xf3n \u2014 ejemplo OpenCADIrrigation")
B.ok=new A.a("Piquete {n}","Paddock {n}","Potrero {n}")
B.mq=new A.a("Pastagem","Pasture","Pastura")
B.is=new A.a("Cerca","Fence","Cerco")
B.rP=new A.a("Buraco 1 \u2014 par 4","Hole 1 \u2014 par 4","Hoyo 1 \u2014 par 4")
B.t3=new A.a("Buraco de golfe \u2014 exemplo OpenCADIrrigation","Golf hole \u2014 OpenCADIrrigation example","Hoyo de golf \u2014 ejemplo OpenCADIrrigation")
B.nY=new A.a("Tee","Tee","Tee")
B.jA=new A.a("Fairway","Fairway","Fairway")
B.kP=new A.a("Fairway {n}","Fairway {n}","Fairway {n}")
B.k1=new A.a("Green","Green","Green")
B.tS=new A.a("Bunker","Bunker","B\xfanker")
B.bZ=new A.a("Lago","Pond","Laguna")
B.l7=new A.a("Piv\xf4 setorial","Sector pivot","Pivote sectorial")
B.pm=new A.a("Piv\xf4 2 \u2014 raio 250 m, setor de 270\xb0","Pivot 2 \u2014 250 m radius, 270\xb0 sector","Pivote 2 \u2014 radio 250 m, sector de 270\xb0")
B.k3=new A.a("Piv\xf4 setorial com canh\xe3o final \u2014 exemplo OpenCADIrrigation","Sector pivot with end gun \u2014 OpenCADIrrigation example","Pivote sectorial con ca\xf1\xf3n final \u2014 ejemplo OpenCADIrrigation")
B.mM=new A.a("Piv\xf4 2","Pivot 2","Pivote 2")
B.nE=new A.a("Soja","Soybean","Soja")
B.nB=new A.a("Sede","Farmstead","Casco")
B.k7=new A.a("Linear 1 \u2014 392 \xd7 800 m","Linear 1 \u2014 392 \xd7 800 m","Lineal 1 \u2014 392 \xd7 800 m")
B.t6=new A.a("Piv\xf4 linear \u2014 exemplo OpenCADIrrigation","Linear move \u2014 OpenCADIrrigation example","Pivote lineal \u2014 ejemplo OpenCADIrrigation")
B.v7=new A.a("Linear 1","Linear 1","Lineal 1")
B.o3=new A.a("Trigo","Wheat","Trigo")
B.im=new A.a("Canal","Canal","Canal")
B.rO=new A.a("Capta\xe7\xe3o","Intake","Toma")
B.dI=new A.br(B.dL,[B.jS,B.m_,B.bF,B.hQ,B.jC,B.vW,B.c_,B.ap,B.bM,B.ck,B.bK,B.D,B.t,B.cq,B.k6,B.bP,B.bz,B.bu,B.eI,B.lV,B.fo,B.fQ,B.fC,B.pI,B.fA,B.ex,B.uN,B.q9,B.iz,B.n6,B.bG,B.uZ,B.vG,B.pD,B.ms,B.bL,B.fT,B.tv,B.iw,B.fm,B.eZ,B.kL,B.m0,B.iK,B.q7,B.fM,B.hL,B.qD,B.lr,B.ju,B.oS,B.oQ,B.hB,B.oz,B.l_,B.rl,B.oH,B.ol,B.hr,B.qH,B.j_,B.f4,B.iT,B.nT,B.nm,B.nt,B.mD,B.qF,B.mR,B.eR,B.uW,B.oO,B.rY,B.kl,B.m1,B.md,B.r1,B.og,B.pv,B.tp,B.lp,B.ru,B.rX,B.jy,B.op,B.ja,B.hN,B.hu,B.c7,B.ne,B.jG,B.nq,B.qV,B.mo,B.nd,B.pO,B.eQ,B.aF,B.tB,B.rh,B.mr,B.jp,B.wH,B.bJ,B.jk,B.jI,B.m5,B.me,B.oi,B.vj,B.le,B.rm,B.o7,B.qf,B.ws,B.nK,B.eg,B.ri,B.iY,B.X,B.iC,B.qE,B.oK,B.j5,B.i9,B.jh,B.v8,B.A,B.aF,B.us,B.rp,B.ar,B.cj,B.fr,B.hC,B.cC,B.qI,B.iZ,B.n8,B.k9,B.uM,B.j6,B.ib,B.tT,B.lX,B.bV,B.cC,B.aF,B.nh,B.p0,B.wG,B.fl,B.bE,B.kr,B.p3,B.lM,B.w1,B.ww,B.tz,B.q0,B.oU,B.pa,B.ot,B.hd,B.lZ,B.hA,B.jT,B.kh,B.lj,B.k8,B.pw,B.fw,B.Y,B.v4,B.uS,B.vR,B.pE,B.ny,B.eM,B.at,B.A,B.t2,B.Y,B.et,B.w3,B.ly,B.l0,B.t9,B.ut,B.f2,B.mj,B.rM,B.nC,B.pK,B.rR,B.f3,B.oZ,B.j7,B.X,B.iB,B.nO,B.p8,B.aC,B.ic,B.uO,B.fF,B.bX,B.W,B.iS,B.kK,B.aq,B.tn,B.mc,B.co,B.bt,B.lx,B.ez,B.qY,B.rF,B.l4,B.u_,B.f0,B.rZ,B.rJ,B.oV,B.l5,B.vk,B.ln,B.ul,B.eN,B.lq,B.my,B.nD,B.bV,B.m6,B.o6,B.aD,B.bL,B.qe,B.ik,B.aw,B.cs,B.t0,B.kx,B.W,B.bD,B.v1,B.tu,B.vh,B.t8,B.qu,B.qz,B.ql,B.n9,B.q_,B.bv,B.D,B.jM,B.u6,B.wD,B.wJ,B.po,B.jH,B.w_,B.aq,B.c3,B.cA,B.mE,B.aE,B.pz,B.X,B.eX,B.fp,B.jB,B.fe,B.hb,B.iE,B.bH,B.az,B.A,B.kH,B.c8,B.vb,B.kZ,B.mC,B.wy,B.vt,B.ev,B.cv,B.wx,B.py,B.wC,B.vY,B.r3,B.D,B.t,B.au,B.os,B.u7,B.av,B.i4,B.wf,B.qa,B.kb,B.hG,B.or,B.hU,B.rz,B.hY,B.l3,B.rc,B.td,B.rA,B.kt,B.m8,B.uI,B.ki,B.oM,B.ts,B.pF,B.r8,B.pl,B.vF,B.uu,B.pV,B.wi,B.pJ,B.jF,B.D,B.bv,B.A,B.au,B.fL,B.oh,B.cv,B.cz,B.cb,B.w2,B.rD,B.te,B.wk,B.tO,B.hW,B.iy,B.ji,B.ks,B.cs,B.iP,B.bY,B.mI,B.l9,B.rw,B.eS,B.eo,B.pq,B.k_,B.mi,B.W,B.lL,B.vc,B.wr,B.ax,B.kw,B.he,B.oL,B.cm,B.as,B.aq,B.cA,B.pW,B.qR,B.vI,B.uc,B.h1,B.mh,B.ue,B.rV,B.mT,B.qA,B.o0,B.nR,B.uV,B.r2,B.w7,B.az,B.q4,B.ep,B.eG,B.jV,B.lK,B.pb,B.v6,B.vM,B.at,B.km,B.A,B.cp,B.cj,B.ar,B.D,B.as,B.q2,B.nI,B.o1,B.bY,B.az,B.bu,B.X,B.ax,B.uU,B.ow,B.z,B.h0,B.j0,B.rf,B.ll,B.lm,B.t7,B.qU,B.c9,B.ci,B.jL,B.tm,B.vP,B.N,B.wb,B.nN,B.mx,B.iu,B.lh,B.mw,B.lT,B.p1,B.kp,B.es,B.qS,B.ed,B.ec,B.t4,B.hZ,B.jX,B.v_,B.kQ,B.rI,B.ld,B.o9,B.mf,B.kV,B.fs,B.hM,B.vK,B.v2,B.oR,B.jf,B.vl,B.iU,B.lD,B.ls,B.ml,B.bH,B.au,B.av,B.qo,B.fa,B.p4,B.ro,B.aw,B.qy,B.cu,B.up,B.uC,B.wd,B.lb,B.iH,B.ta,B.iF,B.ko,B.nS,B.i7,B.pL,B.qN,B.qM,B.ek,B.qc,B.bO,B.ir,B.jE,B.i_,B.uK,B.mm,B.mS,B.o2,B.q6,B.bX,B.mA,B.ke,B.hc,B.oe,B.c8,B.A,B.iJ,B.j2,B.p2,B.je,B.rB,B.rs,B.mk,B.uJ,B.hh,B.rL,B.c3,B.k2,B.hf,B.c2,B.i5,B.r9,B.kE,B.uF,B.rx,B.fJ,B.tU,B.mO,B.ty,B.vu,B.oa,B.pP,B.oT,B.l8,B.ef,B.p_,B.jc,B.at,B.A,B.bQ,B.cp,B.ar,B.of,B.aw,B.iR,B.oE,B.ij,B.we,B.eF,B.W,B.bD,B.ey,B.wa,B.cz,B.cb,B.uz,B.ii,B.re,B.ps,B.uD,B.w8,B.kY,B.ce,B.iI,B.tW,B.fO,B.nJ,B.ma,B.nG,B.mn,B.mG,B.mg,B.qC,B.el,B.hy,B.tH,B.ux,B.wq,B.mb,B.h4,B.pt,B.w5,B.qb,B.uA,B.tl,B.h5,B.jg,B.lz,B.tM,B.nH,B.pT,B.ry,B.r4,B.fR,B.u0,B.kD,B.tw,B.mJ,B.r7,B.eT,B.oy,B.uR,B.q1,B.ka,B.c0,B.kd,B.wc,B.eJ,B.ca,B.qg,B.bN,B.oG,B.hP,B.jm,B.wh,B.ve,B.qG,B.kN,B.fi,B.nL,B.ej,B.kn,B.eC,B.vQ,B.kT,B.w0,B.vn,B.tg,B.ov,B.la,B.nU,B.lC,B.uP,B.wo,B.hX,B.nQ,B.mt,B.lg,B.iv,B.ht,B.vD,B.q8,B.hp,B.ra,B.eU,B.pA,B.un,B.pM,B.en,B.vZ,B.vA,B.qL,B.n1,B.f_,B.lP,B.fK,B.qq,B.kk,B.nl,B.qm,B.jn,B.i6,B.tP,B.na,B.fg,B.iA,B.hj,B.uo,B.kI,B.iO,B.qs,B.c0,B.oJ,B.hT,B.hl,B.kf,B.m3,B.kG,B.jz,B.ap,B.hi,B.kB,B.iV,B.kX,B.pk,B.n4,B.rj,B.nz,B.oo,B.m2,B.iW,B.v3,B.eh,B.rC,B.u1,B.uY,B.uG,B.tj,B.oj,B.pR,B.fS,B.fj,B.p5,B.vN,B.pS,B.j9,B.rS,B.mP,B.fW,B.o5,B.bT,B.N,B.tb,B.uH,B.qr,B.vs,B.c9,B.ci,B.cy,B.bC,B.lt,B.rr,B.cf,B.bq,B.bB,B.bU,B.bw,B.mp,B.ia,B.tR,B.p6,B.uk,B.wz,B.c4,B.ct,B.bQ,B.rG,B.iq,B.vv,B.kU,B.lY,B.tY,B.hE,B.vz,B.tx,B.qn,B.lJ,B.oN,B.bJ,B.ax,B.ph,B.bO,B.jD,B.cu,B.tI,B.aE,B.eA,B.qZ,B.lk,B.ug,B.pj,B.nx,B.iD,B.k5,B.uq,B.hJ,B.uQ,B.fz,B.h2,B.bs,B.iL,B.kJ,B.bs,B.o_,B.tX,B.jK,B.ct,B.rk,B.j3,B.c7,B.w4,B.vg,B.i0,B.eH,B.qt,B.tD,B.wj,B.pi,B.hg,B.qT,B.r0,B.nn,B.uh,B.tq,B.u2,B.rK,B.ob,B.rE,B.ox,B.rU,B.tc,B.h_,B.qO,B.n3,B.mK,B.pY,B.mH,B.ni,B.ui,B.uy,B.fE,B.fk,B.oX,B.tJ,B.qv,B.kg,B.qj,B.ie,B.r_,B.fX,B.tN,B.l1,B.vq,B.ff,B.Y,B.ho,B.lU,B.pZ,B.hw,B.o4,B.jZ,B.as,B.fB,B.oB,B.lu,B.c2,B.px,B.i3,B.cm,B.pr,B.vi,B.nX,B.fd,B.eq,B.qB,B.nw,B.nr,B.kz,B.q3,B.hF,B.um,B.qQ,B.nA,B.kA,B.qJ,B.n7,B.iX,B.kF,B.mQ,B.vf,B.ub,B.uX,B.nb,B.rg,B.lW,B.tF,B.u3,B.mY,B.u9,B.rb,B.vV,B.lB,B.vL,B.fv,B.wn,B.t5,B.em,B.uL,B.pg,B.wE,B.f9,B.iN,B.kO,B.rQ,B.hv,B.vw,B.wF,B.fn,B.l6,B.uT,B.eV,B.bW,B.ft,B.fV,B.aE,B.c1,B.tG,B.jP,B.lQ,B.lR,B.cd,B.qK,B.p9,B.nv,B.uv,B.w6,B.ee,B.wu,B.f5,B.lf,B.ng,B.lA,B.jJ,B.hs,B.eP,B.qk,B.mL,B.i2,B.oW,B.vU,B.fq,B.h8,B.hq,B.by,B.j8,B.wv,B.lw,B.mB,B.fY,B.jY,B.c_,B.nZ,B.vT,B.u8,B.mF,B.v0,B.tV,B.jd,B.pN,B.av,B.c4,B.qx,B.j1,B.ce,B.cg,B.vm,B.jb,B.iQ,B.vE,B.lG,B.ay,B.ns,B.vo,B.oD,B.nW,B.mz,B.tk,B.fD,B.jU,B.iM,B.kj,B.jt,B.uw,B.oF,B.kC,B.wl,B.hx,B.ky,B.m9,B.oP,B.mN,B.vB,B.pG,B.kM,B.iG,B.eW,B.pn,B.nu,B.nc,B.aC,B.ig,B.c1,B.rv,B.hm,B.eD,B.tr,B.pd,B.rN,B.jj,B.hV,B.lS,B.jQ,B.kW,B.mV,B.qw,B.lO,B.qW,B.f1,B.kv,B.jW,B.fN,B.u4,B.fx,B.m4,B.wm,B.pQ,B.rt,B.fG,B.qd,B.kS,B.kq,B.n_,B.vJ,B.tE,B.oC,B.r6,B.qP,B.eB,B.ix,B.bF,B.aD,B.bP,B.v5,B.lN,B.bK,B.bM,B.cd,B.D,B.mv,B.hz,B.cq,B.ap,B.ck,B.bz,B.fu,B.pH,B.r5,B.ti,B.fh,B.jR,B.uE,B.th,B.o8,B.lF,B.ca,B.bN,B.jl,B.rT,B.nP,B.lv,B.co,B.bt,B.aD,B.ku,B.hD,B.by,B.vS,B.bG,B.bW,B.hO,B.bE,B.n0,B.Y,B.nf,B.fI,B.np,B.to,B.jx,B.ha,B.w9,B.hS,B.ou,B.ew,B.fy,B.fc,B.q5,B.vX,B.fZ,B.cg,B.pC,B.mZ,B.k0,B.kc,B.lE,B.pc,B.mU,B.i1,B.jq,B.vd,B.k4,B.uj,B.oc,B.js,B.rq,B.ur,B.eO,B.jr,B.i8,B.wI,B.nM,B.oq,B.ua,B.pU,B.qi,B.tA,B.ud,B.u5,B.va,B.lo,B.wA,B.tQ,B.nV,B.hH,B.er,B.f7,B.wg,B.tZ,B.jo,B.ih,B.vH,B.eY,B.tL,B.jw,B.mW,B.vr,B.mu,B.id,B.jO,B.bA,B.jv,B.pp,B.cr,B.hI,B.vO,B.eE,B.nj,B.wB,B.ay,B.t1,B.hK,B.h9,B.bA,B.hk,B.h3,B.qh,B.li,B.ip,B.j4,B.rW,B.io,B.ei,B.lc,B.kR,B.on,B.bw,B.hR,B.t,B.nk,B.cr,B.cD,B.fH,B.h6,B.il,B.pe,B.Z,B.c5,B.bR,B.t,B.qp,B.rn,B.v9,B.tC,B.O,B.cf,B.Z,B.ch,B.aB,B.ao,B.M,B.r,B.ay,B.z,B.od,B.fP,B.rH,B.N,B.bq,B.E,B.cl,B.r,B.cw,B.oY,B.fU,B.bx,B.rd,B.h7,B.bS,B.p7,B.tf,B.cB,B.pX,B.qX,B.c6,B.l2,B.it,B.br,B.fb,B.eL,B.cx,B.eu,B.f6,B.bI,B.uB,B.f8,B.nF,B.wt,B.pu,B.cn,B.pB,B.n2,B.cw,B.vp,B.vx,B.oI,B.cc,B.no,B.vy,B.bT,B.t,B.bx,B.pf,B.t_,B.hn,B.cc,B.oA,B.lI,B.n5,B.t,B.bS,B.z,B.jN,B.mX,B.O,B.cy,B.N,B.E,B.r,B.cB,B.z,B.aA,B.tt,B.O,B.bC,B.N,B.r,B.M,B.E,B.c6,B.lH,B.aA,B.om,B.O,B.bB,B.r,B.M,B.Z,B.ch,B.aB,B.ao,B.br,B.wp,B.aA,B.vC,B.O,B.bU,B.tK,B.uf,B.r,B.E,B.aB,B.ao,B.cx,B.z,B.eK,B.m7,B.ok,B.mq,B.is,B.M,B.Z,B.t,B.bI,B.cD,B.rP,B.t3,B.nY,B.jA,B.kP,B.k1,B.tS,B.bZ,B.bR,B.c5,B.t,B.l7,B.z,B.pm,B.k3,B.mM,B.nE,B.bZ,B.nB,B.cl,B.r,B.M,B.E,B.cn,B.z,B.k7,B.t6,B.v7,B.o3,B.im,B.rO,B.aC,B.r,B.E],A.Y("br<c,+(c,c,c)>"))
B.dK={DRAWING:0,TEXT:1,DIMENSIONS:2,CONTOURS:3,SPOT_HEIGHTS:4,ZONE_PIPES:5,MAINLINE_PIPES:6,SPRAYLINES:7,TAPES:8,OUTLETS:9,WETTED_RADII:10,CONTROL_VALVES:11,WATER_SUPPLY:12,PUMPS:13,MISC_HYDRAULIC:14,JUNCTIONS:15,AREAS:16,LABELS:17,IMAGES:18,HATCHES:19,SYMBOLS:20,PIVOTS:21}
B.dJ=new A.br(B.dK,[4289773253,4293718001,4287669422,4287458915,4288776319,4282557941,4280191205,4280731354,4284922730,4280923894,1428797174,4294944550,4286470082,4293874512,4294953512,4286091420,867095937,4291811548,4294967295,4286091420,4289773253,4283283116],A.Y("br<c,f>"))
B.an=new A.z(0,0)
B.dU=new A.cN(0,0,0,1)
B.bp=new A.A(0,0)
B.dV=new A.A(0,45)
B.dW=new A.A(0,58)
B.dX=new A.A(0,70)
B.dY=new A.A(0,80)
B.dZ=new A.A(0.001388888888888889,41)
B.e_=new A.A(0.03333333333333333,55)
B.e0=new A.A(0.006944444444444444,60)
B.e1=new A.A(0.005555555555555556,53)
B.e2=new A.A("","")
B.e3=new A.A(0.016666666666666666,30)
B.e4=new A.A(0.011111111111111112,45)
B.e5=new A.A(0.009722222222222222,40)
B.e6=new A.A(0.004166666666666667,25)
B.e7=new A.A(0.002777777777777778,35)
B.e8=new A.A(0,1/0)
B.e9=new A.A(0.003333333333333333,72)
B.ea=new A.A(0.05,38)
B.eb=new A.A(0.016666666666666666,64)
B.wK=new A.cW([0,0,0,0])
B.wM=new A.c5(B.aj,0,A.Y("c5<c>"))
B.wL=new A.c5(B.aj,0,A.Y("c5<f>"))
B.wY=A.be("qg")
B.wZ=A.be("qh")
B.x_=A.be("nN")
B.x0=A.be("bu")
B.x1=A.be("nO")
B.x2=A.be("nP")
B.x3=A.be("nQ")
B.x4=A.be("I")
B.x5=A.be("om")
B.x6=A.be("on")
B.x7=A.be("oo")
B.x8=A.be("l4")
B.cE=new A.dE(0,0,0,0,0,0,0,0,0,0)
B.cF=new A.eU(B.bc,B.b7,B.bo,B.aR)})();(function staticFields(){$.jN=null
$.aS=A.d([],A.Y("n<I>"))
$.lR=null
$.lx=null
$.lw=null
$.mP=null
$.mG=null
$.n_=null
$.ka=null
$.kl=null
$.ll=null
$.jS=A.d([],A.Y("n<o<I>?>"))
$.cY=null
$.dX=null
$.dY=null
$.ld=!1
$.a5=B.u
$.l_=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"qj","n4",()=>A.ke("_$dart_dartClosure"))
s($,"qi","lo",()=>A.ke("_$dart_dartClosure_dartJSInterop"))
s($,"qD","nj",()=>A.d([new J.ej()],A.Y("n<dx>")))
s($,"qp","n7",()=>A.bG(A.jl({
toString:function(){return"$receiver$"}})))
s($,"qq","n8",()=>A.bG(A.jl({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"qr","n9",()=>A.bG(A.jl(null)))
s($,"qs","na",()=>A.bG(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"qv","nd",()=>A.bG(A.jl(void 0)))
s($,"qw","ne",()=>A.bG(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"qu","nc",()=>A.bG(A.m7(null)))
s($,"qt","nb",()=>A.bG(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"qy","ng",()=>A.bG(A.m7(void 0)))
s($,"qx","nf",()=>A.bG(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"qz","lp",()=>A.or())
s($,"qB","ni",()=>A.nY(A.p2(A.d([-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-1,-2,-2,-2,-2,-2,62,-2,62,-2,63,52,53,54,55,56,57,58,59,60,61,-2,-2,-2,-1,-2,-2,-2,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-2,-2,-2,-2,63,-2,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,-2,-2,-2,-2,-2],t.X))))
s($,"qA","nh",()=>A.nZ(0))
s($,"qk","n5",()=>A.ob("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"qC","fv",()=>A.mX(B.x4))
s($,"qm","n6",()=>A.kT(0,"",B.an,B.f))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.cH,SharedArrayBuffer:A.cH,ArrayBufferView:A.dt,DataView:A.ew,Float32Array:A.ex,Float64Array:A.ey,Int16Array:A.ez,Int32Array:A.eA,Int8Array:A.eB,Uint16Array:A.eC,Uint32Array:A.eD,Uint8ClampedArray:A.du,CanvasPixelArray:A.du,Uint8Array:A.eE})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.cI.$nativeSuperclassTag="ArrayBufferView"
A.dK.$nativeSuperclassTag="ArrayBufferView"
A.dL.$nativeSuperclassTag="ArrayBufferView"
A.dr.$nativeSuperclassTag="ArrayBufferView"
A.dM.$nativeSuperclassTag="ArrayBufferView"
A.dN.$nativeSuperclassTag="ArrayBufferView"
A.ds.$nativeSuperclassTag="ArrayBufferView"})()
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
var s=A.q0
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()