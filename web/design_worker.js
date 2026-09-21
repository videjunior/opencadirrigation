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
if(a[b]!==s){A.qh(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.d(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.lk(b)
return new s(c,this)}:function(){if(s===null)s=A.lk(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.lk(a).prototype
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
lp(a,b,c,d){return{i:a,p:b,e:c,x:d}},
ll(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.ln==null){A.pZ()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.l(A.ma("Return interceptor for "+A.z(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.jO
if(o==null)o=$.jO=A.kg(n)
p=q[o]}if(p!=null)return p
p=A.q3(a)
if(p!=null)return p
if(typeof a=="function")return B.dc
s=Object.getPrototypeOf(a)
if(s==null)return B.bs
if(s===Object.prototype)return B.bs
if(typeof q=="function"){o=$.jO
if(o==null)o=$.jO=A.kg(n)
Object.defineProperty(q,o,{value:B.aP,enumerable:false,writable:true,configurable:true})
return B.aP}return B.aP},
lL(a,b){if(a<0||a>4294967295)throw A.l(A.aQ(a,0,4294967295,"length",null))
return J.nW(new Array(a),b)},
lM(a,b){if(a<0)throw A.l(A.d4("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("o<0>"))},
el(a,b){if(a<0)throw A.l(A.d4("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("o<0>"))},
nW(a,b){var s=A.d(a,b.j("o<0>"))
s.$flags=1
return s},
nX(a,b){var s=t.bP
return J.lu(s.a(a),s.a(b))},
lN(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
nY(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.lN(r))break;++b}return b},
nZ(a,b){var s,r,q
for(s=a.length;b>0;b=r){r=b-1
if(!(r<s))return A.b(a,r)
q=a.charCodeAt(r)
if(q!==32&&q!==13&&!J.lN(q))break}return b},
cy(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.dg.prototype
return J.en.prototype}if(typeof a=="string")return J.cg.prototype
if(a==null)return J.dh.prototype
if(typeof a=="boolean")return J.em.prototype
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bU.prototype
if(typeof a=="symbol")return J.dk.prototype
if(typeof a=="bigint")return J.di.prototype
return a}if(a instanceof A.J)return a
return J.ll(a)},
af(a){if(typeof a=="string")return J.cg.prototype
if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bU.prototype
if(typeof a=="symbol")return J.dk.prototype
if(typeof a=="bigint")return J.di.prototype
return a}if(a instanceof A.J)return a
return J.ll(a)},
a1(a){if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bU.prototype
if(typeof a=="symbol")return J.dk.prototype
if(typeof a=="bigint")return J.di.prototype
return a}if(a instanceof A.J)return a
return J.ll(a)},
pT(a){if(typeof a=="number")return J.cf.prototype
if(a==null)return a
if(!(a instanceof A.J))return J.cq.prototype
return a},
pU(a){if(typeof a=="number")return J.cf.prototype
if(typeof a=="string")return J.cg.prototype
if(a==null)return a
if(!(a instanceof A.J))return J.cq.prototype
return a},
aW(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.cy(a).Y(a,b)},
ls(a,b){if(typeof a=="number"&&typeof b=="number")return a-b
return J.pT(a).U(a,b)},
fx(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.q2(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.af(a).h(a,b)},
kS(a,b,c){return J.a1(a).i(a,b,c)},
bM(a,b){return J.a1(a).k(a,b)},
lt(a,b){return J.a1(a).B(a,b)},
nn(a,b){return J.a1(a).aY(a,b)},
lu(a,b){return J.pU(a).S(a,b)},
fy(a,b){return J.a1(a).I(a,b)},
no(a,b,c,d){return J.a1(a).W(a,b,c,d)},
bN(a){return J.a1(a).gu(a)},
aK(a){return J.cy(a).gK(a)},
lv(a){return J.af(a).gF(a)},
np(a){return J.af(a).ga8(a)},
ab(a){return J.a1(a).gt(a)},
kT(a){return J.a1(a).gM(a)},
au(a){return J.af(a).gm(a)},
nq(a){return J.a1(a).gcs(a)},
nr(a){return J.cy(a).gO(a)},
aE(a,b,c){return J.a1(a).aH(a,b,c)},
ns(a,b){return J.af(a).sm(a,b)},
lw(a,b){return J.a1(a).a3(a,b)},
d2(a){return J.cy(a).q(a)},
ej:function ej(){},
em:function em(){},
dh:function dh(){},
dj:function dj(){},
bV:function bV(){},
eJ:function eJ(){},
cq:function cq(){},
bU:function bU(){},
di:function di(){},
dk:function dk(){},
o:function o(a){this.$ti=a},
ek:function ek(){},
ib:function ib(a){this.$ti=a},
c5:function c5(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
cf:function cf(){},
dg:function dg(){},
en:function en(){},
cg:function cg(){}},A={kX:function kX(){},
lB(a,b,c){if(t.Y.b(a))return new A.dJ(a,b.j("@<0>").A(c).j("dJ<1,2>"))
return new A.c6(a,b.j("@<0>").A(c).j("c6<1,2>"))},
lP(a){return new A.et("Field '"+a+"' has been assigned during initialization.")},
bE(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
jb(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
cx(a,b,c){return a},
lo(a){var s,r
for(s=$.aU.length,r=0;r<s;++r)if(a===$.aU[r])return!0
return!1},
bY(a,b,c,d){A.cP(b,"start")
if(c!=null){A.cP(c,"end")
if(b>c)A.bs(A.aQ(b,0,c,"start",null))}return new A.dE(a,b,c,d.j("dE<0>"))},
l_(a,b,c,d){if(t.Y.b(a))return new A.cb(a,b,c.j("@<0>").A(d).j("cb<1,2>"))
return new A.bz(a,b,c.j("@<0>").A(d).j("bz<1,2>"))},
m6(a,b,c){if(t.Y.b(a)){A.k1(b)
return void 1}A.k1(b)
return void 1},
k1(a){A.nt(a,"count",t.S)},
av(){return new A.dD("No element")},
c_:function c_(){},
d6:function d6(a,b){this.a=a
this.$ti=b},
c6:function c6(a,b){this.a=a
this.$ti=b},
dJ:function dJ(a,b){this.a=a
this.$ti=b},
dI:function dI(){},
ac:function ac(a,b){this.a=a
this.$ti=b},
et:function et(a){this.a=a},
j0:function j0(){},
y:function y(){},
u:function u(){},
dE:function dE(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aN:function aN(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bz:function bz(a,b,c){this.a=a
this.b=b
this.$ti=c},
cb:function cb(a,b,c){this.a=a
this.b=b
this.$ti=c},
dr:function dr(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
t:function t(a,b,c){this.a=a
this.b=b
this.$ti=c},
B:function B(a,b,c){this.a=a
this.b=b
this.$ti=c},
dH:function dH(a,b,c){this.a=a
this.b=b
this.$ti=c},
dz:function dz(a,b,c){this.a=a
this.b=b
this.$ti=c},
i0:function i0(a,b,c){this.a=a
this.b=b
this.$ti=c},
dA:function dA(a,b,c){this.a=a
this.b=b
this.$ti=c},
d9:function d9(a){this.$ti=a},
da:function da(a){this.$ti=a},
cr:function cr(a,b){this.a=a
this.$ti=b},
bI:function bI(a,b){this.a=a
this.$ti=b},
U:function U(){},
bp:function bp(a,b){this.a=a
this.$ti=b},
dW:function dW(){},
lE(){throw A.l(A.bq("Cannot modify unmodifiable Map"))},
lF(){throw A.l(A.bq("Cannot modify constant Set"))},
n6(a){var s=A.n5(a)
if(s!=null)return s
return"minified:"+a},
q2(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.dX.b(a)},
z(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.d2(a)
return s},
eL(a){var s,r=$.lT
if(r==null)r=$.lT=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
o8(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.b(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
eM(a){var s,r,q,p
if(a instanceof A.J)return A.aD(A.ax(a),null)
s=J.cy(a)
if(s===B.db||s===B.dd||t.cx.b(a)){r=B.aR(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.aD(A.ax(a),null)},
m_(a){var s,r,q
if(a==null||typeof a=="number"||A.le(a))return J.d2(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.az)return a.q(0)
if(a instanceof A.b5)return a.cb(!0)
s=$.nm()
for(r=0;r<1;++r){q=s[r].e0(a)
if(q!=null)return q}return"Instance of '"+A.eM(a)+"'"},
o9(a,b,c){var s,r,q,p
if(c<=500&&b===0&&c===a.length)return String.fromCharCode.apply(null,a)
for(s=b,r="";s<c;s=q){q=s+500
p=q<c?q:c
r+=String.fromCharCode.apply(null,a.subarray(s,p))}return r},
ar(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aU(s,10)|55296)>>>0,s&1023|56320)}throw A.l(A.aQ(a,0,1114111,null,null))},
oa(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.b6(h,1000)
g+=B.c.bn(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
aO(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
eK(a){return a.c?A.aO(a).getUTCFullYear()+0:A.aO(a).getFullYear()+0},
lY(a){return a.c?A.aO(a).getUTCMonth()+1:A.aO(a).getMonth()+1},
lU(a){return a.c?A.aO(a).getUTCDate()+0:A.aO(a).getDate()+0},
lV(a){return a.c?A.aO(a).getUTCHours()+0:A.aO(a).getHours()+0},
lX(a){return a.c?A.aO(a).getUTCMinutes()+0:A.aO(a).getMinutes()+0},
lZ(a){return a.c?A.aO(a).getUTCSeconds()+0:A.aO(a).getSeconds()+0},
lW(a){return a.c?A.aO(a).getUTCMilliseconds()+0:A.aO(a).getMilliseconds()+0},
o7(a){var s=a.$thrownJsError
if(s==null)return null
return A.cz(s)},
cA(a){throw A.l(A.mK(a))},
b(a,b){if(a==null)J.au(a)
throw A.l(A.fs(a,b))},
fs(a,b){var s,r="index"
if(!A.mz(b))return new A.bi(!0,b,r,null)
s=A.a0(J.au(a))
if(b<0||b>=s)return A.ia(b,s,a,r)
return A.l2(b,r)},
mK(a){return new A.bi(!0,a,null,null)},
li(a){return a},
l(a){return A.a9(a,new Error())},
a9(a,b){var s
if(a==null)a=new A.bG()
b.dartException=a
s=A.qj
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
qj(){return J.d2(this.dartException)},
bs(a,b){throw A.a9(a,b==null?new Error():b)},
aa(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.bs(A.p5(a,b,c),s)},
p5(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.dG("'"+s+"': Cannot "+o+" "+l+k+n)},
k(a){throw A.l(A.am(a))},
bH(a){var s,r,q,p,o,n
a=A.n3(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.d([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.jl(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
jm(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
m9(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
kY(a,b){var s=b==null,r=s?null:b.method
return new A.ep(a,r,s?null:b.receiver)},
bL(a){var s
if(a==null)return new A.iC(a)
if(a instanceof A.db){s=a.a
return A.c4(a,s==null?A.dX(s):s)}if(typeof a!=="object")return a
if("dartException" in a)return A.c4(a,a.dartException)
return A.pF(a)},
c4(a,b){if(t.fz.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
pF(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aU(r,16)&8191)===10)switch(q){case 438:return A.c4(a,A.kY(A.z(s)+" (Error "+q+")",null))
case 445:case 5007:A.z(s)
return A.c4(a,new A.dw())}}if(a instanceof TypeError){p=$.na()
o=$.nb()
n=$.nc()
m=$.nd()
l=$.ng()
k=$.nh()
j=$.nf()
$.ne()
i=$.nj()
h=$.ni()
g=p.aa(s)
if(g!=null)return A.c4(a,A.kY(A.C(s),g))
else{g=o.aa(s)
if(g!=null){g.method="call"
return A.c4(a,A.kY(A.C(s),g))}else if(n.aa(s)!=null||m.aa(s)!=null||l.aa(s)!=null||k.aa(s)!=null||j.aa(s)!=null||m.aa(s)!=null||i.aa(s)!=null||h.aa(s)!=null){A.C(s)
return A.c4(a,new A.dw())}}return A.c4(a,new A.eW(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.dC()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.c4(a,new A.bi(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.dC()
return a},
cz(a){var s
if(a instanceof A.db)return a.b
if(a==null)return new A.dQ(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.dQ(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
mZ(a){if(a==null)return J.aK(a)
if(typeof a=="object")return A.eL(a)
return J.aK(a)},
pR(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.i(0,a[s],a[r])}return b},
pS(a,b){var s,r=a.length
for(s=0;s<r;++s)b.k(0,a[s])
return b},
pf(a,b,c,d,e,f){t.Z.a(a)
switch(A.a0(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.l(new A.jD("Unsupported number of arguments for wrapped closure"))},
fr(a,b){var s=a.$identity
if(!!s)return s
s=A.pL(a,b)
a.$identity=s
return s},
pL(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.pf)},
nE(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.eP().constructor.prototype):Object.create(new A.cD(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.lD(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.nA(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.lD(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
nA(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.l("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.nu)}throw A.l("Error in functionType of tearoff")},
nB(a,b,c,d){var s=A.lA
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
lD(a,b,c,d){if(c)return A.nD(a,b,d)
return A.nB(b.length,d,a,b)},
nC(a,b,c,d){var s=A.lA,r=A.nv
switch(b?-1:a){case 0:throw A.l(new A.eO("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
nD(a,b,c){var s,r
if($.ly==null)$.ly=A.lx("interceptor")
if($.lz==null)$.lz=A.lx("receiver")
s=b.length
r=A.nC(s,c,a,b)
return r},
lk(a){return A.nE(a)},
nu(a,b){return A.dU(v.typeUniverse,A.ax(a.a),b)},
lA(a){return a.a},
nv(a){return a.b},
lx(a){var s,r,q,p=new A.cD("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.l(A.d4("Field name "+a+" not found.",null))},
kg(a){return v.getIsolateTag(a)},
q3(a){var s,r,q,p,o,n=A.C($.mR.$1(a)),m=$.kc[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.kn[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=A.w($.mI.$2(a,n))
if(q!=null){m=$.kc[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.kn[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.kt(s)
$.kc[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.kn[n]=s
return s}if(p==="-"){o=A.kt(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.n1(a,s)
if(p==="*")throw A.l(A.ma(n))
if(v.leafTags[n]===true){o=A.kt(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.n1(a,s)},
n1(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.lp(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
kt(a){return J.lp(a,!1,null,!!a.$iaM)},
q5(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.kt(s)
else return J.lp(s,c,null,null)},
pZ(){if(!0===$.ln)return
$.ln=!0
A.q_()},
q_(){var s,r,q,p,o,n,m,l
$.kc=Object.create(null)
$.kn=Object.create(null)
A.pY()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.n2.$1(o)
if(n!=null){m=A.q5(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
pY(){var s,r,q,p,o,n,m=B.cS()
m=A.d0(B.cT,A.d0(B.cU,A.d0(B.aS,A.d0(B.aS,A.d0(B.cV,A.d0(B.cW,A.d0(B.cX(B.aR),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.mR=new A.kk(p)
$.mI=new A.kl(o)
$.n2=new A.km(n)},
d0(a,b){return a(b)||b},
oN(a,b){var s,r
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.b(b,s)
if(!J.aW(r,b[s]))return!1}return!0},
pN(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
o_(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.l(A.bb("Illegal RegExp pattern ("+String(o)+")",a,null))},
pP(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
n3(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
qf(a,b,c){var s=A.qg(a,b,c)
return s},
qg(a,b,c){var s,r,q
if(b===""){if(a==="")return c
s=a.length
for(r=c,q=0;q<s;++q)r=r+a[q]+c
return r.charCodeAt(0)==0?r:r}if(a.indexOf(b,0)<0)return a
if(a.length<500||c.indexOf("$",0)>=0)return a.split(b).join(c)
return a.replace(new RegExp(A.n3(b),"g"),A.pP(c))},
m:function m(a,b){this.a=a
this.b=b},
a:function a(a,b,c){this.a=a
this.b=b
this.c=c},
cX:function cX(a){this.a=a},
aT:function aT(a){this.a=a},
d7:function d7(){},
b8:function b8(a,b,c){this.a=a
this.b=b
this.$ti=c},
dK:function dK(a,b){this.a=a
this.$ti=b},
ct:function ct(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
d8:function d8(){},
bP:function bP(a,b,c){this.a=a
this.b=b
this.$ti=c},
ei:function ei(){},
ce:function ce(a,b){this.a=a
this.$ti=b},
dy:function dy(){},
jl:function jl(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dw:function dw(){},
ep:function ep(a,b,c){this.a=a
this.b=b
this.c=c},
eW:function eW(a){this.a=a},
iC:function iC(a){this.a=a},
db:function db(a,b){this.a=a
this.b=b},
dQ:function dQ(a){this.a=a
this.b=null},
az:function az(){},
e5:function e5(){},
e6:function e6(){},
eR:function eR(){},
eP:function eP(){},
cD:function cD(a,b){this.a=a
this.b=b},
eO:function eO(a){this.a=a},
bx:function bx(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ic:function ic(a){this.a=a},
ig:function ig(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
a4:function a4(a,b){this.a=a
this.$ti=b},
an:function an(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ao:function ao(a,b){this.a=a
this.$ti=b},
N:function N(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
L:function L(a,b){this.a=a
this.$ti=b},
ag:function ag(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
kk:function kk(a){this.a=a},
kl:function kl(a){this.a=a},
km:function km(a){this.a=a},
b5:function b5(){},
cV:function cV(){},
cW:function cW(){},
cv:function cv(){},
eo:function eo(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
jS:function jS(a){this.b=a},
p6(a){return a},
o1(a){return new Int8Array(a)},
o2(a){return new Uint8Array(a)},
bJ(a,b,c){if(a>>>0!==a||a>=c)throw A.l(A.fs(b,a))},
cI:function cI(){},
du:function du(){},
ey:function ey(){},
cJ:function cJ(){},
ds:function ds(){},
dt:function dt(){},
ez:function ez(){},
eA:function eA(){},
eB:function eB(){},
eC:function eC(){},
eD:function eD(){},
eE:function eE(){},
eF:function eF(){},
dv:function dv(){},
eG:function eG(){},
dL:function dL(){},
dM:function dM(){},
dN:function dN(){},
dO:function dO(){},
l3(a,b){var s=b.c
return s==null?b.c=A.dS(a,"bl",[b.x]):s},
m5(a){var s=a.w
if(s===6||s===7)return A.m5(a.x)
return s===11||s===12},
og(a){return a.as},
n0(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
X(a){return A.jY(v.typeUniverse,a,!1)},
q1(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.c3(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
c3(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.c3(a1,s,a3,a4)
if(r===s)return a2
return A.mk(a1,r,!0)
case 7:s=a2.x
r=A.c3(a1,s,a3,a4)
if(r===s)return a2
return A.mj(a1,r,!0)
case 8:q=a2.y
p=A.d_(a1,q,a3,a4)
if(p===q)return a2
return A.dS(a1,a2.x,p)
case 9:o=a2.x
n=A.c3(a1,o,a3,a4)
m=a2.y
l=A.d_(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.la(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.d_(a1,j,a3,a4)
if(i===j)return a2
return A.ml(a1,k,i)
case 11:h=a2.x
g=A.c3(a1,h,a3,a4)
f=a2.y
e=A.pC(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.mi(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.d_(a1,d,a3,a4)
o=a2.x
n=A.c3(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.lb(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.l(A.e2("Attempted to substitute unexpected RTI kind "+a0))}},
d_(a,b,c,d){var s,r,q,p,o=b.length,n=A.jZ(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.c3(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
pD(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.jZ(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.c3(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
pC(a,b,c,d){var s,r=b.a,q=A.d_(a,r,c,d),p=b.b,o=A.d_(a,p,c,d),n=b.c,m=A.pD(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.f3()
s.a=q
s.b=o
s.c=m
return s},
d(a,b){a[v.arrayRti]=b
return a},
kb(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.pW(s)
return a.$S()}return null},
q0(a,b){var s
if(A.m5(b))if(a instanceof A.az){s=A.kb(a)
if(s!=null)return s}return A.ax(a)},
ax(a){if(a instanceof A.J)return A.i(a)
if(Array.isArray(a))return A.r(a)
return A.ld(J.cy(a))},
r(a){var s=a[v.arrayRti],r=t.dG
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.ld(a)},
ld(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.pd(a,s)},
pd(a,b){var s=a instanceof A.az?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.oX(v.typeUniverse,s.name)
b.$ccache=r
return r},
pW(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.jY(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
pV(a){return A.bK(A.i(a))},
lm(a){var s=A.kb(a)
return A.bK(s==null?A.ax(a):s)},
lh(a){var s
if(a instanceof A.b5)return A.pQ(a.$r,a.aL())
s=a instanceof A.az?A.kb(a):null
if(s!=null)return s
if(t.aJ.b(a))return J.nr(a).a
if(Array.isArray(a))return A.r(a)
return A.ax(a)},
bK(a){var s=a.r
return s==null?a.r=new A.jX(a):s},
pQ(a,b){var s,r,q=b,p=q.length
if(p===0)return t.aK
if(0>=p)return A.b(q,0)
s=A.dU(v.typeUniverse,A.lh(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.b(q,r)
s=A.mn(v.typeUniverse,s,A.lh(q[r]))}return A.dU(v.typeUniverse,s,a)},
bh(a){return A.bK(A.jY(v.typeUniverse,a,!1))},
pc(a){var s=this
s.b=A.pA(s)
return s.b(a)},
pA(a){var s,r,q,p,o
if(a===t.K)return A.pl
if(A.cB(a))return A.pp
s=a.w
if(s===6)return A.pa
if(s===1)return A.mB
if(s===7)return A.pg
r=A.pz(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.cB)){a.f="$i"+q
if(q==="p")return A.pj
if(a===t.m)return A.pi
return A.po}}else if(s===10){p=A.pN(a.x,a.y)
o=p==null?A.mB:p
return o==null?A.dX(o):o}return A.p8},
pz(a){if(a.w===8){if(a===t.S)return A.mz
if(a===t.i||a===t.H)return A.pk
if(a===t.N)return A.pn
if(a===t.y)return A.le}return null},
pb(a){var s=this,r=A.p7
if(A.cB(s))r=A.p1
else if(s===t.K)r=A.dX
else if(A.d1(s)){r=A.p9
if(s===t.aV)r=A.mq
else if(s===t.bl)r=A.w
else if(s===t.o9)r=A.W
else if(s===t.jh)r=A.x
else if(s===t.jX)r=A.p_
else if(s===t.mU)r=A.p0}else if(s===t.S)r=A.a0
else if(s===t.N)r=A.C
else if(s===t.y)r=A.oZ
else if(s===t.H)r=A.at
else if(s===t.i)r=A.T
else if(s===t.m)r=A.mr
s.a=r
return s.a(a)},
p8(a){var s=this
if(a==null)return A.d1(s)
return A.mU(v.typeUniverse,A.q0(a,s),s)},
pa(a){if(a==null)return!0
return this.x.b(a)},
po(a){var s,r=this
if(a==null)return A.d1(r)
s=r.f
if(a instanceof A.J)return!!a[s]
return!!J.cy(a)[s]},
pj(a){var s,r=this
if(a==null)return A.d1(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.J)return!!a[s]
return!!J.cy(a)[s]},
pi(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.J)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
mA(a){if(typeof a=="object"){if(a instanceof A.J)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
p7(a){var s=this
if(a==null){if(A.d1(s))return a}else if(s.b(a))return a
throw A.a9(A.mw(a,s),new Error())},
p9(a){var s=this
if(a==null||s.b(a))return a
throw A.a9(A.mw(a,s),new Error())},
mw(a,b){return new A.cY("TypeError: "+A.md(a,A.aD(b,null)))},
mM(a,b,c,d){if(A.mU(v.typeUniverse,a,b))return a
throw A.a9(A.oP("The type argument '"+A.aD(a,null)+"' is not a subtype of the type variable bound '"+A.aD(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
md(a,b){return A.ec(a)+": type '"+A.aD(A.lh(a),null)+"' is not a subtype of type '"+b+"'"},
oP(a){return new A.cY("TypeError: "+a)},
b6(a,b){return new A.cY("TypeError: "+A.md(a,b))},
pg(a){var s=this
return s.x.b(a)||A.l3(v.typeUniverse,s).b(a)},
pl(a){return a!=null},
dX(a){if(a!=null)return a
throw A.a9(A.b6(a,"Object"),new Error())},
pp(a){return!0},
p1(a){return a},
mB(a){return!1},
le(a){return!0===a||!1===a},
oZ(a){if(!0===a)return!0
if(!1===a)return!1
throw A.a9(A.b6(a,"bool"),new Error())},
W(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.a9(A.b6(a,"bool?"),new Error())},
T(a){if(typeof a=="number")return a
throw A.a9(A.b6(a,"double"),new Error())},
p_(a){if(typeof a=="number")return a
if(a==null)return a
throw A.a9(A.b6(a,"double?"),new Error())},
mz(a){return typeof a=="number"&&Math.floor(a)===a},
a0(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.a9(A.b6(a,"int"),new Error())},
mq(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.a9(A.b6(a,"int?"),new Error())},
pk(a){return typeof a=="number"},
at(a){if(typeof a=="number")return a
throw A.a9(A.b6(a,"num"),new Error())},
x(a){if(typeof a=="number")return a
if(a==null)return a
throw A.a9(A.b6(a,"num?"),new Error())},
pn(a){return typeof a=="string"},
C(a){if(typeof a=="string")return a
throw A.a9(A.b6(a,"String"),new Error())},
w(a){if(typeof a=="string")return a
if(a==null)return a
throw A.a9(A.b6(a,"String?"),new Error())},
mr(a){if(A.mA(a))return a
throw A.a9(A.b6(a,"JSObject"),new Error())},
p0(a){if(a==null)return a
if(A.mA(a))return a
throw A.a9(A.b6(a,"JSObject?"),new Error())},
mF(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.aD(a[q],b)
return s},
pu(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.mF(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.aD(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
mx(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
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
if(!(j===2||j===3||j===4||j===5||k===p))o+=" extends "+A.aD(k,a4)}o+=">"}else o=""
p=a3.x
i=a3.y
h=i.a
g=h.length
f=i.b
e=f.length
d=i.c
c=d.length
b=A.aD(p,a4)
for(a="",a0="",q=0;q<g;++q,a0=a1)a+=a0+A.aD(h[q],a4)
if(e>0){a+=a0+"["
for(a0="",q=0;q<e;++q,a0=a1)a+=a0+A.aD(f[q],a4)
a+="]"}if(c>0){a+=a0+"{"
for(a0="",q=0;q<c;q+=3,a0=a1){a+=a0
if(d[q+1])a+="required "
a+=A.aD(d[q+2],a4)+" "+d[q]}a+="}"}if(a2!=null){a4.toString
a4.length=a2}return o+"("+a+") => "+b},
aD(a,b){var s,r,q,p,o,n,m,l=a.w
if(l===5)return"erased"
if(l===2)return"dynamic"
if(l===3)return"void"
if(l===1)return"Never"
if(l===4)return"any"
if(l===6){s=a.x
r=A.aD(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(l===7)return"FutureOr<"+A.aD(a.x,b)+">"
if(l===8){p=A.pE(a.x)
o=a.y
return o.length>0?p+("<"+A.mF(o,b)+">"):p}if(l===10)return A.pu(a,b)
if(l===11)return A.mx(a,b,null)
if(l===12)return A.mx(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.b(b,n)
return b[n]}return"?"},
pE(a){var s=A.n5(a)
if(s!=null)return s
return"minified:"+a},
oY(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
oX(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.jY(a,b,!1)
else if(typeof m=="number"){s=m
r=A.dT(a,5,"#")
q=A.jZ(s)
for(p=0;p<s;++p)q[p]=r
o=A.dS(a,b,q)
n[b]=o
return o}else return m},
oW(a,b){return A.mo(a.tR,b)},
oV(a,b){return A.mo(a.eT,b)},
jY(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.mm(a,null,b,!1)
r.set(b,s)
return s},
dU(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.mm(a,b,c,!0)
q.set(c,r)
return r},
mn(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.la(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
mm(a,b,c,d){return A.oL(A.oF(a,b,c,d))},
c1(a,b){b.a=A.pb
b.b=A.pc
return b},
dT(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.bg(null,null)
s.w=b
s.as=c
r=A.c1(a,s)
a.eC.set(c,r)
return r},
mk(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.oT(a,b,r,c)
a.eC.set(r,s)
return s},
oT(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.cB(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.d1(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.bg(null,null)
q.w=6
q.x=b
q.as=c
return A.c1(a,q)},
mj(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.oR(a,b,r,c)
a.eC.set(r,s)
return s},
oR(a,b,c,d){var s,r
if(d){s=b.w
if(A.cB(b)||b===t.K)return b
else if(s===1)return A.dS(a,"bl",[b])
else if(b===t.a||b===t.T)return t.gK}r=new A.bg(null,null)
r.w=7
r.x=b
r.as=c
return A.c1(a,r)},
oU(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.bg(null,null)
s.w=13
s.x=b
s.as=q
r=A.c1(a,s)
a.eC.set(q,r)
return r},
dR(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
oQ(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
dS(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.dR(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.bg(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.c1(a,r)
a.eC.set(p,q)
return q},
la(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.dR(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.bg(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.c1(a,o)
a.eC.set(q,n)
return n},
ml(a,b,c){var s,r,q="+"+(b+"("+A.dR(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.bg(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.c1(a,s)
a.eC.set(q,r)
return r},
mi(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.dR(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.dR(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.oQ(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.bg(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.c1(a,p)
a.eC.set(r,o)
return o},
lb(a,b,c,d){var s,r=b.as+("<"+A.dR(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.oS(a,b,c,r,d)
a.eC.set(r,s)
return s},
oS(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.jZ(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.c3(a,b,r,0)
m=A.d_(a,c,r,0)
return A.lb(a,n,m,c!==m)}}l=new A.bg(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.c1(a,l)},
oF(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
oL(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.oH(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.mf(a,r,l,k,!1)
else if(q===46)r=A.mf(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.cu(a.u,a.e,k.pop()))
break
case 94:k.push(A.oU(a.u,k.pop()))
break
case 35:k.push(A.dT(a.u,5,"#"))
break
case 64:k.push(A.dT(a.u,2,"@"))
break
case 126:k.push(A.dT(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.oJ(a,k)
break
case 38:A.oI(a,k)
break
case 63:p=a.u
k.push(A.mk(p,A.cu(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.mj(p,A.cu(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.oG(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.mg(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.oM(a.u,a.e,o)
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
return A.cu(a.u,a.e,m)},
oH(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
mf(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.oY(s,o.x)[p]
if(n==null)A.bs('No "'+p+'" in "'+A.og(o)+'"')
d.push(A.dU(s,o,n))}else d.push(p)
return m},
oJ(a,b){var s,r=a.u,q=A.me(a,b),p=b.pop()
if(typeof p=="string")b.push(A.dS(r,p,q))
else{s=A.cu(r,a.e,p)
switch(s.w){case 11:b.push(A.lb(r,s,q,a.n))
break
default:b.push(A.la(r,s,q))
break}}},
oG(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.me(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.cu(p,a.e,o)
q=new A.f3()
q.a=s
q.b=n
q.c=m
b.push(A.mi(p,r,q))
return
case-4:b.push(A.ml(p,b.pop(),s))
return
default:throw A.l(A.e2("Unexpected state under `()`: "+A.z(o)))}},
oI(a,b){var s=b.pop()
if(0===s){b.push(A.dT(a.u,1,"0&"))
return}if(1===s){b.push(A.dT(a.u,4,"1&"))
return}throw A.l(A.e2("Unexpected extended operation "+A.z(s)))},
me(a,b){var s=b.splice(a.p)
A.mg(a.u,a.e,s)
a.p=b.pop()
return s},
cu(a,b,c){if(typeof c=="string")return A.dS(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.oK(a,b,c)}else return c},
mg(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.cu(a,b,c[s])},
oM(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.cu(a,b,c[s])},
oK(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.l(A.e2("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.l(A.e2("Bad index "+c+" for "+b.q(0)))},
mU(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.a8(a,b,null,c,null)
r.set(c,s)}return s},
a8(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.cB(d))return!0
s=b.w
if(s===4)return!0
if(A.cB(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.a8(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.a8(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.a8(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.a8(a,b.x,c,d,e))return!1
return A.a8(a,A.l3(a,b),c,d,e)}if(s===6)return A.a8(a,p,c,d,e)&&A.a8(a,b.x,c,d,e)
if(q===7){if(A.a8(a,b,c,d.x,e))return!0
return A.a8(a,b,c,A.l3(a,d),e)}if(q===6)return A.a8(a,b,c,p,e)||A.a8(a,b,c,d.x,e)
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
if(!A.a8(a,j,c,i,e)||!A.a8(a,i,e,j,c))return!1}return A.my(a,b.x,c,d.x,e)}if(q===11){if(b===t.dY)return!0
if(p)return!1
return A.my(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.ph(a,b,c,d,e)}if(o&&q===10)return A.pm(a,b,c,d,e)
return!1},
my(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.a8(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.a8(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.a8(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.a8(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.a8(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
ph(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.dU(a,b,r[o])
return A.mp(a,p,null,c,d.y,e)}return A.mp(a,b.y,null,c,d.y,e)},
mp(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.a8(a,b[s],d,e[s],f))return!1
return!0},
pm(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.a8(a,r[s],c,q[s],e))return!1
return!0},
d1(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.cB(a))if(s!==6)r=s===7&&A.d1(a.x)
return r},
cB(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.iD},
mo(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
jZ(a){return a>0?new Array(a):v.typeUniverse.sEA},
bg:function bg(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
f3:function f3(){this.c=this.b=this.a=null},
jX:function jX(a){this.a=a},
f2:function f2(){},
cY:function cY(a){this.a=a},
ov(){var s,r,q
if(self.scheduleImmediate!=null)return A.pH()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.fr(new A.jy(s),1)).observe(r,{childList:true})
return new A.jx(s,r,q)}else if(self.setImmediate!=null)return A.pI()
return A.pJ()},
ow(a){self.scheduleImmediate(A.fr(new A.jz(t.M.a(a)),0))},
ox(a){self.setImmediate(A.fr(new A.jA(t.M.a(a)),0))},
oy(a){A.oo(B.cQ,t.M.a(a))},
oo(a,b){return A.oO(0,b)},
oO(a,b){var s=new A.jV()
s.cH(a,b)
return s},
mC(a){return new A.eY(new A.ae($.a6,a.j("ae<0>")),a.j("eY<0>"))},
mv(a,b){a.$2(0,null)
b.b=!0
return b.a},
ms(a,b){A.p2(a,b)},
mu(a,b){var s,r,q=b.$ti
q.j("1/?").a(a)
s=a==null?q.c.a(a):a
if(!b.b)b.a.bK(s)
else{r=b.a
if(q.j("bl<1>").b(s))r.bO(s)
else r.bP(s)}},
mt(a,b){var s=A.bL(a),r=A.cz(a),q=b.b,p=b.a
if(q)p.bc(new A.b7(s,r))
else p.bL(new A.b7(s,r))},
p2(a,b){var s,r,q=new A.k_(b),p=new A.k0(b)
if(a instanceof A.ae)a.c9(q,p,t.z)
else{s=t.z
if(a instanceof A.ae)a.cu(q,p,s)
else{r=new A.ae($.a6,t._)
r.a=8
r.c=a
r.c9(q,p,s)}}},
mH(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.a6.cr(new A.k7(s),t.r,t.S,t.z)},
mh(a,b,c){return 0},
kU(a){var s
if(t.fz.b(a)){s=a.gaI()
if(s!=null)return s}return B.cZ},
l8(a,b,c){var s,r,q,p,o={},n=o.a=a
for(s=t._;r=n.a,(r&4)!==0;n=a){a=s.a(n.c)
o.a=a}if(n===b){s=A.oj()
b.bL(new A.b7(new A.bi(!0,n,null,"Cannot complete a future with itself"),s))
return}q=b.a&1
s=n.a=r|q
if((s&24)===0){p=t.F.a(b.c)
b.a=b.a&1|4
b.c=n
n.c2(p)
return}if(!c)if(b.c==null)n=(s&16)===0||q!==0
else n=!1
else n=!0
if(n){p=b.aS()
b.aK(o.a)
A.cU(b,p)
return}b.a^=2
A.fp(null,null,b.b,t.M.a(new A.jH(o,b)))},
cU(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d={},c=d.a=a
for(s=t.t,r=t.F;;){q={}
p=c.a
o=(p&16)===0
n=!o
if(b==null){if(n&&(p&1)===0){m=s.a(c.c)
A.lg(m.a,m.b)}return}q.a=b
l=b.a
for(c=b;l!=null;c=l,l=k){c.a=null
A.cU(d.a,c)
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
A.lg(j.a,j.b)
return}g=$.a6
if(g!==h)$.a6=h
else g=null
c=c.c
if((c&15)===8)new A.jL(q,d,n).$0()
else if(o){if((c&1)!==0)new A.jK(q,j).$0()}else if((c&2)!==0)new A.jJ(d,q).$0()
if(g!=null)$.a6=g
c=q.c
if(c instanceof A.ae){p=q.a.$ti
p=p.j("bl<2>").b(c)||!p.y[1].b(c)}else p=!1
if(p){f=q.a.b
if((c.a&24)!==0){e=r.a(f.c)
f.c=null
b=f.aT(e)
f.a=c.a&30|f.a&1
f.c=c.c
d.a=c
continue}else A.l8(c,f,!0)
return}}f=q.a.b
e=r.a(f.c)
f.c=null
b=f.aT(e)
c=q.b
p=q.c
if(!c){f.$ti.c.a(p)
f.a=8
f.c=p}else{s.a(p)
f.a=f.a&1|16
f.c=p}d.a=f
c=f}},
pv(a,b){var s
if(t.ng.b(a))return b.cr(a,t.z,t.K,t.l)
s=t.mq
if(s.b(a))return s.a(a)
throw A.l(A.e0(a,"onError",u.c))},
pr(){var s,r
for(s=$.cZ;s!=null;s=$.cZ){$.dZ=null
r=s.b
$.cZ=r
if(r==null)$.dY=null
s.a.$0()}},
pB(){$.lf=!0
try{A.pr()}finally{$.dZ=null
$.lf=!1
if($.cZ!=null)$.lr().$1(A.mL())}},
mG(a){var s=new A.eZ(a),r=$.dY
if(r==null){$.cZ=$.dY=s
if(!$.lf)$.lr().$1(A.mL())}else $.dY=r.b=s},
py(a){var s,r,q,p=$.cZ
if(p==null){A.mG(a)
$.dZ=$.dY
return}s=new A.eZ(a)
r=$.dZ
if(r==null){s.b=p
$.cZ=$.dZ=s}else{q=r.b
s.b=q
$.dZ=r.b=s
if(q==null)$.dY=s}},
qs(a,b){A.cx(a,"stream",t.K)
return new A.fj(b.j("fj<0>"))},
lg(a,b){A.py(new A.k6(a,b))},
mE(a,b,c,d,e){var s,r=$.a6
if(r===c)return d.$0()
$.a6=c
s=r
try{r=d.$0()
return r}finally{$.a6=s}},
px(a,b,c,d,e,f,g){var s,r=$.a6
if(r===c)return d.$1(e)
$.a6=c
s=r
try{r=d.$1(e)
return r}finally{$.a6=s}},
pw(a,b,c,d,e,f,g,h,i){var s,r=$.a6
if(r===c)return d.$2(e,f)
$.a6=c
s=r
try{r=d.$2(e,f)
return r}finally{$.a6=s}},
fp(a,b,c,d){t.M.a(d)
if(B.u!==c){d=c.dh(d)
d=d}A.mG(d)},
jy:function jy(a){this.a=a},
jx:function jx(a,b,c){this.a=a
this.b=b
this.c=c},
jz:function jz(a){this.a=a},
jA:function jA(a){this.a=a},
jV:function jV(){},
jW:function jW(a,b){this.a=a
this.b=b},
eY:function eY(a,b){this.a=a
this.b=!1
this.$ti=b},
k_:function k_(a){this.a=a},
k0:function k0(a){this.a=a},
k7:function k7(a){this.a=a},
cw:function cw(a,b){var _=this
_.a=a
_.e=_.d=_.c=_.b=null
_.$ti=b},
c0:function c0(a,b){this.a=a
this.$ti=b},
b7:function b7(a,b){this.a=a
this.b=b},
cs:function cs(a,b,c,d,e){var _=this
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
jE:function jE(a,b){this.a=a
this.b=b},
jI:function jI(a,b){this.a=a
this.b=b},
jH:function jH(a,b){this.a=a
this.b=b},
jG:function jG(a,b){this.a=a
this.b=b},
jF:function jF(a,b){this.a=a
this.b=b},
jL:function jL(a,b,c){this.a=a
this.b=b
this.c=c},
jM:function jM(a,b){this.a=a
this.b=b},
jN:function jN(a){this.a=a},
jK:function jK(a,b){this.a=a
this.b=b},
jJ:function jJ(a,b){this.a=a
this.b=b},
eZ:function eZ(a){this.a=a
this.b=null},
fj:function fj(a){this.$ti=a},
dV:function dV(){},
ff:function ff(){},
jU:function jU(a,b){this.a=a
this.b=b},
k6:function k6(a,b){this.a=a
this.b=b},
ih(a,b){return new A.bx(a.j("@<0>").A(b).j("bx<1,2>"))},
S(a,b,c){return b.j("@<0>").A(c).j("lQ<1,2>").a(A.pR(a,new A.bx(b.j("@<0>").A(c).j("bx<1,2>"))))},
n(a,b){return new A.bx(a.j("@<0>").A(b).j("bx<1,2>"))},
ev(a){return new A.br(a.j("br<0>"))},
K(a){return new A.br(a.j("br<0>"))},
ah(a,b){return b.j("lR<0>").a(A.pS(a,new A.br(b.j("br<0>"))))},
l9(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
as(a,b,c){var s=new A.Q(a,b,c.j("Q<0>"))
s.c=a.e
return s},
o0(a,b,c){var s=A.ih(b,c)
a.X(0,new A.ii(s,b,c))
return s},
V(a,b,c){var s=A.ih(b,c)
s.B(0,a)
return s},
cG(a,b){var s,r,q=A.ev(b)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.k)(a),++r)q.k(0,b.a(a[r]))
return q},
dm(a,b){var s=A.ev(b)
s.B(0,a)
return s},
kZ(a){var s,r
if(A.lo(a))return"{...}"
s=new A.cR("")
try{r={}
B.a.k($.aU,a)
s.a+="{"
r.a=!0
a.X(0,new A.il(r,s))
s.a+="}"}finally{if(0>=$.aU.length)return A.b($.aU,-1)
$.aU.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
br:function br(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
f9:function f9(a){this.a=a
this.c=this.b=null},
Q:function Q(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
ii:function ii(a,b,c){this.a=a
this.b=b
this.c=c},
G:function G(){},
a2:function a2(){},
ik:function ik(a){this.a=a},
il:function il(a,b){this.a=a
this.b=b},
bW:function bW(){},
dP:function dP(){},
pt(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.bL(r)
q=A.bb(String(s),null,null)
throw A.l(q)}q=A.k2(p)
return q},
k2(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.f5(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.k2(a[s])
return a},
oC(a,b,c,d,e,f,g,a0){var s,r,q,p,o,n,m,l,k,j,i=a0>>>2,h=3-(a0&3)
for(s=b.length,r=a.length,q=f.$flags|0,p=c,o=0;p<d;++p){if(!(p<s))return A.b(b,p)
n=b[p]
o|=n
i=(i<<8|n)&16777215;--h
if(h===0){m=g+1
l=i>>>18&63
if(!(l<r))return A.b(a,l)
q&2&&A.aa(f)
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
q&2&&A.aa(f)
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
q&2&&A.aa(f)
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
throw A.l(A.e0(b,"Not a byte value at index "+p+": 0x"+B.c.bC(b[p],16),null))},
oB(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i="Invalid encoding before padding",h="Invalid character",g=B.c.aU(a1,2),f=a1&3,e=$.nl()
for(s=a.length,r=e.length,q=d.$flags|0,p=b,o=0;p<c;++p){if(!(p<s))return A.b(a,p)
n=a.charCodeAt(p)
o|=n
m=n&127
if(!(m<r))return A.b(e,m)
l=e[m]
if(l>=0){g=(g<<6|l)&16777215
f=f+1&3
if(f===0){k=a0+1
q&2&&A.aa(d)
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
if(f===3){if((g&3)!==0)throw A.l(A.bb(i,a,p))
k=a0+1
q&2&&A.aa(d)
s=d.length
if(!(a0<s))return A.b(d,a0)
d[a0]=g>>>10
if(!(k<s))return A.b(d,k)
d[k]=g>>>2}else{if((g&15)!==0)throw A.l(A.bb(i,a,p))
q&2&&A.aa(d)
if(!(a0<d.length))return A.b(d,a0)
d[a0]=g>>>4}j=(3-f)*3
if(n===37)j+=2
return A.mc(a,p+1,c,-j-1)}throw A.l(A.bb(h,a,p))}if(o>=0&&o<=127)return(g<<2|f)>>>0
for(p=b;p<c;++p){if(!(p<s))return A.b(a,p)
if(a.charCodeAt(p)>127)break}throw A.l(A.bb(h,a,p))},
oz(a,b,c,d){var s=A.oA(a,b,c),r=(d&3)+(s-b),q=B.c.aU(r,2)*3,p=r&3
if(p!==0&&s<c)q+=p-1
if(q>0)return new Uint8Array(q)
return $.nk()},
oA(a,b,c){var s,r=a.length,q=c,p=q,o=0
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
mc(a,b,c,d){var s,r,q
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
if(b===c)break}if(b!==c)throw A.l(A.bb("Invalid padding character",a,b))
return-s-1},
lO(a,b,c){return new A.dl(a,b)},
p4(a){return a.n()},
oD(a,b){return new A.jP(a,[],A.pM())},
oE(a,b,c){var s,r=new A.cR(""),q=A.oD(r,b)
q.b5(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
f5:function f5(a,b){this.a=a
this.b=b
this.c=null},
f6:function f6(a){this.a=a},
d5:function d5(){},
fA:function fA(){},
jC:function jC(a){this.a=0
this.b=a},
fz:function fz(){},
jB:function jB(){this.a=0},
bO:function bO(){},
e8:function e8(){},
dl:function dl(a,b){this.a=a
this.b=b},
er:function er(a,b){this.a=a
this.b=b},
eq:function eq(){},
ie:function ie(a){this.b=a},
id:function id(a){this.a=a},
jQ:function jQ(){},
jR:function jR(a,b){this.a=a
this.b=b},
jP:function jP(a,b,c){this.c=a
this.a=b
this.b=c},
ft(a){var s=A.o8(a,null)
if(s!=null)return s
throw A.l(A.bb(a,null,null))},
nP(a,b){a=A.a9(a,new Error())
if(a==null)a=A.dX(a)
a.stack=b.q(0)
throw a},
bc(a,b,c,d){var s,r=c?J.lM(a,d):J.lL(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
ew(a,b,c){var s,r=A.d([],c.j("o<0>"))
for(s=J.ab(a);s.l();)B.a.k(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
q(a,b){var s,r
if(Array.isArray(a))return A.d(a.slice(0),b.j("o<0>"))
s=A.d([],b.j("o<0>"))
for(r=J.ab(a);r.l();)B.a.k(s,r.gp())
return s},
ol(a){var s
A.cP(0,"start")
s=A.om(a,0,null)
return s},
om(a,b,c){var s=a.length
if(b>=s)return""
return A.o9(a,b,s)},
of(a){return new A.eo(a,A.o_(a,!1,!0,!1,!1,""))},
m7(a,b,c){var s=J.ab(b)
if(!s.l())return a
if(c.length===0){do a+=A.z(s.gp())
while(s.l())}else{a+=A.z(s.gp())
while(s.l())a=a+c+A.z(s.gp())}return a},
oj(){return A.cz(new Error())},
nF(a,b,c,d,e,f,g,h,i){var s="microsecond",r=A.oa(a,b,c,d,e,f,g,h,i)
if(r==null)return null
if(h>999)A.bs(A.aQ(h,0,999,s,null))
if(r<-864e13||r>864e13)A.bs(A.aQ(r,-864e13,864e13,"millisecondsSinceEpoch",null))
if(r===864e13&&h!==0)A.bs(A.e0(h,s,"Time including microseconds is outside valid range"))
A.cx(i,"isUtc",t.y)
return new A.bt(r,h,i)},
nH(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.n8().dC(a)
if(c!=null){s=new A.h9()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.ft(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.ft(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.ft(q)
if(4>=r.length)return A.b(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.b(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.b(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.b(r,7)
j=new A.ha().$1(r[7])
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
e=A.ft(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.nF(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.l(A.bb("Time out of range",a,null))
return d}else throw A.l(A.bb("Invalid date format",a,null))},
lH(a){var s,r
try{s=A.nH(a)
return s}catch(r){if(A.bL(r) instanceof A.dd)return null
else throw r}},
lG(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
nG(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
h8(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
bu(a){if(a>=10)return""+a
return"0"+a},
ad(a,b,c){var s,r,q
for(s=a.length,r=0;r<s;++r){q=a[r]
if(q.b===b)return q}throw A.l(A.e0(b,"name","No enum value with that name"))},
ec(a){if(typeof a=="number"||A.le(a)||a==null)return J.d2(a)
if(typeof a=="string")return JSON.stringify(a)
return A.m_(a)},
nQ(a,b){A.cx(a,"error",t.K)
A.cx(b,"stackTrace",t.l)
A.nP(a,b)},
e2(a){return new A.e1(a)},
d4(a,b){return new A.bi(!1,null,b,a)},
e0(a,b,c){return new A.bi(!0,a,b,c)},
nt(a,b,c){return a},
l2(a,b){return new A.dx(null,null,!0,a,b,"Value not in range")},
aQ(a,b,c,d,e){return new A.dx(b,c,!0,a,d,"Invalid value")},
m4(a,b,c){if(0>a||a>c)throw A.l(A.aQ(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.l(A.aQ(b,a,c,"end",null))
return b}return c},
cP(a,b){if(a<0)throw A.l(A.aQ(a,0,null,b,null))
return a},
ia(a,b,c,d){return new A.eh(b,!0,a,d,"Index out of range")},
bq(a){return new A.dG(a)},
ma(a){return new A.eU(a)},
l4(a){return new A.dD(a)},
am(a){return new A.e7(a)},
bb(a,b,c){return new A.dd(a,b,c)},
nV(a,b,c){var s,r
if(A.lo(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.d([],t.s)
B.a.k($.aU,a)
try{A.pq(a,s)}finally{if(0>=$.aU.length)return A.b($.aU,-1)
$.aU.pop()}r=A.m7(b,t.e7.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
kW(a,b,c){var s,r
if(A.lo(a))return b+"..."+c
s=new A.cR(b)
B.a.k($.aU,a)
try{r=s
r.a=A.m7(r.a,a,", ")}finally{if(0>=$.aU.length)return A.b($.aU,-1)
$.aU.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
pq(a,b){var s,r,q,p,o,n,m,l=a.gt(a),k=0,j=0
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
cL(a,b,c,d){var s
if(B.e===c){s=J.aK(a)
b=J.aK(b)
return A.jb(A.bE(A.bE($.fw(),s),b))}if(B.e===d){s=J.aK(a)
b=J.aK(b)
c=J.aK(c)
return A.jb(A.bE(A.bE(A.bE($.fw(),s),b),c))}s=J.aK(a)
b=J.aK(b)
c=J.aK(c)
d=J.aK(d)
d=A.jb(A.bE(A.bE(A.bE(A.bE($.fw(),s),b),c),d))
return d},
o3(a){var s,r,q=$.fw()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.k)(a),++r)q=A.bE(q,J.aK(a[r]))
return A.jb(q)},
bt:function bt(a,b,c){this.a=a
this.b=b
this.c=c},
h9:function h9(){},
ha:function ha(){},
ca:function ca(){},
f1:function f1(){},
P:function P(){},
e1:function e1(a){this.a=a},
bG:function bG(){},
bi:function bi(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dx:function dx(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
eh:function eh(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
dG:function dG(a){this.a=a},
eU:function eU(a){this.a=a},
dD:function dD(a){this.a=a},
e7:function e7(a){this.a=a},
eI:function eI(){},
dC:function dC(){},
jD:function jD(a){this.a=a},
dd:function dd(a,b,c){this.a=a
this.b=b
this.c=c},
j:function j(){},
ai:function ai(a,b,c){this.a=a
this.b=b
this.$ti=c},
ap:function ap(){},
J:function J(){},
fk:function fk(){},
cR:function cR(a){this.a=a},
i8:function i8(a){this.a=a},
i9:function i9(a){this.a=a},
nJ(a){var s,r,q,p=t.P.a(a.h(0,"project")),o=A.w(a.h(0,"lang"))
if(o==null)o="en"
s=t.av
if(s.b(a.h(0,"strings"))){r=t.N
r=A.n(r,r)
for(s=s.a(a.h(0,"strings")).gaG(),s=s.gt(s);s.l();){q=s.gp()
r.i(0,A.z(q.a),A.z(q.b))}s=r}else s=null
r=A.W(a.h(0,"sizeZones"))
q=A.W(a.h(0,"sizeMain"))
return new A.hd(p,o,s,r!==!1,q!==!1)},
ps(){var s=new A.ae($.a6,t.cU)
s.bK(null)
return s},
kv(a,b){var s=null
return A.qb(a,b)},
qb(a,a0){var s=0,r=A.mC(t.r),q=1,p=[],o,n,m,l,k,j,i,h,g,f,e,d,c,b
var $async$kv=A.mH(function(a1,a2){if(a1===1){p.push(a2)
s=q}for(;;)switch(s){case 0:c=null
q=3
o=A.nJ(a)
n=A.ob(o.a)
if(o.c!=null&&!$.k4.E(o.b)){g=o.b
f=o.c
f.toString
$.k4.i(0,g,new A.es(f))}g=o.b
m=new A.i8(B.a.v(B.du,g)?g:"en")
l=A.nK(n,new A.kw(m))
g=o.d
f=o.e
e=c
if(e==null)e=A.pO()
s=6
return A.ms(l.aZ(new A.kx(a0),f,g,e),$async$kv)
case 6:k=a2
j=A.n(t.N,t.z)
J.kS(j,"type","done")
J.lt(j,new A.he(k,n.e,n.r).n())
a0.$1(j)
q=1
s=5
break
case 3:q=2
b=p.pop()
i=A.bL(b)
h=A.cz(b)
a0.$1(A.S(["type","error","message",A.z(i),"stack",A.z(h)],t.N,t.z))
s=5
break
case 2:s=1
break
case 5:return A.mu(null,r)
case 1:return A.mt(p.at(-1),r)}})
return A.mv($async$kv,r)},
hd:function hd(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
he:function he(a,b,c){this.a=a
this.b=b
this.c=c},
hf:function hf(){},
kw:function kw(a){this.a=a},
kx:function kx(a){this.a=a},
nK(a,b){var s=Date.now(),r=t.N,q=A.d([],t.lT),p=A.d([],t.s),o=A.d([],t.o6),n=A.d([],t.p4),m=A.d([],t.cu),l=A.l0(a).bq()
return new A.ea(a,b,l,new A.e9(new A.bt(s,0,!1),A.n(r,t.kV),A.n(r,t.oY),q,p,o,n,m,A.K(r)),A.n(r,r),A.n(r,t.x))},
bj:function bj(a,b){this.a=a
this.b=b},
c8:function c8(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
ea:function ea(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
hs:function hs(){},
hz:function hz(){},
hL:function hL(){},
hK:function hK(){},
hM:function hM(a,b,c){this.a=a
this.b=b
this.c=c},
hm:function hm(a){this.a=a},
ht:function ht(){},
hy:function hy(a){this.a=a},
hx:function hx(){},
hA:function hA(a){this.a=a},
hn:function hn(a){this.a=a},
ho:function ho(){},
hp:function hp(a){this.a=a},
hq:function hq(){},
hr:function hr(a){this.a=a},
hJ:function hJ(a){this.a=a},
hO:function hO(){},
hP:function hP(a,b,c){this.a=a
this.b=b
this.c=c},
hw:function hw(a){this.a=a},
hu:function hu(a,b,c,d,e,f,g,h,i,j){var _=this
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
hv:function hv(){},
hW:function hW(){},
hV:function hV(a,b,c){this.a=a
this.b=b
this.c=c},
hX:function hX(a){this.a=a},
hY:function hY(a){this.a=a},
hZ:function hZ(){},
i_:function i_(){},
hD:function hD(a,b,c){this.a=a
this.b=b
this.c=c},
hE:function hE(a,b){this.a=a
this.b=b},
hB:function hB(a){this.a=a},
hC:function hC(){},
hF:function hF(a,b,c){this.a=a
this.b=b
this.c=c},
hG:function hG(a,b){this.a=a
this.b=b},
hH:function hH(a,b){this.a=a
this.b=b},
hI:function hI(a){this.a=a},
hN:function hN(a,b){this.a=a
this.b=b},
hU:function hU(a){this.a=a},
hQ:function hQ(a){this.a=a},
hR:function hR(){},
hS:function hS(){},
hT:function hT(){},
mQ(a,b,c,d){var s,r=new A.kf()
if(c>0&&Math.abs(c-b)>0.5)s=A.z(r.$1(b))+" \xd7 "+A.z(r.$1(c))+" mm"
else s=b>0?A.z(r.$1(b))+" mm":""
return B.k.e_(A.z(d.$1("fit."+a.b))+" "+s)},
qc(f5,f6,f7,f8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7=null,e8=f5.c,e9=t.N,f0=A.n(e9,t.kh),f1=new A.kI(f0),f2=new A.kK(e8,f7),f3=new A.kH(),f4=A.n(e9,t.h)
for(s=f5.e,r=s.length,q=0;p=s.length,q<p;s.length===r||(0,A.k)(s),++q){o=s[q]
f4.i(0,o.a,o)}r=A.K(e9)
for(q=0;q<s.length;s.length===p||(0,A.k)(s),++q){o=s[q]
if(o instanceof A.ak||o instanceof A.aB)r.k(0,o.a)}for(p=f6.a,n=A.i(p).j("N<2>"),m=new A.N(p,p.r,p.e,n),l=t.n,k=t.C;m.l();){j=m.d
i=j.w
h=A.r(i)
g=h.j("v(1)")
h=h.j("B<1>")
f=h.j("j.E")
e=A.q(new A.B(i,g.a(new A.kz(f2)),h),f)
d=A.r(e)
c=d.j("v(1)")
d=d.j("B<1>")
b=d.j("j.E")
a=A.q(new A.B(e,c.a(new A.kA(r)),d),b)
a0=A.q(new A.B(e,c.a(new A.kB(r)),d),b)
for(d=j.r,c=A.i(d),b=new A.Q(d,d.r,c.j("Q<1>")),b.c=d.e,c=c.c,a1=e7,a2=a1,a3=a2,a4=a3;b.l();){d=b.d
o=f4.h(0,d==null?c.a(d):d)
if(o instanceof A.b9){a4=o
continue}if(o instanceof A.aY||o instanceof A.bo){a3=o
continue}if(o instanceof A.aC){a2=o
continue}if(o instanceof A.aZ){a1=o
continue}continue}a5=A.q(new A.B(i,g.a(new A.kC()),h),f)
i=a5.length
if(i!==0)h=a4!=null||a3!=null
else h=!1
if(h)for(h=a3 instanceof A.aY,g=a4!=null,f=j.a,d=A.r(a),c=d.j("e(1)"),d=d.j("t<1,e>"),q=0;q<a5.length;a5.length===i||(0,A.k)(a5),++q){if(a5[q].b!==f)continue
if(g){b=e8.a2(a4.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}else a6=0
if(h){b=e8.a2(a3.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}if(a.length!==0)a7=new A.t(a,c.a(f2),d).L(0,B.q)
else a7=a0.length!==0?f2.$1(B.a.gu(a0)):0
if(a6<=0)a6=a7
b=a6>0
if(b)f1.$3$qty(B.am,a6,2)
if(a7>0&&b&&Math.abs(a7-a6)>0.5)f1.$4$qty$size2(B.v,Math.max(a7,a6),2,Math.min(a7,a6))}if(a.length===0)continue
i=A.r(a)
h=i.j("t<1,e>")
a8=A.q(new A.t(a,i.j("e(1)").a(f2),h),h.j("u.E"))
a9=B.a.L(a8,B.q)
b0=a.length
b1=a4!=null||a3!=null||a2!=null||a1!=null
if(b0===1){if(!b1&&a0.length===0&&a5.length===0)f1.$2(B.K,B.a.gu(a8))
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
if(b7>60)f1.$2(B.aj,a9)
else if(b7>15)f1.$2(B.ak,a9)
else if(b3.f!==b4.f&&!c0&&a5.length===0)f1.$2(B.V,a9)
if(c0)f1.$3$size2(B.v,Math.max(b8,b9),Math.min(b8,b9))
if(a1!=null){b2=e8.a0(a1.f)
if(b2!=null){j=b2.w
f1.$3$size2(B.J,a9,j>0?Math.min(j,a9):0)
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
f1.$3$size2(B.J,i,c7<c6-0.5?c7:0)
i=j.length
if(0>=i)return A.b(j,0)
h=j[0]
if(1>=i)return A.b(j,1)
if(Math.abs(h-j[1])>0.5)f1.$3$size2(B.v,B.a.L(j,B.q),B.a.L(j,B.H))
if(c7>c6+0.5)f1.$3$size2(B.v,c7,c6)
continue}f1.$2(B.al,a9)
for(j=a8.length,i=a9-0.5,q=0;q<a8.length;a8.length===j||(0,A.k)(a8),++q){b2=a8[q]
if(b2<i)f1.$3$size2(B.v,a9,b2)}}c8=A.n(e9,t.cr)
for(f4=new A.N(p,p.r,p.e,n);f4.l();){p=f4.d
n=p.b
c8.i(0,B.b.ae(n.a,3)+"|"+B.b.ae(n.b,3)+"|"+p.d.b,p)}c9=new A.kJ(c8)
d0=new A.kF(r)
for(f4=s.length,r=f6.z,p=f5.b.k4,n=p>0,m=f6.b,l=A.r(m),k=l.j("v(1)"),l=l.j("B<1>"),j=l.j("j.E"),q=0;q<s.length;s.length===f4||(0,A.k)(s),++q){o=s[q]
if(r.v(0,o.a))continue
A:{i={}
i.a=null
h=o instanceof A.ak
if(h)i.a=o
if(h){d1=new A.B(m,k.a(new A.kD(i)),l)
if(!d1.gt(0).l())break A
d2=d1.gt(0)
if(!d2.l())A.bs(A.av())
h=d2.gp().x
h=e8.N(h==null?i.a.e:h)
d3=h==null?e7:h.e
if(d3==null)d3=16
d4=d0.$2(c9.$2(J.bN(i.a.d),B.f),i.a.a)
d5=d0.$2(c9.$2(J.kT(i.a.d),B.f),i.a.a)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.K,d3)
if(!d5)f1.$2(B.K,d3)
a1=e8.a0(i.a.r)
if(a1!=null&&i.a.gb3()>0)f1.$3$qty(B.m,a1.w,i.a.gb3())
break A}i=o instanceof A.aB
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
if(!d4)f1.$2(B.L,d3)
if(!d5)f1.$2(B.L,d3)
break A}i={}
i.a=null
h=o instanceof A.aH
if(h)i.a=o
if(h){if(n){d1=A.q(new A.B(m,k.a(new A.kE(i)),l),j)
if(d1.length===0)break A
h=f7.$1(B.a.gu(d1))
d3=h==null?e7:h.e
if(d3==null)d3=0
d8=B.b.J(A.aV(i.a.d)/p)
if(d3>0&&d8>0)f1.$3$qty(B.V,d3,d8)}break A}break A}}d9=A.n(e9,t.q)
e0=A.d([],t.e0)
e1=new A.ky()
for(e9=new A.N(f0,f0.r,f0.e,f0.$ti.j("N<2>"));e9.l();){f4=e9.d
d8=f4.a
e2=f4.b
f4=d8.a
s=d8.b
r=d8.c
e3=e8.dB(f4,s,r)
if(e3==null){B.a.k(e0,d8)
e4=A.mQ(f4,s,r,f8)+" *"
e5="generic|"+e4
e6=d9.h(0,e5)
if(e6!=null)e6.d+=e2
else d9.i(0,e5,new A.al(e1.$1(f4),e4,"un",e2,0,e7,"",""))
continue}s=e3.a
e6=d9.h(0,s)
if(e6!=null)e6.d+=e2
else d9.i(0,s,new A.al(e1.$1(f4),e3.b,"un",e2,e3.w,s,e3.d,e3.c))}for(e9=d9.$ti,f4=new A.N(d9,d9.r,d9.e,e9.j("N<2>"));f4.l();){s=f4.d
s.d=Math.ceil(s.d)}e9=e9.j("ao<2>")
e9=A.q(new A.ao(d9,e9),e9.j("j.E"))
return new A.i5(e9,e0)},
dc:function dc(a,b,c){this.a=a
this.b=b
this.c=c},
i5:function i5(a,b){this.a=a
this.b=b},
kf:function kf(){},
kI:function kI(a){this.a=a},
kK:function kK(a,b){this.a=a
this.b=b},
kH:function kH(){},
kz:function kz(a){this.a=a},
kA:function kA(a){this.a=a},
kB:function kB(a){this.a=a},
kC:function kC(){},
kJ:function kJ(a){this.a=a},
kF:function kF(a){this.a=a},
kG:function kG(a,b){this.a=a
this.b=b},
kD:function kD(a){this.a=a},
kE:function kE(a){this.a=a},
ky:function ky(){},
qd(c2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7={},b8=c2.b,b9=b8.length,c0=c2.c,c1=c0.length
if(b9===0)return new A.cH(B.N,B.bi,0,0)
s=A.d([],t.ot)
r=A.d([],t.n)
for(q=c0.length,p=0,o=0,n=0;n<c0.length;c0.length===q||(0,A.k)(c0),++n){m=c0[n]
l=m.b
k=m.c
if(k<0){k=-k
switch(l.a){case 0:j=B.bm
break
case 2:j=B.a_
break
case 1:j=B.ap
break
default:j=null}l=j}B.a.k(s,l)
B.a.k(r,k)
if(l!==B.ap)++p
if(l!==B.a_)++o}i=b9+p
h=i+o
g=h+1
f=J.el(c1,t.kI)
for(e=0;e<c1;++e)f[e]=new Float64Array(g)
q=t.S
d=A.bc(c1,-1,!1,q)
c=A.d([],t.X)
for(b=i,a=b9,a0=0;a0<c1;++a0){if(!(a0<c0.length))return A.b(c0,a0)
m=c0[a0]
a1=m.c<0?-1:1
if(!(a0<f.length))return A.b(f,a0)
a2=f[a0]
m.a.X(0,new A.kL(b9,a2,a1))
if(!(a0<r.length))return A.b(r,a0)
j=r[a0]
a2.$flags&2&&A.aa(a2)
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
a6=new A.kM(f,g,c1,d)
a7=new A.kO(b7,new A.kN(g,h,c1,d,f),50*(c1+h)+1000,1e-9,h,c1,f,d,a6)
c0=c.length
if(c0!==0){a8=new Float64Array(g)
for(n=0;n<c0;++n){a9=c[n]
if(!(a9<g))return A.b(a8,a9)
a8[a9]=1}b0=a7.$2(a8,B.yF)
if(b0===B.bn)return new A.cH(b0,A.bc(b9,0,!1,t.i),0,b7.a)
for(b1=0,a0=0;a0<c1;++a0)if(B.a.v(c,d[a0])){if(!(a0<f.length))return A.b(f,a0)
c0=f[a0]
if(!(h<c0.length))return A.b(c0,h)
b1+=c0[h]}if(b1>0.000001)return new A.cH(B.dJ,A.bc(b9,0,!1,t.i),0,b7.a)
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
b4[b3]=j}b0=a7.$2(b4,A.cG(c,q))
b5=A.bc(b9,0,!1,t.i)
for(a0=0;a0<c1;++a0){c0=d[a0]
if(c0<b9){if(!(a0<f.length))return A.b(f,a0)
q=f[a0]
if(!(h<q.length))return A.b(q,h)
B.a.i(b5,c0,q[h])}}for(c0=b8.length,b6=0,b3=0;b3<b9;++b3){if(!(b3<c0))return A.b(b8,b3)
b6+=b8[b3]*b5[b3]}b8=b0===B.N?B.N:b0
return new A.cH(b8,b5,b6,b7.a)},
ck:function ck(a,b){this.a=a
this.b=b},
cj:function cj(a,b,c){this.a=a
this.b=b
this.c=c},
ij:function ij(a,b,c){this.b=a
this.c=b
this.d=c},
cH:function cH(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
by:function by(a,b){this.a=a
this.b=b},
kL:function kL(a,b,c){this.a=a
this.b=b
this.c=c},
kN:function kN(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
kM:function kM(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kO:function kO(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
mV(b7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=t.N,b2=A.n(b1,t.dV),b3=t.n,b4=A.d([],b3),b5=A.d([],t.cH),b6=A.d([],t.s)
for(s=b7.a,r=s.length,q=b7.w,p=b7.r,o=t.S,n=b7.c,m=b7.b,l=0;l<s.length;s.length===r||(0,A.k)(s),++l){k=s[l]
j=m.h(0,k)
if(j==null)j=B.bl
i=n.h(0,k)
if(i==null)i=0
h=A.n(b1,o)
for(g=j.length,f=k+":",e=0;e<j.length;j.length===g||(0,A.k)(j),++e){d=j[e]
c=q?p:1
b=d.a
B.a.k(b4,d.Q*i*c)
B.a.k(b6,f+b)
h.i(0,b,b4.length-1)}b2.i(0,k,h)}a=A.n(o,o)
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
B.a.k(b5,new A.cj(n.a(A.S([f,1],o,p)),B.a_,g))}}for(q=s.length,l=0;l<s.length;s.length===q||(0,A.k)(s),++l){h=b2.h(0,s[l])
if(h.a===0)continue
g=A.n(o,p)
for(f=new A.N(h,h.r,h.e,A.i(h).j("N<2>"));f.l();)g.i(0,f.d,1)
B.a.k(b5,new A.cj(n.a(g),B.ap,1))}for(q=b7.f,g=q.length,l=0;l<q.length;q.length===g||(0,A.k)(q),++l){a3=q[l]
a4=A.n(o,p)
f=a3.a
if(!(f<r.length))return A.b(r,f)
c=r[f].b
if(c!=null)a5=0+c
else{f=a.h(0,f)
f.toString
a4.i(0,f,1)
a5=0}a3.b.X(0,new A.kp(b2,a4))
if(a4.a===0)continue
f=a3.d
if(f!=null){c=A.ih(o,p)
c.B(0,a4)
B.a.k(b5,new A.cj(n.a(c),B.bm,f+a3.c-a5))}f=a3.e
if(f!=null&&isFinite(f)){c=A.ih(o,p)
c.B(0,a4)
B.a.k(b5,new A.cj(n.a(c),B.a_,f+a3.c-a5))}}if(b4.length===0){b1=A.d([],b3)
for(b3=r.length,l=0;l<r.length;r.length===b3||(0,A.k)(r),++l){b4=r[l].b
b1.push(b4==null?0:b4)}return new A.dn(!0,B.bo)}a6=A.qd(new A.ij(b4,b5,b6))
if(a6.a!==B.N)return new A.dn(!1,B.bo)
a7=A.n(b1,t.x)
for(b1=s.length,b4=b7.d,b5=a6.b,b6=b5.length,q=t.an,l=0;l<s.length;s.length===b1||(0,A.k)(s),++l){k=s[l]
p=b2.h(0,k)
p.toString
j=m.h(0,k)
if(j==null)j=B.bl
if(p.a===0)continue
a8=A.d([],q)
for(o=j.length,e=0;e<j.length;j.length===o||(0,A.k)(j),++e){d=j[e]
n=p.h(0,d.a)
n.toString
if(!(n>=0&&n<b6))return A.b(b5,n)
a9=b5[n]
if(a9>0.02)B.a.k(a8,new A.m(d,a9))}if(a8.length===0)B.a.k(a8,new A.m(B.a.gM(j),1))
B.a.am(a8,new A.kq())
p=b4.h(0,k)
a7.i(0,k,A.qa(a8,p==null?1:p))}b0=A.d([],b3)
for(a0=0;a0<r.length;++a0){b1=r[a0].b
if(b1==null){b1=a.h(0,a0)
b1.toString
if(!(b1>=0&&b1<b6))return A.b(b5,b1)
b1=b5[b1]}B.a.k(b0,b1)}return new A.dn(!0,a7)},
qa(a,b){var s,r,q,p,o,n,m=Math.max(1,b)
if(a.length<=m)return A.mD(a)
s=A.r(a).c
r=A.bY(a,0,A.cx(m,"count",t.S),s).cv(0)
for(s=A.bY(a,m,null,s),q=s.$ti,s=new A.aN(s,s.gm(0),q.j("aN<u.E>")),q=q.j("u.E"),p=0;s.l();){o=s.d
p+=(o==null?q.a(o):o).b}n=B.a.gM(r)
B.a.i(r,r.length-1,new A.m(n.a,n.b+p))
return A.mD(r)},
mD(a){var s,r,q,p,o=B.a.W(a,0,new A.k3(),t.i)
if(o<=0)return a
s=A.d([],t.an)
for(r=a.length,q=0;q<a.length;a.length===r||(0,A.k)(a),++q){p=a[q]
s.push(new A.m(p.a,p.b/o))}return s},
dq:function dq(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dp:function dp(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
ex:function ex(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
dn:function dn(a,b){this.a=a
this.b=b},
kp:function kp(a,b){this.a=a
this.b=b},
ko:function ko(a,b){this.a=a
this.b=b},
kq:function kq(){},
k3:function k3(){},
kV(a,b,c,d){return new A.aX(b,c,a,d,A.d([],t.hz),A.K(t.N),A.d([],t.I))},
lK(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return new A.H(h,g,s,i,n,f,o,j,l,r,c,a0,k,d,p,a1,m,q,a,b,e)},
l0(a){var s=t.N,r=t.Q
return new A.im(a,new A.iA(A.n(s,t.cr),A.d([],t.I),A.n(s,t.kM),A.n(s,s),A.n(s,s),A.n(s,r),A.n(s,r),A.K(s),A.K(s),A.d([],t.s),A.K(s)),A.n(t.S,t.g2))},
bS:function bS(a,b){this.a=a
this.b=b},
ba:function ba(a,b,c,d,e,f,g,h,i,j){var _=this
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
aX:function aX(a,b,c,d,e,f,g){var _=this
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
H:function H(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
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
iA:function iA(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
im:function im(a,b,c){var _=this
_.a=a
_.d=_.c=_.b=$
_.e=b
_.f=c
_.r=0},
ip:function ip(){},
iq:function iq(){},
iw:function iw(){},
iy:function iy(){},
ix:function ix(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
ir:function ir(a,b,c){this.a=a
this.b=b
this.c=c},
is:function is(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
it:function it(a){this.a=a},
iu:function iu(){},
iv:function iv(a){this.a=a},
iz:function iz(a){this.a=a},
io:function io(){},
lc(a,b){var s=a.f/1000
if(b<=0||s<=0)return 0
switch(a.x.a){case 0:return A.mT(a.r,s,b,1)
case 1:return A.mO(s,b,a.y,1,a.w/1000)}},
kd(a,b){var s,r=a.gbE(),q=a.c+a.ax
if(r<=0||q<=0)return 0
s=B.b.a_(b/q,0,1)
return a.a===B.E?r*(1-s*s):r*(1-s)},
ke(a,b){var s,r,q,p,o,n,m
if(b<=0)return 0
s=Math.max(4,200)
r=b/s
for(q=a.as,p=0,o=0;o<s;){n=o*r;++o
m=o*r
p+=(A.lc(a,A.kd(a,n)+q)+4*A.lc(a,A.kd(a,(n+m)/2)+q)+A.lc(a,A.kd(a,m)+q))/6*r}return p},
pG(c9,d0,d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8=A.d([],t.s),b9=d0==null?new A.k8():d0,c0=c9.gbE(),c1=c9.as,c2=c0+c1,c3=c9.c,c4=A.ke(c9,c3),c5=b9.$1(c3),c6=c9.Q,c7=c1>0?c9.at:0,c8=Math.max(c6,c7)
c7=c9.z
s=c9.cx
r=c8+c4+c5+c7+s
q=A.d([],t.i5)
p=c9.gcw()
o=A.d([0],t.n)
for(n=c9.e,m=1;m<=p;++m)o.push(m*n)
if(c3-c9.gcw()*n>0.000001)o.push(c3)
for(l=o.length,k=0;j=o.length,k<j;o.length===l||(0,A.k)(o),++k){i=o[k]
j=A.ke(c9,i)
h=b9.$1(i)
if(typeof h!=="number")return A.cA(h)
g=c6+j+h+c7+s
if(g>r)r=g}for(l=r-c7-s,f=0,k=0;k<o.length;o.length===j||(0,A.k)(o),++k,f=d){i=o[k]
h=A.ke(c9,i)
e=b9.$1(i)
if(typeof e!=="number")return A.cA(e)
d=f+1
B.a.k(q,new A.cm(f,i,A.kd(c9,i)+c1,l-h-e,b9.$1(i)))}c=c9.f/1000
b=c>0?A.fu(c,c2):0
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
a9=Math.max(1,B.b.a1(a8/Math.max(e,0.1)))
if(h)b0=0
else b0=j?c0*(a7*a7-a5*a5)/a4:c0*a8/a0
b1=(a5+a7)/2
a8=A.ke(c9,b1)
b2=b9.$1(b1)
if(typeof b2!=="number")return A.cA(b2)
b3=l-a8-b2
b4=b0/a9
a8=d3.length
b5=""
if(a8!==0&&b4>0)for(b6=1/0,k=0;k<d3.length;d3.length===a8||(0,A.k)(d3),++k){b2=d3[k]
b7=b2.a
c=Math.abs(b2.b.a7(Math.max(b3,0.1))-b4)
if(c<b6){b6=c
b5=b7}}++m
B.a.k(a3,new A.bA(m,a5,a7,a9,b4,b3,b5))}}return new A.cM(d1,a3,d2,o,c2,c1,r,c4,c5,c8,c7,s,p,q,c9.gci(),c9.ay,c9.ch,a1,a2,b,b8)},
pX(a,b,c,d){return new A.kj(A.n(t.S,t.i),a,72,c,d,b,d.$1(b))},
cl:function cl(a,b){this.a=a
this.b=b},
iN:function iN(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2){var _=this
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
cm:function cm(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
bA:function bA(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cM:function cM(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
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
iK:function iK(){},
iL:function iL(){},
iM:function iM(){},
k8:function k8(){},
kj:function kj(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
l7(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){return new A.cT(a0,a4,d,q,f,a1,p,j,i,b,a,k,r,o,l,e,a3,s,a2,g,n,c,m,h)},
be:function be(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
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
aw:function aw(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
bQ:function bQ(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
cT:function cT(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){var _=this
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
jt:function jt(){},
js:function js(){},
ju:function ju(){},
jv:function jv(){},
jw:function jw(){},
co:function co(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
aS:function aS(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b4:function b4(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
j7:function j7(){},
j8:function j8(){},
j9:function j9(){},
ja:function ja(){},
al:function al(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cc:function cc(a,b,c,d,e,f,g,h,i,j){var _=this
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
bD:function bD(a,b,c,d,e,f,g,h,i,j){var _=this
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
e9:function e9(a,b,c,d,e,f,g,h,i){var _=this
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
hg:function hg(){},
hh:function hh(){},
hi:function hi(){},
hj:function hj(){},
hk:function hk(){},
hl:function hl(){},
lJ(a){var s,r=A.at(a.h(0,"k")),q=A.at(a.h(0,"x")),p=A.x(a.h(0,"ra"))
if(p==null)p=null
if(p==null)p=0
s=A.x(a.h(0,"rb"))
if(s==null)s=null
return new A.bR(r,q,p,s==null?0:s)},
mS(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(a<=0||b<=0||c<=0)return 0
s=A.d([],t.n)
for(r=0;r<24;++r)for(q=(r+0.5)/24*b,p=0;p<24;++p){o=(p+0.5)/24*c
for(n=0,m=-2;m<=3;++m)for(l=m*b,k=-2;k<=3;++k){j=q-l
i=o-k*c
h=Math.sqrt(j*j+i*i)
if(h<a)n+=1-h/a}B.a.k(s,n)}g=B.a.L(s,new A.kh())/s.length
if(g<=0)return 0
return 100*(1-B.a.W(s,0,new A.ki(g),t.i)/s.length/g)},
bR:function bR(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kh:function kh(){},
ki:function ki(a){this.a=a},
mT(a,b,c,d){var s
if(c===0||d===0)return 0
s=10.67*d*Math.pow(Math.abs(c),1.852)/(Math.pow(a,1.852)*Math.pow(b,4.871))
return c<0?-s:s},
fu(a,b){return b/(3.141592653589793*a*a/4)},
mN(a,b){var s,r,q,p,o,n
if(b<=0)return 0
if(b<2000)return 64/b
if(b<4000){s=a/3.7+5.74/Math.pow(4000,0.9)
r=-0.8685889638065035*Math.log(s)
q=Math.pow(r,-2)
p=q*(2-0.00514215/(s*r))
o=b/2000
return 7*q-p+o*(0.128-17*q+2.5*p+o*(-0.128+13*q-2*p+o*(0.032-3*q+0.5*p)))}n=Math.log(a/3.7+5.74/Math.pow(b,0.9))/2.302585092994046
return 0.25/(n*n)},
mO(a,b,c,d,e){var s,r
if(b===0||d===0)return 0
s=A.fu(a,Math.abs(b))
r=A.mN(e/a,s*a/c)*(d/a)*s*s/19.6133
return b<0?-r:r},
mP(a,b,c,d,e,f,g){switch(f.a){case 0:return A.mT(a,b,c,e)
case 1:return A.mO(b,c,d,e,g)}},
cd:function cd(a,b){this.a=a
this.b=b},
mY(a,b,c){var s=A.fu(a,Math.abs(b)),r=c*s*s/19.6133
return b<0?-r:r},
q8(a,b){var s=3.141592653589793*a*a/4
return b/(19.6133*s*s)},
aF:function aF(a,b,c){this.a=a
this.b=b
this.c=c},
ed(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.de(f,d,n,g,c,h,e,l,i,a,k,b,j,B.n)},
lS(a,b){return new A.iB(b,a)},
df:function df(a,b){this.a=a
this.b=b},
bm:function bm(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=d
_.f=e
_.r=f
_.w=g},
bT:function bT(a,b){this.a=a
this.b=b},
cF:function cF(a,b){this.a=a
this.b=b},
de:function de(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
iB:function iB(a,b){this.a=a
this.b=b},
eH:function eH(a,b){this.a=a
this.b=b},
eu:function eu(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.e=d},
cK:function cK(a,b,c){this.a=a
this.c=b
this.d=c},
ef:function ef(a,b,c){this.a=a
this.b=b
this.c=c},
i7:function i7(){},
m3(a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.r(a4),a2=a1.j("B<1>"),a3=A.q(new A.B(a4,a1.j("v(1)").a(new A.iX()),a2),a2.j("j.E"))
a1=a3.length
if(a1===0)return B.dY
if(a1===1){s=B.a.gu(a3)
r=s.a
q=s.b
return A.m3(A.d([new A.m(0,1.33*q),new A.m(r,q),new A.m(2*r,0)],t.fU))}if(a1===2){if(0>=a1)return A.b(a3,0)
p=a3[0]
o=p.a
n=p.b
if(1>=a1)return A.b(a3,1)
m=a3[1]
l=(m.b-n)/(m.a-o)
return new A.cO(0,l,n-l*o,1)}for(k=0,j=0,i=0,h=0,g=0,f=0,a2=0,e=0;e<a1;++e){d=a3[e]
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
a0=A.oc(A.d([A.d([h,i,j,a2],d),A.d([i,j,k,f],d),A.d([j,k,a1,g],d)],t.iA))
d=a0.length
if(0>=d)return A.b(a0,0)
g=a0[0]
if(1>=d)return A.b(a0,1)
a1=a0[1]
if(2>=d)return A.b(a0,2)
return new A.cO(g,a1,a0[2],1)},
oc(a){var s,r,q,p,o,n,m,l,k,j
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
fq(a,b){var s
if(b<=0)return 1
if(a<=0)return 1/b
s=Math.pow(1+a,b)
return a*s/(s-1)},
mJ(a,b,c,d,e){return 9788.99803*b*c/Math.max(e,0.05)/1000*d*a},
cO:function cO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
iY:function iY(){},
iX:function iX(){},
oh(a){var s,r,q,p=J.el(a,t.jq)
for(s=t.S,r=t.i,q=0;q<a;++q)p[q]=A.n(s,r)
return new A.j1(a,p,A.bc(a,0,!1,r))},
j1:function j1(a,b,c){this.a=a
this.b=b
this.c=c},
j2:function j2(){},
j3:function j3(){},
j4:function j4(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
j5:function j5(a,b,c){this.a=a
this.b=b
this.c=c},
j6:function j6(){},
ot(a,b,c){var s,r,q,p,o,n,m,l,k,j,i=A.r(a),h=i.j("B<1>"),g=A.q(new A.B(a,i.j("v(1)").a(new A.jn()),h),h.j("j.E"))
i=g.length
if(i===0)return B.cK
s=B.a.L(g,new A.jo())/i
h=t.i
r=A.ew(g,!0,h)
B.a.a4(r)
q=B.a.gu(r)
p=B.a.gM(r)
if(s<=0)return new A.dF(i,s,q,p,0,0,0,0,0,0)
o=B.a.W(g,0,new A.jp(s),h)
n=Math.max(1,B.b.ao(i/4))
m=A.bY(r,0,A.cx(n,"count",t.S),A.r(r).c).L(0,new A.jq())/n
h=B.a.W(g,0,new A.jr(s),h)
l=Math.sqrt(h/(i>1?i-1:1))/s
h=Math.sqrt(Math.max(1,b))
k=Math.sqrt(l*l+c*c)
j=p>0?100*(p-q)/p:0
return new A.dF(i,s,q,p,100*(1-o/i/s),100*m/s,100*(1-1.27*c/h)*(m/s),100*(1-k),j,l)},
dF:function dF(a,b,c,d,e,f,g,h,i,j){var _=this
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
jn:function jn(){},
jo:function jo(){},
jp:function jp(a){this.a=a},
jq:function jq(){},
jr:function jr(a){this.a=a},
b_:function b_(a,b,c){this.c=a
this.a=b
this.b=c},
n_(a,b){return $.k4.h(0,a)==null?null:B.aq.h(0,b)},
es:function es(a){this.a=a},
i6:function i6(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aq(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.I(e,h,l,a,i,f,g,d,k,j,n,b,m,c)},
o6(a){var s,r,q,p,o,n,m,l,k,j,i,h=null,g=A.C(a.h(0,"id")),f=A.C(a.h(0,"name")),e=A.w(a.h(0,"sup"))
if(e==null)e=""
s=A.w(a.h(0,"code"))
if(s==null)s=""
r=A.at(a.h(0,"nominalMm"))
q=A.at(a.h(0,"idMm"))
p=A.w(a.h(0,"material"))
if(p==null)p="pvc"
p=A.ad(B.dn,p,t.f7)
o=A.x(a.h(0,"c"))
if(o==null)o=h
if(o==null)o=150
n=A.x(a.h(0,"roughMm"))
if(n==null)n=h
if(n==null)n=0.0015
m=A.x(a.h(0,"ratingM"))
if(m==null)m=h
if(m==null)m=60
l=A.x(a.h(0,"wallMm"))
if(l==null)l=h
if(l==null)l=2
k=A.x(a.h(0,"cost"))
if(k==null)k=h
if(k==null)k=0
j=t.O.a(a.h(0,"usage"))
if(j==null)j=["zone","mainline"]
j=J.aE(j,new A.iI(),t.W).aq(0)
i=A.W(a.h(0,"enabled"))
return A.aq(s,k,i!==!1,o,g,q,p,f,r,m,n,e,j,l)},
o4(a){var s,r,q,p,o,n,m,l=A.C(a.h(0,"id")),k=A.C(a.h(0,"name")),j=A.w(a.h(0,"sup"))
if(j==null)j=""
s=A.w(a.h(0,"code"))
if(s==null)s=""
r=A.ad(B.dl,A.C(a.h(0,"kind")),t.hF)
q=J.aE(t.j.a(a.h(0,"nozzles")),new A.iD(),t.mP)
q=A.q(q,q.$ti.j("u.E"))
p=A.x(a.h(0,"cost"))
if(p==null)p=null
if(p==null)p=0
o=A.x(a.h(0,"inletMm"))
if(o==null)o=null
if(o==null)o=20
n=A.x(a.h(0,"riser"))
if(n==null)n=null
if(n==null)n=0
m=A.W(a.h(0,"enabled"))
return new A.a3(l,k,j,s,r,q,p,o,n,m!==!1)},
cS(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){return new A.aR(j,n,r,b,o,k,g,f,a,d,m,l,e,a0,s,p,q,i,c,h)},
aj(a,b,c,d,e,f,g,h,i,j,k,l){return new A.aP(e,h,l,a,j,k,i,A.m3(i),c,g,f,b,d)},
od(a){var s,r,q,p,o,n,m,l,k,j,i=null,h=A.C(a.h(0,"id")),g=A.W(a.h(0,"sub"))
if(g==null)g=B.yE.v(0,a.h(0,"id"))
s=A.C(a.h(0,"name"))
r=A.w(a.h(0,"sup"))
if(r==null)r=""
q=A.w(a.h(0,"code"))
if(q==null)q=""
p=A.x(a.h(0,"kw"))
if(p==null)p=i
if(p==null)p=0
o=J.aE(t.j.a(a.h(0,"points")),new A.iZ(),t.aL)
o=A.q(o,o.$ti.j("u.E"))
n=A.x(a.h(0,"eff"))
if(n==null)n=i
if(n==null)n=0.7
m=A.x(a.h(0,"minQ"))
if(m==null)m=i
if(m==null)m=0
l=A.x(a.h(0,"maxQ"))
if(l==null)l=i
if(l==null)l=1
k=A.x(a.h(0,"cost"))
if(k==null)k=i
if(k==null)k=0
j=A.W(a.h(0,"enabled"))
return A.aj(q,k,n,j!==!1,h,l,m,s,o,p,g,r)},
lC(a,b,c,d,e,f){return new A.fB(c,b,e,f,d,a)},
nz(a){var s,r,q,p,o=t.O,n=o.a(a.h(0,"pipes"))
if(n==null)n=[]
n=J.aE(n,new A.fL(),t.p)
n=A.q(n,n.$ti.j("u.E"))
s=o.a(a.h(0,"outlets"))
if(s==null)s=[]
s=J.aE(s,new A.fM(),t.fa)
s=A.q(s,s.$ti.j("u.E"))
r=o.a(a.h(0,"tapes"))
if(r==null)r=[]
r=J.aE(r,new A.fN(),t.gs)
r=A.q(r,r.$ti.j("u.E"))
q=o.a(a.h(0,"valves"))
if(q==null)q=[]
q=J.aE(q,new A.fO(),t.e4)
q=A.q(q,q.$ti.j("u.E"))
p=o.a(a.h(0,"pumps"))
if(p==null)p=[]
p=J.aE(p,new A.fP(),t.dz)
p=A.q(p,p.$ti.j("u.E"))
o=o.a(a.h(0,"fittings"))
if(o==null)o=[]
o=J.aE(o,new A.fQ(),t.kN)
o=A.q(o,o.$ti.j("u.E"))
return A.lC(o,s,n,p,r,q)},
nx(){var s,r,q,p,o,n,m,l,k,j="Microaspersor 360\xb0",i="Microaspersor PC",h='Aspersor de impacto 3/4"',g=1500,f='V\xe1lvula hidr\xe1ulica 3"',e='V\xe1lvula hidr\xe1ulica 4"',d='V\xe1lvula hidr\xe1ulica 6"',c='Filtro de discos 2" (120 mesh)',b='Filtro de discos 3" (120 mesh)',a='Filtro de discos 4" (120 mesh)',a0='Ventosa 1"',a1='Ventosa 2"',a2='Ventosa 3"',a3=new A.fD("en"),a4=new A.fE(),a5=t.W,a6=A.d([A.aq("",0.9,!0,140,"pe16",13.6,B.at,"PE 16 mm (PN 4)",16,40,0.003,"",A.ah([B.p],a5),1.2),A.aq("",1.3,!0,140,"pe20",17,B.at,"PE 20 mm (PN 4)",20,40,0.003,"",A.ah([B.p],a5),1.5),A.aq("",2.1,!0,145,"pe25",21,B.y,"PE 25 mm (PN 6)",25,60,0.003,"",A.ah([B.p,B.i],a5),2),A.aq("",3.2,!0,145,"pe32",27.2,B.y,"PE 32 mm (PN 6)",32,60,0.003,"",A.ah([B.p,B.i],a5),2.4),A.aq("",4.9,!0,145,"pe40",34,B.y,"PE 40 mm (PN 6)",40,60,0.003,"",A.ah([B.i],a5),3),A.aq("",7.4,!0,145,"pe50",42.6,B.y,"PE 50 mm (PN 6)",50,60,0.003,"",A.ah([B.i],a5),3.7),A.aq("",4.5,!0,150,"pvc35",32,B.o,"PVC DN 35 PN 80",35,80,0.0015,"",A.ah([B.i,B.j],a5),1.5),A.aq("",7.2,!0,150,"pvc50",46.4,B.o,"PVC DN 50 PN 80",50,80,0.0015,"",A.ah([B.i,B.j],a5),1.8),A.aq("",14.5,!0,150,"pvc75",70.6,B.o,"PVC DN 75 PN 80",75,80,0.0015,"",A.ah([B.i,B.j],a5),2.2),A.aq("",24,!0,150,"pvc100",96,B.o,"PVC DN 100 PN 80",100,80,0.0015,"",A.ah([B.i,B.j],a5),2.5),A.aq("",36,!0,150,"pvc125",118.6,B.o,"PVC DN 125 PN 80",125,80,0.0015,"",A.ah([B.j],a5),3.2),A.aq("",52,!0,150,"pvc150",144,B.o,"PVC DN 150 PN 80",150,80,0.0015,"",A.ah([B.j],a5),3.8),A.aq("",88,!0,150,"pvc200",191.6,B.o,"PVC DN 200 PN 80",200,80,0.0015,"",A.ah([B.j],a5),4.9),A.aq("",135,!0,150,"pvc250",239.4,B.o,"PVC DN 250 PN 80",250,80,0.0015,"",A.ah([B.j],a5),6.2),A.aq("",42,!0,150,"pead110",96.8,B.y,"PEAD 110 mm PN 10",110,100,0.002,"",A.ah([B.j],a5),6.6),A.aq("",85,!0,150,"pead160",141,B.y,"PEAD 160 mm PN 10",160,100,0.002,"",A.ah([B.j],a5),9.5),A.aq("",160,!1,120,"steel150",154,B.br,a3.$3('A\xe7o galvanizado 6"','Galvanised steel 6"','Acero galvanizado 6"'),150,200,0.15,"",A.ah([B.j],a5),4.5)],t.D)
a5=t.nB
s=A.d([new A.a3("drip_pc",a3.$3("Gotejador PC (bot\xe3o)","PC dripper (button)","Gotero PC (bot\xf3n)"),"","",B.as,A.d([new A.E("pc2","2 L/h PC",a4.$3(2,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.E("pc4","4 L/h PC",a4.$3(4,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.E("pc8","8 L/h PC",a4.$3(8,10,0.03),360,5,40,10,0.03,0.05,0.05)],a5),0.6,0,0,!0),new A.a3("drip_turb",a3.$3("Gotejador turbulento","Turbulent dripper","Gotero turbulento"),"","",B.as,A.d([new A.E("t2","2 L/h",a4.$3(2,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.E("t4","4 L/h",a4.$3(4,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.E("t8","8 L/h",a4.$3(8,10,0.5),360,5,25,10,0.04,0.05,0.05)],a5),0.35,0,0,!0),new A.a3("micro",a3.$3(j,"Micro-sprinkler 360\xb0",j),"","",B.ar,A.d([new A.E("m35",a3.$3("35 L/h (raio 3,0 m)","35 L/h (radius 3.0 m)","35 L/h (radio 3,0 m)"),a4.$4$radiusM(35,15,0.5,3),360,10,30,15,0.05,0.05,0.05),new A.E("m50",a3.$3("50 L/h (raio 3,5 m)","50 L/h (radius 3.5 m)","50 L/h (radio 3,5 m)"),a4.$4$radiusM(50,15,0.5,3.5),360,10,30,15,0.05,0.05,0.05),new A.E("m70",a3.$3("70 L/h (raio 4,0 m)","70 L/h (radius 4.0 m)","70 L/h (radio 4,0 m)"),a4.$4$radiusM(70,15,0.5,4),360,10,30,15,0.05,0.05,0.05),new A.E("m120",a3.$3("120 L/h (raio 5,0 m)","120 L/h (radius 5.0 m)","120 L/h (radio 5,0 m)"),a4.$4$radiusM(120,20,0.5,5),360,15,35,20,0.05,0.05,0.05)],a5),2.8,0,0.3,!0),new A.a3("micro_pc",a3.$3(i,"PC micro-sprinkler",i),"","",B.ar,A.d([new A.E("mpc40",a3.$3("40 L/h PC (raio 3,5 m)","40 L/h PC (radius 3.5 m)","40 L/h PC (radio 3,5 m)"),a4.$4$radiusM(40,15,0.05,3.5),360,12,40,20,0.05,0.05,0.05),new A.E("mpc70",a3.$3("70 L/h PC (raio 4,5 m)","70 L/h PC (radius 4.5 m)","70 L/h PC (radio 4,5 m)"),a4.$4$radiusM(70,15,0.05,4.5),360,12,40,20,0.05,0.05,0.05)],a5),3.9,0,0.3,!0),new A.a3("impact34",a3.$3(h,'Impact sprinkler 3/4"',h),"","",B.a1,A.d([new A.E("i3.5",a3.$3("Bocal 3,5 mm (0,9 m\xb3/h, R 12 m)","Nozzle 3.5 mm (0.9 m\xb3/h, R 12 m)","Boquilla 3,5 mm (0,9 m\xb3/h, R 12 m)"),a4.$4$radiusM(900,30,0.5,12),360,20,45,30,0.03,0.05,0.05),new A.E("i4.0",a3.$3("Bocal 4,0 mm (1,2 m\xb3/h, R 13 m)","Nozzle 4.0 mm (1.2 m\xb3/h, R 13 m)","Boquilla 4,0 mm (1,2 m\xb3/h, R 13 m)"),a4.$4$radiusM(1200,30,0.5,13),360,20,45,30,0.03,0.05,0.05),new A.E("i4.5",a3.$3("Bocal 4,5 mm (1,5 m\xb3/h, R 14 m)","Nozzle 4.5 mm (1.5 m\xb3/h, R 14 m)","Boquilla 4,5 mm (1,5 m\xb3/h, R 14 m)"),a4.$4$radiusM(g,30,0.5,14),360,20,45,30,0.03,0.05,0.05),new A.E("i5.0",a3.$3("Bocal 5,0 mm (1,9 m\xb3/h, R 15 m)","Nozzle 5.0 mm (1.9 m\xb3/h, R 15 m)","Boquilla 5,0 mm (1,9 m\xb3/h, R 15 m)"),a4.$4$radiusM(1900,30,0.5,15),360,25,50,35,0.03,0.05,0.05)],a5),18,20,1,!0),new A.a3("gun",a3.$3('Canh\xe3o hidr\xe1ulico 1,5"','Big gun 1.5"','Ca\xf1\xf3n de riego 1,5"'),"","",B.bp,A.d([new A.E("g14",a3.$3("Bocal 14 mm (15 m\xb3/h, R 32 m)","Nozzle 14 mm (15 m\xb3/h, R 32 m)","Boquilla 14 mm (15 m\xb3/h, R 32 m)"),a4.$4$radiusM(15e3,40,0.5,32),360,30,70,40,0.03,0.05,0.05),new A.E("g18",a3.$3("Bocal 18 mm (25 m\xb3/h, R 40 m)","Nozzle 18 mm (25 m\xb3/h, R 40 m)","Boquilla 18 mm (25 m\xb3/h, R 40 m)"),a4.$4$radiusM(25e3,45,0.5,40),360,35,80,45,0.03,0.05,0.05)],a5),420,40,1.5,!0),new A.a3("rotor",a3.$3('Rotor de jardim 1/2"','Turf rotor 1/2"','Rotor de jard\xedn 1/2"'),"","",B.a1,A.d([new A.E("r1.5","#1.5 (0,35 m\xb3/h, R 8 m)",a4.$4$radiusM(350,25,0.5,8),360,17,45,25,0.03,0.05,0.05),new A.E("r3","#3 (0,70 m\xb3/h, R 10 m)",a4.$4$radiusM(700,25,0.5,10),360,17,45,25,0.03,0.05,0.05),new A.E("r3_180","#3 180\xb0 (0,35 m\xb3/h, R 10 m)",a4.$4$radiusM(350,25,0.5,10),180,17,45,25,0.03,0.05,0.05),new A.E("r3_90","#3 90\xb0 (0,18 m\xb3/h, R 10 m)",a4.$4$radiusM(180,25,0.5,10),90,17,45,25,0.03,0.05,0.05)],a5),45,15,0.1,!0),new A.a3("spray",a3.$3('Spray pop-up 4"','Pop-up spray 4"','Difusor emergente 4"'),"","",B.a1,A.d([new A.E("s12","12F (0,60 m\xb3/h, R 3,7 m)",a4.$4$radiusM(600,20,0.5,3.7),360,10,30,20,0.04,0.05,0.05),new A.E("s12h","12H (0,30 m\xb3/h, R 3,7 m)",a4.$4$radiusM(300,20,0.5,3.7),180,10,30,20,0.04,0.05,0.05),new A.E("s12q","12Q (0,15 m\xb3/h, R 3,7 m)",a4.$4$radiusM(150,20,0.5,3.7),90,10,30,20,0.04,0.05,0.05),new A.E("s15","15F (0,84 m\xb3/h, R 4,6 m)",a4.$4$radiusM(840,20,0.5,4.6),360,10,30,20,0.04,0.05,0.05)],a5),12,15,0,!0),new A.a3("demand",a3.$3("Ponto de demanda","Demand point","Punto de demanda"),"","",B.bq,A.d([new A.E("d5","5 m\xb3/h @ 20 m",a4.$3(5000,20,0),360,20,80,20,0,0.5,0.5),new A.E("d10","10 m\xb3/h @ 20 m",a4.$3(1e4,20,0),360,20,80,20,0,0.5,0.5),new A.E("d20","20 m\xb3/h @ 25 m",a4.$3(2e4,25,0),360,25,80,25,0,0.5,0.5)],a5),0,50,0,!0)],t.dO)
a5=a3.$3("Fita gotejadora 16 mm, 1,0 L/h @ 0,30 m","Drip tape 16 mm, 1.0 L/h @ 0.30 m","Cinta de goteo 16 mm, 1,0 L/h @ 0,30 m")
a5=A.cS(0.3,"",0.45,0.03,8,a4.$3(1,7,0.5),0.3,!0,140,"tape16_10_30",15.6,12,4,a5,16,15,0.002,"",20,30)
r=a3.$3("Fita gotejadora 16 mm, 1,6 L/h @ 0,20 m","Drip tape 16 mm, 1.6 L/h @ 0.20 m","Cinta de goteo 16 mm, 1,6 L/h @ 0,20 m")
r=A.cS(0.3,"",0.55,0.03,8,a4.$3(1.6,7,0.5),0.2,!0,140,"tape16_16_20",15.6,12,4,r,16,15,0.002,"",20,30)
q=a3.$3("Tubo gotejador 16 mm, 1,6 L/h @ 0,50 m","Dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo 16 mm, 1,6 L/h @ 0,50 m")
q=A.cS(0.4,"",1.1,0.03,10,a4.$3(1.6,10,0.5),0.5,!0,140,"drip16_16_50",13.8,25,5,q,16,30,0.002,"",20,30)
p=a3.$3("Tubo gotejador 16 mm, 2,4 L/h @ 0,75 m","Dripline 16 mm, 2.4 L/h @ 0.75 m","Tuber\xeda de goteo 16 mm, 2,4 L/h @ 0,75 m")
p=A.cS(0.4,"",1.05,0.03,10,a4.$3(2.4,10,0.5),0.75,!0,140,"drip16_24_75",13.8,25,5,p,16,30,0.002,"",20,30)
o=a3.$3("Tubo gotejador PC 16 mm, 1,6 L/h @ 0,50 m","PC dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo PC 16 mm, 1,6 L/h @ 0,50 m")
o=A.cS(0.4,"",1.6,0.03,15,a4.$3(1.6,10,0.04),0.5,!0,140,"drip16pc_16_50",13.8,40,6,o,16,40,0.002,"",150,50)
n=a3.$3("Tubo gotejador PC 20 mm, 2,3 L/h @ 0,75 m","PC dripline 20 mm, 2.3 L/h @ 0.75 m","Tuber\xeda de goteo PC 20 mm, 2,3 L/h @ 0,75 m")
m=A.d([a5,r,q,p,o,A.cS(0.4,"",2.1,0.03,15,a4.$3(2.3,10,0.04),0.75,!0,140,"drip20pc_23_75",17.5,40,6,n,20,40,0.002,"",150,50)],t.kU)
n=new A.fC()
l=A.d([new A.D("ev25",a3.$3('V\xe1lvula el\xe9trica 1"','Solenoid valve 1"','Electrov\xe1lvula 1"'),"","",B.B,25,n.$2(6,25),0.00005555555555555556,0.0016666666666666666,120,0,!0),new A.D("ev40",a3.$3('V\xe1lvula el\xe9trica 1\xbd"','Solenoid valve 1\xbd"','Electrov\xe1lvula 1\xbd"'),"","",B.B,40,n.$2(5.5,40),0.0002777777777777778,0.0044444444444444444,260,0,!0),new A.D("ev50",a3.$3('V\xe1lvula el\xe9trica 2"','Solenoid valve 2"','Electrov\xe1lvula 2"'),"","",B.B,50,n.$2(5,50),0.0005555555555555556,0.008333333333333333,380,0,!0),new A.D("ev80",a3.$3(f,'Hydraulic valve 3"',f),"","",B.B,80,n.$2(4.5,80),0.001388888888888889,0.022222222222222223,900,0,!0),new A.D("ev100",a3.$3(e,'Hydraulic valve 4"',e),"","",B.B,100,n.$2(4,100),0.002777777777777778,0.03888888888888889,g,0,!0),new A.D("ev150",a3.$3(d,'Hydraulic valve 6"',d),"","",B.B,150,n.$2(3.5,150),0.006944444444444444,0.08333333333333333,2800,0,!0),new A.D("prv50",a3.$3('V\xe1lvula reguladora de press\xe3o 2"','Pressure reducing valve 2"','V\xe1lvula reguladora de presi\xf3n 2"'),"","",B.R,50,n.$2(3,50),0,0.008333333333333333,650,25,!0),new A.D("prv80",a3.$3('V\xe1lvula reguladora de press\xe3o 3"','Pressure reducing valve 3"','V\xe1lvula reguladora de presi\xf3n 3"'),"","",B.R,80,n.$2(3,80),0,0.022222222222222223,1200,30,!0),new A.D("prv100",a3.$3('V\xe1lvula reguladora de press\xe3o 4"','Pressure reducing valve 4"','V\xe1lvula reguladora de presi\xf3n 4"'),"","",B.R,100,n.$2(3,100),0,0.03888888888888889,2100,30,!0),new A.D("gate50",a3.$3('Registro gaveta 2"','Gate valve 2"','V\xe1lvula de compuerta 2"'),"","",B.S,50,n.$2(0.2,50),0,0.011111111111111112,90,0,!0),new A.D("gate80",a3.$3('Registro gaveta 3"','Gate valve 3"','V\xe1lvula de compuerta 3"'),"","",B.S,80,n.$2(0.2,80),0,0.025,220,0,!0),new A.D("gate100",a3.$3('Registro gaveta 4"','Gate valve 4"','V\xe1lvula de compuerta 4"'),"","",B.S,100,n.$2(0.2,100),0,0.041666666666666664,420,0,!0),new A.D("gate150",a3.$3('Registro gaveta 6"','Gate valve 6"','V\xe1lvula de compuerta 6"'),"","",B.S,150,n.$2(0.2,150),0,0.09722222222222222,900,0,!0),new A.D("check50",a3.$3('V\xe1lvula de reten\xe7\xe3o 2"','Check valve 2"','V\xe1lvula de retenci\xf3n 2"'),"","",B.T,50,n.$2(2,50),0,0.011111111111111112,150,0,!0),new A.D("check80",a3.$3('V\xe1lvula de reten\xe7\xe3o 3"','Check valve 3"','V\xe1lvula de retenci\xf3n 3"'),"","",B.T,80,n.$2(2,80),0,0.025,260,0,!0),new A.D("check100",a3.$3('V\xe1lvula de reten\xe7\xe3o 4"','Check valve 4"','V\xe1lvula de retenci\xf3n 4"'),"","",B.T,100,n.$2(2,100),0,0.041666666666666664,380,0,!0),new A.D("filter_disc50",a3.$3(c,'Disc filter 2" (120 mesh)',c),"","",B.C,50,new A.aF(62208,2,0),0,0.006944444444444444,850,0,!0),new A.D("filter_disc80",a3.$3(b,'Disc filter 3" (120 mesh)',b),"","",B.C,80,new A.aF(15552,2,0),0,0.013888888888888888,1600,0,!0),new A.D("filter_disc100",a3.$3(a,'Disc filter 4" (120 mesh)',a),"","",B.C,100,new A.aF(4800,2,0),0,0.025,2600,0,!0),new A.D("filter_screen80",a3.$3('Filtro de tela 3"','Screen filter 3"','Filtro de malla 3"'),"","",B.C,80,new A.aF(9000,2,0),0,0.016666666666666666,1400,0,!0),new A.D("filter_screen100",a3.$3('Filtro de tela 4"','Screen filter 4"','Filtro de malla 4"'),"","",B.C,100,new A.aF(3240,2,0),0,0.027777777777777776,2100,0,!0),new A.D("filter_screen150",a3.$3('Filtro de tela 6"','Screen filter 6"','Filtro de malla 6"'),"","",B.C,150,new A.aF(810,2,0),0,0.05555555555555555,3800,0,!0),new A.D("meter50",a3.$3('Hidr\xf4metro 2"','Water meter 2"','Contador de agua 2"'),"","",B.a7,50,n.$2(7,50),0,0.005555555555555556,700,0,!0),new A.D("meter80",a3.$3('Hidr\xf4metro 3"','Water meter 3"','Contador de agua 3"'),"","",B.a7,80,n.$2(7,80),0,0.016666666666666666,1100,0,!0),new A.D("meter100",a3.$3('Hidr\xf4metro 4"','Water meter 4"','Contador de agua 4"'),"","",B.a7,100,n.$2(7,100),0,0.03333333333333333,1600,0,!0),new A.D("backflow50",a3.$3('V\xe1lvula anti-refluxo 2"','Backflow preventer 2"','V\xe1lvula antirretorno 2"'),"","",B.aQ,50,n.$2(8,50),0,0.006944444444444444,900,0,!0),new A.D("backflow80",a3.$3('V\xe1lvula anti-refluxo 3"','Backflow preventer 3"','V\xe1lvula antirretorno 3"'),"","",B.aQ,80,n.$2(8,80),0,0.016666666666666666,g,0,!0),new A.D("air25",a3.$3(a0,'Air release valve 1"',a0),"","",B.a8,25,B.I,0,1,90,0,!0),new A.D("air50",a3.$3(a1,'Air release valve 2"',a1),"","",B.a8,50,B.I,0,1,180,0,!0),new A.D("air80",a3.$3(a2,'Air release valve 3"',a2),"","",B.a8,80,B.I,0,1,320,0,!0)],t.bD)
n=t.fU
k=A.d([A.aj("",900,0.45,!0,"pump_c1",0.0016666666666666666,0,a3.$3("Bomba centr\xedfuga 1 cv (4 m\xb3/h @ 20 m)","Centrifugal pump 1 hp (4 m\xb3/h @ 20 m)","Bomba centr\xedfuga 1 CV (4 m\xb3/h @ 20 m)"),A.d([B.e1,B.ei,B.eh,B.dZ],n),0.75,!1,""),A.aj("",g,0.5,!0,"pump_c2",0.002777777777777778,0,a3.$3("Bomba centr\xedfuga 2 cv (7 m\xb3/h @ 28 m)","Centrifugal pump 2 hp (7 m\xb3/h @ 28 m)","Bomba centr\xedfuga 2 CV (7 m\xb3/h @ 28 m)"),A.d([B.e2,B.f1,B.eu,B.eg],n),1.5,!1,""),A.aj("",2200,0.55,!0,"pump_small",0.004166666666666667,0,a3.$3("Bomba centr\xedfuga 3 cv (10 m\xb3/h @ 35 m)","Centrifugal pump 3 hp (10 m\xb3/h @ 35 m)","Bomba centr\xedfuga 3 CV (10 m\xb3/h @ 35 m)"),A.d([B.e3,B.ek,B.eV,B.eM],n),2.2,!1,""),A.aj("",3200,0.6,!0,"pump_c5",0.0075,0,a3.$3("Bomba centr\xedfuga 5 cv (18 m\xb3/h @ 38 m)","Centrifugal pump 5 hp (18 m\xb3/h @ 38 m)","Bomba centr\xedfuga 5 CV (18 m\xb3/h @ 38 m)"),A.d([B.e4,B.eI,B.f2,B.eC],n),3.7,!1,""),A.aj("",4500,0.62,!0,"pump_c7_5",0.011666666666666667,0,a3.$3("Bomba centr\xedfuga 7,5 cv (28 m\xb3/h @ 40 m)","Centrifugal pump 7.5 hp (28 m\xb3/h @ 40 m)","Bomba centr\xedfuga 7,5 CV (28 m\xb3/h @ 40 m)"),A.d([B.e5,B.eJ,B.eH,B.ez],n),5.5,!1,""),A.aj("",6500,0.65,!0,"pump_mid",0.016666666666666666,0,a3.$3("Bomba centr\xedfuga 10 cv (40 m\xb3/h @ 45 m)","Centrifugal pump 10 hp (40 m\xb3/h @ 45 m)","Bomba centr\xedfuga 10 CV (40 m\xb3/h @ 45 m)"),A.d([B.e6,B.eq,B.eB,B.ex],n),7.5,!1,""),A.aj("",9000,0.68,!0,"pump_c15",0.022222222222222223,0,a3.$3("Bomba centr\xedfuga 15 cv (55 m\xb3/h @ 45 m)","Centrifugal pump 15 hp (55 m\xb3/h @ 45 m)","Bomba centr\xedfuga 15 CV (55 m\xb3/h @ 45 m)"),A.d([B.e7,B.eF,B.ew,B.em],n),11,!1,""),A.aj("",12e3,0.7,!0,"pump_c20",0.027777777777777776,0,a3.$3("Bomba centr\xedfuga 20 cv (70 m\xb3/h @ 48 m)","Centrifugal pump 20 hp (70 m\xb3/h @ 48 m)","Bomba centr\xedfuga 20 CV (70 m\xb3/h @ 48 m)"),A.d([B.e8,B.f4,B.eS,B.eG],n),15,!1,""),A.aj("",18e3,0.72,!0,"pump_big",0.05,0,a3.$3("Bomba centr\xedfuga 30 cv (120 m\xb3/h @ 55 m)","Centrifugal pump 30 hp (120 m\xb3/h @ 55 m)","Bomba centr\xedfuga 30 CV (120 m\xb3/h @ 55 m)"),A.d([B.e9,B.eZ,B.el,B.eY],n),22,!1,""),A.aj("",28e3,0.74,!0,"pump_c50",0.06388888888888888,0,a3.$3("Bomba centr\xedfuga 50 cv (160 m\xb3/h @ 55 m)","Centrifugal pump 50 hp (160 m\xb3/h @ 55 m)","Bomba centr\xedfuga 50 CV (160 m\xb3/h @ 55 m)"),A.d([B.ea,B.eQ,B.ee,B.ej],n),37,!1,""),A.aj("",4e4,0.76,!0,"pump_c75",0.09166666666666666,0,a3.$3("Bomba centr\xedfuga 75 cv (230 m\xb3/h @ 60 m)","Centrifugal pump 75 hp (230 m\xb3/h @ 60 m)","Bomba centr\xedfuga 75 CV (230 m\xb3/h @ 60 m)"),A.d([B.bv,B.ev,B.f_,B.eE],n),55,!1,""),A.aj("",55e3,0.78,!0,"pump_c100",0.11666666666666667,0,a3.$3("Bomba centr\xedfuga 100 cv (300 m\xb3/h @ 65 m)","Centrifugal pump 100 hp (300 m\xb3/h @ 65 m)","Bomba centr\xedfuga 100 CV (300 m\xb3/h @ 65 m)"),A.d([B.ed,B.ef,B.eU,B.eP],n),75,!1,""),A.aj("",2800,0.55,!0,"pump_s3",0.003333333333333333,0,a3.$3("Bomba submersa 3 cv (8 m\xb3/h @ 55 m)","Submersible pump 3 hp (8 m\xb3/h @ 55 m)","Bomba sumergible 3 CV (8 m\xb3/h @ 55 m)"),A.d([B.bv,B.es,B.eo,B.er],n),2.2,!0,""),A.aj("",3900,0.58,!0,"pump_s5",0.005,0,a3.$3("Bomba submersa 5 cv (12 m\xb3/h @ 65 m)","Submersible pump 5 hp (12 m\xb3/h @ 65 m)","Bomba sumergible 5 CV (12 m\xb3/h @ 65 m)"),A.d([B.bw,B.eD,B.f3,B.eT],n),3.7,!0,""),A.aj("",5400,0.68,!0,"pump_sub",0.009722222222222222,0,a3.$3("Bomba submersa 7,5 cv (25 m\xb3/h @ 60 m)","Submersible pump 7.5 hp (25 m\xb3/h @ 60 m)","Bomba sumergible 7,5 CV (25 m\xb3/h @ 60 m)"),A.d([B.eb,B.eX,B.ep,B.eL],n),5.5,!0,""),A.aj("",9500,0.65,!0,"pump_s15",0.016666666666666666,0,a3.$3("Bomba submersa 15 cv (40 m\xb3/h @ 65 m)","Submersible pump 15 hp (40 m\xb3/h @ 65 m)","Bomba sumergible 15 CV (40 m\xb3/h @ 65 m)"),A.d([B.bw,B.ey,B.e_,B.eA],n),11,!0,""),A.aj("",15e3,0.68,!0,"pump_s25",0.022222222222222223,0,a3.$3("Bomba submersa 25 cv (55 m\xb3/h @ 80 m)","Submersible pump 25 hp (55 m\xb3/h @ 80 m)","Bomba sumergible 25 CV (55 m\xb3/h @ 80 m)"),A.d([B.e0,B.eR,B.f0,B.eK],n),18.5,!0,""),A.aj("",19e3,0.72,!0,"pump_s30",0.03888888888888889,0,a3.$3("Bomba submersa 30 cv (100 m\xb3/h @ 60 m)","Submersible pump 30 hp (100 m\xb3/h @ 60 m)","Bomba sumergible 30 CV (100 m\xb3/h @ 60 m)"),A.d([B.ec,B.eO,B.eN,B.en],n),22,!0,"")],t.fH)
return A.lC(A.ny(a6,"en"),s,a6,k,m,l)},
ny(a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d="Adaptador roscado",c="Conector inicial de lateral",b="Tubo de subida",a="Riser",a0=new A.fJ(a6),a1=A.r(a5),a2=a1.j("e(1)"),a3=new A.t(a5,a2.a(new A.fF()),a1.j("t<1,e>")).aq(0),a4=A.q(a3,A.i(a3).c)
B.a.a4(a4)
s=A.d([],t.eK)
r=new A.fI()
q=new A.fK()
for(a3=a4.length,p=a3,o=0;o<p;h===a3||(0,A.k)(a4),++o,p=h){n=a4[o]
m=r.$1(n)
B.a.k(s,new A.Y("cpl"+m,A.z(a0.$3("Luva","Coupler","Manguito"))+" "+m+" mm","","",B.V,n,0,q.$2(4,n),!0,""))
B.a.k(s,new A.Y("el90_"+m,A.z(a0.$3("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0"))+" "+m+" mm","","",B.aj,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.Y("el45_"+m,A.z(a0.$3("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0"))+" "+m+" mm","","",B.ak,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.Y("tee"+m,A.z(a0.$3("T\xea","Tee","Te"))+" "+m+" mm","","",B.J,n,0,q.$2(8,n),!0,""))
B.a.k(s,new A.Y("cross"+m,A.z(a0.$3("Cruzeta","Cross","Cruz"))+" "+m+" mm","","",B.al,n,0,q.$2(11,n),!0,""))
B.a.k(s,new A.Y("cap"+m,A.z(a0.$3("Tamp\xe3o (cap)","End cap","Tap\xf3n"))+" "+m+" mm","","",B.K,n,0,q.$2(3,n),!0,""))
B.a.k(s,new A.Y("adp"+m,A.z(a0.$3(d,"Threaded adapter",d))+" "+m+" mm","","",B.am,n,0,q.$2(5,n),!0,""))
for(p=a4.length,l="red"+m+"x",k=n<=75,j="teer"+m+"x",i=0;h=a4.length,i<h;a4.length===p||(0,A.k)(a4),++i){g=a4[i]
if(g>=n)continue
f=r.$1(g)
B.a.k(s,new A.Y(l+f,A.z(a0.$3("Redu\xe7\xe3o","Reducer","Reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.v,n,g,q.$2(5,n),!0,""))
if(g>=20||k)B.a.k(s,new A.Y(j+f,A.z(a0.$3("T\xea de redu\xe7\xe3o","Reducing tee","Te de reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.J,n,g,q.$2(9,n),!0,""))}}a3=A.ah([16,20],t.i)
a3.B(0,new A.bz(new A.B(a5,a1.j("v(1)").a(new A.fG()),a1.j("B<1>")),a2.a(new A.fH()),a1.j("bz<1,e>")))
e=A.q(a3,a3.$ti.c)
B.a.a4(e)
for(a1=e.length,o=0;o<e.length;e.length===a1||(0,A.k)(e),++o){n=e[o]
m=r.$1(n)
B.a.k(s,new A.Y("to"+m,A.z(a0.$3(c,"Lateral take-off",c))+" "+m+" mm","","",B.w,n,0,1.2,!0,""))
B.a.k(s,new A.Y("te"+m,A.z(a0.$3("Final de linha","Line end","Final de l\xednea"))+" "+m+" mm","","",B.L,n,0,0.9,!0,""))}B.a.k(s,new A.Y("riser_micro",a0.$3("Haste/tubinho de microaspersor","Micro-sprinkler stake/tube","Estaca/microtubo de microaspersor"),"","",B.m,0,0,1.1,!0,""))
B.a.k(s,new A.Y("riser20",A.z(a0.$3(b,a,b))+" 20 mm","","",B.m,20,0,6,!0,""))
B.a.k(s,new A.Y("riser25",A.z(a0.$3(b,a,b))+" 25 mm","","",B.m,25,0,8,!0,""))
B.a.k(s,new A.Y("riser40",A.z(a0.$3(b,a,b))+" 40 mm","","",B.m,40,0,18,!0,""))
return s},
b0:function b0(a,b){this.a=a
this.b=b},
I:function I(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
iJ:function iJ(){},
iI:function iI(){},
bd:function bd(a,b){this.a=a
this.b=b},
E:function E(a,b,c,d,e,f,g,h,i,j){var _=this
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
iE:function iE(a){this.a=a},
iF:function iF(a){this.a=a},
iG:function iG(){},
iD:function iD(){},
aR:function aR(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){var _=this
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
aJ:function aJ(a,b){this.a=a
this.b=b},
D:function D(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
aP:function aP(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
j_:function j_(){},
iZ:function iZ(){},
a7:function a7(a,b){this.a=a
this.b=b},
Y:function Y(a,b,c,d,e,f,g,h,i,j){var _=this
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
fB:function fB(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
fT:function fT(a){this.a=a},
fU:function fU(){},
fR:function fR(a){this.a=a},
fS:function fS(){},
fZ:function fZ(a){this.a=a},
h_:function h_(){},
h6:function h6(a){this.a=a},
h7:function h7(){},
fX:function fX(a){this.a=a},
fY:function fY(){},
fV:function fV(a){this.a=a},
fW:function fW(){},
h0:function h0(){},
h1:function h1(){},
h2:function h2(){},
h3:function h3(){},
h4:function h4(){},
h5:function h5(){},
fL:function fL(){},
fM:function fM(){},
fN:function fN(){},
fO:function fO(){},
fP:function fP(){},
fQ:function fQ(){},
fD:function fD(a){this.a=a},
fE:function fE(){},
fC:function fC(){},
fJ:function fJ(a){this.a=a},
fF:function fF(){},
fI:function fI(){},
fK:function fK(){},
fG:function fG(){},
fH:function fH(){},
nO(b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=null,a6="rot",a7="scope",a8="spec",a9="depth",b0="zone",b1="mainline",b2=A.ad(B.dr,A.C(b5.h(0,"type")),t.od),b3=A.C(b5.h(0,"id")),b4=A.w(b5.h(0,"layer"))
if(b4==null)b4="DRAWING"
s=A.w(b5.h(0,"name"))
if(s==null)s=""
r=new A.i3(b5)
q=new A.i2(b5)
p=new A.i1(b5)
switch(b2.a){case 0:r=t.j
return new A.ci(A.bC(r.a(b5.h(0,"a"))),A.bC(r.a(b5.h(0,"b"))),b3,b4,s)
case 1:r=r.$0()
q=A.W(b5.h(0,"closed"))
return new A.cN(r,q===!0,b3,b4,s)
case 2:return new A.e4(q.$0(),p.$1("r"),b3,b4,s)
case 3:return new A.d3(q.$0(),p.$1("r"),p.$1("s"),p.$1("w"),b3,b4,s)
case 4:r=r.$0()
q=A.W(b5.h(0,"closed"))
return new A.cQ(r,q===!0,b3,b4,s)
case 5:r=r.$0()
q=p.$2("ang",45)
p=p.$2("sp",1)
o=A.W(b5.h(0,"solid"))
return new A.ee(r,q,p,o===!0,b3,b4,s)
case 6:r=q.$0()
q=A.w(b5.h(0,"kind"))
if(q==null)q="tree"
return new A.eQ(r,A.ad(B.dw,q,t.ai),p.$2("size",2),p.$1(a6),b3,b4,s)
case 7:r=q.$0()
q=A.w(b5.h(0,"text"))
if(q==null)q=""
return new A.eT(r,q,p.$2("h",1),p.$1(a6),b3,b4,s)
case 8:r=t.j
return new A.eb(A.bC(r.a(b5.h(0,"a"))),A.bC(r.a(b5.h(0,"b"))),p.$2("off",1),b3,b4,s)
case 9:r=t.j
return new A.e_(A.bC(r.a(b5.h(0,"v"))),A.bC(r.a(b5.h(0,"a"))),A.bC(r.a(b5.h(0,"b"))),p.$2("r",2),b3,b4,s)
case 10:return new A.eN(A.bC(t.j.a(b5.h(0,"c"))),q.$0(),b3,b4,s)
case 11:r=r.$0()
q=A.w(b5.h(0,"text"))
if(q==null)q=""
return new A.cE(r,q,p.$2("h",1),b3,b4,s)
case 12:r=q.$0()
q=p.$2("w",1)
o=p.$2("h",1)
n=p.$1(a6)
p=p.$2("op",1)
m=A.w(b5.h(0,"mime"))
if(m==null)m="image/png"
l=b5.h(0,"data")!=null?B.cO.br(A.C(b5.h(0,"data"))):a5
k=A.w(b5.h(0,"src"))
return new A.eg(r,q,o,n,p,m,l,k==null?"":k,b3,b4,s)
case 13:r=r.$0()
p=p.$1("z")
q=A.W(b5.h(0,"gen"))
return new A.c7(r,p,q===!0,b3,b4,s)
case 14:return new A.dB(q.$0(),p.$1("z"),b3,b4,s)
case 15:r=r.$0()
q=A.ad(B.D,A.C(b5.h(0,a7)),t.E)
o=A.w(b5.h(0,a8))
n=A.W(b5.h(0,"auto"))
return A.o5(n!==!1,p.$1(a9),b3,b4,s,o,r,q)
case 16:r=r.$0()
q=A.w(b5.h(0,a8))
o=A.W(b5.h(0,"auto"))
n=A.w(b5.h(0,"outlet"))
if(n==null)n=""
m=A.w(b5.h(0,"nozzle"))
l=p.$2("head",20)
k=p.$2("sp",5)
j=p.$2("off",0)
i=p.$2("arc",360)
h=p.$1("riser")
return A.oi(i,o!==!1,p.$1(a9),l,b3,b4,s,m,j,n,q,r,h,k)
case 17:r=r.$0()
q=A.w(b5.h(0,a8))
if(q==null)q=""
o=p.$2("inlet",10)
n=A.W(b5.h(0,"reg"))
m=p.$2("submin",0)
return A.on(p.$1(a9),p.$1("flush"),b3,o,b4,s,r,n===!0,m,q)
case 18:r=q.$0()
q=A.w(b5.h(0,a7))
if(q==null)q=b0
q=A.ad(B.D,q,t.E)
o=A.w(b5.h(0,"outlet"))
if(o==null)o=""
n=A.w(b5.h(0,"nozzle"))
m=p.$2("head",20)
l=p.$2("arc",360)
k=p.$1(a6)
p=p.$1("riser")
j=A.w(b5.h(0,b0))
return new A.aZ(r,q,o,n,m,l,k,p,j==null?"":j,b3,b4,s)
case 19:r=q.$0()
q=A.w(b5.h(0,a8))
o=A.w(b5.h(0,b0))
if(o==null)o=s
n=p.$1(a6)
m=A.x(b5.h(0,"fixed"))
if(m==null)m=a5
return new A.b9(r,q,o,n,m,p.$1(a9),b3,b4,s)
case 20:r=q.$0()
q=A.W(b5.h(0,"calc"))
return new A.aC(r,q!==!1,p.$1("dh"),p.$1("mh"),p.$1("dq"),p.$1("mq"),p.$1("wl"),b3,b4,s)
case 21:r=q.$0()
q=A.w(b5.h(0,a8))
o=p.$2("speed",1)
p=p.$1(a6)
n=A.w(b5.h(0,a7))
if(n==null)n=b1
return new A.bo(r,q,o,p,A.ad(B.D,n,t.E),b3,b4,s)
case 22:r=q.$0()
q=A.w(b5.h(0,a8))
o=A.w(b5.h(0,a7))
if(o==null)o=b1
return new A.aY(r,q,A.ad(B.D,o,t.E),p.$1("set"),p.$1(a6),b3,b4,s)
case 23:r=q.$0()
q=A.w(b5.h(0,a7))
if(q==null)q=b0
q=A.ad(B.D,q,t.E)
p=A.x(b5.h(0,"z"))
return new A.ch(r,q,p==null?a5:p,b3,b4,s)
case 24:r=r.$0()
q=p.$2(a9,5)
o=p.$2("eff",0.9)
n=A.w(b5.h(0,"crop"))
if(n==null)n=""
m=A.x(b5.h(0,"epp"))
m=m==null?a5:B.b.ai(m)
if(m==null)m=0
l=A.W(b5.h(0,"wb"))
return new A.cC(r,q,o,n,m,l===!0,p.$2("eto",5),p.$2("kc",1),p.$2("awc",120),p.$2("root",0.6),p.$2("mad",0.5),p.$1("psp"),p.$1("rsp"),p.$2("wf",1),b3,b4,s)
case 25:r=q.$0()
q=p.$2("r",400)
o=p.$1("ang")
n=A.w(b5.h(0,"kind"))
if(n==null)n="pivot"
n=A.ad(B.dq,n,t.n7)
m=p.$1("travel")
l=p.$2("span",50)
k=A.w(b5.h(0,a8))
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
a4=A.w(b5.h(0,b0))
if(a4==null)a4=""
return new A.b1(p.$2("ssp",2.5),A.w(b5.h(0,"sspec")),A.w(b5.h(0,"rspec")),p.$1("tcost"),r,q,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,b3,b4,s)}},
c2(a){var s=J.aE(a,new A.k5(),t.bd)
s=A.q(s,s.$ti.j("u.E"))
return s},
o5(a,b,c,d,e,f,g,h){return new A.aH(g,h,f,a,b,c,d,e)},
oi(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.ak(l,k,b,j,h,d,n,i,a,m,c,e,f,g)},
on(a,b,c,d,e,f,g,h,i,j){return new A.aB(g,j,d,h,i,a,b,c,e,f)},
nM(a){var s,r=a.gC()
A:{s=B.a9===r||B.aa===r||B.ab===r||B.ac===r||B.ad===r||B.ae===r||B.af===r||B.ag===r||B.ah===r||B.ai===r
break A}return s},
nL(a){var s
A:{s=null
if(a instanceof A.aH){s=a.e
break A}if(a instanceof A.ak){s=B.f
break A}if(a instanceof A.aB){s=B.f
break A}if(a instanceof A.aZ){s=a.e
break A}if(a instanceof A.b9)break A
if(a instanceof A.aC){s=B.h
break A}if(a instanceof A.bo){s=a.w
break A}if(a instanceof A.aY){s=a.f
break A}if(a instanceof A.ch){s=a.e
break A}if(a instanceof A.b1){s=B.h
break A}break A}return s},
nN(a){var s
A:{if(a instanceof A.ci){s=A.d([a.d,a.e],t.C)
break A}if(t.f.b(a)){s=a.gP()
break A}if(a instanceof A.d3){s=a.dS()
break A}s=null
break A}return s},
aG:function aG(a,b){this.a=a
this.b=b},
M:function M(a,b){this.a=a
this.b=b},
F:function F(){},
i3:function i3(a){this.a=a},
i4:function i4(){},
i2:function i2(a){this.a=a},
i1:function i1(a){this.a=a},
bf:function bf(){},
a5:function a5(){},
k5:function k5(){},
ci:function ci(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cN:function cN(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
e4:function e4(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
d3:function d3(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
cQ:function cQ(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
ee:function ee(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
aI:function aI(a,b){this.a=a
this.b=b},
eQ:function eQ(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eT:function eT(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eb:function eb(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
e_:function e_(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eN:function eN(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cE:function cE(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
eg:function eg(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
c7:function c7(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
dB:function dB(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
aH:function aH(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
ak:function ak(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
aB:function aB(a,b,c,d,e,f,g,h,i,j){var _=this
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
aZ:function aZ(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
b9:function b9(a,b,c,d,e,f,g,h,i){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.x=f
_.a=g
_.b=h
_.c=i},
aC:function aC(a,b,c,d,e,f,g,h,i,j){var _=this
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
bo:function bo(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
aY:function aY(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
ch:function ch(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
b1:function b1(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var _=this
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
cC:function cC(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
eX:function eX(){},
f_:function f_(){},
f0:function f0(){},
f4:function f4(){},
f7:function f7(){},
f8:function f8(){},
fa:function fa(){},
fb:function fb(){},
fc:function fc(){},
fd:function fd(){},
fe:function fe(){},
fg:function fg(){},
fh:function fh(){},
fi:function fi(){},
fl:function fl(){},
fm:function fm(){},
fn:function fn(){},
fo:function fo(){},
m2(a,b,c){var s=a.a,r=a.b
return new A.A(s+(b.a-s)*c,r+(b.b-r)*c)},
bC(a){var s=J.af(a)
return new A.A(A.at(s.h(a,0)),A.at(s.h(a,1)))},
nw(a){var s,r,q,p,o,n
for(s=a.$ti,r=new A.aN(a,a.gm(0),s.j("aN<u.E>")),s=s.j("u.E"),q=B.cM;r.l();){p=r.d
if(p==null)p=s.a(p)
o=p.a
n=Math.min(q.a,o)
p=p.b
q=new A.e3(n,Math.min(q.b,p),Math.max(q.c,o),Math.max(q.d,p))}return q},
lj(a,b,c){var s,r=c.U(0,b),q=r.ck(r)
if(q===0)return new A.m(b,0)
s=B.b.a_(a.U(0,b).ck(r)/q,0,1)
return new A.m(b.aj(0,r.ar(0,s)),s)},
aV(a){var s,r,q,p,o,n
for(s=J.af(a),r=0,q=1;q<s.gm(a);++q){p=s.h(a,q-1)
o=s.h(a,q)
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)}return r},
q9(a,b){var s,r,q,p,o,n,m,l,k,j,i,h
for(s=b.length,r=s-1,q=a.b,p=a.a,o=!1,n=0;n<s;m=n+1,r=n,n=m){l=b[n]
if(!(r>=0&&r<s))return A.b(b,r)
k=b[r]
j=l.b
i=k.b
if(j>q!==i>q){h=l.a
h=p<(k.a-h)*(q-j)/(i-j)+h
j=h}else j=!1
if(j)o=!o}return o},
ku(a,b){var s,r,q,p,o,n,m,l,k=J.af(a)
if(k.gF(a))return B.au
for(s=b,r=1;r<k.gm(a);++r){q=r-1
p=k.h(a,q)
o=k.h(a,r)
n=p.a-o.a
o=p.b-o.b
m=Math.sqrt(n*n+o*o)
if(s<=m||r===k.gm(a)-1){l=m===0?0:B.b.a_(s/m,0,1)
return A.m2(k.h(a,q),k.h(a,r),l)}s-=m}return k.gM(a)},
n4(a,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.r(a0),c=d.j("B<1>"),b=A.q(new A.B(a0,d.j("v(1)").a(new A.kQ(a)),c),c.j("j.E"))
B.a.a4(b)
if(b.length===0){d=A.q(a,t.g)
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
f=(b[p]-q)/j}e=A.m2(n,m,f)
B.a.k(r,e)
B.a.k(s,r)
r=A.d([e],c);++p}B.a.k(r,m)}B.a.k(s,r)
d=t.ji
d=A.q(new A.B(s,t.eV.a(new A.kR()),d),d.j("j.E"))
return d},
pK(c1,c2,c3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=J.af(c1)
if(c0.gm(c1)<2){c0=A.q(c1,t.g)
return c0}if(c0.gm(c1)===2)return A.d([c0.h(c1,0),c0.h(c1,1)],t.C)
s=c0.gm(c1)
r=new A.k9(c2,c1,s)
q=A.d([],t.C)
p=c2?s:s-1
for(o=0;o<p;o=l){n=r.$1(o-1)
m=r.$1(o)
l=o+1
k=r.$1(l)
j=r.$1(o+2)
i=new A.ka()
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
B.a.k(q,new A.A(((d*a8+b*a9)*b0+b4*b9)*b1+(b4*b6+(a0*b7+a3*b8)*b2)*b3,((c*a8+a*a9)*b0+b5*b9)*b1+(b5*b6+(a1*b7+a4*b8)*b2)*b3))}}B.a.k(q,c2?c0.gu(c1):c0.gM(c1))
return q},
A:function A(a,b){this.a=a
this.b=b},
e3:function e3(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kQ:function kQ(a){this.a=a},
kR:function kR(){},
k9:function k9(a,b,c){this.a=a
this.b=b
this.c=c},
ka:function ka(){},
lI(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4){return new A.hb(b1,h,b3,a0,p,n,a1,a,c,l,a7,a3,a4,k,b4,b0,m,r,j,i,a8,d,a6,o,e,q,g,f,b,b2,a5,a2,s,a9)},
nI(b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5=null
if(b6==null)return A.lI(!0,!0,0.05,"R$",1,1,0.3,B.an,0,1,2000,0.1,1,2,3,2,100,3,0,1.5,5,6,0.75,0.65,!0,B.a6,10,5,B.aO,!0,B.cL,0,20,500)
s=new A.hc(b6)
r=A.ou(t.dZ.a(b6.h(0,"units")))
q=A.w(b6.h(0,"method"))
if(q==null)q="hazenWilliams"
q=A.ad(B.dp,q,t.m1)
p=s.$2("temp",20)
o=s.$2("vZone",1.5)
n=s.$2("vMain",2)
m=s.$2("vLat",2)
l=s.$2("minorPct",5)
k=A.W(b6.h(0,"minor"))
j=s.$2("tol",0.05)
i=s.$2("interest",0.1)
h=A.x(b6.h(0,"term"))
h=h==null?b5:B.b.ai(h)
if(h==null)h=10
g=s.$2("kwh",0.75)
f=s.$2("eff",0.65)
e=s.$2("hours",2000)
d=s.$2("zoneHours",500)
c=A.W(b6.h(0,"trade"))
b=A.x(b6.h(0,"latSizes"))
b=b==null?b5:B.b.ai(b)
if(b==null)b=1
a=A.x(b6.h(0,"subSizes"))
a=a==null?b5:B.b.ai(a)
if(a==null)a=3
a0=s.$2("cScale",1)
a1=s.$2("cOffset",0)
a2=s.$2("densify",5)
a3=A.w(b6.h(0,"currency"))
if(a3==null)a3="R$"
a4=A.w(b6.h(0,"sizing"))
if(a4==null)a4="lp"
a4=A.ad(B.ds,a4,t.fA)
a5=A.x(b6.h(0,"mainSizes"))
a5=a5==null?b5:B.b.ai(a5)
if(a5==null)a5=3
a6=A.x(b6.h(0,"epp"))
a6=a6==null?b5:B.b.ai(a6)
if(a6==null)a6=1
a7=A.x(b6.h(0,"maxNodes"))
a7=a7==null?b5:B.b.ai(a7)
if(a7==null)a7=100
a8=s.$2("flushV",0.3)
a9=s.$2("flushH",1)
b0=A.W(b6.h(0,"surge"))
b1=s.$2("closure",0)
b2=A.W(b6.h(0,"fittings"))
b3=s.$2("stick",6)
s=s.$2("zoneVar",0)
b4=A.w(b6.h(0,"terrain"))
if(b4==null)b4="idw"
return A.lI(k!==!1,b0!==!1,j,a3,a6,a9,a8,q,a1,a0,e,i,b,m,a5,n,a7,a,s,o,l,b3,g,f,b2!==!1,a4,h,a2,A.ad(B.dt,b4,t.oW),c!==!1,r,b1,p,d)},
m8(a,b,c,d,e){return new A.b3(b,c,e,d,a)},
m0(a,b,c,d,e,f,g,h,i){var s
if(i==null){$.l1=$.l1+1
s="p"+B.c.bC(1000*Date.now(),36)+B.c.bC((A.cL(Date.now(),0,B.e,B.e)^$.l1*2654435761)>>>0,36)}else s=i
return new A.iP(s,b==null?new A.bt(Date.now(),0,!1):b,e,f,a,h,c,g,d)},
m1(){var s,r,q,p=A.d([],t.j8)
for(s=0;s<23;++s){r=B.dI[s]
q=B.dM.h(0,r)
p.push(new A.aA(r,q==null?4294967295:q,!0,!1))}return p},
ob(a){var s,r,q,p,o,n,m,l,k,j,i,h,g=null
if(!J.aW(a.h(0,"format"),"opencadirrigation")&&!J.aW(a.h(0,"format"),"irrigationcad"))throw A.l(B.d7)
s=t.dZ
r=s.a(a.h(0,"meta"))
if(r==null)r=A.m0("",g,"",g,g,"New project","","",g)
else{q=A.w(r.h(0,"uid"))
p=A.w(r.h(0,"created"))
p=A.lH(p==null?"":p)
o=A.w(r.h(0,"modified"))
o=A.lH(o==null?"":o)
n=A.w(r.h(0,"name"))
if(n==null)n=""
m=A.w(r.h(0,"client"))
if(m==null)m=""
l=A.w(r.h(0,"site"))
if(l==null)l=""
k=A.w(r.h(0,"designer"))
if(k==null)k=""
j=A.w(r.h(0,"notes"))
if(j==null)j=""
if(r.h(0,"georef")!=null){r=t.P.a(r.h(0,"georef"))
i=B.b.ai(A.at(r.h(0,"zone")))
h=A.W(r.h(0,"north"))
r=new A.i6(i,h!==!1,A.at(r.h(0,"e0")),A.at(r.h(0,"n0")))}else r=g
q=A.m0(m,p,k,r,o,n,j,l,q)
r=q}s=A.nI(s.a(a.h(0,"params")))
q=a.h(0,"catalog")!=null?A.nz(t.P.a(a.h(0,"catalog"))):A.nx()
p=t.O
o=p.a(a.h(0,"layers"))
if(o==null)o=[]
o=J.aE(o,new A.iQ(),t.df)
o=A.q(o,o.$ti.j("u.E"))
o=new A.iR().$1(o)
n=p.a(a.h(0,"entities"))
if(n==null)n=[]
n=J.aE(n,new A.iS(),t.h)
n=A.q(n,n.$ti.j("u.E"))
p=p.a(a.h(0,"systemFlows"))
if(p==null)p=[]
p=J.aE(p,new A.iT(),t.k)
p=A.q(p,p.$ti.j("u.E"))
m=A.x(a.h(0,"nextId"))
m=m==null?g:B.b.ai(m)
if(m==null)m=1
if(o==null)o=A.m1()
s=new A.iO(r,s,q,o,n,p,m)
r=A.w(a.h(0,"currentLayer"))
s.w=r==null?"DRAWING":r
return s},
aA:function aA(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cn:function cn(a,b){this.a=a
this.b=b},
hb:function hb(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4){var _=this
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
hc:function hc(a){this.a=a},
b3:function b3(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
iP:function iP(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
iO:function iO(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w="DRAWING"},
iU:function iU(){},
iV:function iV(){},
iW:function iW(){},
iQ:function iQ(){},
iR:function iR(){},
iS:function iS(){},
iT:function iT(){},
qe(c2,c3,c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=null,c1=A.nN(c2)
if(c1==null||J.au(c1)<2)return A.d([c2],t.u)
s=A.r(c3)
r=s.j("B<1>")
r=A.dm(new A.B(c3,s.j("v(1)").a(new A.kP(A.aV(c1))),r),r.j("j.E"))
q=A.q(r,A.i(r).c)
B.a.a4(q)
if(q.length===0)return A.d([c2],t.u)
p=A.n4(c1,q)
if(p.length<2)return A.d([c2],t.u)
s=t.u
o=A.d([],s)
for(r=c2 instanceof A.cE,n=c2 instanceof A.cQ,m=c2 instanceof A.aB,l=c2 instanceof A.ak,k=c2 instanceof A.aH,j=c2 instanceof A.c7,i=c2 instanceof A.cN,h=c2 instanceof A.ci,g=c2.c,f=g+" (",e=g.length===0,d=c2.a,c=0,b=0;b<p.length;++b){a=b===0
a0=a?d:c4.$0()
if(e)a1=""
else a1=a?g:f+(b+1)+")"
if(!(b<p.length))return A.b(p,b)
a2=p[b]
a3=A.aV(a2)
A:{a4=h?c2:c0
if(h){a=a4.b
a5=J.a1(a2)
B.a.k(o,new A.ci(a5.gu(a2),a5.gM(a2),a0,a,a1))
break A}a6=i?c2:c0
if(i){B.a.k(o,new A.cN(a2,!1,a0,a6.b,a1))
break A}a7=j?c2:c0
if(j){a=a7.b
B.a.k(o,new A.c7(a2,a7.e,!1,a0,a,a1))
break A}a6=k?c2:c0
if(k){a=a6.b
a5=a6.e
a8=a6.f
a9=a6.r
b0=a6.w
B.a.k(o,new A.aH(a2,a5,a8,a9,b0,a0,a,a1))
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
B.a.k(o,new A.ak(a2,a8,a9,b0,b6,b7,a,b8,b1.Q,b1.as,b1.at,a0,a5,a1))
break A}b9=m?c2:c0
if(m){a=b9.b
a5=b9.e
a8=b9.f
a9=b9.r
b0=b9.w
b6=b9.x
B.a.k(o,new A.aB(a2,a5,a8,a9,b0,b6,b===p.length-1?b9.y:0,a0,a,a1))
break A}b1=n?c2:c0
if(n){B.a.k(o,new A.cQ(a2,!1,a0,b1.b,a1))
break A}a4=r?c2:c0
if(r){a=a4.b
B.a.k(o,new A.cE(a2,a4.e,a4.f,a0,a,a1))
break A}return A.d([c2],s)}c+=a3}return o},
kP:function kP(a){this.a=a},
cp:function cp(a,b){this.a=a
this.b=b},
bF:function bF(a,b){this.a=a
this.b=b},
eS:function eS(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=10
_.f=!1
_.r=null},
jc:function jc(){},
jd:function jd(){},
je:function je(){},
l5(a,b,c,d){var s=new A.jf(a,b,c,d,A.n(t.S,t.J))
s.cX()
return s},
op(c9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3=t.S,c4=A.n(t.N,c3),c5=t.n,c6=A.d([],c5),c7=A.d([],c5),c8=A.d([],c5)
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
if(l<3)return A.l5(c6,c7,c8,A.d([],t.ae))
k=B.a.L(c6,B.H)
j=B.a.L(c6,B.q)
i=B.a.L(c7,B.H)
h=B.a.L(c7,B.q)
g=Math.max(Math.max(j-k,h-i),0.000001)
if(g<1e-9)return A.l5(c6,c7,c8,A.d([],t.ae))
f=(k+j)/2
e=(i+h)/2
c5=t.i
r=A.q(c6,c5)
d=20*g
r.push(f-d)
r.push(f)
r.push(f+d)
c5=A.q(c7,c5)
c5.push(e-g*20)
c5.push(e+d)
c5.push(e-d)
d=t.ae
c=A.d([],d)
b=new A.ji(r,c5)
a=new A.bZ(l,l+1,l+2)
b.$1(a)
B.a.k(c,a)
a0=J.el(l,c3)
for(m=0;m<l;++m)a0[m]=m
B.a.am(a0,new A.jj(new A.jh(r,k,g,B.c.a_(B.b.ao(Math.sqrt(l)/2),1,512),c5,i)))
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
b1=A.n(c3,c3)
b2=A.d([],a3)
b3=new A.jk(b1,b2)
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
a8=new A.bZ(b7,b8,m)
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
B.a.k(b9,c2>0?a8:new A.bZ(d,b5,a2))}return A.l5(c6,c7,c8,b9)},
bZ:function bZ(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=0},
jf:function jf(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=1
_.w=_.r=0},
ji:function ji(a,b){this.a=a
this.b=b},
jh:function jh(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
jj:function jj(a){this.a=a},
jk:function jk(a,b){this.a=a
this.b=b},
jg:function jg(){},
fv(a){var s=B.b.a_(a,0,60)
return 0.000001792/(1+0.0337*s+0.000221*s*s)},
ou(a){var s,r,q,p
if(a==null)return B.cL
s=A.w(a.h(0,"length"))
if(s==null)s="m"
s=A.ad(B.dD,s,t.hu)
r=A.w(a.h(0,"flow"))
if(r==null)r="lph"
r=A.ad(B.dF,r,t.mf)
q=A.w(a.h(0,"pressure"))
if(q==null)q="mH2O"
q=A.ad(B.dE,q,t.c4)
p=A.w(a.h(0,"diameter"))
if(p==null)p="mm"
return new A.eV(s,r,q,A.ad(B.dm,p,t.ks))},
bn:function bn(a,b){this.a=a
this.b=b},
bk:function bk(a,b){this.a=a
this.b=b},
bB:function bB(a,b){this.a=a
this.b=b},
c9:function c9(a,b){this.a=a
this.b=b},
eV:function eV(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
q4(){var s,r=v.G,q=new A.ks(r)
if(typeof q=="function")A.bs(A.d4("Attempting to rewrap a JS function.",null))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.p3,q)
s[$.lq()]=q
r.addEventListener("message",s)},
ks:function ks(a){this.a=a},
kr:function kr(a){this.a=a},
n5(a){return v.mangledGlobalNames[a]},
qh(a){throw A.a9(A.lP(a),new Error())},
qi(){throw A.a9(A.lP(""),new Error())},
p3(a,b,c){t.Z.a(a)
if(A.a0(c)>=1)return a.$1(b)
return a.$0()},
mX(a,b,c){A.mM(c,t.H,"T","min")
return Math.min(c.a(a),c.a(b))},
mW(a,b,c){A.mM(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.kX.prototype={}
J.ej.prototype={
Y(a,b){return a===b},
gK(a){return A.eL(a)},
q(a){return"Instance of '"+A.eM(a)+"'"},
gO(a){return A.bK(A.ld(this))}}
J.em.prototype={
q(a){return String(a)},
gK(a){return a?519018:218159},
gO(a){return A.bK(t.y)},
$iO:1,
$iv:1}
J.dh.prototype={
Y(a,b){return null==b},
q(a){return"null"},
gK(a){return 0},
$iO:1}
J.dj.prototype={$ia_:1}
J.bV.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.eJ.prototype={}
J.cq.prototype={}
J.bU.prototype={
q(a){var s=a[$.n7()]
if(s==null)s=a[$.lq()]
if(s==null)return this.cG(a)
return"JavaScript function for "+J.d2(s)},
$ibw:1}
J.di.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.dk.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.o.prototype={
aY(a,b){return new A.ac(a,A.r(a).j("@<1>").A(b).j("ac<1,2>"))},
k(a,b){A.r(a).c.a(b)
a.$flags&1&&A.aa(a,29)
a.push(b)},
dT(a,b){a.$flags&1&&A.aa(a,"removeAt",1)
if(b<0||b>=a.length)throw A.l(A.l2(b,null))
return a.splice(b,1)[0]},
dH(a,b,c){A.r(a).c.a(c)
a.$flags&1&&A.aa(a,"insert",2)
if(b<0||b>a.length)throw A.l(A.l2(b,null))
a.splice(b,0,c)},
T(a,b){var s
a.$flags&1&&A.aa(a,"remove",1)
for(s=0;s<a.length;++s)if(J.aW(a[s],b)){a.splice(s,1)
return!0}return!1},
B(a,b){var s
A.r(a).j("j<1>").a(b)
a.$flags&1&&A.aa(a,"addAll",2)
if(Array.isArray(b)){this.cJ(a,b)
return}for(s=J.ab(b);s.l();)a.push(s.gp())},
cJ(a,b){var s,r
t.dG.a(b)
s=b.length
if(s===0)return
if(a===b)throw A.l(A.am(a))
for(r=0;r<s;++r)a.push(b[r])},
V(a){a.$flags&1&&A.aa(a,"clear","clear")
a.length=0},
aH(a,b,c){var s=A.r(a)
return new A.t(a,s.A(c).j("1(2)").a(b),s.j("@<1>").A(c).j("t<1,2>"))},
dM(a,b){var s,r=A.bc(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.i(r,s,A.z(a[s]))
return r.join(b)},
a3(a,b){return A.bY(a,b,null,A.r(a).c)},
L(a,b){var s,r,q
A.r(a).j("1(1,1)").a(b)
s=a.length
if(s===0)throw A.l(A.av())
if(0>=s)return A.b(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.l(A.am(a))}return r},
W(a,b,c,d){var s,r,q
d.a(b)
A.r(a).A(d).j("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.l(A.am(a))}return r},
ag(a,b,c){var s,r,q,p=A.r(a)
p.j("v(1)").a(b)
p.j("1()?").a(c)
s=a.length
for(r=0;r<s;++r){q=a[r]
if(b.$1(q))return q
if(a.length!==s)throw A.l(A.am(a))}p=c.$0()
return p},
I(a,b){if(!(b>=0&&b<a.length))return A.b(a,b)
return a[b]},
cF(a,b,c){var s=a.length
if(b>s)throw A.l(A.aQ(b,0,s,"start",null))
if(c<b||c>s)throw A.l(A.aQ(c,b,s,"end",null))
if(b===c)return A.d([],A.r(a))
return A.d(a.slice(b,c),A.r(a))},
gu(a){if(a.length>0)return a[0]
throw A.l(A.av())},
gM(a){var s=a.length
if(s>0)return a[s-1]
throw A.l(A.av())},
Z(a,b){var s,r
A.r(a).j("v(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.l(A.am(a))}return!1},
gcs(a){return new A.bp(a,A.r(a).j("bp<1>"))},
am(a,b){var s,r,q,p,o,n=A.r(a)
n.j("f(1,1)?").a(b)
a.$flags&2&&A.aa(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.pe()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cB()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.fr(b,2))
if(p>0)this.d5(a,p)},
a4(a){return this.am(a,null)},
d5(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
cn(a,b){var s,r=a.length
if(0>=r)return-1
for(s=0;s<r;++s){if(!(s<a.length))return A.b(a,s)
if(J.aW(a[s],b))return s}return-1},
v(a,b){var s
for(s=0;s<a.length;++s)if(J.aW(a[s],b))return!0
return!1},
gF(a){return a.length===0},
ga8(a){return a.length!==0},
q(a){return A.kW(a,"[","]")},
gt(a){return new J.c5(a,a.length,A.r(a).j("c5<1>"))},
gK(a){return A.eL(a)},
gm(a){return a.length},
sm(a,b){a.$flags&1&&A.aa(a,"set length","change the length of")
if(b<0)throw A.l(A.aQ(b,0,null,"newLength",null))
if(b>a.length)A.r(a).c.a(null)
a.length=b},
h(a,b){A.a0(b)
if(!(b>=0&&b<a.length))throw A.l(A.fs(a,b))
return a[b]},
i(a,b,c){A.r(a).c.a(c)
a.$flags&2&&A.aa(a)
if(!(b>=0&&b<a.length))throw A.l(A.fs(a,b))
a[b]=c},
$iy:1,
$ij:1,
$ip:1}
J.ek.prototype={
e0(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.eM(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.ib.prototype={}
J.c5.prototype={
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
J.cf.prototype={
S(a,b){var s
A.at(b)
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
return s+0}throw A.l(A.bq(""+a+".toInt()"))},
ao(a){var s,r
if(a>=0){if(a<=2147483647){s=a|0
return a===s?s:s+1}}else if(a>=-2147483648)return a|0
r=Math.ceil(a)
if(isFinite(r))return r
throw A.l(A.bq(""+a+".ceil()"))},
J(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.l(A.bq(""+a+".floor()"))},
a1(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.l(A.bq(""+a+".round()"))},
by(a){if(a<0)return-Math.round(-a)
else return Math.round(a)},
a_(a,b,c){if(B.c.S(b,c)>0)throw A.l(A.mK(b))
if(this.S(a,b)<0)return b
if(this.S(a,c)>0)return c
return a},
ae(a,b){var s
if(b>20)throw A.l(A.aQ(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gb1(a))return"-"+s
return s},
bC(a,b){var s,r,q,p,o
if(b<2||b>36)throw A.l(A.aQ(b,2,36,"radix",null))
s=a.toString(b)
r=s.length
q=r-1
if(!(q>=0))return A.b(s,q)
if(s.charCodeAt(q)!==41)return s
p=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(s)
if(p==null)A.bs(A.bq("Unexpected toString result: "+s))
r=p.length
if(1>=r)return A.b(p,1)
s=p[1]
if(3>=r)return A.b(p,3)
o=+p[3]
r=p[2]
if(r!=null){s+=r
o-=r.length}return s+B.k.ar("0",o)},
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
bn(a,b){return(a|0)===a?a/b|0:this.dd(a,b)},
dd(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.l(A.bq("Result of truncating division is "+A.z(s)+": "+A.z(a)+" ~/ "+b))},
aU(a,b){var s
if(a>0)s=this.d8(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
d8(a,b){return b>31?0:a>>>b},
gO(a){return A.bK(t.H)},
$iaL:1,
$ie:1,
$iay:1}
J.dg.prototype={
gO(a){return A.bK(t.S)},
$iO:1,
$if:1}
J.en.prototype={
gO(a){return A.bK(t.i)},
$iO:1}
J.cg.prototype={
au(a,b,c){return a.substring(b,A.m4(b,c,a.length))},
e_(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(0>=o)return A.b(p,0)
if(p.charCodeAt(0)===133){s=J.nY(p,1)
if(s===o)return""}else s=0
r=o-1
if(!(r>=0))return A.b(p,r)
q=p.charCodeAt(r)===133?J.nZ(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
ar(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.l(B.cY)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
dR(a,b,c){var s=b-a.length
if(s<=0)return a
return this.ar(c,s)+a},
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
gO(a){return A.bK(t.N)},
gm(a){return a.length},
h(a,b){if(b>=a.length)throw A.l(A.fs(a,b))
return a[b]},
$iO:1,
$iaL:1,
$iiH:1,
$ic:1}
A.c_.prototype={
gt(a){return new A.d6(J.ab(this.ga5()),A.i(this).j("d6<1,2>"))},
gm(a){return J.au(this.ga5())},
gF(a){return J.lv(this.ga5())},
ga8(a){return J.np(this.ga5())},
a3(a,b){var s=A.i(this)
return A.lB(J.lw(this.ga5(),b),s.c,s.y[1])},
I(a,b){return A.i(this).y[1].a(J.fy(this.ga5(),b))},
gu(a){return A.i(this).y[1].a(J.bN(this.ga5()))},
gM(a){return A.i(this).y[1].a(J.kT(this.ga5()))},
q(a){return J.d2(this.ga5())}}
A.d6.prototype={
l(){return this.a.l()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iR:1}
A.c6.prototype={
ga5(){return this.a}}
A.dJ.prototype={$iy:1}
A.dI.prototype={
h(a,b){return this.$ti.y[1].a(J.fx(this.a,A.a0(b)))},
i(a,b,c){var s=this.$ti
J.kS(this.a,b,s.c.a(s.y[1].a(c)))},
sm(a,b){J.ns(this.a,b)},
k(a,b){var s=this.$ti
J.bM(this.a,s.c.a(s.y[1].a(b)))},
$iy:1,
$ip:1}
A.ac.prototype={
aY(a,b){return new A.ac(this.a,this.$ti.j("@<1>").A(b).j("ac<1,2>"))},
ga5(){return this.a}}
A.et.prototype={
q(a){return"LateInitializationError: "+this.a}}
A.j0.prototype={}
A.y.prototype={}
A.u.prototype={
gt(a){var s=this
return new A.aN(s,s.gm(s),A.i(s).j("aN<u.E>"))},
gF(a){return this.gm(this)===0},
gu(a){if(this.gm(this)===0)throw A.l(A.av())
return this.I(0,0)},
gM(a){var s=this
if(s.gm(s)===0)throw A.l(A.av())
return s.I(0,s.gm(s)-1)},
aH(a,b,c){var s=A.i(this)
return new A.t(this,s.A(c).j("1(u.E)").a(b),s.j("@<u.E>").A(c).j("t<1,2>"))},
L(a,b){var s,r,q,p=this
A.i(p).j("u.E(u.E,u.E)").a(b)
s=p.gm(p)
if(s===0)throw A.l(A.av())
r=p.I(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.I(0,q))
if(s!==p.gm(p))throw A.l(A.am(p))}return r},
a3(a,b){return A.bY(this,b,null,A.i(this).j("u.E"))},
aq(a){var s,r=this,q=A.ev(A.i(r).j("u.E"))
for(s=0;s<r.gm(r);++s)q.k(0,r.I(0,s))
return q}}
A.dE.prototype={
gcT(){var s=J.au(this.a),r=this.c
if(r==null||r>s)return s
return r},
gda(){var s=J.au(this.a),r=this.b
if(r>s)return s
return r},
gm(a){var s,r=J.au(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
I(a,b){var s=this,r=s.gda()+b
if(b<0||r>=s.gcT())throw A.l(A.ia(b,s.gm(0),s,"index"))
return J.fy(s.a,r)},
a3(a,b){var s,r,q=this
A.cP(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.d9(q.$ti.j("d9<1>"))
return A.bY(q.a,s,r,q.$ti.c)},
dY(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.af(n),l=m.gm(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=p.$ti.c
return b?J.lM(0,n):J.lL(0,n)}r=A.bc(s,m.I(n,o),b,p.$ti.c)
for(q=1;q<s;++q){B.a.i(r,q,m.I(n,o+q))
if(m.gm(n)<l)throw A.l(A.am(p))}return r},
cv(a){return this.dY(0,!0)}}
A.aN.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=J.af(q),o=p.gm(q)
if(r.b!==o)throw A.l(A.am(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.I(q,s);++r.c
return!0},
$iR:1}
A.bz.prototype={
gt(a){return new A.dr(J.ab(this.a),this.b,A.i(this).j("dr<1,2>"))},
gm(a){return J.au(this.a)},
gF(a){return J.lv(this.a)},
gu(a){return this.b.$1(J.bN(this.a))},
gM(a){return this.b.$1(J.kT(this.a))},
I(a,b){return this.b.$1(J.fy(this.a,b))}}
A.cb.prototype={$iy:1}
A.dr.prototype={
l(){var s=this,r=s.b
if(r.l()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iR:1}
A.t.prototype={
gm(a){return J.au(this.a)},
I(a,b){return this.b.$1(J.fy(this.a,b))}}
A.B.prototype={
gt(a){return new A.dH(J.ab(this.a),this.b,this.$ti.j("dH<1>"))}}
A.dH.prototype={
l(){var s,r
for(s=this.a,r=this.b;s.l();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iR:1}
A.dz.prototype={
a3(a,b){this.b.aj(0,A.k1(b))
return void 1},
gt(a){var s=this.a
return new A.dA(s.gt(s),this.b,A.i(this).j("dA<1>"))}}
A.i0.prototype={
gm(a){var s=this.a,r=B.c.U(s.gm(s),this.b)
if(r>=0)return r
return 0},
a3(a,b){this.b.aj(0,A.k1(b))
return void 1},
$iy:1}
A.dA.prototype={
l(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.l()
this.b=0
return s.l()},
gp(){return this.a.gp()},
$iR:1}
A.d9.prototype={
gt(a){return B.cR},
gF(a){return!0},
gm(a){return 0},
gu(a){throw A.l(A.av())},
gM(a){throw A.l(A.av())},
I(a,b){throw A.l(A.aQ(b,0,0,"index",null))},
a3(a,b){A.cP(b,"count")
return this}}
A.da.prototype={
l(){return!1},
gp(){throw A.l(A.av())},
$iR:1}
A.cr.prototype={
gt(a){return new A.bI(J.ab(this.a),this.$ti.j("bI<1>"))}}
A.bI.prototype={
l(){var s,r
for(s=this.a,r=this.$ti.c;s.l();)if(r.b(s.gp()))return!0
return!1},
gp(){return this.$ti.c.a(this.a.gp())},
$iR:1}
A.U.prototype={
sm(a,b){throw A.l(A.bq("Cannot change the length of a fixed-length list"))},
k(a,b){A.ax(a).j("U.E").a(b)
throw A.l(A.bq("Cannot add to a fixed-length list"))}}
A.bp.prototype={
gm(a){return J.au(this.a)},
I(a,b){var s=this.a,r=J.af(s)
return r.I(s,r.gm(s)-1-b)}}
A.dW.prototype={}
A.m.prototype={$r:"+(1,2)",$s:1}
A.a.prototype={$r:"+(1,2,3)",$s:2}
A.cX.prototype={$r:"+(1,2,3,4)",$s:3}
A.aT.prototype={$r:"+run,stage,zoneId,zoneIndex(1,2,3,4)",$s:4}
A.d7.prototype={
gF(a){return this.gm(this)===0},
q(a){return A.kZ(this)},
i(a,b,c){var s=A.i(this)
s.c.a(b)
s.y[1].a(c)
A.lE()},
T(a,b){A.lE()},
gaG(){return new A.c0(this.dz(),A.i(this).j("c0<ai<1,2>>"))},
dz(){var s=this
return function(){var r=0,q=1,p=[],o,n,m,l,k
return function $async$gaG(a,b,c){if(b===1){p.push(c)
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
A.b8.prototype={
gm(a){return this.b.length},
gbV(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
E(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.E(b))return null
return this.b[this.a[b]]},
X(a,b){var s,r,q,p
this.$ti.j("~(1,2)").a(b)
s=this.gbV()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])},
ga9(){return new A.dK(this.gbV(),this.$ti.j("dK<1>"))}}
A.dK.prototype={
gm(a){return this.a.length},
gF(a){return 0===this.a.length},
ga8(a){return 0!==this.a.length},
gt(a){var s=this.a
return new A.ct(s,s.length,this.$ti.j("ct<1>"))}}
A.ct.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c
if(r>=s.b){s.d=null
return!1}s.d=s.a[r]
s.c=r+1
return!0},
$iR:1}
A.d8.prototype={
k(a,b){A.i(this).c.a(b)
A.lF()},
T(a,b){A.lF()}}
A.bP.prototype={
gm(a){return this.b},
gF(a){return this.b===0},
ga8(a){return this.b!==0},
gt(a){var s,r=this,q=r.$keys
if(q==null){q=Object.keys(r.a)
r.$keys=q}s=q
return new A.ct(s,s.length,r.$ti.j("ct<1>"))},
v(a,b){if(typeof b!="string")return!1
if("__proto__"===b)return!1
return this.a.hasOwnProperty(b)}}
A.ei.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.ce&&this.a.Y(0,b.a)&&A.lm(this)===A.lm(b)},
gK(a){return A.cL(this.a,A.lm(this),B.e,B.e)},
q(a){var s=B.a.dM([A.bK(this.$ti.c)],", ")
return this.a.q(0)+" with "+("<"+s+">")}}
A.ce.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.q1(A.kb(this.a),this.$ti)}}
A.dy.prototype={}
A.jl.prototype={
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
A.dw.prototype={
q(a){return"Null check operator used on a null value"}}
A.ep.prototype={
q(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.eW.prototype={
q(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.iC.prototype={
q(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.db.prototype={}
A.dQ.prototype={
q(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$ibX:1}
A.az.prototype={
q(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.n6(r==null?"unknown":r)+"'"},
$ibw:1,
ge4(){return this},
$C:"$1",
$R:1,
$D:null}
A.e5.prototype={$C:"$0",$R:0}
A.e6.prototype={$C:"$2",$R:2}
A.eR.prototype={}
A.eP.prototype={
q(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.n6(s)+"'"}}
A.cD.prototype={
Y(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.cD))return!1
return this.$_target===b.$_target&&this.a===b.a},
gK(a){return(A.mZ(this.a)^A.eL(this.$_target))>>>0},
q(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.eM(this.a)+"'")}}
A.eO.prototype={
q(a){return"RuntimeError: "+this.a}}
A.bx.prototype={
gm(a){return this.a},
gF(a){return this.a===0},
ga9(){return new A.a4(this,A.i(this).j("a4<1>"))},
gaG(){return new A.L(this,A.i(this).j("L<1,2>"))},
E(a){var s,r
if(typeof a=="string"){s=this.b
if(s==null)return!1
return s[a]!=null}else if(typeof a=="number"&&(a&0x3fffffff)===a){r=this.c
if(r==null)return!1
return r[a]!=null}else return this.dI(a)},
dI(a){var s=this.d
if(s==null)return!1
return this.b0(this.bS(s,a),a)>=0},
B(a,b){A.i(this).j("h<1,2>").a(b).X(0,new A.ic(this))},
h(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.dJ(b)},
dJ(a){var s,r,q=this.d
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
q.bF(r==null?q.c=q.bk():r,b,c)}else q.dL(b,c)},
dL(a,b){var s,r,q,p,o=this,n=A.i(o)
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
else return s.dK(b)},
dK(a){var s,r,q,p,o=this,n=o.d
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
if(r!==q.r)throw A.l(A.am(q))
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
b8(a,b){var s=this,r=A.i(s),q=new A.ig(r.c.a(a),r.y[1].a(b))
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
bu(a){return J.aK(a)&1073741823},
bS(a,b){return a[this.bu(b)]},
b0(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aW(a[r].a,b))return r
return-1},
q(a){return A.kZ(this)},
bk(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ilQ:1}
A.ic.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.i(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).j("~(1,2)")}}
A.ig.prototype={}
A.a4.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.an(s,s.r,s.e,this.$ti.j("an<1>"))},
v(a,b){return this.a.E(b)}}
A.an.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.am(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iR:1}
A.ao.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.N(s,s.r,s.e,this.$ti.j("N<1>"))}}
A.N.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.am(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iR:1}
A.L.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.ag(s,s.r,s.e,this.$ti.j("ag<1,2>"))}}
A.ag.prototype={
gp(){var s=this.d
s.toString
return s},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.am(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.ai(s.a,s.b,r.$ti.j("ai<1,2>"))
r.c=s.c
return!0}},
$iR:1}
A.kk.prototype={
$1(a){return this.a(a)},
$S:24}
A.kl.prototype={
$2(a,b){return this.a(a,b)},
$S:32}
A.km.prototype={
$1(a){return this.a(A.C(a))},
$S:37}
A.b5.prototype={
q(a){return this.cb(!1)},
cb(a){var s,r,q,p,o,n=this.cU(),m=this.aL(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.b(m,q)
o=m[q]
l=a?l+A.m_(o):l+A.z(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
cU(){var s,r=this.$s
while($.jT.length<=r)B.a.k($.jT,null)
s=$.jT[r]
if(s==null){s=this.cP()
B.a.i($.jT,r,s)}return s},
cP(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.el(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.a.i(j,q,r[s])}}j=A.ew(j,!1,k)
j.$flags=3
return j}}
A.cV.prototype={
aL(){return[this.a,this.b]},
Y(a,b){if(b==null)return!1
return b instanceof A.cV&&this.$s===b.$s&&J.aW(this.a,b.a)&&J.aW(this.b,b.b)},
gK(a){return A.cL(this.$s,this.a,this.b,B.e)}}
A.cW.prototype={
aL(){return[this.a,this.b,this.c]},
Y(a,b){var s=this
if(b==null)return!1
return b instanceof A.cW&&s.$s===b.$s&&J.aW(s.a,b.a)&&J.aW(s.b,b.b)&&J.aW(s.c,b.c)},
gK(a){var s=this
return A.cL(s.$s,s.a,s.b,s.c)}}
A.cv.prototype={
aL(){return this.a},
Y(a,b){if(b==null)return!1
return b instanceof A.cv&&this.$s===b.$s&&A.oN(this.a,b.a)},
gK(a){return A.cL(this.$s,A.o3(this.a),B.e,B.e)}}
A.eo.prototype={
q(a){return"RegExp/"+this.a+"/"+this.b.flags},
dC(a){var s=this.b.exec(a)
if(s==null)return null
return new A.jS(s)},
$iiH:1,
$ioe:1}
A.jS.prototype={
h(a,b){var s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.cI.prototype={
gO(a){return B.yS},
$iO:1}
A.du.prototype={}
A.ey.prototype={
gO(a){return B.yT},
$iO:1}
A.cJ.prototype={
gm(a){return a.length},
$iaM:1}
A.ds.prototype={
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
i(a,b,c){A.T(c)
a.$flags&2&&A.aa(a)
A.bJ(b,a,a.length)
a[b]=c},
$iy:1,
$ij:1,
$ip:1}
A.dt.prototype={
i(a,b,c){A.a0(c)
a.$flags&2&&A.aa(a)
A.bJ(b,a,a.length)
a[b]=c},
$iy:1,
$ij:1,
$ip:1}
A.ez.prototype={
gO(a){return B.yU},
$iO:1}
A.eA.prototype={
gO(a){return B.yV},
$iO:1,
$ibv:1}
A.eB.prototype={
gO(a){return B.yW},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1}
A.eC.prototype={
gO(a){return B.yX},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1}
A.eD.prototype={
gO(a){return B.yY},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1}
A.eE.prototype={
gO(a){return B.z_},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1}
A.eF.prototype={
gO(a){return B.z0},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1}
A.dv.prototype={
gO(a){return B.z1},
gm(a){return a.length},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1}
A.eG.prototype={
gO(a){return B.z2},
gm(a){return a.length},
h(a,b){A.a0(b)
A.bJ(b,a,a.length)
return a[b]},
$iO:1,
$il6:1}
A.dL.prototype={}
A.dM.prototype={}
A.dN.prototype={}
A.dO.prototype={}
A.bg.prototype={
j(a){return A.dU(v.typeUniverse,this,a)},
A(a){return A.mn(v.typeUniverse,this,a)}}
A.f3.prototype={}
A.jX.prototype={
q(a){return A.aD(this.a,null)}}
A.f2.prototype={
q(a){return this.a}}
A.cY.prototype={$ibG:1}
A.jy.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:15}
A.jx.prototype={
$1(a){var s,r
this.a.a=t.M.a(a)
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:30}
A.jz.prototype={
$0(){this.a.$0()},
$S:2}
A.jA.prototype={
$0(){this.a.$0()},
$S:2}
A.jV.prototype={
cH(a,b){if(self.setTimeout!=null)self.setTimeout(A.fr(new A.jW(this,b),0),a)
else throw A.l(A.bq("`setTimeout()` not found."))}}
A.jW.prototype={
$0(){this.b.$0()},
$S:0}
A.eY.prototype={}
A.k_.prototype={
$1(a){return this.a.$2(0,a)},
$S:58}
A.k0.prototype={
$2(a,b){this.a.$2(1,new A.db(a,t.l.a(b)))},
$S:86}
A.k7.prototype={
$2(a,b){this.a(A.a0(a),b)},
$S:88}
A.cw.prototype={
gp(){var s=this.b
return s==null?this.$ti.c.a(s):s},
d6(a,b){var s,r,q
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
o.d=null}q=o.d6(m,n)
if(1===q)return!0
if(0===q){o.b=null
p=o.e
if(p==null||p.length===0){o.a=A.mh
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
o.a=A.mh
throw n
return!1}if(0>=p.length)return A.b(p,-1)
o.a=p.pop()
m=1
continue}throw A.l(A.l4("sync*"))}return!1},
e6(a){var s,r,q=this
if(a instanceof A.c0){s=a.a()
r=q.e
if(r==null)r=q.e=[]
B.a.k(r,q.a)
q.a=s
return 2}else{q.d=J.ab(a)
return 2}},
$iR:1}
A.c0.prototype={
gt(a){return new A.cw(this.a(),this.$ti.j("cw<1>"))}}
A.b7.prototype={
q(a){return A.z(this.a)},
$iP:1,
gaI(){return this.b}}
A.cs.prototype={
dO(a){if((this.c&15)!==6)return!0
return this.b.b.bz(t.iW.a(this.d),a.a,t.y,t.K)},
dE(a){var s,r=this,q=r.e,p=null,o=t.z,n=t.K,m=a.a,l=r.b.b
if(t.ng.b(q))p=l.dV(q,m,a.b,o,n,t.l)
else p=l.bz(t.mq.a(q),m,o,n)
try{o=r.$ti.j("2/").a(p)
return o}catch(s){if(t.do.b(A.bL(s))){if((r.c&1)!==0)throw A.l(A.d4("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.l(A.d4("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.ae.prototype={
cu(a,b,c){var s,r,q=this.$ti
q.A(c).j("1/(2)").a(a)
s=$.a6
if(s===B.u){if(!t.ng.b(b)&&!t.mq.b(b))throw A.l(A.e0(b,"onError",u.c))}else{c.j("@<0/>").A(q.c).j("1(2)").a(a)
b=A.pv(b,s)}r=new A.ae(s,c.j("ae<0>"))
this.b9(new A.cs(r,3,a,b,q.j("@<1>").A(c).j("cs<1,2>")))
return r},
c9(a,b,c){var s,r=this.$ti
r.A(c).j("1/(2)").a(a)
s=new A.ae($.a6,c.j("ae<0>"))
this.b9(new A.cs(s,19,a,b,r.j("@<1>").A(c).j("cs<1,2>")))
return s},
d7(a){this.a=this.a&1|16
this.c=a},
aK(a){this.a=a.a&30|this.a&1
this.c=a.c},
b9(a){var s,r=this,q=r.a
if(q<=3){a.a=t.F.a(r.c)
r.c=a}else{if((q&4)!==0){s=t._.a(r.c)
if((s.a&24)===0){s.b9(a)
return}r.aK(s)}A.fp(null,null,r.b,t.M.a(new A.jE(r,a)))}},
c2(a){var s,r,q,p,o,n,m=this,l={}
l.a=a
if(a==null)return
s=m.a
if(s<=3){r=t.F.a(m.c)
m.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){n=t._.a(m.c)
if((n.a&24)===0){n.c2(a)
return}m.aK(n)}l.a=m.aT(a)
A.fp(null,null,m.b,t.M.a(new A.jI(l,m)))}},
aS(){var s=t.F.a(this.c)
this.c=null
return this.aT(s)},
aT(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
bP(a){var s,r=this
r.$ti.c.a(a)
s=r.aS()
r.a=8
r.c=a
A.cU(r,s)},
cO(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.aS()
q.aK(a)
A.cU(q,r)},
bc(a){var s=this.aS()
this.d7(a)
A.cU(this,s)},
bK(a){var s=this.$ti
s.j("1/").a(a)
if(s.j("bl<1>").b(a)){this.bO(a)
return}this.cN(a)},
cN(a){var s=this
s.$ti.c.a(a)
s.a^=2
A.fp(null,null,s.b,t.M.a(new A.jG(s,a)))},
bO(a){A.l8(this.$ti.j("bl<1>").a(a),this,!1)
return},
bL(a){this.a^=2
A.fp(null,null,this.b,t.M.a(new A.jF(this,a)))},
$ibl:1}
A.jE.prototype={
$0(){A.cU(this.a,this.b)},
$S:0}
A.jI.prototype={
$0(){A.cU(this.b,this.a.a)},
$S:0}
A.jH.prototype={
$0(){A.l8(this.a.a,this.b,!0)},
$S:0}
A.jG.prototype={
$0(){this.a.bP(this.b)},
$S:0}
A.jF.prototype={
$0(){this.a.bc(this.b)},
$S:0}
A.jL.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.dU(t.mY.a(q.d),t.z)}catch(p){s=A.bL(p)
r=A.cz(p)
if(k.c&&t.t.a(k.b.a.c).a===s){q=k.a
q.c=t.t.a(k.b.a.c)}else{q=s
o=r
if(o==null)o=A.kU(q)
n=k.a
n.c=new A.b7(q,o)
q=n}q.b=!0
return}if(j instanceof A.ae&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=t.t.a(j.c)
q.b=!0}return}if(j instanceof A.ae){m=k.b.a
l=new A.ae(m.b,m.$ti)
j.cu(new A.jM(l,m),new A.jN(l),t.r)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.jM.prototype={
$1(a){this.a.cO(this.b)},
$S:15}
A.jN.prototype={
$2(a,b){A.dX(a)
t.l.a(b)
this.a.bc(new A.b7(a,b))},
$S:148}
A.jK.prototype={
$0(){var s,r,q,p,o,n,m,l
try{q=this.a
p=q.a
o=p.$ti
n=o.c
m=n.a(this.b)
q.c=p.b.b.bz(o.j("2/(1)").a(p.d),m,o.j("2/"),n)}catch(l){s=A.bL(l)
r=A.cz(l)
q=s
p=r
if(p==null)p=A.kU(q)
o=this.a
o.c=new A.b7(q,p)
o.b=!0}},
$S:0}
A.jJ.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=t.t.a(l.a.a.c)
p=l.b
if(p.a.dO(s)&&p.a.e!=null){p.c=p.a.dE(s)
p.b=!1}}catch(o){r=A.bL(o)
q=A.cz(o)
p=t.t.a(l.a.a.c)
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.kU(p)
m=l.b
m.c=new A.b7(p,n)
p=m}p.b=!0}},
$S:0}
A.eZ.prototype={}
A.fj.prototype={}
A.dV.prototype={$imb:1}
A.ff.prototype={
dW(a){var s,r,q
t.M.a(a)
try{if(B.u===$.a6){a.$0()
return}A.mE(null,null,this,a,t.r)}catch(q){s=A.bL(q)
r=A.cz(q)
A.lg(A.dX(s),t.l.a(r))}},
dh(a){return new A.jU(this,t.M.a(a))},
h(a,b){return null},
dU(a,b){b.j("0()").a(a)
if($.a6===B.u)return a.$0()
return A.mE(null,null,this,a,b)},
bz(a,b,c,d){c.j("@<0>").A(d).j("1(2)").a(a)
d.a(b)
if($.a6===B.u)return a.$1(b)
return A.px(null,null,this,a,b,c,d)},
dV(a,b,c,d,e,f){d.j("@<0>").A(e).A(f).j("1(2,3)").a(a)
e.a(b)
f.a(c)
if($.a6===B.u)return a.$2(b,c)
return A.pw(null,null,this,a,b,c,d,e,f)},
cr(a,b,c,d){return b.j("@<0>").A(c).A(d).j("1(2,3)").a(a)}}
A.jU.prototype={
$0(){return this.a.dW(this.b)},
$S:0}
A.k6.prototype={
$0(){A.nQ(this.a,this.b)},
$S:0}
A.br.prototype={
gt(a){var s=this,r=new A.Q(s,s.r,A.i(s).j("Q<1>"))
r.c=s.e
return r},
gm(a){return this.a},
gF(a){return this.a===0},
ga8(a){return this.a!==0},
v(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.R.a(s[b])!=null}else if(typeof b=="number"&&(b&1073741823)===b){r=this.c
if(r==null)return!1
return t.R.a(r[b])!=null}else return this.cQ(b)},
cQ(a){var s=this.d
if(s==null)return!1
return this.bi(s[this.bd(a)],a)>=0},
gu(a){var s=this.e
if(s==null)throw A.l(A.l4("No elements"))
return A.i(this).c.a(s.a)},
gM(a){var s=this.f
if(s==null)throw A.l(A.l4("No elements"))
return A.i(this).c.a(s.a)},
k(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.bI(s==null?q.b=A.l9():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.bI(r==null?q.c=A.l9():r,b)}else return q.cI(b)},
cI(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.l9()
r=p.bd(a)
q=s[r]
if(q==null)s[r]=[p.bl(a)]
else{if(p.bi(q,a)>=0)return!1
q.push(p.bl(a))}return!0},
T(a,b){var s=this
if(typeof b=="string"&&b!=="__proto__")return s.c5(s.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return s.c5(s.c,b)
else return s.d4(b)},
d4(a){var s,r,q,p,o=this,n=o.d
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
c5(a,b){var s
if(a==null)return!1
s=t.R.a(a[b])
if(s==null)return!1
this.cc(s)
delete a[b]
return!0},
bj(){this.r=this.r+1&1073741823},
bl(a){var s,r=this,q=new A.f9(A.i(r).c.a(a))
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
bd(a){return J.aK(a)&1073741823},
bi(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aW(a[r].a,b))return r
return-1},
$ilR:1}
A.f9.prototype={}
A.Q.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.l(A.am(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.j("1?").a(r.a)
s.c=r.b
return!0}},
$iR:1}
A.ii.prototype={
$2(a,b){this.a.i(0,this.b.a(a),this.c.a(b))},
$S:122}
A.G.prototype={
gt(a){return new A.aN(a,this.gm(a),A.ax(a).j("aN<G.E>"))},
I(a,b){return this.h(a,b)},
gF(a){return this.gm(a)===0},
ga8(a){return!this.gF(a)},
gu(a){if(this.gm(a)===0)throw A.l(A.av())
return this.h(a,0)},
gM(a){if(this.gm(a)===0)throw A.l(A.av())
return this.h(a,this.gm(a)-1)},
Z(a,b){var s,r
A.ax(a).j("v(G.E)").a(b)
s=this.gm(a)
for(r=0;r<s;++r){if(b.$1(this.h(a,r)))return!0
if(s!==this.gm(a))throw A.l(A.am(a))}return!1},
ag(a,b,c){var s,r,q,p=A.ax(a)
p.j("v(G.E)").a(b)
p.j("G.E()?").a(c)
s=this.gm(a)
for(r=0;r<s;++r){q=this.h(a,r)
if(b.$1(q))return q
if(s!==this.gm(a))throw A.l(A.am(a))}p=c.$0()
return p},
aH(a,b,c){var s=A.ax(a)
return new A.t(a,s.A(c).j("1(G.E)").a(b),s.j("@<G.E>").A(c).j("t<1,2>"))},
W(a,b,c,d){var s,r,q
d.a(b)
A.ax(a).A(d).j("1(1,G.E)").a(c)
s=this.gm(a)
for(r=b,q=0;q<s;++q){r=c.$2(r,this.h(a,q))
if(s!==this.gm(a))throw A.l(A.am(a))}return r},
a3(a,b){return A.bY(a,b,null,A.ax(a).j("G.E"))},
aq(a){var s,r=A.ev(A.ax(a).j("G.E"))
for(s=0;s<this.gm(a);++s)r.k(0,this.h(a,s))
return r},
k(a,b){var s
A.ax(a).j("G.E").a(b)
s=this.gm(a)
this.sm(a,s+1)
this.i(a,s,b)},
aY(a,b){return new A.ac(a,A.ax(a).j("@<G.E>").A(b).j("ac<1,2>"))},
gcs(a){return new A.bp(a,A.ax(a).j("bp<G.E>"))},
q(a){return A.kW(a,"[","]")}}
A.a2.prototype={
X(a,b){var s,r,q,p=A.i(this)
p.j("~(a2.K,a2.V)").a(b)
for(s=this.ga9(),s=s.gt(s),p=p.j("a2.V");s.l();){r=s.gp()
q=this.h(0,r)
b.$2(r,q==null?p.a(q):q)}},
gaG(){return this.ga9().aH(0,new A.ik(this),A.i(this).j("ai<a2.K,a2.V>"))},
E(a){return this.ga9().v(0,a)},
gm(a){var s=this.ga9()
return s.gm(s)},
gF(a){var s=this.ga9()
return s.gF(s)},
q(a){return A.kZ(this)},
$ih:1}
A.ik.prototype={
$1(a){var s=this.a,r=A.i(s)
r.j("a2.K").a(a)
s=s.h(0,a)
if(s==null)s=r.j("a2.V").a(s)
return new A.ai(a,s,r.j("ai<a2.K,a2.V>"))},
$S(){return A.i(this.a).j("ai<a2.K,a2.V>(a2.K)")}}
A.il.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.z(a)
r.a=(r.a+=s)+": "
s=A.z(b)
r.a+=s},
$S:11}
A.bW.prototype={
gF(a){return this.gm(this)===0},
ga8(a){return this.gm(this)!==0},
B(a,b){var s
for(s=J.ab(A.i(this).j("j<1>").a(b));s.l();)this.k(0,s.gp())},
q(a){return A.kW(this,"{","}")},
dA(a,b){var s
A.i(this).j("v(1)").a(b)
for(s=this.gt(this);s.l();)if(!b.$1(s.gp()))return!1
return!0},
a3(a,b){return A.m6(this,b,A.i(this).c)},
gu(a){var s=this.gt(this)
if(!s.l())throw A.l(A.av())
return s.gp()},
gM(a){var s,r=this.gt(this)
if(!r.l())throw A.l(A.av())
do s=r.gp()
while(r.l())
return s},
I(a,b){var s,r
A.cP(b,"index")
s=this.gt(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.l(A.ia(b,b-r,this,"index"))},
$iy:1,
$ij:1,
$ib2:1}
A.dP.prototype={}
A.f5.prototype={
h(a,b){var s,r=this.b
if(r==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.d2(b):s}},
gm(a){return this.b==null?this.c.a:this.aD().length},
gF(a){return this.gm(0)===0},
ga9(){if(this.b==null){var s=this.c
return new A.a4(s,A.i(s).j("a4<1>"))}return new A.f6(this)},
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
s=o.aD()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.k2(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.l(A.am(o))}},
aD(){var s=t.O.a(this.c)
if(s==null)s=this.c=A.d(Object.keys(this.a),t.s)
return s},
cd(){var s,r,q,p,o,n=this
if(n.b==null)return n.c
s=A.n(t.N,t.z)
r=n.aD()
for(q=0;p=r.length,q<p;++q){o=r[q]
s.i(0,o,n.h(0,o))}if(p===0)B.a.k(r,"")
else B.a.V(r)
n.a=n.b=null
return n.c=s},
d2(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.k2(this.a[a])
return this.b[a]=s}}
A.f6.prototype={
gm(a){return this.a.gm(0)},
I(a,b){var s=this.a
if(s.b==null)s=s.ga9().I(0,b)
else{s=s.aD()
if(!(b>=0&&b<s.length))return A.b(s,b)
s=s[b]}return s},
gt(a){var s=this.a
if(s.b==null){s=s.ga9()
s=s.gt(s)}else{s=s.aD()
s=new J.c5(s,s.length,A.r(s).j("c5<1>"))}return s},
v(a,b){return this.a.E(b)}}
A.d5.prototype={
gbs(){return B.cP}}
A.fA.prototype={
br(a){var s
t.J.a(a)
s=a.length
if(s===0)return""
s=new A.jC("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/").dw(a,0,s,!0)
s.toString
return A.ol(s)}}
A.jC.prototype={
dw(a,b,c,d){var s,r,q,p,o
t.J.a(a)
s=this.a
r=(s&3)+(c-b)
q=B.c.bn(r,3)
p=q*4
if(r-q*3>0)p+=4
o=new Uint8Array(p)
this.a=A.oC(this.b,a,b,c,!0,o,0,s)
if(p>0)return o
return null}}
A.fz.prototype={
br(a){var s,r,q,p=A.m4(0,null,a.length)
if(0===p)return new Uint8Array(0)
s=new A.jB()
r=s.dq(a,0,p)
r.toString
q=s.a
if(q<-1)A.bs(A.bb("Missing padding character",a,p))
if(q>0)A.bs(A.bb("Invalid length, must be multiple of four",a,p))
s.a=-1
return r}}
A.jB.prototype={
dq(a,b,c){var s,r=this,q=r.a
if(q<0){r.a=A.mc(a,b,c,q)
return null}if(b===c)return new Uint8Array(0)
s=A.oz(a,b,c,q)
r.a=A.oB(a,b,c,s,0,r.a)
return s}}
A.bO.prototype={}
A.e8.prototype={}
A.dl.prototype={
q(a){var s=A.ec(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.er.prototype={
q(a){return"Cyclic error in JSON stringify"}}
A.eq.prototype={
dn(a,b){var s=A.pt(a,this.gdr().a)
return s},
dv(a,b){var s=A.oE(a,this.gbs().b,null)
return s},
gbs(){return B.df},
gdr(){return B.de}}
A.ie.prototype={}
A.id.prototype={}
A.jQ.prototype={
cA(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.k.au(a,r,q)
r=q+1
o=A.ar(92)
s.a+=o
o=A.ar(117)
s.a+=o
o=A.ar(100)
s.a+=o
o=p>>>8&15
o=A.ar(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.ar(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.ar(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.k.au(a,r,q)
r=q+1
o=A.ar(92)
s.a+=o
switch(p){case 8:o=A.ar(98)
s.a+=o
break
case 9:o=A.ar(116)
s.a+=o
break
case 10:o=A.ar(110)
s.a+=o
break
case 12:o=A.ar(102)
s.a+=o
break
case 13:o=A.ar(114)
s.a+=o
break
default:o=A.ar(117)
s.a+=o
o=A.ar(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.ar(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.ar(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.k.au(a,r,q)
r=q+1
o=A.ar(92)
s.a+=o
o=A.ar(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.k.au(a,r,m)},
bb(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.l(new A.er(a,null))}B.a.k(s,a)},
b5(a){var s,r,q,p,o=this
if(o.cz(a))return
o.bb(a)
try{s=o.b.$1(a)
if(!o.cz(s)){q=A.lO(a,null,o.gc_())
throw A.l(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.bL(p)
q=A.lO(a,r,o.gc_())
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
q.e2(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return!0}else if(t.av.b(a)){q.bb(a)
r=q.e3(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return r}else return!1},
e2(a){var s,r,q=this.c
q.a+="["
s=J.af(a)
if(s.ga8(a)){this.b5(s.h(a,0))
for(r=1;r<s.gm(a);++r){q.a+=","
this.b5(s.h(a,r))}}q.a+="]"},
e3(a){var s,r,q,p,o,n,m=this,l={}
if(a.gF(a)){m.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.bc(s,null,!1,t.iD)
q=l.a=0
l.b=!0
a.X(0,new A.jR(l,r))
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
A.jR.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.i(s,r.a++,a)
B.a.i(s,r.a++,b)},
$S:11}
A.jP.prototype={
gc_(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.bt.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.bt&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gK(a){return A.cL(this.a,this.b,B.e,B.e)},
S(a,b){var s
t.cs.a(b)
s=B.c.S(this.a,b.a)
if(s!==0)return s
return B.c.S(this.b,b.b)},
q(a){var s=this,r=A.lG(A.eK(s)),q=A.bu(A.lY(s)),p=A.bu(A.lU(s)),o=A.bu(A.lV(s)),n=A.bu(A.lX(s)),m=A.bu(A.lZ(s)),l=A.h8(A.lW(s)),k=s.b,j=k===0?"":A.h8(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
bB(){var s=this,r=A.eK(s)>=-9999&&A.eK(s)<=9999?A.lG(A.eK(s)):A.nG(A.eK(s)),q=A.bu(A.lY(s)),p=A.bu(A.lU(s)),o=A.bu(A.lV(s)),n=A.bu(A.lX(s)),m=A.bu(A.lZ(s)),l=A.h8(A.lW(s)),k=s.b,j=k===0?"":A.h8(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iaL:1}
A.h9.prototype={
$1(a){if(a==null)return 0
return A.ft(a)},
$S:12}
A.ha.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.b(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:12}
A.ca.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.ca},
gK(a){return B.c.gK(0)},
S(a,b){t.jS.a(b)
return 0},
q(a){return"0:00:00."+B.k.dR(B.c.q(0),6,"0")},
$iaL:1}
A.f1.prototype={
q(a){return this.G()},
$iZ:1}
A.P.prototype={
gaI(){return A.o7(this)}}
A.e1.prototype={
q(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.ec(s)
return"Assertion failed"}}
A.bG.prototype={}
A.bi.prototype={
gbh(){return"Invalid argument"+(!this.a?"(s)":"")},
gbg(){return""},
q(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gbh()+q+o
if(!s.a)return n
return n+s.gbg()+": "+A.ec(s.gbv())},
gbv(){return this.b}}
A.dx.prototype={
gbv(){return A.x(this.b)},
gbh(){return"RangeError"},
gbg(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.z(q):""
else if(q==null)s=": Not greater than or equal to "+A.z(r)
else if(q>r)s=": Not in inclusive range "+A.z(r)+".."+A.z(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.z(r)
return s}}
A.eh.prototype={
gbv(){return A.a0(this.b)},
gbh(){return"RangeError"},
gbg(){if(A.a0(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gm(a){return this.f}}
A.dG.prototype={
q(a){return"Unsupported operation: "+this.a}}
A.eU.prototype={
q(a){return"UnimplementedError: "+this.a}}
A.dD.prototype={
q(a){return"Bad state: "+this.a}}
A.e7.prototype={
q(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.ec(s)+"."}}
A.eI.prototype={
q(a){return"Out of Memory"},
gaI(){return null},
$iP:1}
A.dC.prototype={
q(a){return"Stack Overflow"},
gaI(){return null},
$iP:1}
A.jD.prototype={
q(a){return"Exception: "+this.a}}
A.dd.prototype={
q(a){var s,r,q,p,o,n,m,l,k,j,i,h=this.a,g=""!==h?"FormatException: "+h:"FormatException",f=this.c,e=this.b
if(typeof e=="string"){if(f!=null)s=f<0||f>e.length
else s=!1
if(s)f=null
if(f==null){if(e.length>78)e=B.k.au(e,0,75)+"..."
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
k=""}return g+l+B.k.au(e,i,j)+k+"\n"+B.k.ar(" ",f-i+l.length)+"^\n"}else return f!=null?g+(" (at offset "+A.z(f)+")"):g}}
A.j.prototype={
aY(a,b){return A.lB(this,A.i(this).j("j.E"),b)},
aH(a,b,c){var s=A.i(this)
return A.l_(this,s.A(c).j("1(j.E)").a(b),s.j("j.E"),c)},
W(a,b,c,d){var s,r
d.a(b)
A.i(this).A(d).j("1(1,j.E)").a(c)
for(s=this.gt(this),r=b;s.l();)r=c.$2(r,s.gp())
return r},
Z(a,b){var s
A.i(this).j("v(j.E)").a(b)
for(s=this.gt(this);s.l();)if(b.$1(s.gp()))return!0
return!1},
gm(a){var s,r=this.gt(this)
for(s=0;r.l();)++s
return s},
gF(a){return!this.gt(this).l()},
ga8(a){return!this.gF(this)},
a3(a,b){return A.m6(this,b,A.i(this).j("j.E"))},
gu(a){var s=this.gt(this)
if(!s.l())throw A.l(A.av())
return s.gp()},
gM(a){var s,r=this.gt(this)
if(!r.l())throw A.l(A.av())
do s=r.gp()
while(r.l())
return s},
ag(a,b,c){var s,r
A.i(this).j("v(j.E)").a(b)
for(s=this.gt(this);s.l();){r=s.gp()
if(b.$1(r))return r}throw A.l(A.av())},
dD(a,b){return this.ag(0,b,null)},
I(a,b){var s,r
A.cP(b,"index")
s=this.gt(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.l(A.ia(b,b-r,this,"index"))},
q(a){return A.nV(this,"(",")")}}
A.ai.prototype={
q(a){return"MapEntry("+A.z(this.a)+": "+A.z(this.b)+")"}}
A.ap.prototype={
gK(a){return A.J.prototype.gK.call(this,0)},
q(a){return"null"}}
A.J.prototype={$iJ:1,
Y(a,b){return this===b},
gK(a){return A.eL(this)},
q(a){return"Instance of '"+A.eM(this)+"'"},
gO(a){return A.pV(this)},
toString(){return this.q(this)}}
A.fk.prototype={
q(a){return""},
$ibX:1}
A.cR.prototype={
gm(a){return this.a.length},
q(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$iok:1}
A.i8.prototype={
gcW(){var s,r=this.a
A:{if("pt"===r){s=0
break A}if("en"===r){s=1
break A}if("es"===r){s=2
break A}s=-1
break A}return s},
$2(a,b){var s,r,q,p={}
A.C(a)
t.md.a(b)
s=B.dL.h(0,a)
p.a=null
if(s==null)p.a=a
else{r=this.gcW()
A:{if(0===r){q=s.a
break A}if(2===r){q=s.c
break A}if(1===r){q=s.b
break A}q=$.k4.h(0,this.a)
q=q==null?null:q.a.h(0,a)
if(q==null)q=s.b
break A}p.a=q}if(b!=null)b.X(0,new A.i9(p))
return p.a},
$1(a){return this.$2(a,null)}}
A.i9.prototype={
$2(a,b){var s,r
A.C(a)
A.C(b)
s=this.a
r=s.a
return s.a=A.qf(r,"{"+a+"}",b)},
$S:119}
A.hd.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
q.i(0,"project",r.a)
q.i(0,"lang",r.b)
s=r.c
if(s!=null)q.i(0,"strings",s)
q.i(0,"sizeZones",r.d)
q.i(0,"sizeMain",r.e)
return q}}
A.he.prototype={
n(){var s=this.a.n(),r=this.b,q=A.r(r),p=q.j("t<1,h<c,@>>")
r=A.q(new A.t(r,q.j("h<c,@>(1)").a(new A.hf()),p),p.j("u.E"))
return A.S(["results",s,"entities",r,"nextId",this.c],t.N,t.z)}}
A.hf.prototype={
$1(a){return t.h.a(a).n()},
$S:13}
A.kw.prototype={
$1(a){return this.a.$1(A.C(a))},
$S:100}
A.kx.prototype={
$1(a){var s=A.n(t.N,t.z)
J.kS(s,"type","progress")
J.lt(s,a.n())
return this.a.$1(s)},
$S:91}
A.bj.prototype={
G(){return"DesignStage."+this.b}}
A.c8.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
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
A.ea.prototype={
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
r=new A.iN(a.z,a.d,a.x,a.Q,a.as,g,s*k.cx+k.cy,h,k.b,A.fv(k.c),a.ch,a.CW,a.cx,a.cy,a.db,a.dx,a.dy,a.fr,a.fx,a.fy,a.go,Math.max(k.e,3))
q=this.c.Q
p=q==null||q.c.length===0?l:A.pX(r,a.w,a.y*3.141592653589793/180,q.gdu())
o=a.c
if(!(o.length!==0)){k=a.k1
o=k.length!==0?k:this.b.$1("tool.pivot")}k=A.d([],t.dD)
j=j.a0(a.e)
j=j==null?l:j.f
if(j==null)j=B.dA
h=j.length
n=0
for(;n<j.length;j.length===h||(0,A.k)(j),++n){m=j[n]
k.push(new A.m(m.b,m.c))}return A.pG(r,p,a.a,o,k)},
be(a){var s,r,q,p,o=this
if(o.c.e.E(a)){s=o.a.a6(a)
if(!(s instanceof A.b1))return B.bu
r=o.d.d
q=r.h(0,a)
if(q==null)q=o.cf(s)
r.i(0,a,q)
return new A.m(q.e,q.r)}r=o.d.c
p=r.h(0,a)
if(p==null)p=o.aA(a)
r.i(0,a,p)
return new A.m(p.d,p.r)},
aV(a){var s=this.e.h(0,a.f)
if(s==null)s=a.x
return this.a.c.N(s)},
av(a){var s,r,q=a.y
if(q!=null)return this.a.c.ad(q).f/1000
s=this.aV(a)
if(s!=null)return s.f/1000
r=this.a.c.ab(a.Q)
return r.length===0?0.05:B.a.gu(r).f/1000},
az(a){var s
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
q=j.aV(a)
s=s.b
p=r==null
o=p?i:r.CW
if(o==null)o=q==null?i:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?i:q.x/1000
n=p==null?0.0000015:p}p=j.av(a)
m=j.bf(a)
l=s.w?a.as:0
return A.ed(!1,i,p,a.b,o*s.cx+s.cy,a.a,B.ao,m,l,0,i,n,a,a.c)
case 1:q=j.a.c.a2(a.ay)
s=q==null?i:q.r
if(s==null)s=B.aW
return A.ed(!1,s,0.05,a.b,150,a.a,B.bg,1,0,0,i,0.0000015,a,a.c)
case 3:q=j.a.c.a2(a.ay)
s=q==null
k=s?i:q.r
if(k==null)k=B.I
p=k.a>0?k:B.aW
return A.ed((s?i:q.e)===B.T,p,0.05,a.b,150,a.a,B.bg,1,0,0,i,0.0000015,a,a.c)
case 4:q=j.a.c.a2(a.ay)
s=q==null?i:q.r
return A.ed(!1,s,0.05,a.b,150,a.a,B.M,1,0,a.ax,i,0.0000015,a,a.c)
case 2:q=j.a.c.ap(a.ch)
if(q==null)s=i
else{s=q.w
s=new A.cO(s.a,s.b,s.c,a.CW)}return A.ed(!1,i,0.05,a.b,150,a.a,B.bf,1,0,0,s,0.0000015,a,a.c)}},
bW(a,b,c){var s,r,q,p
if(c<=0)return 0
s=this.a.b
r=b.f/1000
q=this.bf(a)
p=A.mP(b.w*s.cx+s.cy,r,c,A.fv(s.c),q,s.b,b.x/1000)
return p+(s.w&&a.as>0?A.mY(r,c,a.as):0)},
bQ(a,b){var s,r,q,p,o,n,m,l,k=this
if(b<=0)return 0
s=k.a
r=s.c.ad(a.y)
q=k.aV(a)
s=s.b
p=r==null
o=p?null:r.CW
if(o==null)o=q==null?null:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?null:q.x/1000
n=p==null?0.0000015:p}m=k.av(a)
p=k.bf(a)
l=A.mP(o*s.cx+s.cy,m,b,A.fv(s.c),p,s.b,n)
return l+(s.w&&a.as>0?A.mY(m,b,a.as):0)},
aQ(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.Q.a(c)
s=A.S([a,null],t.N,t.B)
r=A.d([a],t.s)
for(q=0;q<r.length;q=p){p=q+1
o=r[q]
if(o===b)break
for(n=this.c.a.h(0,o).w,m=n.length,l=0;l<n.length;n.length===m||(0,A.k)(n),++l){k=n[l]
if(!c.v(0,k.a))continue
j=k.b
if(o===j)j=k.c
if(!s.E(j)){s.i(0,j,k)
B.a.k(r,j)}}}if(!s.E(b))return B.dy
i=A.d([],t.I)
for(h=b;h!==a;){n=s.h(0,h)
n.toString
B.a.k(i,n)
g=n.b
h=h===g?n.c:g}n=t.g9
n=A.q(new A.bp(i,n),n.j("u.E"))
return n},
aJ(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.bq.a(a)
t.Q.a(b)
s=t.N
r=A.n(s,t.B)
q=A.n(s,s)
p=A.n(s,t.S)
o=A.d([],t.s)
for(s=J.ab(a);s.l();){n=s.gp()
r.i(0,n,null)
q.i(0,n,n)
p.i(0,n,0)
B.a.k(o,n)}for(m=0;m<o.length;m=l){l=m+1
k=o[m]
for(s=this.c.a.h(0,k).w,n=s.length,j=0;j<s.length;s.length===n||(0,A.k)(s),++j){i=s[j]
if(!b.v(0,i.a))continue
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
c0(a,b){var s,r,q,p
t.c8.a(a)
s=A.d([],t.I)
for(r=b;;){q=a.h(0,r)
if(q==null)break
B.a.k(s,q)
p=q.b
r=r===p?q.c:p}return s},
aP(a,b){var s,r,q,p
t.d.a(b)
for(s=b.length,r=a.f+1e-9,q=0;q<s;++q){p=b[q]
if(p.f>r)return p}return null},
R(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a.b
e=A.lS(A.fv(e.c),e.b)
s=t.N
r=A.n(s,t.b)
q=A.d([],t.lp)
p=new A.ef(e,r,q)
o=f.c.c.h(0,a).b
n=f.c.f.h(0,a)
if(n==null)n=A.K(s)
for(e=A.as(n,n.r,A.i(n).c),m=e.$ti.c;e.l();){l=e.d
if(l==null)l=m.a(l)
k=f.c.a.h(0,l)
k.toString
if(l===o){j=k.Q
i=j==null
h=i?k.c-k.e:j
r.i(0,l,new A.bm(l,B.Z,h,(i?k.c-k.e:j)+b,null,1,0))
continue}j=k.Q
g=new A.bm(l,B.Y,j==null?k.c-k.e:j,null,null,1,0)
r.i(0,l,g)
f.bM(p,g,k,c)}e=f.c.r.h(0,a)
if(e==null)e=A.K(s)
e=A.as(e,e.r,A.i(e).c)
s=e.$ti.c
while(e.l()){r=e.d
if(r==null)r=s.a(r)
r=f.c.ah(r)
r.toString
B.a.k(q,f.ca(r))}return p},
bM(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=c.f,e=f.length
if(e===0)return
if(!d){b.d=B.a.W(f,0,new A.hs(),t.i)
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
s.i(0,h,new A.bm(h,B.Y,g,null,j,k.d,k.x))
B.a.k(q,new A.de("sat_"+h,r,h,B.ao,0.5,0.01,150,0.0000015,0,!1,null,null,0,B.n))
m=i}}}},
aO(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this.c.f.h(0,a)
if(d==null)d=A.K(t.N)
d=A.as(d,d.r,A.i(d).c)
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
if(e.length!==0&&s.a6(e) instanceof A.aB&&f!==0)continue
f=l.Q
if(f==null)f=i-l.e
e=g.d
p+=(k-(f+g.x))*e
o+=g.e*e
n+=e}}if(n===0)return B.bu
return new A.m(p/n,o/n)},
af(g3,g4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8=f6.a,f9=t.e.a(f8.a6(g3)),g0=t.s,g1=A.d([],g0),g2=f9==null
if(g2||!f6.c.c.E(g3)){f8=g2?f7:f9.f
if(f8==null)f8=""
return f6.bR(g3,f8,A.d(["valve_missing"],g0))}s=f6.c.c.h(0,g3)
r=s.a
q=s.b
g2=f6.c.a.h(0,q)
g2.toString
p=f6.c.f.h(0,g3)
if(p==null)p=A.K(t.N)
if(p.a>1){o=f6.c.r.h(0,g3)
o=o==null?f7:o.a===0
o=o!==!1}else o=!0
if(o)return f6.bR(g3,f9.f,A.d(["zone_empty"],g0))
n=f9.w
g0=n==null
if(!g0)m=f6.R(g3,n,g4).H()
else if(!g4){l=f6.aO(g3,f6.R(g3,10,!1).H())
n=10+(l.b-l.a)
m=f6.R(g3,n,!1).H()}else{k=f6.aO(g3,f6.R(g3,10,!1).H()).b
j=Math.max(k*3,5)
m=f6.R(g3,j,!0).H()
i=0
for(;;){if(!(f6.aO(g3,m).a<k&&i<20))break
j*=2
m=f6.R(g3,j,!0).H();++i}for(h=0,g=0;g<28;++g){f=(h+j)/2
if(f6.aO(g3,f6.R(g3,f,!0).H()).a>k)j=f
else h=f
if(j-h<0.001)break}n=(h+j)/2
m=f6.R(g3,n,!0).H()
g4=!0}if(!m.a)B.a.k(g1,"not_converged")
if(g0){g0=f6.d1(g3,m).a
e=g0[0]
d=g0[1]
c=g0[2]
b=g0[3]
if(d-e<=b-c+1e-9)g0=e<c-0.000001||d>b+0.000001
else g0=!1
if(g0){n+=(c+b)/2-(e+d)/2
m=f6.R(g3,n,g4).H()}}a=A.d([],t.w)
a0=A.d([],t.n)
for(g0=A.as(p,p.r,A.i(p).c),o=m.c,a1=g0.$ti.c,a2=0,a3=1/0,a4=-1/0,a5=-1/0,a6=1/0,a7=0,a8=0,a9=0,b0=0;g0.l();){b1=g0.d
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
B.a.k(a,new A.aw(b9.a,c5,b5,c6+c1,c2,c3,c0.a7(c7),c4,c8,c9,b9.y))
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
d4=A.ot(a0,d3,d2)
d5=A.d([],t.A)
d6=A.d([],t.c)
g0=f6.c.r.h(0,g3)
if(g0==null)g0=A.K(t.N)
g0=A.as(g0,g0.r,A.i(g0).c)
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
e3=f6.av(b6)
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
B.a.k(d5,new A.be(b5,b7,b6.r,b6.cx,b6.cy,c7,e5,b6.w,e3,e7,e8,c1,e4,e9,d8-c5,d9-c6,c8,g3,e4>f6.az(b6)+0.000001))
if(e4>f6.az(b6)+0.000001)B.a.k(g1,"velocity_exceeded:"+b7)
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
B.a.k(d6,new A.bQ(b7,b5,c1,c5,c6,d8-c9,d9-c4,e5.b,c7))
b5=c0.Q
c1=b5==null
c4=c1?c0.c-c0.e:b5
if(c1)b5=c0.c-c0.e
if(f6.c8(b6,d7,d8-c4,b5))B.a.k(g1,"pump_suction_lift:"+b7)}}for(g0=a.length,o=a5-0.000001,b1=a6+0.000001,b8=0;b8<g0;++b8){f0=a[b8]
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
if(o==null)o=A.K(t.N)
o=A.as(o,o.r,A.i(o).c)
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
f5=A.mJ(a1.Q,a2,f8,a1.ax,a1.as)
a1=f6.c.a.h(0,r)
a1.toString
o=f9.f
g2=g2.gaB()
b1=a1.gaB()
b2=A.cG(g1,t.N)
b2=A.q(b2,A.i(b2).c)
a1=a1.gaB()
g0=g0?f7:f1.b
if(g0==null)g0=""
b4=g4?f6.d0(g3,a):0
return A.l7(a6,a5,f5,m.a,d6,n,b0,d3,a4,a3,d1,a,b4,f3,d5,f8+(g2-b1),a2,d4,a1,g3,f2,g0,b2,o)},
aA(a){return this.af(a,!0)},
cS(a){var s,r,q,p,o,n,m,l,k,j
t.ms.a(a)
if(a.length===0)return Math.max(1,this.a.b.fx)
for(s=this.a,r=B.a.gt(s.e),q=new A.bI(r,t.jc),p=t.mu;q.l();){o=p.a(r.gp())
n=o.w
if(n<=0||o.d.length<3)continue
for(m=a.length,o=o.d,l=0,k=0;j=a.length,k<j;a.length===m||(0,A.k)(a),++k)if(A.q9(a[k].c,o))++l
if(l*2>=j)return n}return Math.max(1,s.b.fx)},
d0(a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=null
t.ms.a(a8)
if(a8.length===0)return 0
s=A.r(a8)
r=new A.t(a8,s.j("c(1)").a(new A.hz()),s.j("t<1,c>")).aq(0)
q=A.d([],t.h0)
p=A.d([],t.iv)
for(s=A.as(r,r.r,A.i(r).c),o=this.a,n=s.$ti.c;s.l();){m=s.d
l=o.a6(m==null?n.a(m):m)
if(l instanceof A.ak)B.a.k(q,l)
if(l instanceof A.aZ)B.a.k(p,l)}for(s=a8.length,k=0,j=0,i=0;i<s;++i){h=a8[i]
n=h.w
k+=h.e*n
j+=n}k=j>0?k/j:0
if(q.length!==0){g=B.a.gu(q)
s=o.c.a0(g.r)
f=s==null?a6:s.aC(g.w)
e=f==null?a6:f.c.cq(k)
if(e==null)e=0
if(e<=0)return 0
d=A.d([],t.n)
for(s=q.length,i=0;i<q.length;q.length===s||(0,A.k)(q),++i){c=q[i]
o=c.d
if(J.au(o)<2)continue
b=A.ku(o,A.aV(o)/2)
for(o=q.length,a=1/0,a0=0;a0<q.length;q.length===o||(0,A.k)(q),++a0){a1=q[a0]
if(c===a1)continue
a=Math.min(a,a1.dt(b))}if(isFinite(a))B.a.k(d,a)}if(d.length===0)return 0
B.a.a4(d)
s=d.length
o=s/2|0
if(!(o<s))return A.b(d,o)
return A.mS(e,g.y,d[o])}if(p.length>=4){h=B.a.gu(p)
s=o.c.a0(h.f)
f=s==null?a6:s.aC(h.r)
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
return A.mS(e,g,g)}return 0},
d1(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this.c.f.h(0,a)
if(c==null)c=A.K(t.N)
c=A.as(c,c.r,A.i(c).c)
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
n=Math.min(n,f.r)}}if(!isFinite(q))return B.yD
return new A.cX([q,p,o,n])},
bR(a,b,c){return A.l7(0,0,0,!1,B.bj,0,0,1,0,0,0,B.dz,0,0,B.bk,0,0,B.cK,0,a,0,"",t.bF.a(c),b)},
bo(a){var s,r,q,p,o,n
t.bq.a(a)
s=A.n(t.N,t.e5)
for(r=A.as(a,a.r,A.i(a).c),q=this.a.c,p=r.$ti.c;r.l();){o=r.d
if(o==null)o=p.a(o)
n=this.c.ah(o)
if(n.d!==B.d||!n.z||n.y!=null)continue
if(q.ab(n.Q).length===0)continue
J.bM(s.ac(n.f,new A.hL()),n)}return s},
aM(a,b,c,d){var s,r,q,p,o,n
t.e5.a(a)
t.U.a(c)
t.hZ.a(d)
for(s=J.ab(a),r=b.f/1000,q=0;s.l();){p=s.gp()
if(!d.v(0,p))continue
o=this.av(p)
n=c.h(0,p.a)
if(n==null)n=0
q+=Math.abs(n)*(1-Math.pow(o/r,4.871))}return q},
aw(a){return J.no(t.e5.a(a),0,new A.hK(),t.i)},
aX(a,b){var s=this.a.c.ab(a.Q),r=A.r(s),q=r.j("B<1>"),p=A.q(new A.B(s,r.j("v(1)").a(new A.hM(this,b,a)),q),q.j("j.E"))
return p.length===0?A.d([B.a.gM(s)],t.D):p},
bZ(a){var s
switch(a.Q.a){case 0:s=Math.max(1,this.a.b.ch)
break
case 1:s=Math.max(1,this.a.b.CW)
break
case 2:s=Math.max(1,this.a.b.fr)
break
default:s=null}return s},
ba(a){a.b.X(0,new A.hm(this))},
de(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.L.a(b)
s=A.d([],t.s)
for(r=A.i(b),q=new A.L(b,r.j("L<1,2>")).gt(0),p=t.G,o=d.a.c,n=d.e;q.l();){m=q.d
n.i(0,m.a,B.a.gu(o.ab(p.a(J.bN(m.b)).Q)).a)}for(r=r.j("ag<1,2>"),l=0;l<4;++l){k=d.R(a,10,!1).H()
for(q=new A.ag(b,b.r,b.e,r),p=k.d,j=!1;q.l();){m=q.d
for(o=m.b,i=J.a1(o),h=i.gt(o),g=0;h.l();){f=p.h(0,h.gp().a)
f=f==null?null:f.a
g=Math.max(g,Math.abs(f==null?0:f))}e=B.a.gu(d.aX(i.gu(o),g))
h=e.f/1000
if(g/(3.141592653589793*h*h/4)>d.az(i.gu(o))+0.000001)B.a.k(s,"velocity_exceeded:"+m.a)
o=m.a
i=e.a
if(n.h(0,o)!==i){n.i(0,o,i)
j=!0}}if(!j)break}return s},
c6(a9,b0,b1,b2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=this
t.L.a(b0)
t.bF.a(b1)
s=a8.c.c.h(0,a9).b
r=a8.c.r.h(0,a9)
if(r==null)r=A.K(t.N)
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
i=a8.aQ(s,g,r)
f=A.cG(i,A.r(i).c)
i=A.n(l,k)
for(e=b2.at,d=e.length,c=0;c<e.length;e.length===d||(0,A.k)(e),++c){b=e[c]
i.i(0,b.a,b.at)}for(e=new A.ag(b0,b0.r,b0.e,o),a=null,a0=null,a1=0;e.l();){a2=e.d
d=a2.b
a3=J.a1(d)
if(!a3.Z(d,f.gaF(f)))continue
a4=m.a(a3.gu(d))
a5=q.h(0,a4.f)
a4=n.N(a5==null?a4.x:a5)
a4.toString
a6=a8.aP(a4,n.ab(m.a(a3.gu(d)).Q))
if(a6==null)continue
a7=a8.aM(d,a6,i,f)/Math.max((a6.Q-a4.Q)*a8.aw(d),0.000001)
if(a7>a1){a=a2.a
a1=a7
a0=a6}}if(a==null){B.a.k(b1,"cannot_meet_pressure_window")
break}q.i(0,a,a0.a)
p.T(0,a)
b2=a8.af(a9,!1);++j}return b2},
cR(a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.dV.a(a2)
s=t.N
r=A.n(s,t.bF)
q=this.c.f.h(0,a1)
if(q==null)q=A.K(s)
q=A.as(q,q.r,A.i(q).c)
p=q.$ti.c
while(q.l()){o=q.d
if(o==null)o=p.a(o)
for(n=this.c.a.h(0,o).f,m=n.length,l=0;l<n.length;n.length===m||(0,A.k)(n),++l){k=n[l]
if(k.b===-2)continue
J.bM(r.ac(k.a,new A.ht()),o)}}j=A.K(s)
for(s=new A.N(r,r.r,r.e,r.$ti.j("N<2>")),q=t.s;s.l();){p=s.d
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
j.B(0,p)}if(j.a>1500){a0=A.q(j,j.$ti.c)
return A.bY(a0,0,A.cx(1500,"count",t.S),A.r(a0).c).aq(0)}return j},
bX(d2,d3,d4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0=this,d1=null
t.L.a(d3)
t.Q.a(d4)
s=d0.c.c.h(0,d2).b
r=d0.c.r.h(0,d2)
if(r==null)r=A.K(t.N)
q=d0.R(d2,10,!1).H()
p=new A.hy(q)
o=d0.aJ(A.d([s],t.s),r)
n=o.a
m=t.N
l=A.n(m,m)
for(k=A.i(d3),j=k.j("L<1,2>"),i=new A.L(d3,j).gt(0);i.l();){h=i.d
for(g=J.ab(h.b),f=h.a;g.l();)l.i(0,g.gp().a,f)}e=A.n(m,t.d)
d=A.n(m,t.i)
c=A.n(m,t.S)
for(j=new A.L(d3,j).gt(0);j.l();){h=j.d
for(i=h.b,g=J.a1(i),f=g.gt(i),b=0;f.l();)b=Math.max(b,A.li(p.$1(f.gp())))
f=h.a
e.i(0,f,d0.aX(g.gu(i),b))
d.i(0,f,d0.aw(i))
c.i(0,f,d0.bZ(g.gu(i)))}j=d0.c.f.h(0,d2)
if(j==null)j=A.K(m)
j=A.as(j,j.r,A.i(j).c)
i=j.$ti.c
a=0
while(j.l()){g=j.d
if(g==null)g=i.a(g)
for(g=d0.c.a.h(0,g).f,f=g.length,a0=0;a0<g.length;g.length===f||(0,A.k)(g),++a0){h=g[a0]
a+=h.c.a7(h.e)*h.d}}j=d0.a.b
i=j.ay
a1=i?A.mJ(j.Q,a,1,j.ax,j.as):0
a2=d0.c.a.h(0,s).gaB()
g=A.dm(d0.cR(d2,o.c),m)
g.B(0,d4)
a3=A.d([],t.nE)
for(g=A.as(g,g.r,A.i(g).c),f=q.d,a4=t.U,a5=j.ok,a6=a5>0,a7=g.$ti.c,a5/=200,a8=1-a5,a5=1+a5;g.l();){a9=g.d
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
b4=Math.min(b4,b9*a5)}c0=A.n(m,a4)
for(a9=d0.c0(n,a9),b1=a9.length,c1=0,a0=0;a0<a9.length;a9.length===b1||(0,A.k)(a9),++a0){c2=a9[a0]
b2=c2.a
c3=l.h(0,b2)
if(c3!=null){c4=c0.ac(c3,new A.hx())
for(b2=e.h(0,c3),b8=b2.length,c5=0;c5<b2.length;b2.length===b8||(0,A.k)(b2),++c5){c6=b2[c5]
c7=c6.a
c8=c4.h(0,c7)
if(c8==null)c8=0
c4.i(0,c7,c8+d0.bW(c2,c6,p.$1(c2)))}}else if(c2.d===B.d)c1+=d0.bQ(c2,p.$1(c2))
else{b2=f.h(0,b2)
b2=b2==null?d1:b2.c
c1+=b2==null?0:b2}}a9=b0.Q
c9=(a9==null?b0.c-b0.e:a9)+b5-a2
a9=isFinite(b3)?b3+c9:d1
B.a.k(a3,new A.dp(0,c0,c1,a9,isFinite(b4)?b4+c9:d1))}m=k.j("a4<1>")
m=A.q(new A.a4(d3,m),m.j("j.E"))
return A.mV(new A.ex(m,e,d,c,A.d([new A.dq(a1,d1,d1,"zone")],t.jv),a3,A.fq(j.y,j.z),i))},
d_(a,b){return this.bX(a,b,B.yG)},
cD(c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1=this,c2=c1.a,c3=t.e.a(c2.a6(c4))
if(c3==null||!c1.c.c.E(c4))return c1.aA(c4)
s=c1.c.r.h(0,c4)
if(s==null)s=A.K(t.N)
r=c1.bo(s)
if(r.a===0)return c1.aA(c4)
q=c1.c.c.h(0,c4).b
p=A.d([],t.s)
B.a.B(p,c1.de(c4,r))
o=c2.b
if(o.dy===B.a6){n=c1.d_(c4,r)
m=n.a
if(m){c1.ba(n)
l=c1.af(c4,!1)
k=t.N
j=A.K(k)
i=t.w
h=0
for(;;){if(h<4)g=!(l.w>=l.y-0.000001&&l.x<=l.z+0.000001)
else g=!1
if(!g)break
f=A.K(k)
g=A.d([],i)
e=l.gbx()
if(e!=null)g.push(e)
e=l.gdP()
if(e!=null)g.push(e)
e=g.length
d=0
for(;d<g.length;g.length===e||(0,A.k)(g),++d){c=c1.bm(c4,g[d])
if(c!=null)f.k(0,c)}if(f.dA(0,j.gaF(j)))break
g=A.ev(k)
g.B(0,j)
g.B(0,f)
n=c1.bX(c4,r,g)
if(!n.a)break
c1.ba(n)
l=c1.af(c4,!1);++h
j=g}}else{B.a.k(c1.d.f,"lp_infeasible:"+c3.f)
l=c1.af(c4,!1)}}else{l=c1.af(c4,!1)
m=!1}l=c1.c6(c4,r,p,l)
if(!m&&o.ay){b=A.fq(o.y,o.z)
for(k=c1.e,i=A.i(r).j("ag<1,2>"),g=o.ax,e=o.Q,o=o.as,c2=c2.c,a=t.G,a0=t.N,a1=t.i,a2=0;a2<200;++a2){a3=l.gbx()
if(a3==null)break
a4=c1.bm(c4,a3)
if(a4==null)break
a5=c1.aQ(q,a4,s)
a6=A.cG(a5,A.r(a5).c)
a5=A.n(a0,a1)
for(a7=l.at,a8=a7.length,d=0;d<a7.length;a7.length===a8||(0,A.k)(a7),++d){a9=a7[d]
a5.i(0,a9.a,a9.at)}for(a7=new A.ag(r,r.r,r.e,i),a8=9788.99803*l.d,b0=null,b1=null,b2=0;a7.l();){b3=a7.d
b4=b3.b
b5=J.a1(b4)
if(!b5.Z(b4,a6.gaF(a6)))continue
b6=a.a(b5.gu(b4))
b7=k.h(0,b6.f)
b6=c2.N(b7==null?b6.x:b7)
b6.toString
b8=c1.aP(b6,c2.ab(a.a(b5.gu(b4)).Q))
if(b8==null)continue
b9=a8*c1.aM(b4,b8,a5,a6)/Math.max(o,0.05)/1000*g*e-(b8.Q-b6.Q)*c1.aw(b4)*b
if(b9>b2){b0=b3.a
b2=b9
b1=b8}}if(b0==null)break
k.i(0,b0,b1.a)
l=c1.af(c4,!1)}}c1.c3(q,s,r)
c1.bp(r)
c0=c1.af(c4,!0)
c2=A.dm(p,t.N)
c2.B(0,c0.ch)
c2=A.q(c2,A.i(c2).c)
return c0.cj(c2)},
bm(a,b){var s,r,q,p,o,n,m,l,k=this.c.f.h(0,a)
if(k==null)k=A.K(t.N)
k=A.as(k,k.r,A.i(k).c)
s=b.a
r=b.b
q=k.$ti.c
while(k.l()){p=k.d
if(p==null)p=q.a(p)
for(o=this.c.a.h(0,p).f,n=o.length,m=0;m<n;++m){l=o[m]
if(l.a===s&&l.b===r)return p}}return null},
c3(b1,b2,b3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this
t.Q.a(b2)
t.L.a(b3)
s=t.N
r=A.n(s,s)
for(q=new A.L(b3,A.i(b3).j("L<1,2>")).gt(0);q.l();){p=q.d
for(o=J.ab(p.b),n=p.a;o.l();)r.i(0,o.gp().a,n)}m=A.S([b1,null],s,t.B)
l=A.d([b1],t.s)
k=A.d([],t.I)
for(j=0;j<l.length;j=i){i=j+1
h=l[j]
for(s=b0.c.a.h(0,h).w,q=s.length,g=0;g<s.length;s.length===q||(0,A.k)(s),++g){f=s[g]
if(!b2.v(0,f.a))continue
e=f.b
if(h===e)e=f.c
if(!m.E(e)){m.i(0,e,f)
B.a.k(k,f)
B.a.k(l,e)}}}for(s=t.g9,q=s.j("aN<u.E>"),o=b0.a.c,n=b0.e,d=A.i(m).j("L<1,2>"),c=s.j("u.E"),b=b0.f,a=0;a<5;++a){for(a0=new A.bp(k,s),a0=new A.aN(a0,a0.gm(0),q),a1=!1;a0.l();){a2=a0.d
if(a2==null)a2=c.a(a2)
a3=r.h(0,a2.a)
if(a3==null)continue
a4=new A.L(m,d).dD(0,new A.hA(a2))
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
for(s=new A.L(a,A.i(a).j("L<1,2>")).gt(0),r=this.a,q=this.e;s.l();){p=s.d
o=p.a
n=q.h(0,o)
if(n==null)continue
m=r.a6(o)
if(m instanceof A.aH)m.f=n
if(m instanceof A.ak)m.e=n
for(o=J.ab(p.b);o.l();)o.gp().x=n}},
cM(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5=this,b6=b5.f
if(b6.a===0)return 0
s=t.N
r=A.K(s)
for(q=b5.c.c,q=new A.N(q,q.r,q.e,A.i(q).j("N<2>"));q.l();)r.k(0,q.d.b)
q=b5.c.d
p=A.i(q).j("ao<2>")
o=A.dm(new A.ao(q,p),p.j("j.E"))
s=A.K(s)
for(q=b5.c.r,q=new A.N(q,q.r,q.e,A.i(q).j("N<2>"));q.l();){p=q.d
for(p=p.gt(p);p.l();)s.k(0,A.C(p.gp()))}n=b5.aJ(r,s).c
m=b5.aJ(o,b5.c.x).c
for(s=new A.L(b6,A.i(b6).j("L<1,2>")).gt(0),r=b5.a,q=r.e,p=t.n,l=t.f,k=t.bw,j=t.pa,i=j.j("u.E"),h=t.s,g=0;s.l();){f=s.d
e=r.a6(f.a)
if(e!=null)d=!(e instanceof A.aH||e instanceof A.ak||e instanceof A.aB)
else d=!0
if(d)continue
d=b5.c.b
c=A.r(d)
b=c.j("B<1>")
a=A.q(new A.B(d,c.j("v(1)").a(new A.hn(e)),b),b.j("j.E"))
B.a.am(a,new A.ho())
if(a.length===0)continue
a0=B.a.gu(a).e===B.h?m:n
d=A.d([B.a.gu(a).b],h)
for(c=a.length,a1=0;a1<a.length;a.length===c||(0,A.k)(a),++a1)d.push(a[a1].c)
a2=A.q(new A.t(d,k.a(new A.hp(a0)),j),i)
if(B.a.Z(a2,new A.hq()))continue
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
else{d=J.nq(a6)
a8=A.q(d,d.$ti.j("u.E"))}a9=A.d([],p)
for(d=J.af(a8),b0=0,a5=0;a5<d.gm(a8)-1;++a5){b0+=d.h(a8,a5).b*a7
B.a.k(a9,b0)}b1=A.qe(e,a9,new A.hr(b5))
if(b1.length<2)continue
b2=B.a.cn(q,e)
B.a.dT(q,b2)
for(a5=0;a5<b1.length;++a5){b3=b1[a5]
b4=d.h(a8,Math.min(a5,d.gm(a8)-1)).a
if(b3 instanceof A.aH)b3.f=b4.a
if(b3 instanceof A.ak)b3.e=b4.a
B.a.dH(q,b2+a5,b3)}++g}b6.V(0)
b5.e.V(0)
b5.c=A.l0(r).bq()
return g},
aN(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=t.U
c.a(a)
c.a(b)
c=d.a
s=c.b
s=A.lS(A.fv(s.c),s.b)
r=A.n(t.N,t.b)
q=A.d([],t.lp)
p=new A.ef(s,r,q)
for(s=d.c.w,s=A.as(s,s.r,A.i(s).c),o=s.$ti.c,n=t.v;s.l();){m=s.d
if(m==null)m=o.a(m)
l=d.c.a.h(0,m)
if(l.y){k=l.z
k.toString
j=a.h(0,n.a(c.a6(k)).a)
if(j==null)j=0
k=l.Q
i=k==null
h=i?l.c-l.e:k
r.i(0,m,new A.bm(m,B.Z,h,(i?l.c-l.e:k)+j,null,1,0))
continue}k=l.Q
g=new A.bm(m,B.Y,k==null?l.c-l.e:k,null,null,1,0)
r.i(0,m,g)
d.bM(p,g,l,!0)}for(c=d.c.c,c=new A.L(c,A.i(c).j("L<1,2>")).gt(0);c.l();){f=c.d
e=r.h(0,f.b.a)
if(e==null)continue
s=e.d
o=b.h(0,f.a)
e.d=s+(o==null?0:o)}for(c=d.c.e,c=new A.L(c,A.i(c).j("L<1,2>")).gt(0);c.l();){f=c.d
e=r.h(0,f.b)
if(e==null)continue
s=e.d
o=b.h(0,f.a)
e.d=s+(o==null?0:o)}for(c=d.c.x,c=A.as(c,c.r,A.i(c).c),s=c.$ti.c;c.l();){r=c.d
if(r==null)r=s.a(r)
r=d.c.ah(r)
r.toString
B.a.k(q,d.ca(r))}return p},
gaW(){var s=t.lF,r=s.j("B<j.E>")
s=A.q(new A.B(new A.cr(this.a.e,s),s.j("v(j.E)").a(new A.hJ(this)),r),r.j("j.E"))
return s},
c8(a,b,c,d){var s
if(a.d!==B.X||b.a<=0)return!1
s=this.a.c.ap(a.ch)
if(s==null||s.f)return!1
return-c>10.33*Math.pow(1-0.0000225577*B.b.a_(d,-500,8000),5.25588)-0.24-3+0.000001},
cg(e3,e4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=null,e1=A.d([],t.s),e2=d9.gaW()
if(e2.length===0)return new A.b4(e3.a,e3.b,!1,B.dB,B.dC,B.bk,B.bj,B.dH,0,e3.e,0)
s=t.N
r=t.i
q=A.n(s,r)
p=A.n(s,r)
for(o=e3.c,o=A.as(o,o.r,A.i(o).c),n=o.$ti.c;o.l();){m=o.d
if(m==null)m=n.a(m)
if(d9.ak(m)==null)continue
l=d9.be(m)
q.i(0,m,l.a)
p.i(0,m,l.b)}r=A.n(s,r)
for(o=e2.length,k=0;k<e2.length;e2.length===o||(0,A.k)(e2),++k){j=e2[k]
n=j.e?0:j.f
r.i(0,j.a,n)}i=d9.aN(r,q).H()
o=A.r(e2)
n=o.j("B<1>")
h=A.q(new A.B(e2,o.j("v(1)").a(new A.hO()),n),n.j("j.E"))
g=new A.hP(d9,q,p)
if(h.length!==0){f=g.$1(i)
if(f>0){for(o=h.length,k=0;k<h.length;h.length===o||(0,A.k)(h),++k)r.i(0,h[k].a,f)
i=d9.aN(r,q).H()}}else f=0
o=i.a
if(!o)B.a.k(e1,"not_converged")
e=A.d([],t.eZ)
for(n=new A.an(q,q.r,q.e,q.$ti.j("an<1>")),m=i.c,d=d9.d,c=d.d,d=d.c;n.l();){b=n.d
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
B.a.k(e,new A.aS(b,a4,a3,a5,a6,d9.c.a.h(0,a).b))
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
if(typeof b3!=="number")return A.cA(b3)
b4=j.f+b3}b3=j.c
if(b3.length===0)b3=c.$1("name.supply")
a3=d9.c.a.h(0,a3)
b5=a3.Q
a3=b5==null?a3.c-a3.e:b5
b5=j.r
b6=j.w
B.a.k(a7,new A.co(a2,b3,a9,a5,b4,a3,a6,j.f,b5,b6,j.x))
if(b6>0&&a9>b6+1e-9)B.a.k(e1,"supply_flow_exceeded:"+a2)
if(b5>0&&b4>b5+0.000001)B.a.k(e1,"supply_head_exceeded:"+a2)}b7=A.d([],t.A)
b8=A.d([],t.c)
for(r=d9.c.x,r=A.as(r,r.r,A.i(r).c),n=r.$ti.c,c=d9.a,a2=c.c,a3=d9.e;r.l();){a5=r.d
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
c4=d9.av(a6)
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
B.a.k(b7,new A.be(a5,b6,a6.r,a6.cx,a6.cy,c8,d1,a6.w,c4,d3,d4,b3,c5,d5,c0-c6,c1-c7,c9,e0,c5>d9.az(a6)+0.000001))
if(c5>d9.az(a6)+0.000001)B.a.k(e1,"velocity_exceeded:"+b6)
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
B.a.k(b8,new A.bQ(b6,a5,c6,c7,c8,c0-d1,c1-b9,d2.b,c9))
if(b3===B.X){c3=a2.ap(a6.ch)
if(c3!=null)a5=c6>c3.z+1e-9||c6<=0
else a5=!1
if(a5)B.a.k(e1,"pump_out_of_range:"+b6)
a5=b5.Q
b3=a5==null
b9=b3?b5.c-b5.e:a5
if(b3)a5=b5.c-b5.e
if(d9.c8(a6,b2,c0-b9,a5))B.a.k(e1,"pump_suction_lift:"+b6)}}}d6=e4>0?e3.e/e4:1
r=c.b
d7=r.at*d6
for(n=a7.length,m=r.Q,r=r.as,d8=0,k=0;k<n;++k){c4=a7[k]
if(c4.r&&c4.e>0)d8+=9788.99803*c4.c*c4.e/Math.max(r,0.05)/1000*d7*m}for(n=b8.length,k=0;k<b8.length;b8.length===n||(0,A.k)(b8),++k){c4=b8[k]
d=c4.e
if(d>0){c3=a2.ap(d9.c.ah(c4.b).ch)
c=c3==null?e0:c3.x
if(c==null)c=r
d8+=9788.99803*c4.c*d/Math.max(c,0.05)/1000*d7*m}}s=A.cG(e1,s)
s=A.q(s,A.i(s).c)
return new A.b4(e3.a,e3.b,o,a7,e,b7,b8,s,a8,e3.e,d8)},
cl(){var s,r,q=this,p=q.a.f
if(p.length!==0)return p
p=q.b.$1("name.allZones")
s=q.c.c
s=A.dm(new A.a4(s,A.i(s).j("a4<1>")),t.N)
r=q.c.e
s.B(0,new A.a4(r,A.i(r).j("a4<1>")))
return A.d([A.m8(1,"auto",p,0,s)],t.cD)},
cZ(d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8=this,c9=null,d0={}
t.L.a(d1)
t.k6.a(d2)
s=c8.gaW()
r=t.N
q=A.n(r,t.v)
for(p=s.length,o=0;o<s.length;s.length===p||(0,A.k)(s),++o){n=s[o]
m=c8.c.d.h(0,n.a)
m.toString
q.i(0,m,n)}d0.a=d0.b=null
l=c8.aJ(new A.a4(q,q.$ti.j("a4<1>")),c8.c.x)
d0.b=l.a
d0.a=l.b
p=A.n(r,r)
for(m=A.i(d1),k=m.j("L<1,2>"),j=new A.L(d1,k).gt(0);j.l();){i=j.d
for(h=J.ab(i.b),g=i.a;h.l();)p.i(0,h.gp().a,g)}f=A.d([],t.lH)
e=A.d([],t.gN)
for(j=d2.length,h=t.i,o=0;o<d2.length;d2.length===j||(0,A.k)(d2),++o){d=A.n(r,h)
for(g=d2[o].c,c=A.i(g),b=new A.Q(g,g.r,c.j("Q<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
if(c8.ak(g)==null)continue
d.i(0,g,c8.be(g).a)}B.a.k(e,d)
g=A.n(r,h)
for(c=s.length,a=0;a<s.length;s.length===c||(0,A.k)(s),++a){n=s[a]
b=n.e?0:n.f
g.i(0,n.a,b)}B.a.k(f,c8.aN(g,d).H())}a0=A.n(r,t.d)
a1=A.n(r,h)
j=t.S
a2=A.n(r,j)
for(k=new A.L(d1,k).gt(0);k.l();){i=k.d
for(h=f.length,g=i.b,c=J.a1(g),a3=0,o=0;o<f.length;f.length===h||(0,A.k)(f),++o){a4=f[o]
for(b=c.gt(g),a5=a4.d;b.l();){a6=a5.h(0,b.gp().a)
a6=a6==null?c9:a6.a
a3=Math.max(a3,Math.abs(a6==null?0:a6))}}h=i.a
a0.i(0,h,c8.aX(c.gu(g),a3))
a1.i(0,h,c8.aw(g))
a2.i(0,h,c8.bZ(c.gu(g)))}a7=A.d([],t.jv)
a8=A.n(r,j)
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
B.a.k(a7,new A.dq(b9,b1,b2,n.c+"|"+d2[a9].b))}}c0=A.d([],t.nE)
for(j=c8.d,h=j.c,j=j.d,a9=0;a9<d2.length;++a9){if(!(a9<f.length))return A.b(f,a9)
a4=f[a9]
c1=new A.hu(d0,c8,q,p,a0,new A.hw(a4),a4,c0,a8,a9)
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
c7=Math.max(c7,i.x)}if(isFinite(c5))c1.$4(g,c5,isFinite(c6)?c6:c9,c7)}}q=m.j("a4<1>")
q=A.q(new A.a4(d1,q),q.j("j.E"))
return A.mV(new A.ex(q,a0,a1,a2,a7,c0,A.fq(r.y,r.z),k))},
cC(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5=this,d6=null,d7=d5.cl(),d8=t.i,d9=B.a.W(d7,0,new A.hW(),d8),e0=d5.bo(d5.c.x),e1=new A.hV(d5,d7,d9)
if(e0.a===0||d5.gaW().length===0){d8=d5.d.e
B.a.V(d8)
B.a.B(d8,e1.$0())
return}s=d5.gaW()
r=A.r(s)
q=new A.t(s,r.j("c(1)").a(new A.hX(d5)),r.j("t<1,c>")).aq(0)
for(r=A.i(e0),p=new A.L(e0,r.j("L<1,2>")).gt(0),o=t.G,n=d5.a,m=n.c,l=d5.e;p.l();){k=p.d
l.i(0,k.a,B.a.gu(m.ab(o.a(J.bN(k.b)).Q)).a)}for(r=r.j("ag<1,2>"),p=t.N,j=0;j<4;++j){i=A.n(p,d8)
for(h=d7.length,g=0;g<d7.length;d7.length===h||(0,A.k)(d7),++g){f=A.n(p,d8)
for(e=d7[g].c,d=A.i(e),c=new A.Q(e,e.r,d.j("Q<1>")),c.c=e.e,d=d.c;c.l();){e=c.d
if(e==null)e=d.a(e)
if(d5.ak(e)==null)continue
f.i(0,e,d5.be(e).a)}e=A.n(p,d8)
for(d=s.length,b=0;b<s.length;s.length===d||(0,A.k)(s),++b){a=s[b]
c=a.e?0:a.f
e.i(0,a.a,c)}a0=d5.aN(e,f).H()
for(e=new A.ag(e0,e0.r,e0.e,r),d=a0.d;e.l();){k=e.d
for(c=J.ab(k.b),a1=k.a;c.l();){a2=c.gp()
a3=i.h(0,a1)
if(a3==null)a3=0
a2=d.h(0,a2.a)
a2=a2==null?d6:a2.a
i.i(0,a1,Math.max(a3,Math.abs(a2==null?0:a2)))}}}for(h=new A.ag(e0,e0.r,e0.e,r),a4=!1;h.l();){k=h.d
e=J.bN(k.b)
d=k.a
c=i.h(0,d)
e=B.a.gu(d5.aX(e,c==null?0:c)).a
if(l.h(0,d)!==e){l.i(0,d,e)
a4=!0}}if(!a4)break}n=n.b
if(n.dy===B.a6){h=d5.c.x
e=A.i(h)
a5=new A.B(h,e.j("v(1)").a(new A.hY(d5)),e.j("B<1>")).gm(0)
h=d5.c.w.a
if(a5>=h&&h!==0)B.a.k(d5.d.f,"lp_loops_approx")
a6=d5.cZ(e0,d7,d9)
a7=a6.a
if(a7)d5.ba(a6)
else B.a.k(d5.d.f,"lp_infeasible:"+A.z(d5.b.$1("menu.mainline")))}else a7=!1
a8=e1.$0()
if(B.a.Z(s,new A.hZ()))for(h=d5.f,e=A.i(q),d=e.j("Q<1>"),e=e.c,a9=0;a9<400;++a9){for(c=a8.length,b0=d6,b1=b0,g=0;g<c;++g){b2=a8[g]
for(a1=b2.e,a2=a1.length,b=0;b<a2;++b){b3=a1[b]
a3=b3.e-b3.d
if(a3>0.01)a3=b0==null||a3>b0.e-b0.d
else a3=!1
if(a3){b0=b3
b1=b2}}}if(b1==null||b0==null)break
c=d5.ak(b0.a)
c.toString
b4=A.K(o)
for(a1=new A.Q(q,q.r,d),a1.c=q.e;a1.l();){a2=a1.d
if(a2==null)a2=e.a(a2)
b5=d5.aQ(a2,c,d5.c.x)
a2=b5.length
if(a2!==0){a3=b4.a
a2=a3===0||a2<a3}else a2=!1
if(a2)b4=A.cG(b5,A.r(b5).c)}c=A.n(p,d8)
for(a1=b1.f,a2=a1.length,g=0;g<a1.length;a1.length===a2||(0,A.k)(a1),++g){b5=a1[g]
c.i(0,b5.a,b5.at)}for(a1=new A.ag(e0,e0.r,e0.e,r),b6=d6,b7=b6,b8=0;a1.l();){k=a1.d
a2=k.b
a3=J.a1(a2)
if(!a3.Z(a2,b4.gaF(b4)))continue
b9=o.a(a3.gu(a2))
c0=l.h(0,b9.f)
b9=m.N(c0==null?b9.x:c0)
b9.toString
c1=d5.aP(b9,m.ab(o.a(a3.gu(a2)).Q))
if(c1==null)continue
c2=d5.aM(a2,c1,c,b4)/Math.max((c1.Q-b9.Q)*d5.aw(a2),0.000001)
if(c2>b8){b7=k.a
b8=c2
b6=c1}}if(b7==null){B.a.k(d5.d.f,"mainline_cannot_meet_pressure")
break}l.i(0,b7,b6.a)
h.T(0,b7)
a8=e1.$0()}if(!a7&&n.ay){c3=A.fq(n.y,n.z)
for(h=n.at,e=n.Q,n=n.as,d=d9>0,c=A.i(q),a1=c.j("Q<1>"),c=c.c,a9=0;a9<300;++a9){for(a2=new A.ag(e0,e0.r,e0.e,r),b6=d6,b7=b6,c4=0;a2.l();){k=a2.d
a3=k.b
b9=J.a1(a3)
c5=o.a(b9.gu(a3))
c0=l.h(0,c5.f)
c5=m.N(c0==null?c5.x:c0)
c5.toString
c1=d5.aP(c5,m.ab(o.a(b9.gu(a3)).Q))
if(c1==null)continue
for(c6=a8.length,c7=0,g=0;g<a8.length;a8.length===c6||(0,A.k)(a8),++g){b2=a8[g]
c8=b2.e
if(c8.length===0)continue
c8=d5.ak(B.a.L(c8,new A.i_()).a)
c8.toString
b4=A.K(o)
for(c9=new A.Q(q,q.r,a1),c9.c=q.e;c9.l();){d0=c9.d
if(d0==null)d0=c.a(d0)
b5=d5.aQ(d0,c8,d5.c.x)
d0=b5.length
if(d0!==0){d1=b4.a
d0=d1===0||d0<d1}else d0=!1
if(d0)b4=A.cG(b5,A.r(b5).c)}if(!b9.Z(a3,b4.gaF(b4)))continue
c8=A.n(p,d8)
for(c9=b2.f,d0=c9.length,b=0;b<c9.length;c9.length===d0||(0,A.k)(c9),++b){b5=c9[b]
c8.i(0,b5.a,b5.at)}d2=d5.aM(a3,c1,c8,b4)
d3=d?b2.y/d9:1
c7+=9788.99803*b2.x*d2/Math.max(n,0.05)/1000*(h*d3)*e}d4=c7-(c1.Q-c5.Q)*d5.aw(a3)*c3
if(d4>c4){b7=k.a
c4=d4
b6=c1}}if(b7==null)break
l.i(0,b7,b6.a)
a8=e1.$0()}}for(d8=A.as(q,q.r,A.i(q).c),r=d8.$ti.c;d8.l();){p=d8.d
if(p==null)p=r.a(p)
d5.c3(p,d5.c.x,e0)}d5.bp(e0)
d8=d5.d.e
B.a.V(d8)
B.a.B(d8,e1.$0())},
c7(a,b){return new A.c0(this.dc(a,b),t.iG)},
dc(a,b){var s=this
return function(){var r=a,q=b
var p=0,o=1,n=[],m,l,k,j,i,h,g,f,e
return function $async$c7(c,d,a0){if(d===1){n.push(a0)
p=o}for(;;)switch(p){case 0:e=s.d
e.y.B(0,s.c.z)
B.a.B(e.f,s.c.y)
e.b=q||r?s.a.b.dy.b:"analysis"
e=s.c.c,e=new A.an(e,e.r,e.e,A.i(e).j("an<1>")),m=0
case 2:if(!e.l()){p=3
break}l=e.d;++m
p=4
return c.b=new A.aT([new A.hD(s,q,l),B.aU,l,m]),1
case 4:p=2
break
case 3:e=B.a.gt(s.a.e),l=new A.bI(e,t.bo),k=t.m9
case 5:if(!l.l()){p=6
break}j=k.a(e.gp())
i=s.c
h=j.a
if(!i.e.E(h)){p=5
break}++m
p=7
return c.b=new A.aT([new A.hE(s,j),B.aU,h,m]),1
case 7:p=5
break
case 6:g=new A.hB(s)
p=8
return c.b=new A.aT([new A.hF(s,r,g),B.d_,null,0]),1
case 8:p=s.f.a!==0?9:10
break
case 9:f={}
f.a=0
p=11
return c.b=new A.aT([new A.hG(f,s),B.U,null,0]),1
case 11:p=f.a>0?12:13
break
case 12:e=s.c.c,e=new A.an(e,e.r,e.e,A.i(e).j("an<1>")),m=0
case 14:if(!e.l()){p=15
break}l=e.d;++m
p=16
return c.b=new A.aT([new A.hH(s,l),B.U,l,m]),1
case 16:p=14
break
case 15:p=17
return c.b=new A.aT([g,B.U,null,0]),1
case 17:case 13:case 10:p=18
return c.b=new A.aT([new A.hI(s),B.d0,null,0]),1
case 18:p=19
return c.b=new A.aT([s.gdl(),B.d1,null,0]),1
case 19:p=20
return c.b=new A.aT([s.gdi(),B.aV,null,0]),1
case 20:return 0
case 1:return c.c=n.at(-1),3}}}},
d3(a){var s,r,q,p,o,n,m,l=this,k=l.aA(a)
if(k.ge1())return k
s=l.c.r.h(0,a)
r=l.bo(s==null?A.K(t.N):s)
if(r.a===0)return k
q=A.d([],t.s)
for(s=new A.L(r,A.i(r).j("L<1,2>")).gt(0),p=l.a.c,o=l.e;s.l();){n=s.d
m=p.N(J.bN(n.b).x)
if(m!=null)o.i(0,n.a,m.a)}l.c6(a,r,q,l.af(a,!1))
l.bp(r)
k=l.aA(a)
s=A.dm(q,t.N)
s.B(0,k.ch)
s=A.q(s,A.i(s).c)
return k.cj(s)},
aZ(a,b,c,d){return this.ds(t.dn.a(a),b,c,t.ga.a(d))},
ds(a,b,c,d){var s=0,r=A.mC(t.nJ),q,p=this,o,n,m,l,k,j,i,h,g
var $async$aZ=A.mH(function(e,f){if(e===1)return A.mt(f,r)
for(;;)switch(s){case 0:h=p.c.c.a
g=h+4
o=p.c7(b,c),n=o.$ti,o=new A.cw(o.a(),n.j("cw<1>")),n=n.c,m=0,l=!1
case 3:if(!o.l()){s=4
break}k=o.b
j=(k==null?n.a(k):k).a
i=j[1]
if(i===B.U&&!l){g+=p.c.c.a+2
l=!0}a.$1(new A.c8(i,m,g,j[2],j[3],p.c.c.a))
s=5
return A.ms(d.$0(),$async$aZ)
case 5:j[0].$0();++m
s=3
break
case 4:a.$1(new A.c8(B.aV,g,g,null,0,h))
q=p.d
s=1
break
case 1:return A.mu(q,r)}})
return A.mv($async$aZ,r)},
dg(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=d9.d.w
B.a.V(e0)
b7=d9.a
b8=t.hP
b9=A.q(new A.cr(b7.e,b8),b8.j("j.E"))
s=b9
if(J.au(s)===0||b7.b.go<=0)return e0
b8=t.N
c0=A.n(b8,t.i)
for(c1=s,c2=c1.length,c3=0;c3<c1.length;c1.length===c2||(0,A.k)(c1),++c3){c4=c1[c3]
c0.i(0,c4.a,c4.y)}r=c0
for(c0=s,c1=c0.length,c2=b7.c,c4=b7.b,c5=c4.go,c6=c5*3.141592653589793,c3=0;c3<c0.length;c0.length===c1||(0,A.k)(c0),++c3){c7=c0[c3]
c8=c2.ad(c7.e)
if(c8==null)continue
if(c7.y<=0){c9=c8.f/1000
c7.y=c6*c9*c9/4}}q=d9.c
try{c0=A.l0(b7).bq()
d9.c=c0
for(c0=c0.c,c0=new A.an(c0,c0.r,c0.e,A.i(c0).j("an<1>")),c4=c4.id,c1=t.s,c6=t.e;c0.l();){p=c0.d
o=c6.a(b7.a6(p))
if(o==null)continue
d0=d9.c.f.h(0,p)
n=d0==null?A.K(b8):d0
m=A.d([],c1)
l=0
k=A.K(b8)
for(c7=n,c9=A.i(c7),d1=new A.Q(c7,c7.r,c9.j("Q<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
j=c7==null?c9.a(c7):c7
for(c7=d9.c.a.h(0,j).f,d2=c7.length,c3=0;c3<c7.length;c7.length===d2||(0,A.k)(c7),++c3){i=c7[c3]
if(i.b===-2){J.bM(m,j)
J.bM(k,i.a)}}}l=k.a
if(J.au(m)===0)continue
h=null
g=null
c7=d9.c.c.h(0,p)
c7.toString
f=c7
h=f.a
g=f.b
e=new A.hN(d9,m)
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
if(typeof c7!=="number")return c7.ar()
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
if(typeof c9!=="number")return A.cA(c9)
a1=(c7+c9)/2
b=d9.R(p,a1,!0).H()
c7=e.$1(b)
if(typeof c7!=="number")return c7.e5()
if(c7>=c4)c=a1
else d=a1
c7=c
c9=d
if(typeof c7!=="number")return c7.U()
if(typeof c9!=="number")return A.cA(c9)
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
if(c7==null)c7=A.K(b8)
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
d3=d9.av(b0)
a8=Math.max(A.li(c7),Math.abs(d2)/(3.141592653589793*d3*d3/4))}}b2=c2.a2(o.e)
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
if(typeof d2!=="number")return A.cA(d2)
d3=b4
d4=d3.Q
d3=d4==null?d3.c-d3.e:d4
d4=b5
d5=d4.Q
d4=d5==null?d4.c-d4.e:d5
B.a.k(e0,new A.cc(p,c7,c9,a2,d1+d2+(d3-d4),l,e.$1(b),a8,c5,b.a))}}finally{for(b7=s,b8=b7.length,c3=0;c3<b7.length;b7.length===b8||(0,A.k)(b7),++c3){b6=b7[c3]
c0=J.fx(r,b6.a)
c0.toString
b6.y=c0}d9.c=q}return e0},
dm(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=this.d,b2=b1.x
B.a.V(b2)
s=this.a
r=s.b
if(!r.k1)return b2
q=A.n(t.N,t.ft)
p=new A.hU(q)
for(o=b1.c,n=A.i(o).j("N<2>"),m=new A.N(o,o.r,o.e,n);m.l();){l=m.d
for(k=l.at,j=k.length,l=l.b,i=0;i<k.length;k.length===j||(0,A.k)(k),++i)p.$2(k[i],l)}for(m=b1.e,l=m.length,i=0;i<m.length;m.length===l||(0,A.k)(m),++i){h=m[i]
for(k=h.f,j=k.length,g=h.b,f=0;f<k.length;k.length===j||(0,A.k)(k),++f)p.$2(k[f],g)}for(l=new A.L(q,q.$ti.j("L<1,2>")).gt(0),e=r.k2,r=t.f,k=s.c,b1=b1.f;l.l();){d=l.d
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
for(g=new A.N(o,o.r,o.e,n);g.l();)for(a8=g.d.at,a9=a8.length,i=0;i<a9;++i){b0=a8[i]
if(b0.b===j)a7=Math.max(a7,Math.max(b0.ax,b0.ay))}for(g=m.length,i=0;i<g;++i)for(a8=m[i].f,a9=a8.length,f=0;f<a9;++f){b0=a8[f]
if(b0.b===j)a7=Math.max(a7,Math.max(b0.ax,b0.ay))}g=a.b
a8=a.y
B.a.k(b2,new A.bD(j,c.b,g,a2,a3,a6,a7,a8,e,a5))
if(a8>0&&a7+a6>a8+0.000001)B.a.k(b1,"surge_rating_exceeded:"+j)}return b2},
dj(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=this,b7=null,b8="bom.pipes",b9="bom.outlets",c0="un",c1="bom.pivots",c2=t.N,c3=A.n(c2,t.q),c4=new A.hQ(c3)
for(s=b6.c.b,r=s.length,q=b6.a,p=q.c,o=b6.e,n=0;n<s.length;s.length===r||(0,A.k)(s),++n){m=s[n]
if(m.d!==B.d)continue
l=p.ad(m.y)
if(l!=null){c4.$8$code$supplier("bom.tapes",l.b,"m",m.w,l.cx,l.a,l.d,l.c)
continue}k=o.h(0,m.f)
j=p.N(k==null?m.x:k)
if(j!=null)c4.$8$code$supplier(b8,j.b,"m",m.w,j.Q,j.a,j.d,j.c)}for(s=q.e,r=s.length,o=b6.b,i=b6.d,h=i.d,n=0;n<s.length;s.length===r||(0,A.k)(s),++n){g=s[n]
if(b6.c.z.v(0,g.a))continue
A:{f=g instanceof A.aZ
e=f?g:b7
if(f){d=p.a0(e.f)
if(d!=null){f=d.b
c=d.aC(e.r)
c=c==null?b7:c.b
if(c==null)c=""
c4.$8$code$supplier(b9,f+" \u2014 "+c,c0,1,d.r,d.a,d.d,d.c)}break A}f=g instanceof A.ak
d=f?g:b7
if(f){j=p.a0(d.r)
if(j!=null){f=j.b
c=j.aC(d.w)
c=c==null?b7:c.b
if(c==null)c=""
c4.$8$code$supplier(b9,f+" \u2014 "+c,c0,d.gb3(),j.r,j.a,j.d,j.c)}break A}f=g instanceof A.b9
b=f?g:b7
if(f){d=p.a2(b.e)
if(d!=null)c4.$8$code$supplier("bom.valves",d.b,c0,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.aY
a=f?g:b7
if(f){d=p.a2(a.e)
if(d!=null)c4.$8$code$supplier("bom.devices",d.b,c0,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.bo
a0=f?g:b7
if(f){d=p.ap(a0.e)
if(d!=null)c4.$8$code$supplier("bom.pumps",d.b,c0,1,d.Q,d.a,d.d,d.c)
break A}f=g instanceof A.b1
a0=f?g:b7
if(f){a1=h.h(0,a0.a)
f=a1==null
a2=f?b7:a1.as
if(a2==null)a2=a0.dZ().length
a3=a0.c
c=(a3.length!==0?a3:o.$1("tool.pivot"))+" \u2014 "
a4=A.z(a0.z===B.E?o.$1("pivot.kindPivot"):o.$1("pivot.kindLinear"))
a5=a0.x
c4.$6(c1,c+a4+" "+B.b.a1(a5)+" m, "+a2+" "+A.z(o.$1("pivot.towers")),c0,1,a0.id,b7)
c4.$6(c1,c+A.z(o.$1("pivot.towersItem"))+" ("+B.b.a1(a0.as)+" m)",c0,a2,a0.r,b7)
a6=p.N(a0.at)
if(a6!=null)c4.$8$code$supplier(b8,a6.b,"m",a5,a6.Q,a6.a,a6.d,a6.c)
a7=f?b7:a1.gcE()
if(a7==null){f=a0.d
a7=f>0?B.b.a1(a5/f):0}a8=p.a0(a0.e)
f=a7>0
if(f){a4=a8==null
a5=a4?b7:a8.b
a5=A.z(a5==null?o.$1("pivot.sprinklersItem"):a5)
a9=a4?b7:a8.r
if(a9==null)a9=0
b0=a4?b7:a8.a
b1=a4?b7:a8.d
if(b1==null)b1=""
a4=a4?b7:a8.c
if(a4==null)a4=""
c4.$8$code$supplier(c1,c+a5,c0,a7,a9,b0,b1,a4)}b2=p.a2(a0.f)
if(b2!=null&&f)c4.$8$code$supplier(c1,c+b2.b,c0,a7,b2.y,b2.a,b2.d,b2.c)
if(a0.cx>0)c4.$6(c1,c+A.z(o.$1("pivot.endGunItem")),c0,1,0,b7)
break A}break A}}s=i.r
B.a.V(s)
B.a.B(s,new A.ao(c3,c3.$ti.j("ao<2>")))
r=q.b
if(r.k3){b3=A.qc(q,b6.c,b6.gd9(),o)
B.a.B(s,b3.a)
b4=A.K(c2)
for(c2=b3.b,q=c2.length,p=i.f,n=0;n<c2.length;c2.length===q||(0,A.k)(c2),++n){a=c2[n]
b5=A.mQ(a.a,a.b,a.c,o)
if(b4.k(0,b5))B.a.k(p,"fitting_missing:"+b5)}}B.a.am(s,new A.hR())
c2=t.i
q=B.a.W(s,0,new A.hS(),c2)
i.z=q
i.Q=q*A.fq(r.y,r.z)
i.as=B.a.W(i.e,0,new A.hT(),c2)
return s}}
A.hs.prototype={
$2(a,b){return A.T(a)+t.cQ.a(b).gdQ()},
$S:69}
A.hz.prototype={
$1(a){return t.o.a(a).a},
$S:64}
A.hL.prototype={
$0(){return A.d([],t.I)},
$S:50}
A.hK.prototype={
$2(a,b){return A.T(a)+t.G.a(b).w},
$S:75}
A.hM.prototype={
$1(a){return A.fu(t.p.a(a).f/1000,this.b)<=this.a.az(this.c)+1e-9},
$S:6}
A.hm.prototype={
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
A.ht.prototype={
$0(){return A.d([],t.s)},
$S:38}
A.hy.prototype={
$1(a){var s=this.a.d.h(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:7}
A.hx.prototype={
$0(){return A.n(t.N,t.i)},
$S:29}
A.hA.prototype={
$1(a){return t.j5.a(a).b===this.a},
$S:31}
A.hn.prototype={
$1(a){t.G.a(a)
return a.f===this.a.a&&a.d===B.d},
$S:1}
A.ho.prototype={
$2(a,b){var s=t.G
return B.c.S(s.a(a).r,s.a(b).r)},
$S:33}
A.hp.prototype={
$1(a){return this.a.h(0,A.C(a))},
$S:34}
A.hq.prototype={
$1(a){return A.mq(a)==null},
$S:35}
A.hr.prototype={
$0(){return"e"+this.a.a.r++},
$S:36}
A.hJ.prototype={
$1(a){var s=this.a,r=t.v.a(a).a
if(s.c.d.E(r)){s=s.c
r=s.w.v(0,s.d.h(0,r))
s=r}else s=!1
return s},
$S:8}
A.hO.prototype={
$1(a){return t.v.a(a).e},
$S:8}
A.hP.prototype={
$1(a){var s,r,q,p,o,n,m,l
for(s=this.b,s=new A.an(s,s.r,s.e,A.i(s).j("an<1>")),r=this.c,q=a.c,p=this.a,o=-1/0;s.l();){n=s.d
m=p.ak(n)
l=q.h(0,m==null?"":m)
if(l==null)continue
n=r.h(0,n)
n.toString
o=Math.max(o,n-l.b)}return isFinite(o)?o:0},
$S:28}
A.hw.prototype={
$1(a){var s=this.a.d.h(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:7}
A.hu.prototype={
$4(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this,a2=a1.a,a3=a2.a.h(0,a4)
if(a3==null)return
s=a1.c.h(0,a3)
s.toString
r=A.n(t.N,t.U)
for(q=a1.b,a2=q.c0(a2.b,a4),p=a2.length,o=a1.r.d,n=a1.d,m=a1.f,l=a1.e,k=0,j=0;j<a2.length;a2.length===p||(0,A.k)(a2),++j){i=a2[j]
h=i.a
g=n.h(0,h)
if(g!=null){f=r.ac(g,new A.hv())
for(h=l.h(0,g),e=h.length,d=0;d<h.length;h.length===e||(0,A.k)(h),++d){c=h[d]
b=c.a
a=f.h(0,b)
if(a==null)a=0
f.i(0,b,a+q.bW(i,c,m.$1(i)))}}else if(i.d===B.d)k+=q.bQ(i,m.$1(i))
else{h=o.h(0,h)
h=h==null?null:h.c
k+=h==null?0:h}}a0=q.c.a.h(0,a4).gaB()+a7-q.c.a.h(0,a3).gaB()
a2=a1.x.h(0,s.a+"|"+a1.y)
a2.toString
s=a6!=null?a6+a0:null
B.a.k(a1.w,new A.dp(a2,r,k,a5+a0,s))},
$S:39}
A.hv.prototype={
$0(){return A.n(t.N,t.i)},
$S:29}
A.hW.prototype={
$2(a,b){return A.T(a)+t.k.a(b).e},
$S:27}
A.hV.prototype={
$0(){var s,r,q,p,o,n=A.d([],t.lT)
for(s=this.b,r=s.length,q=this.a,p=this.c,o=0;o<s.length;s.length===r||(0,A.k)(s),++o)n.push(q.cg(s[o],p))
return n},
$S:41}
A.hX.prototype={
$1(a){var s
t.v.a(a)
s=this.a.c.d.h(0,a.a)
s.toString
return s},
$S:42}
A.hY.prototype={
$1(a){var s
A.C(a)
s=this.a.c.ah(a)
return(s==null?null:s.d)===B.d},
$S:43}
A.hZ.prototype={
$1(a){return!t.v.a(a).e},
$S:8}
A.i_.prototype={
$2(a,b){var s=t.nN
s.a(a)
s.a(b)
return a.e-a.d>=b.e-b.d?a:b},
$S:44}
A.hD.prototype={
$0(){var s=this.a,r=this.c,q=this.b?s.cD(r):s.aA(r)
s.d.c.i(0,r,q)
return q},
$S:0}
A.hE.prototype={
$0(){var s=this.a,r=this.b,q=s.cf(r)
s.d.d.i(0,r.a,q)
return q},
$S:0}
A.hB.prototype={
$0(){var s,r,q,p=this.a,o=p.cl(),n=B.a.W(o,0,new A.hC(),t.i),m=p.d.e
B.a.V(m)
s=A.d([],t.lT)
for(r=o.length,q=0;q<o.length;o.length===r||(0,A.k)(o),++q)s.push(p.cg(o[q],n))
B.a.B(m,s)},
$S:0}
A.hC.prototype={
$2(a,b){return A.T(a)+t.k.a(b).e},
$S:27}
A.hF.prototype={
$0(){if(this.b)this.a.cC()
else this.c.$0()},
$S:0}
A.hG.prototype={
$0(){var s,r,q=this.b,p=q.cM()
this.a.a=p
if(p>0){s=q.d
r=s.y
if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.bj()}r.B(0,q.c.z)
s.c.V(0)}},
$S:0}
A.hH.prototype={
$0(){var s=this.a,r=this.b,q=s.d3(r)
s.d.c.i(0,r,q)
return q},
$S:0}
A.hI.prototype={
$0(){this.a.dg()},
$S:0}
A.hN.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h=1/0
for(q=this.b,p=q.length,o=this.a,n=a.c,m=0;m<q.length;q.length===p||(0,A.k)(q),++m){s=q[m]
r=n.h(0,s)
if(r==null)continue
l=h
k=r.a
j=o.c.a.h(0,s)
i=j.Q
j=i==null?j.c-j.e:i
h=Math.min(A.li(l),k-j)}return isFinite(h)?h:0},
$S:28}
A.hU.prototype={
$2(a,b){var s=this.a,r=a.b,q=s.h(0,r)
if(q==null||a.as>q.a.as)s.i(0,r,new A.m(a,b))},
$S:45}
A.hQ.prototype={
$8$code$supplier(a,b,c,d,e,f,g,h){var s=a+"|"+b,r=this.a,q=r.h(0,s)
if(q!=null)q.d+=d
else r.i(0,s,new A.al(a,b,c,d,e,f,g,h))},
$6(a,b,c,d,e,f){return this.$8$code$supplier(a,b,c,d,e,f,"","")},
$S:46}
A.hR.prototype={
$2(a,b){var s,r=t.q
r.a(a)
r.a(b)
r=a.a
s=b.a
return r===s?B.k.S(a.b,b.b):B.k.S(r,s)},
$S:47}
A.hS.prototype={
$2(a,b){A.T(a)
t.q.a(b)
return a+b.d*b.e},
$S:48}
A.hT.prototype={
$2(a,b){return A.T(a)+t.ju.a(b).z},
$S:49}
A.dc.prototype={
gco(){return this.a.b+"|"+B.b.ae(this.b,1)+"|"+B.b.ae(this.c,1)}}
A.i5.prototype={}
A.kf.prototype={
$1(a){return a===B.b.by(a)?""+B.b.a1(a):B.b.ae(a,1)},
$S:14}
A.kI.prototype={
$4$qty$size2(a,b,c,d){var s=new A.dc(a,b,d),r=this.a,q=r.h(0,s.gco()),p=s.gco(),o=q==null?null:q.b
r.i(0,p,new A.m(s,(o==null?0:o)+c))},
$2(a,b){return this.$4$qty$size2(a,b,1,0)},
$3$qty(a,b,c){return this.$4$qty$size2(a,b,c,0)},
$3$size2(a,b,c){return this.$4$qty$size2(a,b,1,c)},
$S:51}
A.kK.prototype={
$1(a){var s,r
t.G.a(a)
s=this.a.ad(a.y)
if(s!=null)return s.e
r=this.b.$1(a)
r=r==null?null:r.e
return r==null?0:r},
$S:7}
A.kH.prototype={
$2(a,b){var s=a.cx,r=a.cy
return a.b===b?r.U(0,s).gcp():s.U(0,r).gcp()},
$S:52}
A.kz.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.d){s=this.a.$1(a)
if(typeof s!=="number")return s.cB()
s=s>0}else s=!1
return s},
$S:1}
A.kA.prototype={
$1(a){return!this.a.v(0,t.G.a(a).f)},
$S:1}
A.kB.prototype={
$1(a){return this.a.v(0,t.G.a(a).f)},
$S:1}
A.kC.prototype={
$1(a){return t.G.a(a).d!==B.d},
$S:1}
A.kJ.prototype={
$2(a,b){return this.a.h(0,B.b.ae(a.a,3)+"|"+B.b.ae(a.b,3)+"|"+b.b)},
$S:53}
A.kF.prototype={
$2(a,b){return a!=null&&B.a.Z(a.w,new A.kG(b,this.a))},
$S:54}
A.kG.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.d){s=a.f
s=s!==this.a&&!this.b.v(0,s)}else s=!1
return s},
$S:1}
A.kD.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.kE.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.ky.prototype={
$1(a){var s
A:{if(B.w===a||B.L===a){s="bom.takeoffs"
break A}if(B.m===a){s="bom.risers"
break A}s="bom.fittings"
break A}return s},
$S:55}
A.ck.prototype={
G(){return"LpSense."+this.b}}
A.cj.prototype={}
A.ij.prototype={}
A.cH.prototype={}
A.by.prototype={
G(){return"LpStatus."+this.b}}
A.kL.prototype={
$2(a,b){var s,r
A.a0(a)
A.T(b)
if(a>=0&&a<this.a){s=this.b
if(!(a>=0&&a<s.length))return A.b(s,a)
r=s[a]
s.$flags&2&&A.aa(s)
s[a]=r+b*this.c}},
$S:56}
A.kN.prototype={
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
A.kM.prototype={
$2(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a,d=e.length
if(!(a>=0&&a<d))return A.b(e,a)
s=e[a]
r=s.length
if(!(b>=0&&b<r))return A.b(s,b)
q=s[b]
for(p=f.b,o=s.$flags|0,n=0;n<p;++n){if(!(n<r))return A.b(s,n)
m=s[n]
o&2&&A.aa(s)
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
i&2&&A.aa(m)
m[n]=h-j*g}}B.a.i(f.d,a,b)},
$S:9}
A.kO.prototype={
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
a1=a3}}if(a1<0)return B.dK
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
e=!1}}return B.bn},
$S:59}
A.dq.prototype={}
A.dp.prototype={}
A.ex.prototype={}
A.dn.prototype={}
A.kp.prototype={
$2(a,b){var s
A.C(a)
t.U.a(b)
s=this.a.h(0,a)
if(s==null)return
b.X(0,new A.ko(s,this.b))},
$S:60}
A.ko.prototype={
$2(a,b){var s,r,q
A.C(a)
A.T(b)
s=this.a.h(0,a)
if(s!=null){r=this.b
q=r.h(0,s)
r.i(0,s,(q==null?0:q)-b)}},
$S:61}
A.kq.prototype={
$2(a,b){var s=t.ca
s.a(a)
return B.b.S(s.a(b).a.f,a.a.f)},
$S:62}
A.k3.prototype={
$2(a,b){return A.T(a)+t.ca.a(b).b},
$S:63}
A.bS.prototype={
G(){return"GLinkKind."+this.b}}
A.ba.prototype={
gdQ(){return this.c.a7(this.e)*this.d}}
A.aX.prototype={
gaB(){var s=this.Q
return s==null?this.c-this.e:s}}
A.H.prototype={
gm(a){return this.w}}
A.iA.prototype={
ah(a){var s,r,q,p
for(s=this.b,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null}}
A.im.prototype={
gb4(){var s=this.c
return s===$?this.c=this.a.b.x:s},
gct(){var s,r=this,q=r.d
if(q===$){s=r.a.dk()
r.d!==$&&A.qi()
r.d=s
q=s}return q},
bU(a){var s=this.gb4()*4
return(B.b.J(a.a/s)*73856093^B.b.J(a.b/s)*19349663)>>>0},
aE(a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=a0.a,e=g.gb4(),d=e*4,c=B.b.J(f/d),b=a0.b,a=B.b.J(b/d)
for(d=g.f,s=null,r=1/0,q=-1;q<=1;++q)for(p=(c+q)*73856093,o=-1;o<=1;++o){n=d.h(0,(p^(a+o)*19349663)>>>0)
if(n==null)continue
for(m=J.ab(n);m.l();){l=m.gp()
if(l.d!==a1)continue
k=l.b
j=k.a-f
k=k.b-b
i=Math.sqrt(j*j+k*k)
if(i<=e&&i<r){r=i
s=l}}}f=s==null
if(!f||!a2)return f?$.n9():s
f=g.r++
h=A.kV(g.gct().b_(a0),"n"+f,a0,a1)
g.e.a.i(0,h.a,h)
J.bM(d.ac(g.bU(a0),new A.ip()),h)
return h},
an(a,b){return this.aE(a,b,!0)},
bq(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8="outlet_spec_missing:",f9=f6.e
f9.Q=f6.gct()
s=f6.a
r=s.c
s=s.e
q=A.r(s)
p=q.j("B<1>")
o=A.q(new A.B(s,q.j("v(1)").a(new A.iq()),p),p.j("j.E"))
q=t.C
n=A.d([],q)
p=t.N
m=A.n(p,t.V)
for(l=o.length,k=0;k<o.length;o.length===l||(0,A.k)(o),++k)m.i(0,o[k].a,A.d([],q))
j=new A.iw()
i=new A.iy()
h=new A.ix(f6,o,i,j,m)
for(l=s.length,g=t.dr,k=0;k<s.length;s.length===l||(0,A.k)(s),++k){f=s[k]
e=f instanceof A.aZ
d=e?f:f7
if(e){h.$2(d.d,A.d([d.e],g))
continue}e=f instanceof A.ch
c=e?f:f7
if(e){h.$2(c.d,A.d([c.e],g))
continue}e=f instanceof A.b9
b=e?f:f7
if(e){h.$2(b.d,B.D)
continue}e=f instanceof A.bo
a=e?f:f7
if(e){h.$2(a.d,A.d([a.w],g))
continue}e=f instanceof A.aY
a0=e?f:f7
if(e){h.$2(a0.d,A.d([a0.f],g))
continue}e=f instanceof A.aC
a1=e?f:f7
if(e){h.$2(a1.d,A.d([B.h],g))
continue}e=f instanceof A.b1
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
if(J.au(a8)<2){a6.k(0,f.a)
continue}a9=f.a
b0=m.h(0,a9)
b0.toString
a2=A.ew(a8,!0,l)
if(b0.length!==0){b1=A.d([],g)
for(b2=b0.length,b3=0;b3<b0.length;b0.length===b2||(0,A.k)(b0),++b3){a1=b0[b3]
for(b4=a1.a,b5=a1.b,b6=0,b7=1/0,b8=0,b9=1;b9<a2.length;++b9){c0=b9-1
c1=A.lj(a1,a2[c0],a2[b9])
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
b6+=Math.sqrt(c4*c4+c3*c3)}B.a.k(b1,b8)}c7=A.n4(a2,b1)
a2=A.d([J.bN(B.a.gu(c7))],q)
for(b0=c7.length,b3=0;b3<c7.length;c7.length===b0||(0,A.k)(c7),++b3)B.a.B(a2,J.lw(c7[b3],1))}B.a.B(n,a2)
A:{b0=f instanceof A.aH
a=b0?f:f7
if(b0){c8=r.N(a.f)
c9=a7===B.f?B.i:B.j
b0=c8==null
b2=b0?f7:c8.a
b0=a.r||b0
f6.cL(a9,a2,a7,b0,a.w,b2,c9)
break A}b0=f instanceof A.ak
a1=b0?f:f7
if(b0){d0=r.a0(a1.r)
b0=d0==null
d1=b0?f7:d0.aC(a1.w)
if(b0||d1==null){B.a.k(a5,f8+a9)
a6.k(0,a9)
continue}c8=r.N(a1.e)
d2=A.aV(a2)
d3=a1.gb3()
d4=a1.z
d4=d4>0?d4:a1.y
b0=a1.x
d5=f6.ce(d1,b0)
d6=d5.a
d7=d5.b
b2=A.d([],g)
for(b4=a1.y,b9=0;b9<d3;++b9)b2.push(d4+b9*b4)
d8=f6.bY(b2,d2)
d9=A.n(a3,a4)
for(b2=d8.length,b4=d1.c,b5=d1.w,c0=a1.as,c3=d0.x,c4=a1.at,c3=c0+c3+c4,c0=d1.b,b3=0;b3<d8.length;d8.length===b2||(0,A.k)(d8),++b3){c6=d8[b3]
d9.i(0,c6.a,new A.ba(a9,c6.c,b4,c6.b,b0,d6,d7,b5,c3,c0))}b0=c8==null
b2=b0?f7:c8.a
f6.cK(a9,a2,a7,d9,a1.f||b0,c4,0,b2,B.p)
break A}b0=f instanceof A.aB
e0=b0?f:f7
if(b0){c8=r.ad(e0.e)
if(c8==null){B.a.k(a5,"tape_spec_missing:"+a9)
a6.k(0,a9)
continue}d2=A.aV(a2)
b0=c8.r
d3=B.b.J(d2/b0)
b2=A.d([],g)
for(b9=1;b9<=d3;++b9)b2.push(b9*b0)
d8=f6.bY(b2,d2)
b0=c8.z
b2=e0.f
d6=Math.max(b0,b2*(1-c8.at/100))
d7=Math.min(c8.Q,b2*(1+c8.ax/100))
d9=A.n(a3,a4)
for(b0=d8.length,b4=c8.w,b5=c8.y,c0=e0.x,c3=c8.b,b3=0;b3<d8.length;d8.length===b0||(0,A.k)(d8),++b3){c4=d8[b3]
d9.i(0,c4.a,new A.ba(a9,c4.c,b4,c4.b,b2,d6,d7,b5,c0,c3))}b0=c8.a
b2=c8.x
f6.bJ(a9,a2,a7,d9,!1,c0,e0.y,b2,f7,b0,B.p)
break A}break A}}for(q=[0,1],m=f9.c,l=f9.d,g=f9.e,k=0;k<2;++k){e1=q[k]
for(e=s.length,a3=e1===0,b3=0;b3<s.length;s.length===e||(0,A.k)(s),++b3){f=s[b3]
a4=f instanceof A.bo
if(a3===(a4||f instanceof A.aY))continue
B:{a9=f instanceof A.aZ
d=a9?f:f7
if(a9){d0=r.a0(d.f)
a4=d0==null
d1=a4?f7:d0.aC(d.r)
if(a4||d1==null){B.a.k(a5,f8+f.a)
continue}d3=f6.aE(d.d,d.e,!1)
if(d3.a.length===0){a6.k(0,f.a)
continue}a4=d.w
e2=f6.ce(d1,a4)
a9=f.a
d3.r.k(0,a9)
B.a.k(d3.f,new A.ba(a9,-1,d1.c,1,a4,e2.a,e2.b,d1.w,d.z+d0.x,d1.b))
break B}a9=f instanceof A.ch
c=a9?f:f7
if(a9){d3=f6.an(c.d,c.e)
d3.r.k(0,f.a)
a4=c.f
if(a4!=null)d3.Q=a4
break B}a9=f instanceof A.b1
a=a9?f:f7
if(a9){d3=f6.aE(a.w,B.h,!1)
a4=d3.a
if(a4.length===0){a6.k(0,f.a)
continue}a9=f.a
d3.r.k(0,a9)
g.i(0,a9,a4)
break B}a9=f instanceof A.aC
a1=a9?f:f7
if(a9){d3=f6.an(a1.d,B.h)
a4=f.a
d3.r.k(0,a4)
d3.y=!0
d3.z=a4
l.i(0,a4,d3.a)
if(d3.w.length===0)a6.k(0,a4)
break B}a9=f instanceof A.b9
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
f6.aR(new A.H("cv_"+a9,b0,b2,B.W,B.h,a9,0,0,f7,f7,!1,B.i,0,b.x,0,b4,f7,1,a4,a4,0))
m.i(0,a9,new A.m(b0,b2))
if(e4.w.length<=1)B.a.k(a5,"valve_no_zone_pipes:"+a9)
break B}a9={}
a9.a=null
if(a4){a9.a=f
b0=f}else b0=f7
if(a4){c8=r.ap(b0.e)
if(c8==null){B.a.k(a5,"pump_spec_missing:"+f.a)
continue}f6.bT(f.a,b0.d,b0.w,new A.ir(a9,f,c8))
break B}a4={}
a4.a=null
a9=f instanceof A.aY
if(a9){a4.a=f
b0=f}else b0=f7
if(a9){c8=r.a2(b0.e)
if(c8==null){B.a.k(a5,"valve_spec_missing:"+f.a)
continue}a9=c8.e
f6.bT(f.a,b0.d,b0.f,new A.is(a4,f,a9===B.R,c8))
break B}break B}}}for(q=f9.a,e=new A.N(q,q.r,q.e,A.i(q).j("N<2>"));e.l();){a3=e.d
for(a4=a3.w,a9=a4.length,c5=0,k=0;k<a9;++k)c5=Math.max(c5,a4[k].at)
a3.e=c5}for(e=new A.L(m,A.i(m).j("L<1,2>")).gt(0),a3=f9.f,a4=f9.r,a9=t.s;e.l();){e5=e.d
e6=e5.a
e7=e5.b.b
e8=A.K(p)
e9=A.K(p)
f0=A.d([e7],a9)
e8.k(0,e7)
while(b0=f0.length,b0!==0){if(0>=b0)return A.b(f0,-1)
f1=f0.pop()
d3=q.h(0,f1)
b0=d3.x
if(b0!=null&&b0!==e6){f2=A.d([e6,b0],a9)
B.a.a4(f2)
f3="zone_overlap:"+f2[0]+":"+f2[1]
if(!B.a.v(a5,f3))B.a.k(a5,f3)}d3.x=e6
for(b0=d3.w,b2=b0.length,k=0;k<b0.length;b0.length===b2||(0,A.k)(b0),++k){f4=b0[k]
if(f4.d===B.W)continue
if(f4.e!==B.f)continue
e9.k(0,f4.a)
f4.dx=e6
d=f4.b
if(f1===d)d=f4.c
if(e8.k(0,d))B.a.k(f0,d)}}a3.i(0,e6,e8)
a4.i(0,e6,e9)}p=A.q(new A.ao(l,A.i(l).j("ao<2>")),p)
l=f9.w
l.B(0,p)
for(e=f9.x;a3=p.length,a3!==0;){if(0>=a3)return A.b(p,-1)
f1=p.pop()
for(a3=q.h(0,f1).w,a4=a3.length,k=0;k<a3.length;a3.length===a4||(0,A.k)(a3),++k){f4=a3[k]
if(f4.e!==B.h||f4.d===B.W)continue
e.k(0,f4.a)
d=f4.b
if(f1===d)d=f4.c
if(l.k(0,d))B.a.k(p,d)}}f6.cY()
for(q=s.length,k=0;k<s.length;s.length===q||(0,A.k)(s),++k){f=s[k]
if(!A.nM(f))continue
p=f.a
if(a6.v(0,p))continue
C:{if(f instanceof A.b9){f5=m.h(0,p)
if(!l.v(0,(f5==null?B.et:f5).a))a6.k(0,p)
break C}e=f instanceof A.aH
if(e)a3=f.e===B.h
else a3=!1
if(a3){if(!f6.bw(p).Z(0,new A.it(f6)))a6.k(0,p)
break C}if(e||f instanceof A.ak||f instanceof A.aB){if(!f6.bw(p).Z(0,new A.iu()))a6.k(0,p)
break C}e=f instanceof A.aZ
d=e?f:f7
if(e){e=d.d
a3=d.e
d3=f6.aE(e,a3,!1)
e=d3.a
if(e.length===0)a6.k(0,p)
else if(a3===B.f?d3.x==null:!l.v(0,e))a6.k(0,p)
break C}if(f instanceof A.bo||f instanceof A.aY){if(!f6.bw(p).Z(0,new A.iv(f6)))a6.k(0,p)
break C}if(f instanceof A.b1){d3=g.h(0,p)
if(d3==null||!l.v(0,d3))a6.k(0,p)
break C}break C}}return f9},
bw(a){var s=this.e.b,r=A.r(s)
return new A.B(s,r.j("v(1)").a(new A.iz(a)),r.j("B<1>"))},
ce(a,b){var s=a.c.dF(b,a.y,a.x)
return new A.m(Math.max(s.a,a.e),Math.min(s.b,a.f))},
bY(a,b){var s,r,q,p,o,n,m,l,k,j
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
aR(a){var s=this.e
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
this.aR(new A.H(s+q,n,m,B.d,c,a,q,i,f,null,d,g,0,e,0,null,null,1,j,b[r],0))}},
bJ(a,b,a0,a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.V.a(b)
t.nh.a(a1)
s=A.ah([0,A.aV(b)],t.i)
for(r=0,q=1;q<b.length;++q){p=b[q-1]
o=b[q]
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)
s.k(0,r)}s.B(0,new A.a4(a1,A.i(a1).j("a4<1>")))
m=A.q(s,s.$ti.c)
B.a.a4(m)
for(p=m.length,o=a+"_",l=null,k=0,j=0,i=0,h=0;h<m.length;m.length===p||(0,A.k)(m),++h,k=g,l=e){g=m[h]
f=A.ku(b,g)
n=l!=null
e=n&&g-k<this.gb4()?l:this.an(f,a0)
e.r.k(0,a)
d=a1.h(0,g)
if(d!=null){B.a.k(e.f,d)
i+=d.d}if(n&&l.a!==e.a){c=j+1
this.aR(new A.H(o+j,l.a,e.a,B.d,a0,a,c-1,g-k,a6,a7,a2,a8,a5*i,a3,0,null,null,1,A.ku(b,k),f,i))
j=c
i=0}}if(a4>0&&l!=null)B.a.k(l.f,new A.ba(a,-2,new A.bR(a4,0,0,0),1,1,0,1/0,0,0,"flush"))},
cK(a,b,c,d,e,f,g,h,i){return this.bJ(a,b,c,d,e,f,0,g,h,null,i)},
cY(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=t.N,a=A.n(b,t.i)
for(s=this.a,r=s.e,q=r.length,p=this.e,o=p.a,n=p.d,m=0;m<r.length;r.length===q||(0,A.k)(r),++m){l=r[m]
if(!(l instanceof A.aC))continue
k=n.h(0,l.a)
j=o.h(0,k==null?"":k)
if(j==null)continue
i=j.c+l.y
j.Q=i
a.i(0,j.a,i)}r=A.d([],t.I)
for(q=p.b,n=q.length,p=p.x,s=s.c,m=0;m<q.length;q.length===n||(0,A.k)(q),++m){h=q[m]
k=!1
if(h.d===B.X)if(p.v(0,h.a)){k=s.ap(h.ch)
k=k==null?null:k.f
k=k===!0}if(k)r.push(h)}if(r.length===0||a.a===0)return
s=A.n(b,b)
for(q=a.$ti,n=new A.an(a,a.r,a.e,q.j("an<1>"));n.l();){k=n.d
s.i(0,k,k)}b=A.q(new A.a4(a,q.j("a4<1>")),b)
for(g=0;g<b.length;++g){f=b[g]
for(q=o.h(0,f).w,n=q.length,m=0;m<q.length;q.length===n||(0,A.k)(q),++m){h=q[m]
if(!p.v(0,h.a))continue
e=h.b
if(f===e)e=h.c
if(s.E(e))continue
k=s.h(0,f)
k.toString
s.i(0,e,k)
B.a.k(b,e)}}for(b=r.length,m=0;m<r.length;r.length===b||(0,A.k)(r),++m){h=r[m]
q=h.b
d=s.h(0,q)
if(d==null)continue
for(q=[q,h.c],c=0;c<2;++c){j=o.h(0,q[c])
if(!j.y)j.Q=a.h(0,d)}}},
bT(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this
t.fC.a(a7)
s=a3.aE(a5,a6,!1)
r=s.a
if(r.length===0){a3.e.z.k(0,a4)
return}s.r.k(0,a4)
q=s.w
p=A.ew(q,!0,t.G)
o=p.length
n=null
if(o>=2){m=a3.cV(a6)
for(l=1/0,k=0;k<p.length;p.length===o||(0,A.k)(p),++k){j=p[k]
i=j.b
h=m.h(0,r===i?j.c:i)
if(h==null)h=1/0
if(h<l){l=h
n=j}}}else if(o===1)n=s.y?null:B.a.gu(p)
g=A.kV(s.c,"n"+a3.r++,a5,a6)
o=a3.e
i=o.a
f=g.a
i.i(0,f,g)
J.bM(a3.f.ac(a3.bU(a5),new A.io()),g)
g.r.k(0,a4)
for(e=p.length,d=g.w,o=o.b,k=0;k<p.length;p.length===e||(0,A.k)(p),++k){j=p[k]
if(j===n)continue
c=B.a.cn(o,j)
b=j.b
a=b===r?f:b
a0=j.c
a1=a0===r?f:a0
a2=new A.H(j.a,a,a1,j.d,j.e,j.f,j.r,j.w,j.x,j.y,j.z,j.Q,j.as,j.at,j.ax,j.ay,j.ch,j.CW,j.cx,j.cy,j.db)
B.a.i(o,c,a2)
B.a.T(q,j)
b=i.h(0,r===b?a0:b).w
B.a.T(b,j)
B.a.k(b,a2)
B.a.k(d,a2)}a3.aR(a7.$2(r,f))},
cV(a){var s,r,q,p,o,n,m,l,k,j,i=A.n(t.N,t.i),h=A.d([],t.s)
if(a===B.h){for(s=this.e,r=s.d,r=new A.N(r,r.r,r.e,A.i(r).j("N<2>"));r.l();){q=r.d
i.i(0,q,0)
B.a.k(h,q)}for(s=s.a,s=new A.N(s,s.r,s.e,A.i(s).j("N<2>"));s.l();){r=s.d
if(r.y&&!i.E(r.a)){r=r.a
i.i(0,r,0)
B.a.k(h,r)}}}else for(s=this.e.c,s=new A.N(s,s.r,s.e,A.i(s).j("N<2>"));s.l();){r=s.d.b
i.i(0,r,0)
B.a.k(h,r)}for(s=this.e.a,p=0;p<h.length;p=o){o=p+1
n=h[p]
for(r=s.h(0,n).w,q=r.length,m=0;m<r.length;r.length===q||(0,A.k)(r),++m){l=r[m]
if(l.d===B.W)continue
k=l.b
if(n===k)k=l.c
if(!i.E(k)){j=i.h(0,n)
j.toString
i.i(0,k,j+1)
B.a.k(h,k)}}}return i}}
A.ip.prototype={
$0(){return A.d([],t.go)},
$S:23}
A.iq.prototype={
$1(a){t.h.a(a)
return a instanceof A.aH||a instanceof A.ak||a instanceof A.aB},
$S:65}
A.iw.prototype={
$1(a){return t.f.a(a).gP()},
$S:66}
A.iy.prototype={
$1(a){var s=A.nL(a)
return s==null?B.f:s},
$S:67}
A.ix.prototype={
$3$exclude(a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this
t.lv.a(a3)
for(s=a1.b,r=s.length,q=a2.a,p=a2.b,o=a1.a,n=a1.e,m=a1.d,l=a1.c,k=0;k<s.length;s.length===r||(0,A.k)(s),++k){j=s[k]
i=j.a
if(i===a4)continue
if(!B.a.v(a3,l.$1(j)))continue
h=m.$1(j)
for(g=J.af(h),f=1;f<g.gm(h);++f){e=f-1
d=A.lj(a2,g.h(h,e),g.h(h,f))
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
A.ir.prototype={
$2(a,b){var s=this.b.a,r=this.a.a,q=r.d
return A.lK(q,q,!1,0,0,s,a,"pump_"+s,B.X,0,0,null,this.c.a,r.w,0,0,r.f,null,b,B.i,null)},
$S:22}
A.is.prototype={
$2(a,b){var s,r=this,q=r.b.a,p=r.c,o=p?B.d9:B.d8,n=r.a.a,m=r.d
if(p){p=n.r
p=p>0?p:m.z}else p=0
s=n.d
return A.lK(s,s,!1,0,0,q,a,"dev_"+q,o,0,0,null,null,n.f,0,p,1,null,b,B.i,m.a)},
$S:22}
A.it.prototype={
$1(a){return this.a.e.x.v(0,t.G.a(a).a)},
$S:1}
A.iu.prototype={
$1(a){return t.G.a(a).dx!=null},
$S:1}
A.iv.prototype={
$1(a){t.G.a(a)
return this.a.e.x.v(0,a.a)||a.dx!=null},
$S:1}
A.iz.prototype={
$1(a){return t.G.a(a).f===this.a},
$S:1}
A.io.prototype={
$0(){return A.d([],t.go)},
$S:23}
A.cl.prototype={
G(){return"PivotKind."+this.b}}
A.iN.prototype={
gci(){var s=this,r=s.c+s.ax
return s.a===B.E?3.141592653589793*r*r*(B.b.a_(s.db,1,360)/360):r*Math.max(s.d,0)},
gbE(){var s=this.ch
return s<=0?0:this.gci()*this.ay/1000/(s*3600)},
gcw(){var s=this.e
return s<=0?0:Math.max(1,B.b.J(this.c/s))}}
A.cm.prototype={
n(){var s=this
return A.S(["i",s.a,"d",s.b,"q",s.c,"h",s.d,"dz",s.e],t.N,t.z)}}
A.bA.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
q.i(0,"i",r.a)
q.i(0,"r0",r.b)
q.i(0,"r1",r.c)
q.i(0,"n",r.d)
q.i(0,"q",r.e)
q.i(0,"h",r.f)
s=r.r
if(s.length!==0)q.i(0,"noz",s)
return q}}
A.cM.prototype={
gcE(){return B.a.W(this.b,0,new A.iK(),t.S)},
n(){var s,r,q,p=this,o=A.n(t.N,t.z)
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
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.iL()),q),q.j("u.E"))
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
if(s.length!==0){r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.iM()),q),q.j("u.E"))
o.i(0,"spans",s)}return o}}
A.iK.prototype={
$2(a,b){return A.a0(a)+t.fR.a(b).d},
$S:70}
A.iL.prototype={
$1(a){return t.oz.a(a).n()},
$S:71}
A.iM.prototype={
$1(a){return t.fR.a(a).n()},
$S:72}
A.k8.prototype={
$1(a){return 0},
$S:21}
A.kj.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=B.b.a1(a2*10),a0=b.a,a1=a0.h(0,a)
if(a1!=null)return a1
s=b.b
r=-1/0
if(s.a===B.E){q=B.b.a_(s.db,1,360)*3.141592653589793/180
p=Math.max(8,B.b.a1(b.c*q/6.283185307179586))
for(s=b.e,o=b.f,n=o.a,o=o.b,m=b.r,l=q/2,k=q>=6.283185306179586,j=b.d,i=0;i<=p;++i){h=k?0:l
g=j+q*i/p-h
h=s.$1(new A.A(n+a2*Math.cos(g),o+a2*Math.sin(g)))
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
d=h.$1(new A.A(j+e,o+f))
f=h.$1(new A.A(k+e,l+f))
if(typeof d!=="number")return d.U()
if(typeof f!=="number")return A.cA(f)
r=Math.max(r,d-f)}}c=isFinite(r)?Math.max(r,0):0
a0.i(0,a,c)
return c},
$S:21}
A.be.prototype={
n(){var s,r,q=this,p=A.n(t.N,t.z)
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
A.aw.prototype={
n(){var s=this,r=s.c
return A.S(["ent",s.a,"i",s.b,"p",A.d([r.a,r.b],t.n),"z",s.d,"h",s.e,"q",s.f,"qn",s.r,"n",s.w,"lo",s.x,"hi",s.y,"label",s.z],t.N,t.z)}}
A.bQ.prototype={
n(){var s=this
return A.S(["ent",s.a,"link",s.b,"q",s.c,"hf",s.d,"hp",s.e,"pu",s.f,"pd",s.r,"st",s.w,"z",s.x],t.N,t.z)}}
A.cT.prototype={
ge1(){var s=this
return s.w>=s.y-0.000001&&s.x<=s.z+0.000001},
gbx(){var s=this.ax
return s.length===0?null:B.a.L(s,new A.jt())},
gdP(){var s=this.ax
return s.length===0?null:B.a.L(s,new A.js())},
cj(a){var s=this
t.fm.a(a)
return A.l7(s.z,s.y,s.dx,s.c,s.ay,s.e,s.cy,s.fr,s.x,s.w,s.Q,s.ax,s.dy,s.db,s.at,s.r,s.d,s.as,s.CW,s.a,s.f,s.cx,a,s.b)},
n(){var s,r,q=this,p=q.as.n(),o=q.at,n=A.r(o),m=n.j("t<1,h<c,@>>")
o=A.q(new A.t(o,n.j("h<c,@>(1)").a(new A.ju()),m),m.j("u.E"))
n=q.ax
m=A.r(n)
s=m.j("t<1,h<c,@>>")
n=A.q(new A.t(n,m.j("h<c,@>(1)").a(new A.jv()),s),s.j("u.E"))
m=q.ay
s=A.r(m)
r=s.j("t<1,h<c,@>>")
m=A.q(new A.t(m,s.j("h<c,@>(1)").a(new A.jw()),r),r.j("u.E"))
return A.S(["valve",q.a,"name",q.b,"conv",q.c,"q",q.d,"hd",q.e,"hv",q.f,"hreq",q.r,"pmin",q.w,"pmax",q.x,"lo",q.y,"hi",q.z,"pn",q.Q,"uni",p,"pipes",o,"outlets",n,"devices",m,"warn",q.ch,"zv",q.CW,"valveName",q.cx,"n",q.cy,"cost",q.db,"energy",q.dx,"ocu",q.dy,"epp",q.fr],t.N,t.z)}}
A.jt.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e<=b.e?a:b},
$S:20}
A.js.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e>=b.e?a:b},
$S:20}
A.ju.prototype={
$1(a){return t.h4.a(a).n()},
$S:10}
A.jv.prototype={
$1(a){return t.o.a(a).n()},
$S:76}
A.jw.prototype={
$1(a){return t.n6.a(a).n()},
$S:19}
A.co.prototype={
n(){var s=this
return A.S(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"z",s.f,"calc",s.r,"dh",s.w,"mh",s.x,"dq",s.y,"mq",s.z],t.N,t.z)}}
A.aS.prototype={
n(){var s=this,r=s.f
return A.S(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"p",A.d([r.a,r.b],t.n)],t.N,t.z)}}
A.b4.prototype={
n(){var s,r,q,p=this,o=p.d,n=A.r(o),m=n.j("t<1,h<c,@>>")
o=A.q(new A.t(o,n.j("h<c,@>(1)").a(new A.j7()),m),m.j("u.E"))
n=p.e
m=A.r(n)
s=m.j("t<1,h<c,@>>")
n=A.q(new A.t(n,m.j("h<c,@>(1)").a(new A.j8()),s),s.j("u.E"))
m=p.f
s=A.r(m)
r=s.j("t<1,h<c,@>>")
m=A.q(new A.t(m,s.j("h<c,@>(1)").a(new A.j9()),r),r.j("u.E"))
s=p.r
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.ja()),q),q.j("u.E"))
return A.S(["id",p.a,"name",p.b,"conv",p.c,"supplies",o,"valves",n,"pipes",m,"devices",s,"warn",p.w,"q",p.x,"dur",p.y,"energy",p.z],t.N,t.z)}}
A.j7.prototype={
$1(a){return t.ep.a(a).n()},
$S:78}
A.j8.prototype={
$1(a){return t.nN.a(a).n()},
$S:79}
A.j9.prototype={
$1(a){return t.h4.a(a).n()},
$S:10}
A.ja.prototype={
$1(a){return t.n6.a(a).n()},
$S:19}
A.al.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
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
A.cc.prototype={
n(){var s=this
return A.S(["valve",s.a,"name",s.b,"q",s.c,"hd",s.d,"hreq",s.e,"n",s.f,"hend",s.r,"vmax",s.w,"vf",s.x,"conv",s.y],t.N,t.z)}}
A.bD.prototype={
n(){var s=this
return A.S(["ent",s.a,"ctx",s.b,"name",s.c,"v",s.d,"a",s.e,"dh",s.f,"hs",s.r,"pn",s.w,"tc",s.x,"tcrit",s.y],t.N,t.z)}}
A.e9.prototype={
n(){var s,r,q,p=this,o=A.n(t.N,t.z)
o.i(0,"timestamp",p.a.bB())
o.i(0,"method",p.b)
s=p.c
r=A.i(s).j("ao<2>")
q=t.P
r=A.l_(new A.ao(s,r),r.j("h<c,@>(j.E)").a(new A.hg()),r.j("j.E"),q)
s=A.q(r,A.i(r).j("j.E"))
o.i(0,"zones",s)
s=p.d
if(s.a!==0){r=A.i(s).j("ao<2>")
q=A.l_(new A.ao(s,r),r.j("h<c,@>(j.E)").a(new A.hh()),r.j("j.E"),q)
s=A.q(q,A.i(q).j("j.E"))
o.i(0,"pivots",s)}s=p.e
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.hi()),q),q.j("u.E"))
o.i(0,"systemFlows",s)
o.i(0,"messages",p.f)
s=p.r
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.hj()),q),q.j("u.E"))
o.i(0,"bom",s)
s=p.w
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.hk()),q),q.j("u.E"))
o.i(0,"flushing",s)
s=p.x
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.hl()),q),q.j("u.E"))
o.i(0,"surge",s)
s=p.y
s=A.q(s,A.i(s).c)
o.i(0,"unconnected",s)
o.i(0,"capital",p.z)
o.i(0,"annualCapital",p.Q)
o.i(0,"annualEnergy",p.as)
return o}}
A.hg.prototype={
$1(a){return t.kV.a(a).n()},
$S:80}
A.hh.prototype={
$1(a){return t.oY.a(a).n()},
$S:81}
A.hi.prototype={
$1(a){return t.ju.a(a).n()},
$S:82}
A.hj.prototype={
$1(a){return t.q.a(a).n()},
$S:83}
A.hk.prototype={
$1(a){return t.lG.a(a).n()},
$S:84}
A.hl.prototype={
$1(a){return t.eu.a(a).n()},
$S:85}
A.bR.prototype={
a7(a){if(a<=0)return 0
return this.a*Math.pow(a,this.b)},
cq(a){if(a<=0||this.c===0)return 0
return this.c*Math.pow(a,this.d)},
al(a){var s=Math.max(a,0.000001),r=this.b
if(r===0)return 1e-9
return this.a*r*Math.pow(s,r-1)},
dF(a,b,c){var s=this.b
if(s<=0.01)return B.eW
s=1/s
return new A.m(a*Math.pow(1-c,s),a*Math.pow(1+b,s))},
n(){var s=this
return A.S(["k",s.a,"x",s.b,"ra",s.c,"rb",s.d],t.N,t.z)}}
A.kh.prototype={
$2(a,b){return A.T(a)+A.T(b)},
$S:3}
A.ki.prototype={
$2(a,b){return A.T(a)+Math.abs(A.T(b)-this.a)},
$S:3}
A.cd.prototype={
G(){return"FrictionMethod."+this.b}}
A.aF.prototype={
b2(a){var s
if(a===0)return 0
s=this.a*Math.pow(Math.abs(a),this.b)+this.c
return a<0?-s:s},
al(a){var s=this.b
return Math.max(s*this.a*Math.pow(Math.max(Math.abs(a),1e-9),s-1),1e-9)},
n(){return A.S(["k",this.a,"n",this.b,"c",this.c],t.N,t.z)}}
A.df.prototype={
G(){return"HNodeKind."+this.b}}
A.bm.prototype={}
A.bT.prototype={
G(){return"HLinkKind."+this.b}}
A.cF.prototype={
G(){return"LinkStatus."+this.b}}
A.de.prototype={
gm(a){return this.f}}
A.iB.prototype={}
A.eH.prototype={}
A.eu.prototype={}
A.cK.prototype={}
A.ef.prototype={
H(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7,f8=this,f9=A.d([],t.s),g0=f8.b,g1=A.i(g0).j("ao<2>"),g2=A.q(new A.ao(g0,g1),g1.j("j.E"))
g1=t.N
s=A.n(g1,t.S)
for(r=g2.length,q=0,p=0;p<g2.length;g2.length===r||(0,A.k)(g2),++p){o=g2[p]
if(o.b===B.Y){n=q+1
s.i(0,o.a,q)
q=n}}r=A.r(g2)
if(!new A.B(g2,r.j("v(1)").a(new A.i7()),r.j("B<1>")).gt(0).l())B.a.k(f9,"no_fixed_head_node")
r=t.i
m=A.n(g1,r)
for(l=g2.length,p=0;p<g2.length;g2.length===l||(0,A.k)(g2),++p){o=g2[p]
if(o.b===B.Z){k=o.e
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
g=h===B.M
if(g)i.ay=B.x
h=h===B.da
if(h)i.ay=B.l
if(!h&&!g)i.ay=B.n}k=A.n(g1,r)
for(h=g2.length,p=0;p<g2.length;g2.length===h||(0,A.k)(g2),++p)k.i(0,g2[p].a,0)
f=A.n(g1,t.y)
h=l.length
e=A.bc(h,1,!1,r)
g=l.length
d=A.bc(g,0,!1,r)
r=f8.a.a
b=r===B.be
r=r===B.an
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
else{a6=f8.c1(i,a3)
o=r?1.852:2
a7=Math.max(Math.abs(a3),1e-7)
a8=i.x
if(a8>0){a9=i.e
b0=3.141592653589793*a9*a9/4
b1=a8/(19.6133*b0*b0)}else b1=0
b2=o*a6*Math.pow(a7,o-1)+2*b1*a7
if(b&&a7>0.000001)b2+=(f8.c1(i,a7*1.01)-a6)/(a7*0.01)*Math.pow(a7,o)
b3=a6*Math.pow(a7,o)+b1*a7*a7
a4=Math.max(b2,1e-12)
a5=a3<0?-b3:b3}break
case 3:b4=i.Q
if(b4==null)b4=B.I
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
B.a.i(d,a2,a5)}b8=A.oh(q)
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
if(i.d===B.M&&i.ay===B.x){a8=g0.h(0,c2).c
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
if(i.d===B.M&&i.ay===B.x){a8=g0.h(0,a9).d
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
if(a8===B.ao&&i.y){a9=m.h(0,i.b)
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
e8=f1}}if(a8===B.M){a8=i.c
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
f4=A.n(g1,t.oX)
for(g0=g2.length,p=0;p<g2.length;g2.length===g0||(0,A.k)(g2),++p){o=g2[p]
r=o.a
k=m.h(0,r)
k.toString
h=o.f
if(h!=null&&o.r>0)h.a7(Math.max(k-o.c-o.w,0))
f4.i(0,r,new A.eH(k,k-o.c))}f5=A.n(g1,t.g_)
for(a2=0;a2<l.length;++a2){i=l[a2]
if(!(a2<j.length))return A.b(j,a2)
f6=j[a2]
g0=m.h(0,i.b)
g0.toString
g1=m.h(0,i.c)
g1.toString
f7=i.d===B.bf&&i.z!=null&&f6>0?i.z.bt(f6):0
f5.i(0,i.a,new A.eu(f6,g0-g1,i.ay,f7))}return new A.cK(c,f4,f5)},
c1(a,b){var s,r,q=this.a
switch(q.a.a){case 0:return 10.67*a.f/(Math.pow(a.r,1.852)*Math.pow(a.e,4.871))
case 1:s=a.e
r=3.141592653589793*s*s/4
return A.mN(a.w/s,A.fu(s,Math.max(Math.abs(b),1e-7))*s/q.b)*a.f/(s*2*9.80665*r*r)}}}
A.i7.prototype={
$1(a){return t.b.a(a).b===B.Z},
$S:87}
A.cO.prototype={
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
p=A.q(new A.B(A.d([(s-Math.sqrt(r))/n,(s+Math.sqrt(r))/n],t.n),t.eq.a(new A.iY()),q),q.j("j.E"))
B.a.a4(p)
return p.length===0?1/0:B.a.gu(p)*o.d},
n(){var s=this
return A.S(["a",s.a,"b",s.b,"c",s.c,"w",s.d],t.N,t.z)}}
A.iY.prototype={
$1(a){return A.T(a)>0},
$S:4}
A.iX.prototype={
$1(a){t.aL.a(a)
return a.a>=0&&a.b>=0},
$S:89}
A.j1.prototype={
H(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5={},b6=b4.a
if(b6===0)return B.bi
s=b4.b
r=A.r(s)
q=r.j("t<1,h<f,e>>")
p=A.q(new A.t(s,r.j("h<f,e>(1)").a(new A.j2()),q),q.j("u.E"))
s=t.i
o=A.ew(b4.c,!0,s)
n=A.bc(b6,!1,!1,t.y)
r=t.X
m=A.d([],r)
l=A.d([],t.l0)
q=t.S
k=J.el(b6,q)
for(j=0;j<b6;++j){if(!(j<p.length))return A.b(p,j)
i=p[j]
i=i.gm(i)
if(!(j<p.length))return A.b(p,j)
k[j]=i-(p[j].E(j)?1:0)}h=A.n(q,t.nO)
for(j=0;j<b6;++j){if(!(j<k.length))return A.b(k,j)
h.ac(k[j],new A.j3()).k(0,j)}b5.a=0
g=new A.j4(b5,b4,h,n)
f=new A.j5(b5,h,k)
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
for(a2=c.gaG(),a2=a2.gt(a2);a2.l();){a3=a2.gp()
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
a2=A.n(q,s)
for(a6=0;a6<a0.length;++a6){a3=a0[a6]
if(!(a6<a1.length))return A.b(a1,a6)
a2.i(0,a3,a1[a6])}a2.i(0,d,a)
B.a.k(l,a2)}a6=A.bc(b6,0,!1,s)
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
A.j2.prototype={
$1(a){return A.o0(t.jq.a(a),t.S,t.i)},
$S:90}
A.j3.prototype={
$0(){return A.K(t.S)},
$S:18}
A.j4.prototype={
$0(){var s,r,q,p,o,n,m,l=this
for(s=l.a,r=l.b.a,q=r+1,p=l.c;;){o=p.h(0,s.a)
if(o!=null&&o.ga8(o)){n=o.gu(o)
o.T(0,n)
return n}if(++s.a>q){for(s=l.d,q=s.length,m=0;m<r;++m){if(!(m<q))return A.b(s,m)
if(!s[m])return m}return-1}}},
$S:92}
A.j5.prototype={
$2(a,b){var s,r=this.b,q=this.c
if(!(a>=0&&a<q.length))return A.b(q,a)
s=r.h(0,q[a])
if(s!=null)s.T(0,a)
B.a.i(q,a,b)
r.ac(b,new A.j6()).k(0,a)
r=this.a
if(b<r.a)r.a=b},
$S:9}
A.j6.prototype={
$0(){return A.K(t.S)},
$S:18}
A.dF.prototype={
n(){var s=this
return A.S(["count",s.a,"mean",s.b,"min",s.c,"max",s.d,"cu",s.e,"du",s.f,"eu",s.r,"us",s.w,"qvar",s.x,"cv",s.y],t.N,t.z)}}
A.jn.prototype={
$1(a){return isFinite(A.T(a))},
$S:4}
A.jo.prototype={
$2(a,b){return A.T(a)+A.T(b)},
$S:3}
A.jp.prototype={
$2(a,b){return A.T(a)+Math.abs(A.T(b)-this.a)},
$S:3}
A.jq.prototype={
$2(a,b){return A.T(a)+A.T(b)},
$S:3}
A.jr.prototype={
$2(a,b){var s
A.T(a)
s=A.T(b)-this.a
return a+s*s},
$S:3}
A.b_.prototype={
G(){return"PipeMaterial."+this.b}}
A.es.prototype={
n(){return A.S(["strings",this.a,"tutorial",B.aq,"catalog",B.aq],t.N,t.z)}}
A.i6.prototype={
n(){var s=this
return A.S(["zone",s.a,"north",s.b,"e0",s.c,"n0",s.d],t.N,t.z)}}
A.b0.prototype={
G(){return"PipeUsage."+this.b}}
A.I.prototype={
n(){var s,r,q,p=this,o=A.n(t.N,t.z)
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
q=r.j("cb<1,c>")
s=A.q(new A.cb(s,r.j("c(1)").a(new A.iJ()),q),q.j("j.E"))
o.i(0,"usage",s)
o.i(0,"enabled",p.at)
s=p.c
if(s.length!==0)o.i(0,"sup",s)
s=p.d
if(s.length!==0)o.i(0,"code",s)
return o}}
A.iJ.prototype={
$1(a){return t.W.a(a).b},
$S:93}
A.iI.prototype={
$1(a){return A.ad(B.dk,A.C(a),t.W)},
$S:94}
A.bd.prototype={
G(){return"OutletKind."+this.b}}
A.E.prototype={
n(){var s=this
return A.S(["id",s.a,"name",s.b,"curve",s.c.n(),"arc",s.d,"minH",s.e,"maxH",s.f,"defH",s.r,"cv",s.w,"tolB",s.x,"tolA",s.y],t.N,t.z)}}
A.a3.prototype={
aC(a){var s=this.f
if(s.length===0)return null
return B.a.ag(s,new A.iE(a),new A.iF(this))},
n(){var s,r,q,p=this,o=A.n(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
o.i(0,"kind",p.e.b)
s=p.f
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.iG()),q),q.j("u.E"))
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
A.iE.prototype={
$1(a){return t.mP.a(a).a===this.a},
$S:95}
A.iF.prototype={
$0(){return B.a.gu(this.a.f)},
$S:96}
A.iG.prototype={
$1(a){return t.mP.a(a).n()},
$S:97}
A.iD.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j=null,i=t.P
i.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
i=A.lJ(i.a(a.h(0,"curve")))
q=A.x(a.h(0,"arc"))
if(q==null)q=j
if(q==null)q=360
p=A.x(a.h(0,"minH"))
if(p==null)p=j
if(p==null)p=5
o=A.x(a.h(0,"maxH"))
if(o==null)o=j
if(o==null)o=60
n=A.x(a.h(0,"defH"))
if(n==null)n=j
if(n==null)n=20
m=A.x(a.h(0,"cv"))
if(m==null)m=j
if(m==null)m=0.03
l=A.x(a.h(0,"tolB"))
if(l==null)l=j
if(l==null)l=0.05
k=A.x(a.h(0,"tolA"))
if(k==null)k=j
return new A.E(s,r,i,q,p,o,n,m,l,k==null?0.05:k)},
$S:98}
A.aR.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
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
A.aJ.prototype={
G(){return"ValveKind."+this.b}}
A.D.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
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
A.aP.prototype={
n(){var s,r,q,p=this,o=A.n(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
s=p.r
r=A.r(s)
q=r.j("t<1,p<e>>")
s=A.q(new A.t(s,r.j("p<e>(1)").a(new A.j_()),q),q.j("u.E"))
o.i(0,"points",s)
o.i(0,"eff",p.x)
o.i(0,"minQ",p.y)
o.i(0,"maxQ",p.z)
o.i(0,"cost",p.Q)
o.i(0,"enabled",p.as)
s=p.c
if(s.length!==0)o.i(0,"sup",s)
s=p.d
if(s.length!==0)o.i(0,"code",s)
s=p.e
if(s>0)o.i(0,"kw",s)
o.i(0,"sub",p.f)
return o}}
A.j_.prototype={
$1(a){t.aL.a(a)
return A.d([a.a,a.b],t.n)},
$S:99}
A.iZ.prototype={
$1(a){var s=J.af(a)
return new A.m(A.at(s.h(a,0)),A.at(s.h(a,1)))},
$S:150}
A.a7.prototype={
G(){return"FittingKind."+this.b}}
A.Y.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
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
A.fB.prototype={
dB(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
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
s=new A.ac(s,A.r(s).j("ac<1,I?>"))
s=s.ag(s,new A.fT(a),new A.fU())}return s},
a0(a){var s
if(a==null)s=null
else{s=this.b
s=new A.ac(s,A.r(s).j("ac<1,a3?>"))
s=s.ag(s,new A.fR(a),new A.fS())}return s},
ad(a){var s
if(a==null)s=null
else{s=this.c
s=new A.ac(s,A.r(s).j("ac<1,aR?>"))
s=s.ag(s,new A.fZ(a),new A.h_())}return s},
a2(a){var s
if(a==null)s=null
else{s=this.d
s=new A.ac(s,A.r(s).j("ac<1,D?>"))
s=s.ag(s,new A.h6(a),new A.h7())}return s},
ap(a){var s
if(a==null)s=null
else{s=this.e
s=new A.ac(s,A.r(s).j("ac<1,aP?>"))
s=s.ag(s,new A.fX(a),new A.fY())}return s},
ab(a){var s=this.a,r=A.r(s),q=r.j("B<1>")
s=A.q(new A.B(s,r.j("v(1)").a(new A.fV(a)),q),q.j("j.E"))
B.a.am(s,new A.fW())
return s},
n(){var s,r,q,p,o,n=this,m=n.a,l=A.r(m),k=l.j("t<1,h<c,@>>")
m=A.q(new A.t(m,l.j("h<c,@>(1)").a(new A.h0()),k),k.j("u.E"))
l=n.b
k=A.r(l)
s=k.j("t<1,h<c,@>>")
l=A.q(new A.t(l,k.j("h<c,@>(1)").a(new A.h1()),s),s.j("u.E"))
k=n.c
s=A.r(k)
r=s.j("t<1,h<c,@>>")
k=A.q(new A.t(k,s.j("h<c,@>(1)").a(new A.h2()),r),r.j("u.E"))
s=n.d
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.h3()),q),q.j("u.E"))
r=n.e
q=A.r(r)
p=q.j("t<1,h<c,@>>")
r=A.q(new A.t(r,q.j("h<c,@>(1)").a(new A.h4()),p),p.j("u.E"))
q=n.f
p=A.r(q)
o=p.j("t<1,h<c,@>>")
q=A.q(new A.t(q,p.j("h<c,@>(1)").a(new A.h5()),o),o.j("u.E"))
return A.S(["pipes",m,"outlets",l,"tapes",k,"valves",s,"pumps",r,"fittings",q],t.N,t.z)}}
A.fT.prototype={
$1(a){return t.cV.a(a).a===this.a},
$S:101}
A.fU.prototype={
$0(){return null},
$S:2}
A.fR.prototype={
$1(a){return t.h2.a(a).a===this.a},
$S:102}
A.fS.prototype={
$0(){return null},
$S:2}
A.fZ.prototype={
$1(a){return t.lJ.a(a).a===this.a},
$S:103}
A.h_.prototype={
$0(){return null},
$S:2}
A.h6.prototype={
$1(a){return t.kf.a(a).a===this.a},
$S:104}
A.h7.prototype={
$0(){return null},
$S:2}
A.fX.prototype={
$1(a){return t.gL.a(a).a===this.a},
$S:105}
A.fY.prototype={
$0(){return null},
$S:2}
A.fV.prototype={
$1(a){t.p.a(a)
return a.at&&a.as.v(0,this.a)},
$S:6}
A.fW.prototype={
$2(a,b){var s=t.p
return B.b.S(s.a(a).f,s.a(b).f)},
$S:106}
A.h0.prototype={
$1(a){return t.p.a(a).n()},
$S:107}
A.h1.prototype={
$1(a){return t.fa.a(a).n()},
$S:108}
A.h2.prototype={
$1(a){return t.gs.a(a).n()},
$S:109}
A.h3.prototype={
$1(a){return t.e4.a(a).n()},
$S:110}
A.h4.prototype={
$1(a){return t.dz.a(a).n()},
$S:111}
A.h5.prototype={
$1(a){return t.kN.a(a).n()},
$S:112}
A.fL.prototype={
$1(a){return A.o6(t.P.a(a))},
$S:113}
A.fM.prototype={
$1(a){return A.o4(t.P.a(a))},
$S:114}
A.fN.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=null,a1=t.P
a1.a(a2)
s=A.C(a2.h(0,"id"))
r=A.C(a2.h(0,"name"))
q=A.w(a2.h(0,"sup"))
if(q==null)q=""
p=A.w(a2.h(0,"code"))
if(p==null)p=""
o=A.x(a2.h(0,"nominalMm"))
if(o==null)o=a0
if(o==null)o=16
n=A.at(a2.h(0,"idMm"))
m=A.at(a2.h(0,"spacing"))
a1=A.lJ(a1.a(a2.h(0,"emitter")))
l=A.x(a2.h(0,"barbK"))
if(l==null)l=a0
if(l==null)l=0.4
k=A.x(a2.h(0,"cv"))
if(k==null)k=a0
if(k==null)k=0.03
j=A.x(a2.h(0,"minH"))
if(j==null)j=a0
if(j==null)j=4
i=A.x(a2.h(0,"maxH"))
if(i==null)i=a0
if(i==null)i=15
h=A.x(a2.h(0,"inletH"))
if(h==null)h=a0
if(h==null)h=10
g=A.x(a2.h(0,"tolB"))
if(g==null)g=a0
if(g==null)g=30
f=A.x(a2.h(0,"tolA"))
if(f==null)f=a0
if(f==null)f=20
e=A.x(a2.h(0,"ratingM"))
if(e==null)e=a0
if(e==null)e=25
d=A.x(a2.h(0,"roughMm"))
if(d==null)d=a0
if(d==null)d=0.002
c=A.x(a2.h(0,"c"))
if(c==null)c=a0
if(c==null)c=140
b=A.x(a2.h(0,"cost"))
if(b==null)b=a0
if(b==null)b=0
a=A.W(a2.h(0,"enabled"))
return A.cS(l,p,b,k,h,a1,m,a!==!1,c,s,n,i,j,r,o,e,d,q,f,g)},
$S:115}
A.fO.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e=t.P
e.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
q=A.w(a.h(0,"sup"))
if(q==null)q=""
p=A.w(a.h(0,"code"))
if(p==null)p=""
o=A.ad(B.dv,A.C(a.h(0,"kind")),t.bn)
n=A.at(a.h(0,"sizeMm"))
e=e.a(a.h(0,"loss"))
m=A.at(e.h(0,"k"))
l=A.x(e.h(0,"n"))
if(l==null)l=f
if(l==null)l=2
e=A.x(e.h(0,"c"))
if(e==null)e=f
if(e==null)e=0
k=A.x(a.h(0,"minQ"))
if(k==null)k=f
if(k==null)k=0
j=A.x(a.h(0,"maxQ"))
if(j==null)j=f
if(j==null)j=1
i=A.x(a.h(0,"cost"))
if(i==null)i=f
if(i==null)i=0
h=A.x(a.h(0,"setting"))
if(h==null)h=f
if(h==null)h=0
g=A.W(a.h(0,"enabled"))
return new A.D(s,r,q,p,o,n,new A.aF(m,l,e),k,j,i,h,g!==!1)},
$S:116}
A.fP.prototype={
$1(a){return A.od(t.P.a(a))},
$S:117}
A.fQ.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j
t.P.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
q=A.ad(B.dG,A.C(a.h(0,"kind")),t.na)
p=A.at(a.h(0,"sizeMm"))
o=A.x(a.h(0,"size2Mm"))
if(o==null)o=null
if(o==null)o=0
n=A.x(a.h(0,"cost"))
if(n==null)n=null
if(n==null)n=0
m=A.W(a.h(0,"enabled"))
l=A.w(a.h(0,"sup"))
if(l==null)l=""
k=A.w(a.h(0,"code"))
if(k==null)k=""
j=A.w(a.h(0,"mat"))
if(j==null)j=""
return new A.Y(s,r,l,k,q,p,o,n,m!==!1,j)},
$S:118}
A.fD.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.n_(r,b)
s=b
break A}return s},
$S:26}
A.fE.prototype={
$4$radiusM(a,b,c,d){var s=d>0,r=s?0.35:0,q=Math.pow(b,c),p=s?d/Math.pow(b,r):0
s=s?r:0
return new A.bR(a*27777777777777776e-23/q,c,p,s)},
$3(a,b,c){return this.$4$radiusM(a,b,c,0)},
$S:120}
A.fC.prototype={
$2(a,b){return new A.aF(A.q8(b/1000,a),2,0)},
$S:121}
A.fJ.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.n_(r,b)
s=b
break A}return s},
$S:26}
A.fF.prototype={
$1(a){return t.p.a(a).e},
$S:25}
A.fI.prototype={
$1(a){return a===B.b.by(a)?""+B.b.a1(a):B.b.ae(a,1)},
$S:14}
A.fK.prototype={
$2(a,b){return B.b.by(a*(0.25+b/40))},
$S:3}
A.fG.prototype={
$1(a){t.p.a(a)
return a.as.v(0,B.p)||a.e<=50},
$S:6}
A.fH.prototype={
$1(a){return t.p.a(a).e},
$S:25}
A.aG.prototype={
G(){return"HydraulicScope."+this.b}}
A.M.prototype={
G(){return"EntityType."+this.b}}
A.F.prototype={
D(){var s,r=this,q=A.n(t.N,t.z)
q.i(0,"type",r.gC().b)
q.i(0,"id",r.a)
q.i(0,"layer",r.b)
s=r.c
if(s.length!==0)q.i(0,"name",s)
return q}}
A.i3.prototype={
$0(){var s=t.O.a(this.a.h(0,"pts"))
if(s==null)s=[]
s=J.aE(s,new A.i4(),t.g)
s=A.q(s,s.$ti.j("u.E"))
return s},
$S:123}
A.i4.prototype={
$1(a){return A.bC(t.j.a(a))},
$S:124}
A.i2.prototype={
$0(){return A.bC(t.j.a(this.a.h(0,"p")))},
$S:125}
A.i1.prototype={
$2(a,b){var s=A.x(this.a.h(0,a))
if(s==null)s=null
return s==null?b:s},
$1(a){return this.$2(a,0)},
$S:126}
A.bf.prototype={}
A.a5.prototype={
gm(a){return A.aV(this.gP())},
dt(a){var s,r,q,p,o,n,m=this
for(s=a.a,r=a.b,q=1/0,p=1;p<J.au(m.gP());++p){o=A.lj(a,J.fx(m.gP(),p-1),J.fx(m.gP(),p)).a
n=s-o.a
o=r-o.b
q=Math.min(q,Math.sqrt(n*n+o*o))}return J.au(m.gP())===1?J.ls(J.bN(m.gP()),a).gm(0):q}}
A.k5.prototype={
$1(a){t.g.a(a)
return A.d([a.a,a.b],t.n)},
$S:127}
A.ci.prototype={
gC(){return B.aY},
gm(a){return this.d.U(0,this.e).gm(0)},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d,q=t.n
s.i(0,"a",A.d([r.a,r.b],q))
r=this.e
s.i(0,"b",A.d([r.a,r.b],q))
return s}}
A.cN.prototype={
gm(a){var s,r=this.d,q=A.aV(r)
if(this.e&&J.au(r)>2){s=J.a1(r)
r=J.ls(s.gM(r),t.g.a(s.gu(r))).gm(0)}else r=0
return q+r},
gC(){return B.aZ},
n(){var s=A.V(this.D(),t.N,t.z)
s.i(0,"pts",A.c2(this.d))
s.i(0,"closed",this.e)
return s},
gP(){return this.d}}
A.e4.prototype={
gC(){return B.b4},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d
s.i(0,"p",A.d([r.a,r.b],t.n))
s.i(0,"r",this.e)
return s}}
A.d3.prototype={
gC(){return B.b6},
gm(a){return this.e*Math.abs(this.r)},
dS(){var s,r,q,p,o,n,m=this,l=m.r,k=Math.max(2,B.b.ao(32*Math.abs(l)/6.283185307179586)),j=A.d([],t.C)
for(s=m.d,r=m.e,q=m.f,p=s.a,s=s.b,o=0;o<=k;++o){n=q+l*o/k
j.push(new A.A(p+r*Math.cos(n),s+r*Math.sin(n)))}return j},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"r",s.e)
r.i(0,"s",s.f)
r.i(0,"w",s.r)
return r}}
A.cQ.prototype={
gC(){return B.b7},
gm(a){return A.aV(A.pK(this.d,this.e,8))},
n(){var s=A.V(this.D(),t.N,t.z)
s.i(0,"pts",A.c2(this.d))
s.i(0,"closed",this.e)
return s},
gP(){return this.d}}
A.ee.prototype={
gC(){return B.b8},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c2(s.d))
r.i(0,"ang",s.e)
r.i(0,"sp",s.f)
r.i(0,"solid",s.r)
return r},
gP(){return this.d}}
A.aI.prototype={
G(){return"SymbolKind."+this.b}}
A.eQ.prototype={
gC(){return B.b9},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"kind",s.e.b)
r.i(0,"size",s.f)
r.i(0,"rot",s.r)
return r}}
A.eT.prototype={
gC(){return B.ba},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"text",s.e)
r.i(0,"h",s.f)
r.i(0,"rot",s.r)
return r}}
A.eb.prototype={
gC(){return B.bb},
gm(a){return this.d.U(0,this.e).gm(0)},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d,p=t.n
r.i(0,"a",A.d([q.a,q.b],p))
q=s.e
r.i(0,"b",A.d([q.a,q.b],p))
r.i(0,"off",s.f)
return r}}
A.e_.prototype={
gC(){return B.bc},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d,p=t.n
r.i(0,"v",A.d([q.a,q.b],p))
q=s.e
r.i(0,"a",A.d([q.a,q.b],p))
q=s.f
r.i(0,"b",A.d([q.a,q.b],p))
r.i(0,"r",s.r)
return r}}
A.eN.prototype={
gC(){return B.b_},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d,q=t.n
s.i(0,"c",A.d([r.a,r.b],q))
r=this.e
s.i(0,"p",A.d([r.a,r.b],q))
return s}}
A.cE.prototype={
gC(){return B.b0},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c2(s.d))
r.i(0,"text",s.e)
r.i(0,"h",s.f)
return r},
gP(){return this.d}}
A.eg.prototype={
gC(){return B.b1},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"w",s.e)
r.i(0,"h",s.f)
r.i(0,"rot",s.r)
r.i(0,"op",s.w)
r.i(0,"mime",s.x)
q=s.y
if(q!=null){t.fn.j("bO.S").a(q)
r.i(0,"data",B.cN.gbs().br(q))}q=s.z
if(q.length!==0)r.i(0,"src",q)
return r}}
A.c7.prototype={
gC(){return B.b2},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c2(s.d))
r.i(0,"z",s.e)
if(s.f)r.i(0,"gen",!0)
return r},
gP(){return this.d}}
A.dB.prototype={
gC(){return B.b3},
n(){var s=A.V(this.D(),t.N,t.z),r=this.d
s.i(0,"p",A.d([r.a,r.b],t.n))
s.i(0,"z",this.e)
return s}}
A.aH.prototype={
gC(){return B.a9},
n(){var s,r=this,q=A.V(r.D(),t.N,t.z)
q.i(0,"pts",A.c2(r.d))
q.i(0,"scope",r.e.b)
s=r.f
if(s!=null)q.i(0,"spec",s)
q.i(0,"auto",r.r)
q.i(0,"depth",r.w)
return q},
gP(){return this.d}}
A.ak.prototype={
gC(){return B.aa},
gb3(){var s=this,r=A.aV(s.d),q=s.z,p=q>0
if(r<(p?q:s.y)-1e-9)return 0
return B.b.J((r-(p?q:s.y))/s.y+1e-9)+1},
n(){var s,r=this,q=A.V(r.D(),t.N,t.z)
q.i(0,"pts",A.c2(r.d))
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
A.aB.prototype={
gC(){return B.ab},
n(){var s=this,r=A.V(s.D(),t.N,t.z)
r.i(0,"pts",A.c2(s.d))
r.i(0,"spec",s.e)
r.i(0,"inlet",s.f)
r.i(0,"reg",s.r)
r.i(0,"submin",s.w)
r.i(0,"depth",s.x)
r.i(0,"flush",s.y)
return r},
gP(){return this.d}}
A.aZ.prototype={
gC(){return B.ac},
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
A.b9.prototype={
gC(){return B.ad},
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
A.aC.prototype={
gC(){return B.ae},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"calc",s.e)
r.i(0,"dh",s.f)
r.i(0,"mh",s.r)
r.i(0,"dq",s.w)
r.i(0,"mq",s.x)
r.i(0,"wl",s.y)
return r}}
A.bo.prototype={
gC(){return B.af},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"speed",s.f)
r.i(0,"rot",s.r)
r.i(0,"scope",s.w.b)
return r}}
A.aY.prototype={
gC(){return B.ag},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"scope",s.f.b)
r.i(0,"set",s.r)
r.i(0,"rot",s.w)
return r}}
A.ch.prototype={
gC(){return B.ah},
n(){var s=this,r=A.V(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"scope",s.e.b)
q=s.f
if(q!=null)r.i(0,"z",q)
return r}}
A.b1.prototype={
dZ(){var s,r,q,p,o,n,m,l=this,k=l.as
if(k<=0)return B.dx
s=Math.max(1,B.b.J(l.x/k))
r=A.d([],t.C)
for(q=l.w,p=l.y*3.141592653589793/180,o=q.a,q=q.b,n=1;n<=s;++n){m=n*k
r.push(new A.A(o+Math.cos(p)*m,q+Math.sin(p)*m))}return r},
gC(){return B.ai},
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
A.cC.prototype={
gC(){return B.b5},
n(){var s,r=this,q=A.V(r.D(),t.N,t.z)
q.i(0,"pts",A.c2(r.d))
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
A.eX.prototype={}
A.f_.prototype={}
A.f0.prototype={}
A.f4.prototype={}
A.f7.prototype={}
A.f8.prototype={}
A.fa.prototype={}
A.fb.prototype={}
A.fc.prototype={}
A.fd.prototype={}
A.fe.prototype={}
A.fg.prototype={}
A.fh.prototype={}
A.fi.prototype={}
A.fl.prototype={}
A.fm.prototype={}
A.fn.prototype={}
A.fo.prototype={}
A.A.prototype={
aj(a,b){return new A.A(this.a+b.a,this.b+b.b)},
U(a,b){return new A.A(this.a-b.a,this.b-b.b)},
ar(a,b){return new A.A(this.a*b,this.b*b)},
gm(a){var s=this.a,r=this.b
return Math.sqrt(s*s+r*r)},
gcp(){var s=this.gm(0)
return s===0?B.au:new A.A(this.a/s,this.b/s)},
ck(a){return this.a*a.a+this.b*a.b},
n(){return A.S(["x",this.a,"y",this.b],t.N,t.z)},
Y(a,b){if(b==null)return!1
return b instanceof A.A&&b.a===this.a&&b.b===this.b},
gK(a){return A.cL(this.a,this.b,B.e,B.e)},
q(a){return"Pt("+B.b.ae(this.a,3)+", "+B.b.ae(this.b,3)+")"}}
A.e3.prototype={}
A.kQ.prototype={
$1(a){A.T(a)
return a>1e-9&&a<A.aV(this.a)-1e-9},
$S:4}
A.kR.prototype={
$1(a){return A.aV(t.V.a(a))>1e-9},
$S:128}
A.k9.prototype={
$1(a){var s=this.b,r=this.c,q=J.af(s)
return this.a?q.h(s,B.c.b6(B.c.b6(a,r)+r,r)):q.h(s,B.c.a_(a,0,r-1))},
$S:129}
A.ka.prototype={
$3(a,b,c){return a+Math.pow(b.U(0,c).gm(0),0.5)},
$S:130}
A.aA.prototype={
n(){var s=this
return A.S(["name",s.a,"color",s.b,"visible",s.c,"locked",s.d],t.N,t.z)}}
A.cn.prototype={
G(){return"SizingMethod."+this.b}}
A.hb.prototype={
n(){var s=this
return A.S(["units",s.a.n(),"method",s.b.b,"temp",s.c,"vZone",s.d,"vMain",s.e,"vLat",s.f,"minorPct",s.r,"minor",s.w,"tol",s.x,"interest",s.y,"term",s.z,"kwh",s.Q,"eff",s.as,"hours",s.at,"zoneHours",s.ax,"trade",s.ay,"latSizes",s.ch,"subSizes",s.CW,"cScale",s.cx,"cOffset",s.cy,"densify",s.db,"currency",s.dx,"sizing",s.dy.b,"mainSizes",s.fr,"epp",s.fx,"maxNodes",s.fy,"flushV",s.go,"flushH",s.id,"surge",s.k1,"closure",s.k2,"fittings",s.k3,"stick",s.k4,"zoneVar",s.ok,"terrain",s.p1.b],t.N,t.z)}}
A.hc.prototype={
$2(a,b){var s=A.x(this.a.h(0,a))
if(s==null)s=null
return s==null?b:s},
$S:131}
A.b3.prototype={
n(){var s=this,r=s.c
r=A.q(r,A.i(r).c)
return A.S(["id",s.a,"name",s.b,"valves",r,"start",s.d,"dur",s.e],t.N,t.z)}}
A.iP.prototype={
n(){var s,r=this,q=A.n(t.N,t.z)
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
A.iO.prototype={
a6(a){var s,r,q,p
for(s=this.e,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null},
dk(){var s,r,q,p=this.b,o=A.d([],t.pn),n=new A.eS(p.db,p.p1,o,A.n(t.S,t.J))
for(p=this.e,s=p.length,r=0;r<p.length;p.length===s||(0,A.k)(p),++r){q=p[r]
if(q instanceof A.c7&&!q.f)n.df(q.d,q.e)
if(q instanceof A.dB){B.a.k(o,new A.bF(q.d,q.e))
n.f=!0}}return n},
n(){var s,r,q,p=this,o=A.n(t.N,t.z)
o.i(0,"format","opencadirrigation")
o.i(0,"version",1)
o.i(0,"meta",p.a.n())
o.i(0,"params",p.b.n())
o.i(0,"catalog",p.c.n())
s=J.aE(p.d,new A.iU(),t.P)
s=A.q(s,s.$ti.j("u.E"))
o.i(0,"layers",s)
s=p.e
r=A.r(s)
q=r.j("h<c,@>(1)").a(new A.iV())
r=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,q,r),r.j("u.E"))
o.i(0,"entities",s)
s=p.f
r=A.r(s)
q=r.j("t<1,h<c,@>>")
s=A.q(new A.t(s,r.j("h<c,@>(1)").a(new A.iW()),q),q.j("u.E"))
o.i(0,"systemFlows",s)
o.i(0,"nextId",p.r)
s=p.w
if(s!=="DRAWING")o.i(0,"currentLayer",s)
return o}}
A.iU.prototype={
$1(a){return t.df.a(a).n()},
$S:132}
A.iV.prototype={
$1(a){return t.h.a(a).n()},
$S:13}
A.iW.prototype={
$1(a){return t.k.a(a).n()},
$S:133}
A.iQ.prototype={
$1(a){var s,r,q,p
t.P.a(a)
s=A.C(a.h(0,"name"))
r=A.a0(a.h(0,"color"))
q=A.W(a.h(0,"visible"))
p=A.W(a.h(0,"locked"))
return new A.aA(s,r,q!==!1,p===!0)},
$S:134}
A.iR.prototype={
$1(a){t.er.a(a)
return a.length===0?A.m1():a},
$S:135}
A.iS.prototype={
$1(a){return A.nO(t.P.a(a))},
$S:136}
A.iT.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.C(a.h(0,"id"))
r=A.C(a.h(0,"name"))
q=t.O.a(a.h(0,"valves"))
if(q==null)q=[]
q=J.nn(q,t.N)
q=q.aq(q)
p=A.x(a.h(0,"start"))
if(p==null)p=null
if(p==null)p=0
o=A.x(a.h(0,"dur"))
if(o==null)o=null
return A.m8(o==null?1:o,s,r,p,q)},
$S:137}
A.kP.prototype={
$1(a){A.T(a)
return a>0.000001&&a<this.a-0.000001},
$S:4}
A.cp.prototype={
G(){return"TerrainMethod."+this.b}}
A.bF.prototype={}
A.eS.prototype={
gdX(){var s,r,q,p,o,n,m,l=this,k=l.r
if(k==null||l.f){s=l.c
r=s.length
q=r>12e3?B.b.ao(r/12e3):1
p=A.d([],t.kb)
for(o=0;o<r;o+=q){if(!(o>=0&&o<s.length))return A.b(s,o)
n=s[o]
m=n.a
p.push(new A.a(m.a,m.b,n.b))}k=l.r=A.op(p)
if(l.f)l.c4()}return k},
df(a,b){var s,r,q,p,o=this
t.V.a(a)
s=J.af(a)
if(s.gF(a))return
if(s.gm(a)===1){B.a.k(o.c,new A.bF(t.g.a(s.gu(a)),b))
o.f=!0
return}r=A.aV(a)
q=Math.max(1,B.b.ao(r/o.a))
for(s=o.c,p=0;p<=q;++p){B.a.k(s,new A.bF(A.ku(a,r*p/q),b))
o.f=!0}o.f=!0},
c4(){var s,r,q,p,o=this,n=o.d
n.V(0)
s=o.c
if(s.length===0){o.f=!1
return}r=A.r(s)
q=A.nw(new A.t(s,r.j("A(1)").a(new A.jc()),r.j("t<1,A>")))
o.e=Math.max(0.001,Math.max(q.c-q.a,q.d-q.b)/Math.max(1,Math.sqrt(s.length)))
for(p=0;p<s.length;++p){r=s[p].a
J.bM(n.ac((B.b.J(r.a/o.e)*73856093^B.b.J(r.b/o.e)*19349663)>>>0,new A.jd()),p)}o.f=!1},
cm(a,b,c){var s,r=this
if(r.c.length===0)return b
if(r.b===B.aO){s=r.gdX().b_(a)
if(s!=null)return s}return r.dG(a,b,c)},
b_(a){return this.cm(a,0,8)},
dG(a8,a9,b0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this,a7=a6.c
if(a7.length===0)return a9
if(a6.f)a6.c4()
s=A.d([],t.ip)
r=a8.a
q=B.b.J(r/a6.e)
p=a8.b
o=B.b.J(p/a6.e)
for(n=a6.d,m=0;m<=64;){for(l=-m,k=m>0,j=l;j<=m;++j)for(i=(q+j)*73856093,h=Math.abs(j)!==m,g=l;g<=m;++g){if(k&&h&&Math.abs(g)!==m)continue
f=n.h(0,(i^(o+g)*19349663)>>>0)
if(f==null)continue
for(e=J.ab(f);e.l();){d=e.gp()
if(d>>>0!==d||d>=a7.length)return A.b(a7,d)
c=a7[d].a
b=c.a-r
c=c.b-p
B.a.k(s,new A.m(Math.sqrt(b*b+c*c),d))}}if(s.length>=b0&&m>=1)break;++m}if(s.length===0)for(a=0;a<a7.length;++a){n=a7[a].a
k=n.a-r
n=n.b-p
B.a.k(s,new A.m(Math.sqrt(k*k+n*n),a))}B.a.am(s,new A.je())
a0=A.bY(s,0,A.cx(b0,"count",t.S),t.mT).cv(0)
if(B.a.gu(a0).a<1e-9){r=B.a.gu(a0).b
if(!(r>=0&&r<a7.length))return A.b(a7,r)
return a7[r].b}for(r=a0.length,p=a7.length,a1=0,a2=0,a3=0;a3<r;++a3){n=a0[a3]
a4=n.a
a=n.b
a5=1/(a4*a4)
if(!(a>=0&&a<p))return A.b(a7,a)
a1+=a5*a7[a].b
a2+=a5}return a2===0?a9:a1/a2}}
A.jc.prototype={
$1(a){return t.jH.a(a).a},
$S:139}
A.jd.prototype={
$0(){return A.d([],t.X)},
$S:16}
A.je.prototype={
$2(a,b){var s=t.mT
return B.b.S(s.a(a).a,s.a(b).a)},
$S:141}
A.bZ.prototype={}
A.jf.prototype={
cX(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=b.e
a.V(0)
s=b.d
if(s.length===0)return
r=b.a
b.r=B.a.L(r,B.H)
q=b.b
b.w=B.a.L(q,B.H)
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
for(d=B.b.J((h-b.r)/b.f);d<=B.b.J((g-b.r)/b.f);++d)for(c=B.b.J((f-b.w)/b.f),n=d*73856093;c<=B.b.J((e-b.w)/b.f);++c)J.bM(a.ac((n^c*19349663)>>>0,new A.jg()),p)}},
dN(a){var s,r,q,p=this,o=p.d
if(o.length===0)return-1
s=p.e.h(0,(B.b.J((a.a-p.r)/p.f)*73856093^B.b.J((a.b-p.w)/p.f)*19349663)>>>0)
if(s==null)return-1
for(r=J.ab(s);r.l();){q=r.gp()
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
b_(a){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.dN(a)
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
A.ji.prototype={
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
A.jh.prototype={
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
A.jj.prototype={
$2(a,b){var s
A.a0(a)
A.a0(b)
s=this.a
return J.lu(s.$1(a),s.$1(b))},
$S:144}
A.jk.prototype={
$2(a,b){var s=a<b?a*4194304+b:b*4194304+a,r=this.a,q=r.h(0,s)
if(q==null){r.i(0,s,1)
B.a.k(this.b,new A.m(a,b))}else r.i(0,s,q+1)},
$S:9}
A.jg.prototype={
$0(){return A.d([],t.X)},
$S:16}
A.bn.prototype={
G(){return"LengthUnit."+this.b}}
A.bk.prototype={
G(){return"FlowUnit."+this.b}}
A.bB.prototype={
G(){return"PressureUnit."+this.b}}
A.c9.prototype={
G(){return"DiameterUnit."+this.b}}
A.eV.prototype={
n(){var s=this
return A.S(["length",s.a.b,"flow",s.b.b,"pressure",s.c.b,"diameter",s.d.b],t.N,t.z)},
gm(a){return this.a}}
A.ks.prototype={
$1(a){var s=A.mr(a).data
if(s==null||!(typeof s==="string"))return
A.kv(t.P.a(B.aT.dn(A.C(s),null)),new A.kr(this.a))},
$S:145}
A.kr.prototype={
$1(a){return this.a.postMessage(B.aT.dv(t.P.a(a),null))},
$S:146};(function aliases(){var s=J.bV.prototype
s.cG=s.q})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._static_0,p=hunkHelpers._instance_1i,o=hunkHelpers._instance_1u,n=hunkHelpers._instance_0u,m=hunkHelpers.installInstanceTearOff,l=hunkHelpers.installStaticTearOff
s(J,"pe","nX",147)
r(A,"pH","ow",5)
r(A,"pI","ox",5)
r(A,"pJ","oy",5)
q(A,"mL","pB",0)
p(A.br.prototype,"gaF","v",140)
r(A,"pM","p4",24)
q(A,"pO","ps",149)
var k
o(k=A.ea.prototype,"gd9","aV",77)
n(k,"gdl","dm",74)
n(k,"gdi","dj",73)
m(A.eS.prototype,"gdu",0,1,null,["$3$fallback$neighbours","$1"],["cm","b_"],138,0,0)
l(A,"q7",2,null,["$1$2","$2"],["mX",function(a,b){return A.mX(a,b,t.H)}],17,0)
l(A,"q6",2,null,["$1$2","$2"],["mW",function(a,b){return A.mW(a,b,t.H)}],17,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.J,null)
q(A.J,[A.kX,J.ej,A.dy,J.c5,A.j,A.d6,A.P,A.j0,A.aN,A.dr,A.dH,A.dA,A.da,A.bI,A.U,A.b5,A.d7,A.ct,A.bW,A.az,A.jl,A.iC,A.db,A.dQ,A.a2,A.ig,A.an,A.N,A.ag,A.eo,A.jS,A.bg,A.f3,A.jX,A.jV,A.eY,A.cw,A.b7,A.cs,A.ae,A.eZ,A.fj,A.dV,A.f9,A.Q,A.G,A.bO,A.e8,A.jC,A.jB,A.jQ,A.bt,A.ca,A.f1,A.eI,A.dC,A.jD,A.dd,A.ai,A.ap,A.fk,A.cR,A.i8,A.hd,A.he,A.c8,A.ea,A.dc,A.i5,A.cj,A.ij,A.cH,A.dq,A.dp,A.ex,A.dn,A.ba,A.aX,A.H,A.iA,A.im,A.iN,A.cm,A.bA,A.cM,A.be,A.aw,A.bQ,A.cT,A.co,A.aS,A.b4,A.al,A.cc,A.bD,A.e9,A.bR,A.aF,A.bm,A.de,A.iB,A.eH,A.eu,A.cK,A.ef,A.cO,A.j1,A.dF,A.es,A.i6,A.I,A.E,A.a3,A.aR,A.D,A.aP,A.Y,A.fB,A.F,A.bf,A.a5,A.A,A.e3,A.aA,A.hb,A.b3,A.iP,A.iO,A.bF,A.eS,A.bZ,A.jf,A.eV])
q(J.ej,[J.em,J.dh,J.dj,J.di,J.dk,J.cf,J.cg])
q(J.dj,[J.bV,J.o,A.cI,A.du])
q(J.bV,[J.eJ,J.cq,J.bU])
r(J.ek,A.dy)
r(J.ib,J.o)
q(J.cf,[J.dg,J.en])
q(A.j,[A.c_,A.y,A.bz,A.B,A.dz,A.cr,A.dK,A.c0])
q(A.c_,[A.c6,A.dW])
r(A.dJ,A.c6)
r(A.dI,A.dW)
r(A.ac,A.dI)
q(A.P,[A.et,A.bG,A.ep,A.eW,A.eO,A.f2,A.dl,A.e1,A.bi,A.dG,A.eU,A.dD,A.e7])
q(A.y,[A.u,A.d9,A.a4,A.ao,A.L])
q(A.u,[A.dE,A.t,A.bp,A.f6])
r(A.cb,A.bz)
r(A.i0,A.dz)
q(A.b5,[A.cV,A.cW,A.cv])
r(A.m,A.cV)
r(A.a,A.cW)
q(A.cv,[A.cX,A.aT])
r(A.b8,A.d7)
q(A.bW,[A.d8,A.dP])
r(A.bP,A.d8)
q(A.az,[A.ei,A.e5,A.e6,A.eR,A.kk,A.km,A.jy,A.jx,A.k_,A.jM,A.ik,A.h9,A.ha,A.hf,A.kw,A.kx,A.hz,A.hM,A.hy,A.hA,A.hn,A.hp,A.hq,A.hJ,A.hO,A.hP,A.hw,A.hu,A.hX,A.hY,A.hZ,A.hN,A.hQ,A.kf,A.kI,A.kK,A.kz,A.kA,A.kB,A.kC,A.kG,A.kD,A.kE,A.ky,A.kN,A.iq,A.iw,A.iy,A.ix,A.it,A.iu,A.iv,A.iz,A.iL,A.iM,A.k8,A.kj,A.ju,A.jv,A.jw,A.j7,A.j8,A.j9,A.ja,A.hg,A.hh,A.hi,A.hj,A.hk,A.hl,A.i7,A.iY,A.iX,A.j2,A.jn,A.iJ,A.iI,A.iE,A.iG,A.iD,A.j_,A.iZ,A.fT,A.fR,A.fZ,A.h6,A.fX,A.fV,A.h0,A.h1,A.h2,A.h3,A.h4,A.h5,A.fL,A.fM,A.fN,A.fO,A.fP,A.fQ,A.fD,A.fE,A.fJ,A.fF,A.fI,A.fG,A.fH,A.i4,A.i1,A.k5,A.kQ,A.kR,A.k9,A.ka,A.iU,A.iV,A.iW,A.iQ,A.iR,A.iS,A.iT,A.kP,A.jc,A.ji,A.jh,A.ks,A.kr])
r(A.ce,A.ei)
r(A.dw,A.bG)
q(A.eR,[A.eP,A.cD])
q(A.a2,[A.bx,A.f5])
q(A.e6,[A.ic,A.kl,A.k0,A.k7,A.jN,A.ii,A.il,A.jR,A.i9,A.hs,A.hK,A.hm,A.ho,A.hW,A.i_,A.hC,A.hU,A.hR,A.hS,A.hT,A.kH,A.kJ,A.kF,A.kL,A.kM,A.kO,A.kp,A.ko,A.kq,A.k3,A.ir,A.is,A.iK,A.jt,A.js,A.kh,A.ki,A.j5,A.jo,A.jp,A.jq,A.jr,A.fW,A.fC,A.fK,A.hc,A.je,A.jj,A.jk])
q(A.du,[A.ey,A.cJ])
q(A.cJ,[A.dL,A.dN])
r(A.dM,A.dL)
r(A.ds,A.dM)
r(A.dO,A.dN)
r(A.dt,A.dO)
q(A.ds,[A.ez,A.eA])
q(A.dt,[A.eB,A.eC,A.eD,A.eE,A.eF,A.dv,A.eG])
r(A.cY,A.f2)
q(A.e5,[A.jz,A.jA,A.jW,A.jE,A.jI,A.jH,A.jG,A.jF,A.jL,A.jK,A.jJ,A.jU,A.k6,A.hL,A.ht,A.hx,A.hr,A.hv,A.hV,A.hD,A.hE,A.hB,A.hF,A.hG,A.hH,A.hI,A.ip,A.io,A.j3,A.j4,A.j6,A.iF,A.fU,A.fS,A.h_,A.h7,A.fY,A.i3,A.i2,A.jd,A.jg])
r(A.ff,A.dV)
r(A.br,A.dP)
q(A.bO,[A.d5,A.eq])
q(A.e8,[A.fA,A.fz,A.ie,A.id])
r(A.er,A.dl)
r(A.jP,A.jQ)
q(A.bi,[A.dx,A.eh])
q(A.f1,[A.bj,A.ck,A.by,A.bS,A.cl,A.cd,A.df,A.bT,A.cF,A.b_,A.b0,A.bd,A.aJ,A.a7,A.aG,A.M,A.aI,A.cn,A.cp,A.bn,A.bk,A.bB,A.c9])
q(A.F,[A.ci,A.fd,A.e4,A.d3,A.fg,A.f4,A.fl,A.fn,A.eb,A.e_,A.eN,A.f8,A.eg,A.f_,A.fh,A.fc,A.fi,A.fm,A.fb,A.f0,A.fo,A.fe,A.fa,A.f7,A.b1,A.eX])
r(A.cN,A.fd)
r(A.cQ,A.fg)
r(A.ee,A.f4)
r(A.eQ,A.fl)
r(A.eT,A.fn)
r(A.cE,A.f8)
r(A.c7,A.f_)
r(A.dB,A.fh)
r(A.aH,A.fc)
r(A.ak,A.fi)
r(A.aB,A.fm)
r(A.aZ,A.fb)
r(A.b9,A.f0)
r(A.aC,A.fo)
r(A.bo,A.fe)
r(A.aY,A.fa)
r(A.ch,A.f7)
r(A.cC,A.eX)
s(A.dW,A.G)
s(A.dL,A.G)
s(A.dM,A.U)
s(A.dN,A.G)
s(A.dO,A.U)
s(A.eX,A.a5)
s(A.f_,A.a5)
s(A.f0,A.bf)
s(A.f4,A.a5)
s(A.f7,A.bf)
s(A.f8,A.a5)
s(A.fa,A.bf)
s(A.fb,A.bf)
s(A.fc,A.a5)
s(A.fd,A.a5)
s(A.fe,A.bf)
s(A.fg,A.a5)
s(A.fh,A.bf)
s(A.fi,A.a5)
s(A.fl,A.bf)
s(A.fm,A.a5)
s(A.fn,A.bf)
s(A.fo,A.bf)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{f:"int",e:"double",ay:"num",c:"String",v:"bool",ap:"Null",p:"List",J:"Object",h:"Map",a_:"JSObject"},mangledNames:{},types:["~()","v(H)","ap()","e(e,e)","v(e)","~(~())","v(I)","e(H)","v(aC)","~(f,f)","h<c,@>(be)","~(J?,J?)","f(c?)","h<c,@>(F)","c(e)","ap(@)","p<f>()","0^(0^,0^)<ay>","b2<f>()","h<c,@>(bQ)","aw(aw,aw)","e(e)","H(c,c)","p<aX>()","@(@)","e(I)","c(c,c,c)","e(e,b3)","e(cK)","h<c,e>()","ap(~())","v(ai<c,H?>)","@(@,c)","f(H,H)","f?(c)","v(f?)","c()","@(c)","p<c>()","~(c,e,e?,e)","~(c,p<+(I,e)>)","p<b4>()","c(aC)","v(c)","aS(aS,aS)","~(be,c)","~(c,c,c,e,e,c?{code:c,supplier:c})","f(al,al)","e(e,al)","e(e,b4)","p<H>()","~(a7,e{qty:e,size2:e})","A(H,c)","aX?(A,aG)","v(aX?,c)","c(a7)","~(f,e)","bv(bv)","~(@)","by(bv,b2<f>)","~(c,h<c,e>)","~(c,e)","f(+(I,e),+(I,e))","e(e,+(I,e))","c(aw)","v(F)","p<A>(F)","aG(F)","~(A,j<aG>{exclude:c?})","e(e,ba)","f(f,bA)","h<c,@>(cm)","h<c,@>(bA)","p<al>()","p<bD>()","e(e,H)","h<c,@>(aw)","I?(H)","h<c,@>(co)","h<c,@>(aS)","h<c,@>(cT)","h<c,@>(cM)","h<c,@>(b4)","h<c,@>(al)","h<c,@>(cc)","h<c,@>(bD)","ap(@,bX)","v(bm)","~(f,@)","v(+(e,e))","h<f,e>(h<f,e>)","~(c8)","f()","c(b0)","b0(@)","v(E)","E()","h<c,@>(E)","E(@)","p<e>(+(e,e))","c(c)","v(I?)","v(a3?)","v(aR?)","v(D?)","v(aP?)","f(I,I)","h<c,@>(I)","h<c,@>(a3)","h<c,@>(aR)","h<c,@>(D)","h<c,@>(aP)","h<c,@>(Y)","I(@)","a3(@)","aR(@)","D(@)","aP(@)","Y(@)","~(c,c)","bR(e,e,e{radiusM:e})","aF(e,e)","~(@,@)","p<A>()","A(@)","A()","e(c[e])","p<e>(A)","v(p<A>)","A(f)","e(e,A,A)","e(c,e)","h<c,@>(aA)","h<c,@>(b3)","aA(@)","p<aA>(p<aA>)","F(@)","b3(@)","e(A{fallback:e,neighbours:f})","A(bF)","v(J?)","f(+(e,f),+(e,f))","~(bZ)","f(f)","f(f,f)","ap(a_)","~(h<c,@>)","f(@,@)","ap(J,bX)","bl<~>()","+(e,e)(@)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.m&&a.b(c.a)&&b.b(c.b),"3;":(a,b,c)=>d=>d instanceof A.a&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;":a=>b=>b instanceof A.cX&&A.n0(a,b.a),"4;run,stage,zoneId,zoneIndex":a=>b=>b instanceof A.aT&&A.n0(a,b.a)}}
A.oW(v.typeUniverse,JSON.parse('{"eJ":"bV","cq":"bV","bU":"bV","qp":"cI","em":{"v":[],"O":[]},"dh":{"O":[]},"dj":{"a_":[]},"bV":{"a_":[]},"o":{"p":["1"],"y":["1"],"a_":[],"j":["1"]},"ek":{"dy":[]},"ib":{"o":["1"],"p":["1"],"y":["1"],"a_":[],"j":["1"]},"c5":{"R":["1"]},"cf":{"e":[],"ay":[],"aL":["ay"]},"dg":{"e":[],"f":[],"ay":[],"aL":["ay"],"O":[]},"en":{"e":[],"ay":[],"aL":["ay"],"O":[]},"cg":{"c":[],"aL":["c"],"iH":[],"O":[]},"c_":{"j":["2"]},"d6":{"R":["2"]},"c6":{"c_":["1","2"],"j":["2"],"j.E":"2"},"dJ":{"c6":["1","2"],"c_":["1","2"],"y":["2"],"j":["2"],"j.E":"2"},"dI":{"G":["2"],"p":["2"],"c_":["1","2"],"y":["2"],"j":["2"]},"ac":{"dI":["1","2"],"G":["2"],"p":["2"],"c_":["1","2"],"y":["2"],"j":["2"],"G.E":"2","j.E":"2"},"et":{"P":[]},"y":{"j":["1"]},"u":{"y":["1"],"j":["1"]},"dE":{"u":["1"],"y":["1"],"j":["1"],"j.E":"1","u.E":"1"},"aN":{"R":["1"]},"bz":{"j":["2"],"j.E":"2"},"cb":{"bz":["1","2"],"y":["2"],"j":["2"],"j.E":"2"},"dr":{"R":["2"]},"t":{"u":["2"],"y":["2"],"j":["2"],"j.E":"2","u.E":"2"},"B":{"j":["1"],"j.E":"1"},"dH":{"R":["1"]},"dz":{"j":["1"],"j.E":"1"},"i0":{"dz":["1"],"y":["1"],"j":["1"],"j.E":"1"},"dA":{"R":["1"]},"d9":{"y":["1"],"j":["1"],"j.E":"1"},"da":{"R":["1"]},"cr":{"j":["1"],"j.E":"1"},"bI":{"R":["1"]},"bp":{"u":["1"],"y":["1"],"j":["1"],"j.E":"1","u.E":"1"},"m":{"cV":[],"b5":[]},"a":{"cW":[],"b5":[]},"cX":{"cv":[],"b5":[]},"aT":{"cv":[],"b5":[]},"d7":{"h":["1","2"]},"b8":{"d7":["1","2"],"h":["1","2"]},"dK":{"j":["1"],"j.E":"1"},"ct":{"R":["1"]},"d8":{"bW":["1"],"b2":["1"],"y":["1"],"j":["1"]},"bP":{"d8":["1"],"bW":["1"],"b2":["1"],"y":["1"],"j":["1"]},"ei":{"az":[],"bw":[]},"ce":{"az":[],"bw":[]},"dw":{"bG":[],"P":[]},"ep":{"P":[]},"eW":{"P":[]},"dQ":{"bX":[]},"az":{"bw":[]},"e5":{"az":[],"bw":[]},"e6":{"az":[],"bw":[]},"eR":{"az":[],"bw":[]},"eP":{"az":[],"bw":[]},"cD":{"az":[],"bw":[]},"eO":{"P":[]},"bx":{"a2":["1","2"],"lQ":["1","2"],"h":["1","2"],"a2.K":"1","a2.V":"2"},"a4":{"y":["1"],"j":["1"],"j.E":"1"},"an":{"R":["1"]},"ao":{"y":["1"],"j":["1"],"j.E":"1"},"N":{"R":["1"]},"L":{"y":["ai<1,2>"],"j":["ai<1,2>"],"j.E":"ai<1,2>"},"ag":{"R":["ai<1,2>"]},"cV":{"b5":[]},"cW":{"b5":[]},"cv":{"b5":[]},"eo":{"oe":[],"iH":[]},"cI":{"a_":[],"O":[]},"du":{"a_":[]},"ey":{"a_":[],"O":[]},"cJ":{"aM":["1"],"a_":[]},"ds":{"G":["e"],"p":["e"],"aM":["e"],"y":["e"],"a_":[],"j":["e"],"U":["e"]},"dt":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"]},"ez":{"G":["e"],"p":["e"],"aM":["e"],"y":["e"],"a_":[],"j":["e"],"U":["e"],"O":[],"G.E":"e","U.E":"e"},"eA":{"bv":[],"G":["e"],"p":["e"],"aM":["e"],"y":["e"],"a_":[],"j":["e"],"U":["e"],"O":[],"G.E":"e","U.E":"e"},"eB":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"eC":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"eD":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"eE":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"eF":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"dv":{"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"eG":{"l6":[],"G":["f"],"p":["f"],"aM":["f"],"y":["f"],"a_":[],"j":["f"],"U":["f"],"O":[],"G.E":"f","U.E":"f"},"f2":{"P":[]},"cY":{"bG":[],"P":[]},"cw":{"R":["1"]},"c0":{"j":["1"],"j.E":"1"},"b7":{"P":[]},"ae":{"bl":["1"]},"dV":{"mb":[]},"ff":{"dV":[],"mb":[]},"br":{"bW":["1"],"lR":["1"],"b2":["1"],"y":["1"],"j":["1"]},"Q":{"R":["1"]},"a2":{"h":["1","2"]},"bW":{"b2":["1"],"y":["1"],"j":["1"]},"dP":{"bW":["1"],"b2":["1"],"y":["1"],"j":["1"]},"f5":{"a2":["c","@"],"h":["c","@"],"a2.K":"c","a2.V":"@"},"f6":{"u":["c"],"y":["c"],"j":["c"],"j.E":"c","u.E":"c"},"d5":{"bO":["p<f>","c"],"bO.S":"p<f>"},"dl":{"P":[]},"er":{"P":[]},"eq":{"bO":["J?","c"],"bO.S":"J?"},"bt":{"aL":["bt"]},"e":{"ay":[],"aL":["ay"]},"ca":{"aL":["ca"]},"f":{"ay":[],"aL":["ay"]},"p":{"y":["1"],"j":["1"]},"ay":{"aL":["ay"]},"b2":{"y":["1"],"j":["1"]},"c":{"aL":["c"],"iH":[]},"f1":{"Z":[]},"e1":{"P":[]},"bG":{"P":[]},"bi":{"P":[]},"dx":{"P":[]},"eh":{"P":[]},"dG":{"P":[]},"eU":{"P":[]},"dD":{"P":[]},"e7":{"P":[]},"eI":{"P":[]},"dC":{"P":[]},"fk":{"bX":[]},"cR":{"ok":[]},"bj":{"Z":[]},"ck":{"Z":[]},"by":{"Z":[]},"bS":{"Z":[]},"cl":{"Z":[]},"cd":{"Z":[]},"df":{"Z":[]},"bT":{"Z":[]},"cF":{"Z":[]},"b_":{"Z":[]},"b0":{"Z":[]},"bd":{"Z":[]},"aJ":{"Z":[]},"a7":{"Z":[]},"aG":{"Z":[]},"M":{"Z":[]},"aI":{"Z":[]},"ak":{"a5":[],"F":[]},"aB":{"a5":[],"F":[]},"aZ":{"F":[]},"aC":{"F":[]},"b1":{"F":[]},"cC":{"a5":[],"F":[]},"ci":{"F":[]},"cN":{"a5":[],"F":[]},"e4":{"F":[]},"d3":{"F":[]},"cQ":{"a5":[],"F":[]},"ee":{"a5":[],"F":[]},"eQ":{"F":[]},"eT":{"F":[]},"eb":{"F":[]},"e_":{"F":[]},"eN":{"F":[]},"cE":{"a5":[],"F":[]},"eg":{"F":[]},"c7":{"a5":[],"F":[]},"dB":{"F":[]},"aH":{"a5":[],"F":[]},"b9":{"F":[]},"bo":{"F":[]},"aY":{"F":[]},"ch":{"F":[]},"cn":{"Z":[]},"cp":{"Z":[]},"bn":{"Z":[]},"bk":{"Z":[]},"bB":{"Z":[]},"c9":{"Z":[]},"nU":{"p":["f"],"y":["f"],"j":["f"]},"l6":{"p":["f"],"y":["f"],"j":["f"]},"os":{"p":["f"],"y":["f"],"j":["f"]},"nS":{"p":["f"],"y":["f"],"j":["f"]},"oq":{"p":["f"],"y":["f"],"j":["f"]},"nT":{"p":["f"],"y":["f"],"j":["f"]},"or":{"p":["f"],"y":["f"],"j":["f"]},"nR":{"p":["e"],"y":["e"],"j":["e"]},"bv":{"p":["e"],"y":["e"],"j":["e"]}}'))
A.oV(v.typeUniverse,JSON.parse('{"dW":2,"cJ":1,"dP":1,"e8":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",h:"SHP: {r} registros, {n} entidades ({crs})",n:"{k}: {p} marcadores, {n} entidades ({crs})"}
var t=(function rtii(){var s=A.X
return{mu:s("cC"),t:s("b7"),fn:s("d5"),q:s("al"),bP:s("aL<@>"),lq:s("bP<c>"),cs:s("bt"),nJ:s("e9"),n6:s("bQ"),ks:s("c9"),jS:s("ca"),Y:s("y<@>"),cQ:s("ba"),h:s("F"),od:s("M"),fz:s("P"),na:s("a7"),kN:s("Y"),kI:s("bv"),mf:s("bk"),lG:s("cc"),m1:s("cd"),Z:s("bw"),G:s("H"),fC:s("H(c,c)"),cr:s("aX"),b:s("bm"),E:s("aG"),id:s("ce<e>"),lv:s("j<aG>"),bq:s("j<c>"),e7:s("j<@>"),o6:s("o<al>"),c:s("o<bQ>"),hz:s("o<ba>"),u:s("o<F>"),e0:s("o<dc>"),eK:s("o<Y>"),p4:s("o<cc>"),I:s("o<H>"),go:s("o<aX>"),lp:s("o<de>"),dr:s("o<aG>"),j8:s("o<aA>"),gv:s("o<p<A>>"),iA:s("o<p<e>>"),cH:s("o<cj>"),nE:s("o<dp>"),jv:s("o<dq>"),ot:s("o<ck>"),gN:s("o<h<c,e>>"),l0:s("o<h<f,e>>"),lH:s("o<cK>"),nB:s("o<E>"),iv:s("o<aZ>"),w:s("o<aw>"),dO:s("o<a3>"),A:s("o<be>"),D:s("o<I>"),eN:s("o<bA>"),i5:s("o<cm>"),C:s("o<A>"),fH:s("o<aP>"),an:s("o<+(I,e)>"),dD:s("o<+(c,bR)>"),fU:s("o<+(e,e)>"),ip:s("o<+(e,f)>"),hD:s("o<+(f,f)>"),kb:s("o<+(e,e,e)>"),nV:s("o<+(e,f,f)>"),h0:s("o<ak>"),s:s("o<c>"),iF:s("o<co>"),cu:s("o<bD>"),cD:s("o<b3>"),lT:s("o<b4>"),kU:s("o<aR>"),pn:s("o<bF>"),ae:s("o<bZ>"),eZ:s("o<aS>"),bD:s("o<D>"),n:s("o<e>"),dG:s("o<@>"),X:s("o<f>"),T:s("dh"),m:s("a_"),dY:s("bU"),dX:s("aM<@>"),df:s("aA"),hu:s("bn"),g_:s("eu"),e5:s("p<H>"),g2:s("p<aX>"),er:s("p<aA>"),ms:s("p<aw>"),d:s("p<I>"),V:s("p<A>"),x:s("p<+(I,e)>"),bF:s("p<c>"),k6:s("p<b3>"),bd:s("p<e>"),j:s("p<@>"),J:s("p<f>"),j5:s("ai<c,H?>"),U:s("h<c,e>"),P:s("h<c,@>"),dV:s("h<c,f>"),nh:s("h<e,ba>"),av:s("h<@,@>"),jq:s("h<f,e>"),L:s("h<c,p<H>>"),c8:s("h<c,H?>"),pa:s("t<c,f?>"),oX:s("eH"),mP:s("E"),a:s("ap"),K:s("J"),hF:s("bd"),o:s("aw"),fa:s("a3"),f7:s("b_"),h4:s("be"),p:s("I"),W:s("b0"),m9:s("b1"),n7:s("cl"),oY:s("cM"),fR:s("bA"),oz:s("cm"),f:s("a5"),c4:s("bB"),g:s("A"),dz:s("aP"),lZ:s("qr"),aK:s("+()"),kh:s("+(dc,e)"),ft:s("+(be,c)"),ca:s("+(I,e)"),kM:s("+(c,c)"),aL:s("+(e,e)"),mT:s("+(e,f)"),g9:s("bp<H>"),hZ:s("b2<H>"),Q:s("b2<c>"),nO:s("b2<f>"),fA:s("cn"),l:s("bX"),N:s("c"),ep:s("co"),eu:s("bD"),ai:s("aI"),k:s("b3"),ju:s("b4"),gs:s("aR"),oW:s("cp"),jH:s("bF"),aJ:s("O"),do:s("bG"),cx:s("cq"),nN:s("aS"),bn:s("aJ"),e4:s("D"),v:s("aC"),ji:s("B<p<A>>"),ee:s("B<e>"),hP:s("cr<aB>"),lF:s("cr<aC>"),jc:s("bI<cC>"),bo:s("bI<b1>"),kV:s("cT"),_:s("ae<@>"),cU:s("ae<~>"),iG:s("c0<+run,stage,zoneId,zoneIndex(~(),bj,c?,f)>"),y:s("v"),eV:s("v(p<A>)"),iW:s("v(J)"),eq:s("v(e)"),i:s("e"),z:s("@"),mY:s("@()"),mq:s("@(J)"),ng:s("@(J,bX)"),S:s("f"),e:s("b9?"),gK:s("bl<ap>?"),ga:s("bl<~>()?"),B:s("H?"),mU:s("a_?"),fm:s("p<c>?"),O:s("p<@>?"),md:s("h<c,c>?"),dZ:s("h<c,@>?"),iD:s("J?"),h2:s("a3?"),cV:s("I?"),gL:s("aP?"),bl:s("c?"),lJ:s("aR?"),kf:s("D?"),F:s("cs<@,@>?"),R:s("f9?"),o9:s("v?"),jX:s("e?"),aV:s("f?"),bw:s("f?(c)"),jh:s("ay?"),dn:s("~(c8)?"),H:s("ay"),r:s("~"),M:s("~()"),lc:s("~(c,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.db=J.ej.prototype
B.a=J.o.prototype
B.c=J.dg.prototype
B.b=J.cf.prototype
B.k=J.cg.prototype
B.dc=J.bU.prototype
B.dd=J.dj.prototype
B.bs=J.eJ.prototype
B.aP=J.cq.prototype
B.cM=new A.e3(1/0,1/0,-1/0,-1/0)
B.q=new A.ce(A.q6(),t.id)
B.H=new A.ce(A.q7(),t.id)
B.cP=new A.fA()
B.cN=new A.d5()
B.cO=new A.fz()
B.cQ=new A.ca()
B.cR=new A.da(A.X("da<0&>"))
B.aR=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.cS=function() {
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
B.cX=function(getTagFallback) {
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
B.cT=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.cW=function(hooks) {
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
B.cV=function(hooks) {
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
B.cU=function(hooks) {
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
B.aS=function(hooks) { return hooks; }

B.aT=new A.eq()
B.cY=new A.eI()
B.e=new A.j0()
B.u=new A.ff()
B.cZ=new A.fk()
B.aU=new A.bj(0,"zones")
B.d_=new A.bj(1,"mainline")
B.U=new A.bj(2,"splits")
B.d0=new A.bj(3,"flushing")
B.d1=new A.bj(4,"surge")
B.aV=new A.bj(5,"bom")
B.I=new A.aF(0,2,0)
B.aW=new A.aF(0.001,2,0)
B.aY=new A.M(0,"line")
B.aZ=new A.M(1,"polyline")
B.b_=new A.M(10,"radialDimension")
B.b0=new A.M(11,"leader")
B.b1=new A.M(12,"image")
B.b2=new A.M(13,"contour")
B.b3=new A.M(14,"spotHeight")
B.a9=new A.M(15,"pipe")
B.aa=new A.M(16,"sprayline")
B.ab=new A.M(17,"tape")
B.ac=new A.M(18,"outlet")
B.ad=new A.M(19,"controlValve")
B.b4=new A.M(2,"circle")
B.ae=new A.M(20,"waterSupply")
B.af=new A.M(21,"pump")
B.ag=new A.M(22,"misc")
B.ah=new A.M(23,"junction")
B.b5=new A.M(24,"area")
B.ai=new A.M(25,"pivot")
B.b6=new A.M(3,"arc")
B.b7=new A.M(4,"spline")
B.b8=new A.M(5,"hatch")
B.b9=new A.M(6,"symbol")
B.ba=new A.M(7,"text")
B.bb=new A.M(8,"dimension")
B.bc=new A.M(9,"angularDimension")
B.V=new A.a7(0,"coupler")
B.aj=new A.a7(1,"elbow90")
B.m=new A.a7(10,"riser")
B.ak=new A.a7(2,"elbow45")
B.J=new A.a7(3,"tee")
B.al=new A.a7(4,"cross")
B.v=new A.a7(5,"reducer")
B.K=new A.a7(6,"endCap")
B.am=new A.a7(7,"adapter")
B.w=new A.a7(8,"takeOff")
B.L=new A.a7(9,"tapeEnd")
B.d7=new A.dd("Not an OpenCADIrrigation project",null,null)
B.an=new A.cd(0,"hazenWilliams")
B.be=new A.cd(1,"darcyWeisbach")
B.d=new A.bS(0,"pipe")
B.W=new A.bS(1,"controlValve")
B.X=new A.bS(2,"pump")
B.d8=new A.bS(3,"device")
B.d9=new A.bS(4,"prv")
B.ao=new A.bT(0,"pipe")
B.bf=new A.bT(1,"pump")
B.M=new A.bT(2,"prv")
B.bg=new A.bT(3,"device")
B.da=new A.bT(4,"closed")
B.Y=new A.df(0,"junction")
B.Z=new A.df(1,"reservoir")
B.f=new A.aG(0,"zone")
B.h=new A.aG(1,"mainline")
B.de=new A.id(null)
B.df=new A.ie(null)
B.n=new A.cF(0,"open")
B.l=new A.cF(1,"closed")
B.x=new A.cF(2,"active")
B.p=new A.b0(0,"lateral")
B.i=new A.b0(1,"zone")
B.j=new A.b0(2,"mainline")
B.dk=s([B.p,B.i,B.j],A.X("o<b0>"))
B.a1=new A.bd(0,"sprinkler")
B.ar=new A.bd(1,"microSprinkler")
B.as=new A.bd(2,"dripper")
B.dQ=new A.bd(3,"bubbler")
B.bp=new A.bd(4,"gun")
B.bq=new A.bd(5,"demandPoint")
B.dl=s([B.a1,B.ar,B.as,B.dQ,B.bp,B.bq],A.X("o<bd>"))
B.aX=new A.c9(0,"mm")
B.d2=new A.c9(1,"inch")
B.dm=s([B.aX,B.d2],A.X("o<c9>"))
B.o=new A.b_(3e9,0,"pvc")
B.y=new A.b_(9e8,1,"pehd")
B.at=new A.b_(3e8,2,"peld")
B.br=new A.b_(2e11,3,"steel")
B.dR=new A.b_(17e10,4,"ductileIron")
B.dT=new A.b_(7e10,5,"aluminium")
B.dS=new A.b_(3e10,6,"concrete")
B.dn=s([B.o,B.y,B.at,B.br,B.dR,B.dT,B.dS],A.X("o<b_>"))
B.dp=s([B.an,B.be],A.X("o<cd>"))
B.D=s([B.f,B.h],t.dr)
B.E=new A.cl(0,"pivot")
B.dU=new A.cl(1,"linear")
B.dq=s([B.E,B.dU],A.X("o<cl>"))
B.dr=s([B.aY,B.aZ,B.b4,B.b6,B.b7,B.b8,B.b9,B.ba,B.bb,B.bc,B.b_,B.b0,B.b1,B.b2,B.b3,B.a9,B.aa,B.ab,B.ac,B.ad,B.ae,B.af,B.ag,B.ah,B.b5,B.ai],A.X("o<M>"))
B.a6=new A.cn(0,"lp")
B.yH=new A.cn(1,"greedy")
B.ds=s([B.a6,B.yH],A.X("o<cn>"))
B.aO=new A.cp(0,"tin")
B.yR=new A.cp(1,"idw")
B.dt=s([B.aO,B.yR],A.X("o<cp>"))
B.du=s(["id","de","en","es","fr","ha","sw","pt","vi","tr","ru","ar","ur","hi","mr","bn","pa","te","zh","ja"],t.s)
B.B=new A.aJ(0,"control")
B.R=new A.aJ(1,"prv")
B.S=new A.aJ(2,"isolation")
B.T=new A.aJ(3,"check")
B.aQ=new A.aJ(4,"backflow")
B.C=new A.aJ(5,"filter")
B.a7=new A.aJ(6,"meter")
B.a8=new A.aJ(7,"airRelease")
B.z3=new A.aJ(8,"other")
B.dv=s([B.B,B.R,B.S,B.T,B.aQ,B.C,B.a7,B.a8,B.z3],A.X("o<aJ>"))
B.yI=new A.aI(0,"northArrow")
B.yJ=new A.aI(1,"tree")
B.yK=new A.aI(2,"building")
B.yL=new A.aI(3,"tank")
B.yM=new A.aI(4,"well")
B.yN=new A.aI(5,"valveBox")
B.yO=new A.aI(6,"pumpHouse")
B.yP=new A.aI(7,"gate")
B.yQ=new A.aI(8,"filterStation")
B.dw=s([B.yI,B.yJ,B.yK,B.yL,B.yM,B.yN,B.yO,B.yP,B.yQ],A.X("o<aI>"))
B.bj=s([],t.c)
B.dy=s([],t.I)
B.dA=s([],t.nB)
B.dz=s([],t.w)
B.bk=s([],t.A)
B.bl=s([],t.D)
B.dx=s([],t.C)
B.dB=s([],t.iF)
B.dC=s([],t.eZ)
B.bi=s([],t.n)
B.z4=s([],t.dD)
B.bh=new A.bn(0,"m")
B.dg=new A.bn(1,"mm")
B.dh=new A.bn(2,"cm")
B.di=new A.bn(3,"ft")
B.dj=new A.bn(4,"inch")
B.dD=s([B.bh,B.dg,B.dh,B.di,B.dj],A.X("o<bn>"))
B.bt=new A.bB(0,"mH2O")
B.dV=new A.bB(1,"kPa")
B.dW=new A.bB(2,"bar")
B.dX=new A.bB(3,"psi")
B.dE=s([B.bt,B.dV,B.dW,B.dX],A.X("o<bB>"))
B.bd=new A.bk(0,"lph")
B.d3=new A.bk(1,"lpm")
B.d4=new A.bk(2,"lps")
B.d5=new A.bk(3,"m3h")
B.d6=new A.bk(4,"gpm")
B.dF=s([B.bd,B.d3,B.d4,B.d5,B.d6],A.X("o<bk>"))
B.dG=s([B.V,B.aj,B.ak,B.J,B.al,B.v,B.K,B.am,B.w,B.L,B.m],A.X("o<a7>"))
B.dH=s(["no_water_supply"],t.s)
B.dI=s(["IMAGES","DRAWING","HATCHES","SYMBOLS","TEXT","DIMENSIONS","CONTOURS","SPOT_HEIGHTS","DEM","ZONE_PIPES","MAINLINE_PIPES","SPRAYLINES","TAPES","OUTLETS","WETTED_RADII","CONTROL_VALVES","WATER_SUPPLY","PUMPS","MISC_HYDRAULIC","JUNCTIONS","PIVOTS","AREAS","LABELS"],t.s)
B.a_=new A.ck(0,"le")
B.ap=new A.ck(1,"eq")
B.bm=new A.ck(2,"ge")
B.N=new A.by(0,"optimal")
B.dJ=new A.by(1,"infeasible")
B.dK=new A.by(2,"unbounded")
B.bn=new A.by(3,"iterationLimit")
B.dO={"app.title":0,ok:1,cancel:2,apply:3,close:4,auto:5,clear:6,"menu.file":7,"menu.edit":8,"menu.view":9,"menu.draw":10,"menu.zone":11,"menu.mainline":12,"menu.design":13,"menu.reports":14,"menu.tools":15,"menu.help":16,"file.new":17,"file.open":18,"file.save":19,"file.exportDxf":20,"file.exportDrawing":21,"file.exportReport":22,"file.georef":23,"file.newTab":24,"file.closeTab":25,"tab.new":26,"tab.close":27,"edit.clipCopy":28,"edit.clipCut":29,"edit.paste":30,"msg.copied":31,"msg.cut":32,"msg.pipeCut":33,"msg.pasted":34,"msg.nothingSelected":35,"msg.clipboardEmpty":36,"msg.unknownCommand":37,"status.command":38,"help.shortcuts":39,"sc.title":40,"sc.intro":41,"sc.file":42,"sc.edit":43,"sc.view":44,"sc.commands":45,"sc.hydraulic":46,"sc.switchTab":47,"sc.cancel":48,"sc.finish":49,"sc.undoPoint":50,"sc.repeat":51,"sc.zoom":52,"sc.pan":53,"sc.panHold":54,"sc.reports":55,"sc.gridDisplay":56,"sc.angleLock":57,"sc.autoRun":58,"sc.toggles":59,"sc.designCmds":60,"exp.dxf":61,"exp.dwg":62,"exp.pdf":63,"exp.svg":64,"exp.kml":65,"exp.kmz":66,"exp.geojson":67,"exp.csv":68,"exp.txt":69,"exp.xlsx":70,"exp.reportPdf":71,"msg.exported":72,"msg.needResults":73,"msg.nothingToExport":74,"msg.georefSet":75,"geo.title":76,"geo.explain":77,"geo.modeLatLon":78,"geo.modeUtm":79,"geo.lat":80,"geo.lon":81,"geo.zone":82,"geo.north":83,"geo.easting":84,"geo.northing":85,"geo.current":86,"geo.none":87,"geo.remove":88,"geo.invalid":89,"plot.title":90,"plot.page":91,"plot.orientation":92,"plot.landscape":93,"plot.portrait":94,"plot.scale":95,"plot.scaleAuto":96,"plot.wetted":97,"plot.labels":98,"plot.legend":99,"plot.reports":100,"plot.export":101,"plot.fits":102,"pdf.date":103,"pdf.scale":104,"pdf.sheet":105,"pdf.origin":106,"pdf.summary":107,"pdf.crs":108,"pdf.local":109,"pdf.legend":110,"pdf.subtitle":111,"pdf.reportTitle":112,"pdf.generated":113,"pdf.page":114,"pdf.cont":115,"pdf.noResults":116,"pdf.params":117,"layer.DRAWING":118,"layer.TEXT":119,"layer.DIMENSIONS":120,"layer.CONTOURS":121,"layer.SPOT_HEIGHTS":122,"layer.DEM":123,"layer.ZONE_PIPES":124,"layer.MAINLINE_PIPES":125,"layer.SPRAYLINES":126,"layer.TAPES":127,"layer.OUTLETS":128,"layer.WETTED_RADII":129,"layer.CONTROL_VALVES":130,"layer.WATER_SUPPLY":131,"layer.PUMPS":132,"layer.MISC_HYDRAULIC":133,"layer.JUNCTIONS":134,"layer.AREAS":135,"layer.LABELS":136,"file.details":137,"edit.undo":138,"edit.redo":139,"edit.delete":140,"edit.selectAll":141,"edit.copy":142,"view.zoomAll":143,"view.zoomIn":144,"view.zoomOut":145,"view.grid":146,"view.labels":147,"view.wetted":148,"view.overlay.none":149,"view.overlay.velocity":150,"view.overlay.pressure":151,"view.overlay.sizes":152,"view.layers":153,"view.language":154,"lang.pt":155,"lang.en":156,"lang.es":157,"design.params":158,"design.management":159,"design.check":160,"design.zone":161,"design.analyze":162,"design.mainline":163,"design.all":164,"design.clear":165,"design.progress.title":166,"design.progress.start":167,"design.progress.zones":168,"design.progress.mainline":169,"design.progress.splits":170,"design.progress.flushing":171,"design.progress.surge":172,"design.progress.bom":173,"design.progress.bg":174,"design.progress.hint":175,"design.catalog":176,"design.block":177,"design.autohead":178,"reports.zone":179,"reports.pipes":180,"reports.outlets":181,"reports.mainline":182,"reports.devices":183,"reports.bom":184,"reports.water":185,"reports.hgl":186,"reports.messages":187,"tools.lateral":188,"tools.pump":189,"tools.hammer":190,"tools.units":191,"help.about":192,"help.tutorial":193,"tool.select":194,"tool.pan":195,"tool.line":196,"tool.polyline":197,"tool.rect":198,"tool.circle":199,"tool.text":200,"tool.dimension":201,"tool.contour":202,"tool.spot":203,"tool.area":204,"tool.zonePipe":205,"tool.mainPipe":206,"tool.sprayline":207,"tool.tape":208,"tool.outlet":209,"tool.valve":210,"tool.supply":211,"tool.pump":212,"tool.misc":213,"tool.junction":214,"tool.block":215,"tool.autohead":216,"tool.measure":217,"hint.select":218,"hint.pan":219,"hint.line":220,"hint.polyline":221,"hint.rect":222,"hint.circle":223,"hint.text":224,"hint.dimension":225,"hint.contour":226,"hint.spot":227,"hint.area":228,"hint.pipe":229,"hint.point":230,"hint.block":231,"hint.measure":232,"status.ready":233,"status.snap":234,"status.grid":235,"status.ortho":236,"status.keepLinks":237,"status.keepLinksTip":238,"status.entities":239,"props.title":240,"props.none":241,"props.multi":242,"props.layer":243,"props.name":244,"props.pipe":245,"props.auto":246,"props.depth":247,"props.outlet":248,"props.nozzle":249,"props.head":250,"props.spacing":251,"props.offset":252,"props.arc":253,"props.riser":254,"props.tape":255,"props.inlet":256,"props.regulated":257,"props.submainMin":258,"props.valve":259,"props.zone":260,"props.fixedHead":261,"props.calc":262,"props.designHead":263,"props.maxHead":264,"props.designFlow":265,"props.maxFlow":266,"props.waterLevel":267,"props.pump":268,"props.speed":269,"props.misc":270,"props.setting":271,"props.elevation":272,"props.elevationDem":273,"props.text":274,"props.textHeight":275,"props.radius":276,"props.closed":277,"props.netDepth":278,"props.efficiency":279,"props.crop":280,"props.length":281,"props.area":282,"props.outlets":283,"props.scope":284,"props.results":285,"props.orientation":286,"props.rotation":287,"props.dimOffset":288,"props.zoomTo":289,"props.halfSpacing":290,"props.downstream":291,"props.required":292,"props.valveLoss":293,"props.emitterMinMax":294,"props.allowed":295,"props.uniformity":296,"props.defaults":297,"scope.zone":298,"scope.mainline":299,"result.flow":300,"result.velocity":301,"result.loss":302,"result.pressure":303,"result.pStart":304,"result.pEnd":305,"result.min":306,"result.max":307,"msg.saved":308,"msg.loaded":309,"msg.designDone":310,"msg.unconnected":311,"msg.allConnected":312,"msg.designBusy":313,"msg.designStale":314,"msg.noValves":315,"msg.deleted":316,"msg.imported":317,"msg.error":318,"msg.unsavedConfirm":319,"msg.noResults":320,"msg.noAreas":321,"msg.selectForHgl":322,"msg.noMessages":323,"msg.unconnectedItem":324,"imp.dwg":325,"imp.skipped":326,"imp.kml":327,"imp.dxf":328,"dwg.notDwg":329,"dwg.corrupt":330,"kmz.noKml":331,"rep.zone":332,"rep.valve":333,"rep.emitters":334,"rep.flow":335,"rep.pDown":336,"rep.valveLoss":337,"rep.pRequired":338,"rep.pMin":339,"rep.pMax":340,"rep.allowMin":341,"rep.allowMax":342,"rep.varAllow":343,"rep.varActual":344,"rep.pipeCost":345,"rep.warnings":346,"rep.context":347,"rep.entity":348,"rep.segment":349,"rep.pipe":350,"rep.innerDiam":351,"rep.length":352,"rep.q":353,"rep.velocity":354,"rep.hf":355,"rep.pStart":356,"rep.pEnd":357,"rep.zStart":358,"rep.zEnd":359,"rep.pn":360,"rep.emitter":361,"rep.n":362,"rep.qTotal":363,"rep.qMean":364,"rep.flowName":365,"rep.item":366,"rep.pAvailable":367,"rep.status":368,"rep.energyYear":369,"rep.supply":370,"rep.pump":371,"rep.device":372,"rep.calculated":373,"rep.surplus":374,"rep.fixed":375,"rep.deficit":376,"rep.ok":377,"rep.pumpHead":378,"rep.pIn":379,"rep.pOut":380,"rep.loss":381,"rep.st.running":382,"rep.st.stopped":383,"rep.st.open":384,"rep.st.closed":385,"rep.st.active":386,"rep.suction":387,"rep.submersible":388,"rep.outOfRange":389,"rep.category":390,"rep.description":391,"rep.unit":392,"rep.quantity":393,"rep.unitCost":394,"rep.total":395,"rep.totalRow":396,"rep.annualCapital":397,"rep.annualEnergy":398,"rep.annualTotal":399,"rep.area":400,"rep.grossDepth":401,"rep.volume":402,"rep.rate":403,"rep.hoursDay":404,"hgl.legend":405,"csv.zones":406,"csv.flows":407,"csv.bom":408,"bom.pipes":409,"bom.tapes":410,"bom.outlets":411,"bom.valves":412,"bom.devices":413,"bom.pumps":414,"name.zone":415,"name.supply":416,"name.allZones":417,"name.submain":418,"name.stub":419,"name.lateral":420,"name.area":421,"name.newProject":422,"name.text":423,"name.flow":424,"name.report":425,"ex.name":426,"ex.client":427,"ex.site":428,"ex.boundary":429,"ex.title":430,"ex.zoneA":431,"ex.zoneB":432,"ex.blockA":433,"ex.blockB":434,"ex.citrus":435,"ex.grape":436,"ex.riser":437,"ex.branchA":438,"ex.branchB":439,"ex.well":440,"ex.flow1":441,"ex.flow2":442,"dlg.project":443,"dlg.client":444,"dlg.site":445,"dlg.designer":446,"dlg.notes":447,"dlg.hydraulics":448,"dlg.frictionFormula":449,"dlg.hw":450,"dlg.dw":451,"dlg.waterTemp":452,"dlg.vLateral":453,"dlg.vZone":454,"dlg.vMain":455,"dlg.minorPct":456,"dlg.connectTol":457,"dlg.applyMinor":458,"dlg.cScale":459,"dlg.cOffset":460,"dlg.sizing":461,"dlg.maxSubmainSizes":462,"dlg.densify":463,"dlg.economics":464,"dlg.tradeCapital":465,"dlg.interest":466,"dlg.term":467,"dlg.energyCost":468,"dlg.pumpEff":469,"dlg.hoursMain":470,"dlg.hoursZone":471,"dlg.currency":472,"dlg.metric":473,"dlg.us":474,"dlg.length":475,"dlg.flow":476,"dlg.pressure":477,"dlg.diameter":478,"dlg.allTogether":479,"dlg.oneAtATime":480,"dlg.addFlow":481,"dlg.name":482,"dlg.startHour":483,"dlg.durationHours":484,"dlg.noFlows":485,"dlg.sprayBlock":486,"dlg.dripBlock":487,"dlg.laterals":488,"dlg.emitterSpacing":489,"dlg.lateralPipe":490,"dlg.lateralSpacing":491,"dlg.lateralDirection":492,"dlg.submainValve":493,"dlg.submainPosition":494,"dlg.submainStart":495,"dlg.submainCentre":496,"dlg.submainEnd":497,"dlg.submainPipe":498,"dlg.valvePosition":499,"dlg.posStart":500,"dlg.posCentre":501,"dlg.posEnd":502,"dlg.stub":503,"dlg.spacingPct":504,"dlg.direction":505,"dlg.square":506,"dlg.triangular":507,"dlg.gridSummary":508,"dlg.tapeLateral":509,"dlg.emitterLateral":510,"dlg.slope":511,"dlg.tolBelow":512,"dlg.tolAbove":513,"dlg.results":514,"dlg.emittersCount":515,"dlg.inletFlow":516,"dlg.totalLoss":517,"dlg.endPressure":518,"dlg.pMinMax":519,"dlg.pVariation":520,"dlg.maxVelocity":521,"dlg.uniformity4":522,"dlg.qvar":523,"dlg.maxLength":524,"dlg.staticHead":525,"dlg.speed":526,"dlg.mainPipe":527,"dlg.hoursYear":528,"dlg.operatingPoint":529,"dlg.pumpCannot":530,"dlg.head":531,"dlg.velocityMain":532,"dlg.hydraulicPower":533,"dlg.shaftPower":534,"dlg.annualEnergy":535,"dlg.shutoffRunout":536,"dlg.velocity":537,"dlg.closureTime":538,"dlg.staticPressure":539,"dlg.resultJoukowsky":540,"dlg.celerity":541,"dlg.maxSurge":542,"dlg.criticalTime":543,"dlg.estSurge":544,"dlg.totalPressure":545,"dlg.pipeClass":546,"cat.pipes":547,"cat.outlets":548,"cat.tapes":549,"cat.valves":550,"cat.pumps":551,"cat.use":552,"cat.name":553,"cat.dn":554,"cat.idmm":555,"cat.c":556,"cat.pn":557,"cat.costM":558,"cat.outlet":559,"cat.nozzle":560,"cat.k":561,"cat.x":562,"cat.pMin":563,"cat.pMax":564,"cat.pDefault":565,"cat.cv":566,"cat.tol":567,"cat.cost":568,"cat.spacing":569,"cat.qNom":570,"cat.kd":571,"cat.type":572,"cat.kLoss":573,"cat.n":574,"cat.qMax":575,"cat.points":576,"cat.eff":577,"cat.submersible":578,"cat.hint":579,"mat.pvc":580,"mat.pehd":581,"mat.peld":582,"mat.steel":583,"mat.ductileIron":584,"mat.aluminium":585,"mat.concrete":586,"warn.not_converged":587,"warn.cannot_meet_pressure_window":588,"warn.mainline_cannot_meet_pressure":589,"warn.no_water_supply":590,"warn.outlet_over_pressure":591,"warn.outlet_under_pressure":592,"warn.pressure_rating_exceeded":593,"warn.pump_out_of_range":594,"warn.pump_suction_lift":595,"warn.supply_flow_exceeded":596,"warn.supply_head_exceeded":597,"warn.valve_flow_out_of_range":598,"warn.valve_missing":599,"warn.valve_pressure_deficit":600,"warn.valve_unreachable":601,"warn.velocity_exceeded":602,"warn.zone_empty":603,"warn.zone_overlap":604,"warn.valve_no_zone_pipes":605,"warn.outlet_spec_missing":606,"warn.tape_spec_missing":607,"warn.pump_spec_missing":608,"warn.valve_spec_missing":609,"warn.no_fixed_head_node":610,"warn.page_missing":611,"about.text":612,"about.version":613,"about.site":614,"tool.arc":615,"tool.spline":616,"tool.hatch":617,"tool.symbol":618,"tool.dimAngular":619,"tool.dimRadial":620,"tool.leader":621,"tool.rotate":622,"tool.mirror":623,"tool.scale":624,"tool.offset":625,"tool.trim":626,"tool.extend":627,"tool.cutPipe":628,"tool.profile":629,"hint.arc":630,"hint.spline":631,"hint.hatch":632,"hint.symbol":633,"hint.dimAngular":634,"hint.dimRadial":635,"hint.leader":636,"hint.rotate":637,"hint.mirror":638,"hint.scale":639,"hint.offset":640,"hint.trim":641,"hint.extend":642,"hint.cutPipe":643,"hint.profile":644,"edit.transform":645,"edit.array":646,"edit.feed":647,"arr.title":648,"arr.rect":649,"arr.polar":650,"arr.rows":651,"arr.cols":652,"arr.dx":653,"arr.dy":654,"arr.angle":655,"arr.count":656,"arr.center":657,"arr.total":658,"arr.rotateItems":659,"arr.selection":660,"msg.layerLocked":661,"msg.noIntersection":662,"msg.selectLateral":663,"msg.feedComputed":664,"msg.arrayDone":665,"view.overlay.minMax":666,"view.baseMap":667,"view.baseMap.none":668,"view.baseMap.streets":669,"view.baseMap.satellite":670,"view.baseMap.topo":671,"view.baseMap.carto":672,"view.baseMap.esriStreets":673,"view.baseMap.esriTopo":674,"view.baseMap.googleRoads":675,"view.baseMap.googleSatellite":676,"view.baseMap.googleHybrid":677,"view.baseMap.googleTerrain":678,"view.baseMap.custom":679,"view.baseMap.googleKey":680,"view.baseMap.customUrl":681,"basemap.googleKey.title":682,"basemap.googleKey.explain":683,"basemap.googleKey.steps":684,"basemap.googleKey.console":685,"basemap.googleKey.docs":686,"basemap.googleKey.field":687,"basemap.googleKey.privacy":688,"basemap.googleKey.remove":689,"basemap.googleKeyMissing":690,"basemap.googleError":691,"basemap.custom.title":692,"basemap.custom.explain":693,"basemap.custom.field":694,"basemap.custom.placeholders":695,"basemap.customInvalid":696,"view.baseMapNeedsGeo":697,"view.grips":698,"zone.feedEnvelope":699,"layer.current":700,"layer.lock":701,"layer.add":702,"layer.rename":703,"layer.delete":704,"layer.color":705,"layer.name":706,"layer.exists":707,"layer.hint":708,"props.batch":709,"props.mixed":710,"props.symbolKind":711,"props.symbolSize":712,"props.hatchAngle":713,"props.hatchSpacing":714,"props.hatchSolid":715,"props.opacity":716,"props.imageWidth":717,"props.imageHeight":718,"props.source":719,"props.emittersPerPlant":720,"props.waterBalance":721,"props.eto":722,"props.kc":723,"props.kcPreset":724,"props.awc":725,"props.rootDepth":726,"props.mad":727,"props.wettedFraction":728,"props.plantSpacing":729,"props.rowSpacing":730,"props.etc":731,"props.interval":732,"props.offsetDistance":733,"props.copyOnTransform":734,"props.mirrorKeep":735,"props.splitOnInsert":736,"props.splineClosed":737,"props.angle":738,"props.leaderText":739,"props.dimRadius":740,"props.locked":741,"props.flushingFlow":742,"props.envelope":743,"props.envelopeBest":744,"props.envelopeRange":745,"props.envelopeNone":746,"sym.northArrow":747,"sym.tree":748,"sym.building":749,"sym.tank":750,"sym.well":751,"sym.valveBox":752,"sym.pumpHouse":753,"sym.gate":754,"sym.filterStation":755,"crop.citrus":756,"crop.grape":757,"crop.coffee":758,"crop.banana":759,"crop.mango":760,"crop.apple":761,"crop.tomato":762,"crop.maize":763,"crop.sugarcane":764,"crop.vegetables":765,"crop.turf":766,"crop.pasture":767,"crop.custom":768,"reports.flushing":769,"reports.surge":770,"reports.crop":771,"reports.schedule":772,"reports.profile":773,"rep.code":774,"rep.tapes":775,"rep.vFlush":776,"rep.celerity":777,"rep.surge":778,"rep.pStatic":779,"rep.pTotal":780,"rep.tCritical":781,"rep.raw":782,"rep.interval":783,"rep.netEvent":784,"rep.grossEvent":785,"rep.hoursEvent":786,"rep.overlapCu":787,"sch.date":788,"sch.flow":789,"sch.zones":790,"sch.start":791,"sch.end":792,"sch.duration":793,"prof.distance":794,"prof.elevation":795,"prof.hint":796,"prof.slope":797,"fit.coupler":798,"fit.elbow90":799,"fit.elbow45":800,"fit.tee":801,"fit.cross":802,"fit.reducer":803,"fit.endCap":804,"fit.adapter":805,"fit.takeOff":806,"fit.tapeEnd":807,"fit.riser":808,"bom.fittings":809,"bom.takeoffs":810,"bom.risers":811,"cat.fittings":812,"cat.kind":813,"cat.size2":814,"cat.supplier":815,"cat.code":816,"cat.add":817,"cat.duplicate":818,"cat.remove":819,"cat.import":820,"cat.export":821,"cat.exportCsv":822,"cat.reset":823,"cat.setDefault":824,"cat.importHint":825,"cat.removeConfirm":826,"cat.inUse":827,"msg.catalogImported":828,"msg.catalogDefaultSaved":829,"msg.catalogReset":830,"warn.lp_infeasible":831,"warn.fitting_missing":832,"warn.surge_rating_exceeded":833,"warn.schedule_no_area":834,"warn.schedule_over_24h":835,"file.importDrawing":836,"imp.points":837,"imp.shp":838,"imp.image":839,"imp.imageGeo":840,"imp.err.dem_bad_response":841,"imp.err.dem_bad_tile":842,"imp.err.dem_count_mismatch":843,"imp.err.points_empty":844,"imp.err.points_no_columns":845,"imp.err.shp_bad_header":846,"imp.err.shp_zip_no_shp":847,"imp.err.image_zip_no_image":848,"imp.err.image_unreadable":849,"file.georefImage":850,"gimg.title":851,"gimg.explain":852,"gimg.keepAspect":853,"dlg.sizingMethod":854,"dlg.lp":855,"dlg.greedy":856,"dlg.maxLateralSizes":857,"dlg.maxMainlineSizes":858,"dlg.epp":859,"dlg.maxNodes":860,"dlg.zoneVar":861,"dlg.flushing":862,"dlg.flushV":863,"dlg.flushH":864,"dlg.checkSurge":865,"dlg.closure":866,"dlg.bom":867,"dlg.fittings":868,"dlg.stick":869,"design.pumpSelect":870,"design.dem3d":871,"pump.title":872,"pump.duty":873,"pump.supply":874,"pump.candidates":875,"pump.hAtDuty":876,"pump.margin":877,"pump.opPoint":878,"pump.power":879,"pump.parallel":880,"pump.energy":881,"pump.insert":882,"pump.replace":883,"pump.noSupply":884,"pump.unsuitable":885,"pump.suction":886,"msg.pumpApplied":887,"dem.title":888,"dem.exaggeration":889,"dem.hint":890,"dem.noData":891,"dem.range":892,"file.recent":893,"file.noRecent":894,"file.versions":895,"file.autosave":896,"rec.title":897,"rec.text":898,"rec.restore":899,"rec.discard":900,"rec.later":901,"rec.item":902,"msg.recovered":903,"ver.title":904,"ver.none":905,"ver.restore":906,"ver.item":907,"msg.versionRestored":908,"mgmt.flows":909,"mgmt.schedule":910,"mgmt.apply":911,"mgmt.export":912,"mgmt.days":913,"mgmt.dayStart":914,"mgmt.keepStart":915,"mgmt.maxDaily":916,"mgmt.needResults":917,"mgmt.perFlow":918,"sc.editCmds":919,"sc.gripRemove":920,"sc.gripInsert":921,"sc.touch":922,"tool.pivot":923,"hint.pivot":924,"tool.alignImage":925,"hint.alignImage":926,"align.step1":927,"align.step2":928,"align.step3":929,"align.step4":930,"align.keepScale":931,"msg.alignDone":932,"msg.alignSelectFirst":933,"msg.profileCleared":934,"elev.title":935,"elev.contourTitle":936,"elev.spotTitle":937,"elev.value":938,"elev.interval":939,"elev.autoIncrement":940,"elev.ask":941,"elev.explainContour":942,"elev.explainSpot":943,"menu.terrain":944,"terrain.onlineDem":945,"terrain.generateContours":946,"terrain.method":947,"terrain.tin":948,"terrain.idw":949,"terrain.clearProfile":950,"terrain.stats":951,"terrain.none":952,"dlg.terrainMethod":953,"dem.online.title":954,"dem.online.explain":955,"dem.online.source":956,"dem.online.spacing":957,"dem.online.extent":958,"dem.online.replace":959,"dem.online.existing":960,"dem.online.replaceExisting":961,"dem.online.keepWarn":962,"dem.online.mismatchTitle":963,"dem.online.mismatch":964,"dem.online.mismatchRemove":965,"dem.online.mismatchKeep":966,"dem.online.wait":967,"dem.online.estimate":968,"dem.online.limitHint":969,"dem.online.cancelled":970,"dem.online.noData":971,"dem.online.layerHint":972,"dem.online.useView":973,"dem.online.run":974,"dem.online.progress":975,"dem.online.done":976,"dem.online.needGeo":977,"dem.online.error":978,"dem.online.empty":979,"cgen.title":980,"cgen.explain":981,"cgen.interval":982,"cgen.replace":983,"cgen.preview":984,"cgen.done":985,"cgen.run":986,"prof.clear":987,"prof.ground":988,"prof.pipe":989,"prof.hgl":990,"prof.lowest":991,"prof.highest":992,"prof.howTo":993,"prof.noTerrain":994,"prof.station":995,"prof.pressure":996,"prof.pathLabel":997,"reports.pivots":998,"rep.pivot":999,"rep.type":1000,"rep.towers":1001,"rep.pAvail":1002,"rep.rise":1003,"rep.depthCycle":1004,"rep.hoursCycle":1005,"rep.appRatePeak":1006,"pivot.kindPivot":1007,"pivot.kindLinear":1008,"pivot.towers":1009,"bom.pivots":1010,"warn.pivot_pressure_deficit":1011,"warn.pivot_app_rate":1012,"warn.pivot_no_flow":1013,"warn.pivot_no_end_pressure":1014,"props.pivotKind":1015,"props.pivotRadius":1016,"props.pivotSpan":1017,"props.pivotTravel":1018,"props.pivotPipe":1019,"props.pivotPipeId":1020,"props.pivotC":1021,"props.pivotHeight":1022,"props.pivotEndP":1023,"props.pivotGunQ":1024,"props.pivotGunP":1025,"props.pivotThrow":1026,"props.pivotDepth":1027,"props.pivotHours":1028,"props.pivotWidth":1029,"props.pivotLoss":1030,"props.pivotMaxRate":1031,"props.pivotSector":1032,"props.pivotCost":1033,"props.pivotAngle":1034,"props.pivotResults":1035,"props.pivotArea":1036,"props.pivotInlet":1037,"props.contourInterval":1038,"props.derived":1039,"check.title":1040,"check.explain":1041,"check.summary":1042,"check.ok":1043,"check.run":1044,"check.sev.error":1045,"check.sev.warning":1046,"check.sev.info":1047,"check.no_hydraulics":1048,"check.no_supply":1049,"check.no_valves":1050,"check.unconnected":1051,"check.zone_no_emitters":1052,"check.duplicate_zone_name":1053,"check.mainline_dead_end":1054,"check.zone_dead_end":1055,"check.zero_length":1056,"check.tiny_segment":1057,"check.duplicate_item":1058,"check.pipes_cross":1059,"check.spec_missing":1060,"check.supply_no_head":1061,"check.pivot_unconnected":1062,"check.no_terrain":1063,"check.looped_mainline":1064,"check.area_no_emitters":1065,"design.checkFull":1066,"cat.packs":1067,"cat.packsExplain":1068,"cat.packAdd":1069,"cat.packAdded":1070,"cat.packItems":1071,"cat.exportXlsx":1072,"cat.importAny":1073,"mob.menu":1074,"mob.done":1075,"mob.cancel":1076,"mob.props":1077,"mob.tools":1078,"mob.hint":1079,"mob.group.nav":1080,"mob.group.draw":1081,"mob.group.edit":1082,"mob.group.terrain":1083,"mob.group.zone":1084,"mob.group.main":1085,"mob.selection":1086,"mob.project":1087,"mob.file":1088,"mob.view":1089,"mob.help":1090,"sc.mobile":1091,"dlg.followGuide":1092,"hist.title":1093,"hist.hint":1094,"hist.start":1095,"hist.edit":1096,"hist.add":1097,"hist.addMany":1098,"hist.delete":1099,"hist.move":1100,"hist.rotate":1101,"hist.scale":1102,"hist.mirror":1103,"hist.transform":1104,"hist.copy":1105,"hist.array":1106,"hist.block":1107,"hist.grid":1108,"hist.props":1109,"hist.import":1110,"hist.design":1111,"hist.contours":1112,"hist.dem":1113,"hist.demClear":1114,"hist.paste":1115,"hist.elevation":1116,"hist.align":1117,"hist.layer":1118,"plot.bomOnSheet":1119,"pdf.bom":1120,"pdf.qty":1121,"pdf.bomMore":1122,"imp.demTiff":1123,"reports.pivotSpans":1124,"rep.span":1125,"rep.rFrom":1126,"rep.rTo":1127,"rep.sprinklers":1128,"rep.qSprinkler":1129,"rep.pMid":1130,"rep.nozzleSuggested":1131,"props.pivotSprSpacing":1132,"props.pivotSprinkler":1133,"props.pivotRegulator":1134,"props.pivotTowerCost":1135,"pivot.towersItem":1136,"pivot.sprinklersItem":1137,"pivot.endGunItem":1138,"props.contourSmooth":1139,"dem.online.maxPoints":1140,"pump.motor":1141,"warn.lp_loops_approx":1142,"cat.packsBundled":1143,"cat.packsLoaded":1144,"cat.packImport":1145,"cat.packUrl":1146,"cat.packLoad":1147,"cat.packLoading":1148,"cat.packLoaded":1149,"cat.packLoadError":1150,"cat.packExport":1151,"cat.packExportTitle":1152,"cat.packExportExplain":1153,"cat.packBrand":1154,"cat.packName":1155,"cat.packDescription":1156,"cat.packSource":1157,"cat.packExported":1158,"cat.packFormat":1159,"cat.packFrom":1160,"imp.err.catalog_json_unknown":1161,"imp.err.catalog_index_not_pack":1162,"imp.err.catalog_index_unknown":1163,"imp.err.catalog_pack_version":1164,"dem.online.coord":1165,"dem.online.coordHint":1166,"dem.online.coordExplain":1167,"dem.online.useCoord":1168,"dem.online.areaSize":1169,"dem.online.coordInvalid":1170,"dem.online.contours":1171,"dem.online.contourInterval":1172,"dem.online.doneContours":1173,"msg.georefAt":1174,"file.examples":1175,"help.welcome":1176,"welcome.title":1177,"welcome.body":1178,"welcome.examples":1179,"welcome.examplesHint":1180,"welcome.tutorial":1181,"welcome.skip":1182,"exg.orchard.title":1183,"exg.orchard.sub":1184,"exg.orchard.tags":1185,"exg.garden.title":1186,"exg.garden.sub":1187,"exg.garden.tags":1188,"exg.sportsField.title":1189,"exg.sportsField.sub":1190,"exg.sportsField.tags":1191,"exg.rowCrop.title":1192,"exg.rowCrop.sub":1193,"exg.rowCrop.tags":1194,"exg.pivot.title":1195,"exg.pivot.sub":1196,"exg.pivot.tags":1197,"ex.shift":1198,"ex.g.name":1199,"ex.g.client":1200,"ex.g.site":1201,"ex.g.title":1202,"ex.g.lot":1203,"ex.g.house":1204,"ex.g.front":1205,"ex.g.back":1206,"ex.g.bed":1207,"ex.g.zone1":1208,"ex.g.zone2":1209,"ex.g.zone3":1210,"ex.g.supply":1211,"ex.g.grass":1212,"ex.g.shrubs":1213,"ex.g.main":1214,"ex.g.street":1215,"ex.f.name":1216,"ex.f.client":1217,"ex.f.site":1218,"ex.f.title":1219,"ex.f.pitch":1220,"ex.f.row":1221,"ex.f.tank":1222,"ex.f.pumpHouse":1223,"ex.f.grass":1224,"ex.f.main":1225,"ex.c.name":1226,"ex.c.client":1227,"ex.c.site":1228,"ex.c.title":1229,"ex.c.block":1230,"ex.c.tomato":1231,"ex.c.reservoir":1232,"ex.c.trunk":1233,"ex.c.west":1234,"ex.c.east":1235,"ex.c.road":1236,"ex.c.field":1237,"ex.p.name":1238,"ex.p.client":1239,"ex.p.site":1240,"ex.p.title":1241,"ex.p.pivot":1242,"ex.p.well":1243,"ex.p.maize":1244,"ex.p.adductor":1245,"ex.p.field":1246,"ex.p.boundary":1247,"exg.greenhouse.title":1248,"exg.greenhouse.sub":1249,"exg.greenhouse.tags":1250,"exg.nursery.title":1251,"exg.nursery.sub":1252,"exg.nursery.tags":1253,"exg.coffee.title":1254,"exg.coffee.sub":1255,"exg.coffee.tags":1256,"exg.bananas.title":1257,"exg.bananas.sub":1258,"exg.bananas.tags":1259,"exg.sugarcane.title":1260,"exg.sugarcane.sub":1261,"exg.sugarcane.tags":1262,"exg.gravity.title":1263,"exg.gravity.sub":1264,"exg.gravity.tags":1265,"exg.pasture.title":1266,"exg.pasture.sub":1267,"exg.pasture.tags":1268,"exg.golf.title":1269,"exg.golf.sub":1270,"exg.golf.tags":1271,"exg.sectorPivot.title":1272,"exg.sectorPivot.sub":1273,"exg.sectorPivot.tags":1274,"exg.linear.title":1275,"exg.linear.sub":1276,"exg.linear.tags":1277,"ex.gh.name":1278,"ex.gh.client":1279,"ex.gh.site":1280,"ex.gh.title":1281,"ex.gh.lot":1282,"ex.gh.tunnel":1283,"ex.gh.crop":1284,"ex.gh.tank":1285,"ex.gh.main":1286,"ex.nu.name":1287,"ex.nu.client":1288,"ex.nu.site":1289,"ex.nu.title":1290,"ex.nu.lot":1291,"ex.nu.bed":1292,"ex.nu.crop":1293,"ex.nu.tank":1294,"ex.nu.main":1295,"ex.cf.name":1296,"ex.cf.client":1297,"ex.cf.site":1298,"ex.cf.title":1299,"ex.cf.block":1300,"ex.cf.coffee":1301,"ex.cf.well":1302,"ex.cf.main":1303,"ex.cf.boundary":1304,"ex.ba.name":1305,"ex.ba.client":1306,"ex.ba.site":1307,"ex.ba.title":1308,"ex.ba.block":1309,"ex.ba.banana":1310,"ex.ba.well":1311,"ex.ba.field":1312,"ex.ba.road":1313,"ex.ba.main":1314,"ex.sc.name":1315,"ex.sc.client":1316,"ex.sc.site":1317,"ex.sc.title":1318,"ex.sc.block":1319,"ex.sc.cane":1320,"ex.sc.field":1321,"ex.sc.road":1322,"ex.sc.reservoir":1323,"ex.sc.trunk":1324,"ex.sc.west":1325,"ex.sc.east":1326,"ex.gr.name":1327,"ex.gr.client":1328,"ex.gr.site":1329,"ex.gr.title":1330,"ex.gr.block":1331,"ex.gr.crop":1332,"ex.gr.reservoir":1333,"ex.gr.prv":1334,"ex.gr.field":1335,"ex.gr.main":1336,"ex.gr.west":1337,"ex.gr.east":1338,"ex.pa.name":1339,"ex.pa.client":1340,"ex.pa.site":1341,"ex.pa.title":1342,"ex.pa.paddock":1343,"ex.pa.grass":1344,"ex.pa.fence":1345,"ex.pa.road":1346,"ex.pa.reservoir":1347,"ex.pa.main":1348,"ex.go.name":1349,"ex.go.client":1350,"ex.go.site":1351,"ex.go.title":1352,"ex.go.tee":1353,"ex.go.fairway":1354,"ex.go.fairwayZone":1355,"ex.go.green":1356,"ex.go.bunker":1357,"ex.go.pond":1358,"ex.go.turf":1359,"ex.go.pumpHouse":1360,"ex.go.main":1361,"ex.sp.name":1362,"ex.sp.client":1363,"ex.sp.site":1364,"ex.sp.title":1365,"ex.sp.pivot":1366,"ex.sp.soy":1367,"ex.sp.pond":1368,"ex.sp.farm":1369,"ex.sp.field":1370,"ex.sp.boundary":1371,"ex.sp.road":1372,"ex.sp.adductor":1373,"ex.li.name":1374,"ex.li.client":1375,"ex.li.site":1376,"ex.li.title":1377,"ex.li.machine":1378,"ex.li.wheat":1379,"ex.li.canal":1380,"ex.li.intake":1381,"ex.li.field":1382,"ex.li.boundary":1383,"ex.li.main":1384}
B.kX=new A.a("OpenCADIrrigation","OpenCADIrrigation","OpenCADIrrigation")
B.ne=new A.a("OK","OK","Aceptar")
B.bM=new A.a("Cancelar","Cancel","Cancelar")
B.iV=new A.a("Aplicar","Apply","Aplicar")
B.kH=new A.a("Fechar","Close","Cerrar")
B.xM=new A.a("Autom\xe1tico","Automatic","Autom\xe1tico")
B.c6=new A.a("Limpar","Clear","Limpiar")
B.aw=new A.a("Arquivo","File","Archivo")
B.bT=new A.a("Editar","Edit","Editar")
B.cq=new A.a("Ver","View","Ver")
B.bR=new A.a("Desenhar","Draw","Dibujar")
B.F=new A.a("Zona","Zone","Zona")
B.t=new A.a("Linha principal","Mainline","L\xednea principal")
B.cw=new A.a("Projeto","Design","Dise\xf1o")
B.lc=new A.a("Relat\xf3rios","Reports","Informes")
B.bW=new A.a("Ferramentas","Tools","Herramientas")
B.bG=new A.a("Ajuda","Help","Ayuda")
B.bB=new A.a("Novo projeto","New project","Nuevo proyecto")
B.fC=new A.a("Abrir projeto\u2026","Open project\u2026","Abrir proyecto\u2026")
B.n7=new A.a("Salvar projeto","Save project","Guardar proyecto")
B.hk=new A.a("Exportar DXF","Export DXF","Exportar DXF")
B.hN=new A.a("Exportar desenho","Export drawing","Exportar dibujo")
B.hy=new A.a("Exportar relat\xf3rio","Export report","Exportar informe")
B.rc=new A.a("Georrefer\xeancia\u2026","Georeference\u2026","Georreferencia\u2026")
B.hw=new A.a("Nova aba de projeto","New project tab","Nueva pesta\xf1a de proyecto")
B.fq=new A.a("Fechar aba","Close tab","Cerrar pesta\xf1a")
B.wx=new A.a("Nova aba (Ctrl+Alt+N)","New tab (Ctrl+Alt+N)","Nueva pesta\xf1a (Ctrl+Alt+N)")
B.rE=new A.a("Fechar aba (Ctrl+Alt+W)","Close tab (Ctrl+Alt+W)","Cerrar pesta\xf1a (Ctrl+Alt+W)")
B.jD=new A.a("Copiar","Copy","Copiar")
B.om=new A.a("Recortar","Cut","Cortar")
B.bN=new A.a("Colar","Paste","Pegar")
B.wL=new A.a("{n} itens copiados","{n} items copied","{n} elementos copiados")
B.xv=new A.a("{n} itens recortados","{n} items cut","{n} elementos cortados")
B.r6=new A.a("Tubo cortado em 2 trechos","Pipe cut into 2 pieces","Tuber\xeda cortada en 2 tramos")
B.nH=new A.a("{n} itens colados","{n} items pasted","{n} elementos pegados")
B.bS=new A.a("Nada selecionado","Nothing selected","Nada seleccionado")
B.hQ=new A.a("\xc1rea de transfer\xeancia vazia","Clipboard is empty","Portapapeles vac\xedo")
B.v7=new A.a("Comando desconhecido: {cmd} (veja Ajuda \u2192 Atalhos de teclado)","Unknown command: {cmd} (see Help \u2192 Keyboard shortcuts)","Comando desconocido: {cmd} (vea Ayuda \u2192 Atajos de teclado)")
B.jA=new A.a("Comando","Command","Comando")
B.hi=new A.a("Atalhos de teclado\u2026","Keyboard shortcuts\u2026","Atajos de teclado\u2026")
B.fU=new A.a("Atalhos de teclado","Keyboard shortcuts","Atajos de teclado")
B.lS=new A.a("Com o desenho em foco, digite o alias do comando e pressione Enter ou Espa\xe7o, como no AutoCAD (ex.: L \u23ce linha, PL \u23ce polilinha, ZE \u23ce enquadrar, E \u23ce apagar). Esc limpa o comando digitado. As combina\xe7\xf5es com Ctrl e as teclas F funcionam em qualquer parte da tela.","With the drawing focused, type the command alias and press Enter or Space, as in AutoCAD (e.g. L \u23ce line, PL \u23ce polyline, ZE \u23ce zoom extents, E \u23ce erase). Esc clears the typed command. Ctrl combinations and F keys work anywhere.","Con el dibujo enfocado, escriba el alias del comando y pulse Enter o Espacio, como en AutoCAD (p. ej. L \u23ce l\xednea, PL \u23ce polil\xednea, ZE \u23ce encuadrar, E \u23ce borrar). Esc limpia el comando. Las combinaciones con Ctrl y las teclas F funcionan en toda la pantalla.")
B.nf=new A.a("Arquivo e abas","File and tabs","Archivo y pesta\xf1as")
B.jO=new A.a("Edi\xe7\xe3o","Editing","Edici\xf3n")
B.rC=new A.a("Vista e desenho","View and drawing","Vista y dibujo")
B.hJ=new A.a("Comandos (alias \u23ce)","Commands (alias \u23ce)","Comandos (alias \u23ce)")
B.iQ=new A.a("Ferramentas hidr\xe1ulicas (alias \u23ce)","Hydraulic tools (alias \u23ce)","Herramientas hidr\xe1ulicas (alias \u23ce)")
B.t8=new A.a("Alternar aba de projeto","Switch project tab","Cambiar pesta\xf1a de proyecto")
B.mB=new A.a("Cancelar / voltar a selecionar","Cancel / back to select","Cancelar / volver a seleccionar")
B.kz=new A.a("Concluir polilinha / executar comando","Finish polyline / run command","Terminar polil\xednea / ejecutar comando")
B.qf=new A.a("Remover \xfaltimo ponto / apagar letra do comando","Remove last point / delete command letter","Quitar \xfaltimo punto / borrar letra del comando")
B.qc=new A.a("Repetir \xfaltima ferramenta (Enter ao selecionar)","Repeat last tool (Enter while selecting)","Repetir \xfaltima herramienta (Enter al seleccionar)")
B.iF=new A.a("Aproximar / afastar","Zoom in / out","Acercar / alejar")
B.pW=new A.a("Deslocar vista","Pan view","Desplazar vista")
B.m9=new A.a("Mover vista (segurar; ou bot\xe3o do meio do mouse)","Pan (hold; or middle mouse button)","Mover vista (mantener; o bot\xf3n central del rat\xf3n)")
B.tT=new A.a("Mostrar/ocultar relat\xf3rios","Show/hide reports","Mostrar/ocultar informes")
B.q3=new A.a("Mostrar/ocultar grade","Show/hide grid","Mostrar/ocultar cuadr\xedcula")
B.pH=new A.a("Travar a linha em 0\xb0/45\xb0/90\xb0 enquanto desenha (segurar)","Lock the line to 0\xb0/45\xb0/90\xb0 while drawing (hold)","Bloquear la l\xednea en 0\xb0/45\xb0/90\xb0 mientras dibuja (mantener)")
B.iu=new A.a("Alias digitado executa sozinho ap\xf3s uma pausa (ou Enter/Espa\xe7o)","A typed alias runs by itself after a pause (or Enter/Space)","El alias escrito se ejecuta solo tras una pausa (o Intro/Espacio)")
B.tc=new A.a("Snap / orto / grade vis\xedvel / snap \xe0 grade","Snap / ortho / grid display / grid snap","Snap / orto / cuadr\xedcula visible / snap a cuadr\xedcula")
B.k4=new A.a("Projetar tudo / verificar conex\xf5es / relat\xf3rios","Design all / check connectivity / reports","Dise\xf1ar todo / verificar conexiones / informes")
B.h0=new A.a("DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)")
B.jY=new A.a("DWG (AutoCAD 2000, bin\xe1rio)","DWG (AutoCAD 2000, binary)","DWG (AutoCAD 2000, binario)")
B.pc=new A.a("PDF (prancha para impress\xe3o)\u2026","PDF (plot sheet)\u2026","PDF (l\xe1mina para impresi\xf3n)\u2026")
B.oC=new A.a("SVG (figura vetorial: web, Inkscape)","SVG (vector figure: web, Inkscape)","SVG (figura vectorial: web, Inkscape)")
B.oL=new A.a("KML (Google Earth)","KML (Google Earth)","KML (Google Earth)")
B.nS=new A.a("KMZ (Google Earth, compactado)","KMZ (Google Earth, zipped)","KMZ (Google Earth, comprimido)")
B.ta=new A.a("GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)")
B.o5=new A.a("CSV (planilha)","CSV (spreadsheet)","CSV (hoja de c\xe1lculo)")
B.fM=new A.a("TXT (texto)","TXT (plain text)","TXT (texto)")
B.wH=new A.a("XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)")
B.qa=new A.a("PDF (documento)","PDF (document)","PDF (documento)")
B.uy=new A.a("Exportado: {f}","Exported: {f}","Exportado: {f}")
B.lr=new A.a("Execute o projeto (F5) antes de exportar o relat\xf3rio","Run the design (F5) before exporting the report","Ejecute el dise\xf1o (F5) antes de exportar el informe")
B.ng=new A.a("O desenho est\xe1 vazio","The drawing is empty","El dibujo est\xe1 vac\xedo")
B.ns=new A.a("Georrefer\xeancia definida: {crs}","Georeference set: {crs}","Georreferencia definida: {crs}")
B.ty=new A.a("Georrefer\xeancia do projeto","Project georeference","Georreferencia del proyecto")
B.pC=new A.a("Para exportar em KML, KMZ ou GeoJSON o desenho precisa de uma posi\xe7\xe3o no mundo. Informe a coordenada da origem do desenho (x = 0, y = 0). Projetos importados de KML/KMZ j\xe1 v\xeam georreferenciados.","To export KML, KMZ or GeoJSON the drawing needs a position on Earth. Enter the coordinate of the drawing origin (x = 0, y = 0). Projects imported from KML/KMZ are already georeferenced.","Para exportar en KML, KMZ o GeoJSON el dibujo necesita una posici\xf3n en el mundo. Indique la coordenada del origen del dibujo (x = 0, y = 0). Los proyectos importados de KML/KMZ ya vienen georreferenciados.")
B.qX=new A.a("Latitude / longitude (WGS84)","Latitude / longitude (WGS84)","Latitud / longitud (WGS84)")
B.v1=new A.a("UTM (WGS84)","UTM (WGS84)","UTM (WGS84)")
B.mz=new A.a("Latitude (\xb0)","Latitude (\xb0)","Latitud (\xb0)")
B.u2=new A.a("Longitude (\xb0)","Longitude (\xb0)","Longitud (\xb0)")
B.ux=new A.a("Fuso UTM (1\u201360)","UTM zone (1\u201360)","Huso UTM (1\u201360)")
B.kD=new A.a("Hemisf\xe9rio norte","Northern hemisphere","Hemisferio norte")
B.pM=new A.a("Este (m)","Easting (m)","Este (m)")
B.kf=new A.a("Norte (m)","Northing (m)","Norte (m)")
B.iS=new A.a("Atual: {crs} \xb7 origem E {e} m, N {n} m","Current: {crs} \xb7 origin E {e} m, N {n} m","Actual: {crs} \xb7 origen E {e} m, N {n} m")
B.iy=new A.a("Projeto ainda sem georrefer\xeancia","Project not georeferenced yet","Proyecto a\xfan sin georreferencia")
B.aF=new A.a("Remover","Remove","Quitar")
B.ou=new A.a("Coordenadas inv\xe1lidas","Invalid coordinates","Coordenadas no v\xe1lidas")
B.kL=new A.a("Exportar PDF (prancha)","Export PDF (plot sheet)","Exportar PDF (l\xe1mina)")
B.oH=new A.a("Formato do papel","Paper size","Tama\xf1o de papel")
B.tr=new A.a("Orienta\xe7\xe3o","Orientation","Orientaci\xf3n")
B.nD=new A.a("Paisagem","Landscape","Horizontal")
B.ot=new A.a("Retrato","Portrait","Vertical")
B.ri=new A.a("Escala 1 :","Scale 1 :","Escala 1 :")
B.fK=new A.a("Ajustar \xe0 folha","Fit to sheet","Ajustar a la hoja")
B.aN=new A.a("Raios molhados","Wetted radii","Radios mojados")
B.vf=new A.a("R\xf3tulos e resultados","Labels and results","Etiquetas y resultados")
B.tP=new A.a("Legenda de camadas","Layer legend","Leyenda de capas")
B.nG=new A.a("Anexar p\xe1ginas de relat\xf3rio","Append report pages","Adjuntar p\xe1ginas de informe")
B.ku=new A.a("Exportar","Export","Exportar")
B.yA=new A.a("Escala autom\xe1tica: 1:{n}","Automatic scale: 1:{n}","Escala autom\xe1tica: 1:{n}")
B.bQ=new A.a("Data","Date","Fecha")
B.kp=new A.a("Escala","Scale","Escala")
B.kN=new A.a("Folha","Sheet","Hoja")
B.nk=new A.a("Origem","Origin","Origen")
B.nt=new A.a("Zonas / emissores","Zones / outlets","Zonas / emisores")
B.pE=new A.a("Coordenadas","Coordinates","Coordenadas")
B.x8=new A.a("Locais (m)","Local (m)","Locales (m)")
B.mo=new A.a("Legenda","Legend","Leyenda")
B.tU=new A.a("Projeto de irriga\xe7\xe3o pressurizada","Pressurised irrigation design","Dise\xf1o de riego presurizado")
B.pt=new A.a("Relat\xf3rio de dimensionamento hidr\xe1ulico","Hydraulic design report","Informe de dise\xf1o hidr\xe1ulico")
B.rK=new A.a("Gerado por OpenCADIrrigation em {d}","Generated by OpenCADIrrigation on {d}","Generado por OpenCADIrrigation el {d}")
B.yj=new A.a("P\xe1gina {i} de {n}","Page {i} of {n}","P\xe1gina {i} de {n}")
B.p3=new A.a("(continua\xe7\xe3o)","(continued)","(continuaci\xf3n)")
B.f9=new A.a("Sem resultados de dimensionamento: execute o projeto para incluir as tabelas hidr\xe1ulicas.","No design results: run the design to include the hydraulic tables.","Sin resultados de dise\xf1o: ejecute el dise\xf1o para incluir las tablas hidr\xe1ulicas.")
B.tQ=new A.a("Par\xe2metros de projeto","Design parameters","Par\xe1metros de dise\xf1o")
B.k2=new A.a("Desenho","Drawing","Dibujo")
B.a3=new A.a("Texto","Text","Texto")
B.jG=new A.a("Cotas","Dimensions","Cotas")
B.t9=new A.a("Curvas de n\xedvel","Contours","Curvas de nivel")
B.q6=new A.a("Pontos cotados","Spot heights","Puntos acotados")
B.vA=new A.a("MDT baixado","Downloaded DEM","MDT descargado")
B.ka=new A.a("Tubos de zona","Zone pipes","Tuber\xedas de zona")
B.jf=new A.a("Linha principal","Mainline pipes","L\xednea principal")
B.km=new A.a("Laterais com emissores","Spraylines","Laterales con emisores")
B.wW=new A.a("Fitas gotejadoras","Drip tapes","Cintas de goteo")
B.A=new A.a("Emissores","Outlets","Emisores")
B.wb=new A.a("V\xe1lvulas de controle","Control valves","V\xe1lvulas de control")
B.tY=new A.a("Fontes de \xe1gua","Water supplies","Fuentes de agua")
B.ay=new A.a("Bombas","Pumps","Bombas")
B.cp=new A.a("Acess\xf3rios hidr\xe1ulicos","Hydraulic devices","Accesorios hidr\xe1ulicos")
B.hn=new A.a("N\xf3s","Junctions","Nudos")
B.iG=new A.a("\xc1reas irrigadas","Irrigated areas","\xc1reas regadas")
B.cI=new A.a("R\xf3tulos","Labels","Etiquetas")
B.td=new A.a("Detalhes do projeto\u2026","Project details\u2026","Detalles del proyecto\u2026")
B.k3=new A.a("Desfazer","Undo","Deshacer")
B.oo=new A.a("Refazer","Redo","Rehacer")
B.lf=new A.a("Excluir sele\xe7\xe3o","Delete selection","Eliminar selecci\xf3n")
B.ww=new A.a("Selecionar tudo","Select all","Seleccionar todo")
B.kb=new A.a("Duplicar sele\xe7\xe3o","Duplicate selection","Duplicar selecci\xf3n")
B.jh=new A.a("Enquadrar tudo","Zoom all","Encuadrar todo")
B.vx=new A.a("Aproximar","Zoom in","Acercar")
B.n9=new A.a("Afastar","Zoom out","Alejar")
B.c1=new A.a("Grade","Grid","Cuadr\xedcula")
B.ox=new A.a("Sem resultados","No results overlay","Sin resultados")
B.qo=new A.a("Colorir por velocidade","Colour by velocity","Colorear por velocidad")
B.yz=new A.a("Colorir por press\xe3o","Colour by pressure","Colorear por presi\xf3n")
B.hh=new A.a("Mostrar di\xe2metros","Show diameters","Mostrar di\xe1metros")
B.bL=new A.a("Camadas","Layers","Capas")
B.lx=new A.a("Idioma","Language","Idioma")
B.qt=new A.a("Portugu\xeas","Portuguese","Portugu\xe9s")
B.mZ=new A.a("Ingl\xeas","English","Ingl\xe9s")
B.xS=new A.a("Espanhol","Spanish","Espa\xf1ol")
B.yn=new A.a("Par\xe2metros de projeto\u2026","Design parameters\u2026","Par\xe1metros de dise\xf1o\u2026")
B.vd=new A.a("Turnos de opera\xe7\xe3o (management)\u2026","System flows (management)\u2026","Turnos de operaci\xf3n\u2026")
B.rv=new A.a("Verifica\xe7\xe3o do projeto (Design Check)\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o (Design Check)\u2026")
B.qh=new A.a("Dimensionar zonas (LP/velocidade)","Size zones (LP/velocity)","Dimensionar zonas (LP/velocidad)")
B.qA=new A.a("Analisar (tamanhos atuais)","Analyse (existing sizes)","Analizar (tama\xf1os actuales)")
B.pQ=new A.a("Dimensionar linha principal","Size mainline","Dimensionar l\xednea principal")
B.ib=new A.a("Projetar tudo","Design all","Dise\xf1ar todo")
B.nc=new A.a("Limpar resultados","Clear results","Limpiar resultados")
B.iE=new A.a("Calculando o projeto\u2026","Designing the system\u2026","Calculando el dise\xf1o\u2026")
B.kY=new A.a("Montando a rede hidr\xe1ulica","Building the hydraulic network","Armando la red hidr\xe1ulica")
B.ln=new A.a("Zona {i} de {n}","Zone {i} of {n}","Zona {i} de {n}")
B.mt=new A.a("Linha principal e turnos de opera\xe7\xe3o","Mainline and system flows","L\xednea principal y turnos de operaci\xf3n")
B.le=new A.a("Reanalisando trechos telescopados","Re-analysing telescoped pipes","Reanalizando tramos telescopados")
B.qZ=new A.a("An\xe1lise de lavagem (flushing)","Flushing analysis","An\xe1lisis de lavado (flushing)")
B.hs=new A.a("Verifica\xe7\xe3o de golpe de ar\xedete","Water hammer check","Verificaci\xf3n de golpe de ariete")
B.a4=new A.a("Lista de materiais","Bill of materials","Lista de materiales")
B.wS=new A.a("Calculando em segundo plano: navegue \xe0 vontade; edi\xe7\xf5es esperam o fim.","Running in the background: navigate freely; edits wait until it finishes.","Calculando en segundo plano: navega libremente; las ediciones esperan al final.")
B.wC=new A.a("O navegador pode ficar lento enquanto o c\xe1lculo roda.","The browser may be slow while the calculation runs.","El navegador puede ir lento mientras corre el c\xe1lculo.")
B.xH=new A.a("Cat\xe1logo de componentes\u2026","Component catalog\u2026","Cat\xe1logo de componentes\u2026")
B.r8=new A.a("Bloco de laterais\u2026","Lateral block\u2026","Bloque de laterales\u2026")
B.oQ=new A.a("Aspersores autom\xe1ticos (grade)\u2026","Auto sprinklers (grid)\u2026","Aspersores autom\xe1ticos (malla)\u2026")
B.fG=new A.a("Resumo das zonas","Zone summary","Resumen de zonas")
B.aA=new A.a("Tubos","Pipes","Tuber\xedas")
B.uD=new A.a("Linha principal / duty","Mainline / duty","L\xednea principal / demanda")
B.m7=new A.a("Bombas e acess\xf3rios","Pumps and devices","Bombas y accesorios")
B.fm=new A.a("Requisitos h\xeddricos","Water requirements","Requerimientos h\xeddricos")
B.xU=new A.a("Linha piezom\xe9trica","Hydraulic grade line","L\xednea piezom\xe9trica")
B.mJ=new A.a("Mensagens","Messages","Mensajes")
B.ma=new A.a("Calculadora de lateral\u2026","Lateral calculator\u2026","Calculadora de lateral\u2026")
B.uL=new A.a("Bomba e curva do sistema\u2026","Pump & system curve\u2026","Bomba y curva del sistema\u2026")
B.wd=new A.a("Golpe de ar\xedete\u2026","Water hammer\u2026","Golpe de ariete\u2026")
B.fZ=new A.a("Unidades\u2026","Units\u2026","Unidades\u2026")
B.ny=new A.a("Sobre","About","Acerca de")
B.ul=new A.a("Tutorial interativo","Interactive tutorial","Tutorial interactivo")
B.oU=new A.a("Selecionar","Select","Seleccionar")
B.re=new A.a("Mover vista","Pan","Mover vista")
B.uq=new A.a("Linha","Line","L\xednea")
B.h_=new A.a("Polilinha","Polyline","Polil\xednea")
B.qm=new A.a("Ret\xe2ngulo","Rectangle","Rect\xe1ngulo")
B.kc=new A.a("C\xedrculo","Circle","C\xedrculo")
B.jF=new A.a("Cota","Dimension","Cota")
B.p7=new A.a("Curva de n\xedvel","Contour","Curva de nivel")
B.qy=new A.a("Cota de ponto","Spot height","Cota de punto")
B.aK=new A.a("\xc1rea irrigada","Irrigated area","\xc1rea regada")
B.ji=new A.a("Tubo de zona","Zone pipe","Tuber\xeda de zona")
B.wy=new A.a("Tubo principal","Mainline pipe","Tuber\xeda principal")
B.hB=new A.a("Lateral (sprayline)","Sprayline (lateral)","Lateral (sprayline)")
B.c3=new A.a("Fita/tubo gotejador","Drip tape / dripline","Cinta/tuber\xeda de goteo")
B.a2=new A.a("Emissor","Outlet","Emisor")
B.jX=new A.a("V\xe1lvula de controle","Control valve","V\xe1lvula de control")
B.lR=new A.a("Fonte de \xe1gua","Water supply","Fuente de agua")
B.ax=new A.a("Bomba","Pump","Bomba")
B.uZ=new A.a("Acess\xf3rio hidr\xe1ulico","Misc. hydraulic","Accesorio hidr\xe1ulico")
B.nr=new A.a("Jun\xe7\xe3o","Junction","Nudo")
B.cu=new A.a("Bloco de laterais","Lateral block","Bloque de laterales")
B.bA=new A.a("Grade de aspersores","Sprinkler grid","Malla de aspersores")
B.mI=new A.a("Medir","Measure","Medir")
B.fs=new A.a("Clique para selecionar, arraste para mover ou janela; Shift adiciona; Del exclui","Click to select, drag to move or window; Shift adds; Del deletes","Clic para seleccionar, arrastre para mover o ventana; Shift a\xf1ade; Supr elimina")
B.tu=new A.a("Arraste para mover a vista; roda do mouse para zoom","Drag to pan; mouse wheel zooms","Arrastre para mover la vista; rueda del rat\xf3n para zoom")
B.ue=new A.a("Clique no primeiro ponto, depois no segundo","Click first point, then second","Clic en el primer punto y luego en el segundo")
B.me=new A.a("Clique nos v\xe9rtices; Enter/duplo clique termina; Esc cancela","Click vertices; Enter/double-click ends; Esc cancels","Clic en los v\xe9rtices; Intro/doble clic termina; Esc cancela")
B.vF=new A.a("Clique nos dois cantos opostos","Click two opposite corners","Clic en dos esquinas opuestas")
B.fW=new A.a("Clique no centro, depois no raio","Click centre, then radius","Clic en el centro y luego en el radio")
B.uz=new A.a("Clique na posi\xe7\xe3o do texto","Click text position","Clic en la posici\xf3n del texto")
B.ui=new A.a("Clique nos dois pontos e depois na posi\xe7\xe3o da linha de cota","Click two points, then the dimension line position","Clic en dos puntos y luego en la posici\xf3n de la l\xednea de cota")
B.qi=new A.a("Clique os v\xe9rtices da curva de n\xedvel; Enter (ou Concluir) termina e pede a eleva\xe7\xe3o; Esc cancela","Click the contour vertices; Enter (or Done) finishes and asks for the elevation; Esc cancels","Clic en los v\xe9rtices de la curva de nivel; Intro (o Terminar) termina y pide la elevaci\xf3n; Esc cancela")
B.mf=new A.a("Clique onde fica a cota; a eleva\xe7\xe3o \xe9 pedida a cada ponto","Click where the spot height goes; the elevation is asked for each point","Clic donde va la cota; la elevaci\xf3n se pide en cada punto")
B.x9=new A.a("Clique nos v\xe9rtices do pol\xedgono; Enter fecha","Click polygon vertices; Enter closes","Clic en los v\xe9rtices del pol\xedgono; Intro cierra")
B.mx=new A.a("Clique nos v\xe9rtices do tubo; Enter/duplo clique termina; conecta automaticamente","Click pipe vertices; Enter/double-click ends; connects automatically","Clic en los v\xe9rtices de la tuber\xeda; Intro/doble clic termina; conecta autom\xe1ticamente")
B.w2=new A.a("Clique sobre um tubo ou jun\xe7\xe3o para conectar","Click on a pipe or junction to connect","Clic sobre una tuber\xeda o nudo para conectar")
B.fH=new A.a("Clique nos v\xe9rtices do bloco; Enter conclui e abre as op\xe7\xf5es","Click block vertices; Enter finishes and opens options","Clic en los v\xe9rtices del bloque; Intro termina y abre las opciones")
B.mA=new A.a("Clique em dois pontos","Click two points","Clic en dos puntos")
B.nN=new A.a("Pronto","Ready","Listo")
B.oV=new A.a("Snap","Snap","Snap")
B.nl=new A.a("Orto","Ortho","Orto")
B.u9=new A.a("Conex\xe3o","Linked","Conexi\xf3n")
B.fT=new A.a("Ao arrastar o n\xf3 de um tubo, as pontas de tubos e os itens ligados a ele acompanham o movimento","Dragging the node of a pipe drags along the pipe ends and items joined to it","Al arrastrar el nodo de una tuber\xeda, los extremos de tuber\xeda y los elementos unidos a \xe9l acompa\xf1an el movimiento")
B.ps=new A.a("ent.","ent.","ent.")
B.aL=new A.a("Propriedades","Properties","Propiedades")
B.rJ=new A.a("{n} itens selecionados","{n} items selected","{n} elementos seleccionados")
B.jp=new A.a("Camada","Layer","Capa")
B.aD=new A.a("Nome","Name","Nombre")
B.cy=new A.a("Tubo","Pipe","Tuber\xeda")
B.uB=new A.a("Dimensionar automaticamente","Computer sized","Dimensionar autom\xe1ticamente")
B.lD=new A.a("Profundidade (m)","Depth (m)","Profundidad (m)")
B.bK=new A.a("Bocal","Nozzle","Boquilla")
B.wO=new A.a("Press\xe3o nominal","Nominal pressure","Presi\xf3n nominal")
B.v6=new A.a("Espa\xe7amento","Spacing","Espaciamiento")
B.x6=new A.a("Deslocamento do 1\xba emissor","First outlet offset","Desplazamiento del 1.\xba emisor")
B.uK=new A.a("Arco (\xb0)","Arc (\xb0)","Arco (\xb0)")
B.t_=new A.a("Altura da haste (m)","Riser height (m)","Altura del tubo de subida (m)")
B.t4=new A.a("Fita/tubo gotejador","Tape / dripline","Cinta/tuber\xeda de goteo")
B.rQ=new A.a("Press\xe3o de entrada","Inlet pressure","Presi\xf3n de entrada")
B.op=new A.a("Regulada","Regulated","Regulada")
B.ru=new A.a("Press\xe3o m\xedn. no submain","Submain min. pressure","Presi\xf3n m\xedn. en el submain")
B.bC=new A.a("V\xe1lvula","Valve","V\xe1lvula")
B.kR=new A.a("Press\xe3o a jusante fixa (vazio = calcular)","Fixed downstream pressure (blank = calculate)","Presi\xf3n aguas abajo fija (vac\xedo = calcular)")
B.vO=new A.a("Calcular press\xe3o necess\xe1ria","Calculate required pressure","Calcular presi\xf3n necesaria")
B.yw=new A.a("Press\xe3o de projeto","Design pressure","Presi\xf3n de dise\xf1o")
B.yC=new A.a("Press\xe3o m\xe1xima","Maximum pressure","Presi\xf3n m\xe1xima")
B.qO=new A.a("Vaz\xe3o de projeto","Design flow","Caudal de dise\xf1o")
B.kM=new A.a("Vaz\xe3o m\xe1xima","Maximum flow","Caudal m\xe1ximo")
B.xQ=new A.a("N\xedvel de \xe1gua relativo ao solo (m)","Water level relative to ground (m)","Nivel de agua respecto al suelo (m)")
B.ca=new A.a("Rota\xe7\xe3o relativa","Relative speed","Velocidad relativa")
B.cG=new A.a("Acess\xf3rio","Device","Accesorio")
B.nT=new A.a("Press\xe3o regulada (PRV)","Regulated pressure (PRV)","Presi\xf3n regulada (PRV)")
B.aM=new A.a("Eleva\xe7\xe3o (m)","Elevation (m)","Elevaci\xf3n (m)")
B.r1=new A.a("Eleva\xe7\xe3o (m; 0 = do terreno)","Elevation (m; 0 = from DEM)","Elevaci\xf3n (m; 0 = del terreno)")
B.fS=new A.a("Altura do texto (m)","Text height (m)","Altura del texto (m)")
B.hl=new A.a("Raio (m)","Radius (m)","Radio (m)")
B.kG=new A.a("Fechado","Closed","Cerrado")
B.ha=new A.a("L\xe2mina l\xedquida (mm/dia)","Net depth (mm/day)","L\xe1mina neta (mm/d\xeda)")
B.i9=new A.a("Efici\xeancia","Efficiency","Eficiencia")
B.jI=new A.a("Cultura","Crop","Cultivo")
B.bO=new A.a("Comprimento","Length","Longitud")
B.aH=new A.a("\xc1rea","Area","\xc1rea")
B.lN=new A.a("Escopo","Scope","\xc1mbito")
B.ce=new A.a("Resultados","Results","Resultados")
B.wZ=new A.a("Orienta\xe7\xe3o (\xb0)","Orientation (\xb0)","Orientaci\xf3n (\xb0)")
B.m8=new A.a("Rota\xe7\xe3o (\xb0)","Rotation (\xb0)","Rotaci\xf3n (\xb0)")
B.nR=new A.a("Afastamento da cota","Dimension offset","Desplazamiento de la cota")
B.yq=new A.a("Enquadrar","Zoom to","Encuadrar")
B.xi=new A.a("1\xba emissor a meio espa\xe7amento","First outlet at half spacing","1.\xba emisor a medio espaciamiento")
B.fo=new A.a("P a jusante","Downstream P","P aguas abajo")
B.cB=new A.a("P requerida","Required P","P requerida")
B.yo=new A.a("Perda na v\xe1lvula","Valve loss","P\xe9rdida en la v\xe1lvula")
B.r0=new A.a("Emissor m\xedn/m\xe1x","Outlet min/max","Emisor m\xedn/m\xe1x")
B.yv=new A.a("Admiss\xedvel","Allowable","Admisible")
B.xO=new A.a("CU / DU / EU","CU / DU / EU","CU / DU / EU")
B.tA=new A.a("valores padr\xe3o","defaults","valores predeterminados")
B.aB=new A.a("Vaz\xe3o","Flow","Caudal")
B.pP=new A.a("Velocidade","Velocity","Velocidad")
B.vP=new A.a("Perda de carga","Head loss","P\xe9rdida de carga")
B.aC=new A.a("Press\xe3o","Pressure","Presi\xf3n")
B.j9=new A.a("Press\xe3o in\xedcio","Start pressure","Presi\xf3n inicio")
B.y5=new A.a("Press\xe3o fim","End pressure","Presi\xf3n final")
B.rF=new A.a("M\xedn","Min","M\xedn")
B.lh=new A.a("M\xe1x","Max","M\xe1x")
B.iK=new A.a("Projeto salvo","Project saved","Proyecto guardado")
B.pO=new A.a("Projeto carregado","Project loaded","Proyecto cargado")
B.iZ=new A.a("Projeto conclu\xeddo: {z} zonas, {f} turnos","Design finished: {z} zones, {f} system flows","Dise\xf1o terminado: {z} zonas, {f} turnos")
B.u7=new A.a("{n} itens n\xe3o conectados (marcados em vermelho)","{n} unconnected items (marked in red)","{n} elementos sin conectar (marcados en rojo)")
B.j2=new A.a("Todos os itens est\xe3o conectados","All items are connected","Todos los elementos est\xe1n conectados")
B.md=new A.a("C\xe1lculo em andamento: aguarde para editar o projeto.","Design running: wait for it to finish before editing.","C\xe1lculo en curso: espera a que termine para editar.")
B.tK=new A.a("O projeto mudou durante o c\xe1lculo; resultados descartados. Rode o c\xe1lculo de novo.","The project changed while the design ran; results discarded. Run the design again.","El proyecto cambi\xf3 durante el c\xe1lculo; resultados descartados. Ejecuta el c\xe1lculo de nuevo.")
B.uP=new A.a("Nenhuma v\xe1lvula de controle no projeto","No control valve in the design","No hay v\xe1lvulas de control en el dise\xf1o")
B.u8=new A.a("{n} itens exclu\xeddos","{n} items deleted","{n} elementos eliminados")
B.lz=new A.a("Importado","Imported","Importado")
B.nn=new A.a("Erro: {e}","Error: {e}","Error: {e}")
B.ws=new A.a("O projeto atual tem altera\xe7\xf5es n\xe3o salvas. Continuar?","The current project has unsaved changes. Continue?","El proyecto actual tiene cambios sin guardar. \xbfContinuar?")
B.lo=new A.a("Execute Projeto \u25b6 para gerar resultados","Run Design \u25b6 to generate results","Ejecute Dise\xf1o \u25b6 para generar resultados")
B.q8=new A.a("Desenhe \xe1reas irrigadas (ferramenta \xc1rea) para calcular tempos de irriga\xe7\xe3o","Draw irrigated areas (Area tool) to compute irrigation times","Dibuje \xe1reas regadas (herramienta \xc1rea) para calcular tiempos de riego")
B.v4=new A.a("Selecione um tubo, lateral ou v\xe1lvula","Select a pipe, lateral or valve","Seleccione una tuber\xeda, lateral o v\xe1lvula")
B.r9=new A.a("Sem mensagens","No messages","Sin mensajes")
B.tG=new A.a("N\xe3o conectado","Not connected","Sin conectar")
B.qL=new A.a("DWG {v}: {n} entidades, {l} camadas","DWG {v}: {n} entities, {l} layers","DWG {v}: {n} entidades, {l} capas")
B.xu=new A.a(", {n} objetos ignorados",", {n} objects skipped",", {n} objetos omitidos")
B.we=new A.a(u.n,"{k}: {p} placemarks, {n} entities ({crs})",u.n)
B.rp=new A.a("DXF: {n} entidades","DXF: {n} entities","DXF: {n} entidades")
B.y8=new A.a("N\xe3o \xe9 um arquivo DWG reconhecido","Not a recognised DWG file","No es un archivo DWG reconocido")
B.rd=new A.a("Estrutura do DWG n\xe3o encontrada (arquivo danificado ou variante n\xe3o suportada)","DWG structure not found (damaged file or unsupported variant)","Estructura del DWG no encontrada (archivo da\xf1ado o variante no compatible)")
B.kK=new A.a("KMZ sem arquivo .kml","KMZ without a .kml file","KMZ sin archivo .kml")
B.hI=new A.a("P jusante","Downstream P","P aguas abajo")
B.pD=new A.a("Perda v\xe1lv.","Valve loss","P\xe9rdida v\xe1lv.")
B.cF=new A.a("P m\xedn","Min P","P m\xedn")
B.ch=new A.a("P m\xe1x","Max P","P m\xe1x")
B.xT=new A.a("Adm. m\xedn","Allow. min","Adm. m\xedn")
B.uc=new A.a("Adm. m\xe1x","Allow. max","Adm. m\xe1x")
B.uQ=new A.a("Var. adm. %","Allow. var. %","Var. adm. %")
B.yb=new A.a("Var. real %","Actual var. %","Var. real %")
B.vs=new A.a("Custo tubos","Pipe cost","Costo tuber\xedas")
B.j0=new A.a("Avisos","Warnings","Avisos")
B.jC=new A.a("Contexto","Context","Contexto")
B.kn=new A.a("Entidade","Entity","Entidad")
B.ly=new A.a("Seg.","Seg.","Seg.")
B.jU=new A.a("DI","ID","DI")
B.c4=new A.a("L","L","L")
B.nX=new A.a("Q","Q","Q")
B.mj=new A.a("V (m/s)","V (m/s)","V (m/s)")
B.u4=new A.a("hf","hf","hf")
B.fN=new A.a("P in\xedcio","Start P","P inicio")
B.fh=new A.a("P fim","End P","P fin")
B.qR=new A.a("Z in\xedcio","Start Z","Z inicio")
B.l5=new A.a("Z fim","End Z","Z fin")
B.nx=new A.a("PN","PN","PN")
B.mY=new A.a("N","N","N")
B.x_=new A.a("Q total","Total Q","Q total")
B.yi=new A.a("Q m\xe9dio","Mean Q","Q medio")
B.aE=new A.a("Turno","System flow","Turno")
B.lC=new A.a("Item","Item","Elemento")
B.id=new A.a("P dispon\xedvel","Available P","P disponible")
B.q7=new A.a("Situa\xe7\xe3o","Status","Estado")
B.cs=new A.a("Energia/ano","Energy/year","Energ\xeda/a\xf1o")
B.az=new A.a("Fonte","Supply","Fuente")
B.rq=new A.a("calculada","calculated","calculada")
B.x0=new A.a("sobra","surplus","sobra")
B.tn=new A.a("fixa","fixed","fija")
B.xy=new A.a("d\xe9ficit","deficit","d\xe9ficit")
B.vU=new A.a("ok","ok","ok")
B.hZ=new A.a("H bomba","Pump H","H bomba")
B.uH=new A.a("P entrada","Inlet P","P entrada")
B.ir=new A.a("P sa\xedda","Outlet P","P salida")
B.qq=new A.a("Perda","Loss","P\xe9rdida")
B.oj=new A.a("em opera\xe7\xe3o","running","en operaci\xf3n")
B.w4=new A.a("parada","stopped","detenida")
B.qW=new A.a("aberto","open","abierto")
B.tk=new A.a("fechado","closed","cerrado")
B.wE=new A.a("regulando","regulating","regulando")
B.jP=new A.a("suc\xe7\xe3o","suction lift","succi\xf3n")
B.x1=new A.a("submersa","submersible","sumergible")
B.nd=new A.a("fora da faixa","out of range","fuera de rango")
B.nw=new A.a("Categoria","Category","Categor\xeda")
B.vW=new A.a("Descri\xe7\xe3o","Description","Descripci\xf3n")
B.uv=new A.a("Un.","Unit","Ud.")
B.o7=new A.a("Quantidade","Quantity","Cantidad")
B.t5=new A.a("Unit\xe1rio","Unit cost","Unitario")
B.pm=new A.a("Total","Total","Total")
B.pa=new A.a("TOTAL","TOTAL","TOTAL")
B.wG=new A.a("Custo anualizado (capital)","Annualised cost (capital)","Costo anualizado (capital)")
B.tz=new A.a("Custo anual de energia","Annual energy cost","Costo anual de energ\xeda")
B.xY=new A.a("Custo anual total","Total annual cost","Costo anual total")
B.rz=new A.a("L\xe2mina bruta (mm/d)","Gross depth (mm/d)","L\xe1mina bruta (mm/d)")
B.fi=new A.a("Volume (m\xb3/d)","Volume (m\xb3/d)","Volumen (m\xb3/d)")
B.fz=new A.a("Taxa (mm/h)","Rate (mm/h)","Tasa (mm/h)")
B.l0=new A.a("Horas/dia","Hours/day","Horas/d\xeda")
B.mX=new A.a("HGL (azul) \xb7 terreno (marrom) \xb7 faixa admiss\xedvel (verde)","HGL (blue) \xb7 ground (brown) \xb7 allowable band (green)","LP (azul) \xb7 terreno (marr\xf3n) \xb7 banda admisible (verde)")
B.qB=new A.a("ZONAS","ZONES","ZONAS")
B.wU=new A.a("TURNOS","SYSTEM FLOWS","TURNOS")
B.xC=new A.a("LISTA DE MATERIAIS","BILL OF MATERIALS","LISTA DE MATERIALES")
B.ls=new A.a("Fitas/tubos gotejadores","Drip tapes/lines","Cintas/tuber\xedas de goteo")
B.cv=new A.a("V\xe1lvulas","Valves","V\xe1lvulas")
B.rx=new A.a("Todas as zonas","All zones","Todas las zonas")
B.p_=new A.a("Submain","Submain","Submain")
B.pn=new A.a("Trecho","Stub","Tramo")
B.wF=new A.a("relatorio","report","informe")
B.pU=new A.a("Exemplo pomar","Orchard example","Ejemplo huerto")
B.z=new A.a("Fazenda Exemplo","Example Farm","Finca Ejemplo")
B.hY=new A.a("Blocos A e B","Blocks A and B","Bloques A y B")
B.k5=new A.a("Divisa","Boundary","Lindero")
B.tN=new A.a("Pomar \u2014 exemplo OpenCADIrrigation","Orchard \u2014 OpenCADIrrigation example","Huerto \u2014 ejemplo OpenCADIrrigation")
B.mv=new A.a("Zona A","Zone A","Zona A")
B.mw=new A.a("Zona B","Zone B","Zona B")
B.uJ=new A.a("Bloco A","Block A","Bloque A")
B.tq=new A.a("Bloco B","Block B","Bloque B")
B.cf=new A.a("Citros","Citrus","C\xedtricos")
B.co=new A.a("Uva","Grapes","Uva")
B.kQ=new A.a("Recalque","Rising main","Impulsi\xf3n")
B.uY=new A.a("Ramal A","Branch A","Ramal A")
B.xF=new A.a("Ramal B","Branch B","Ramal B")
B.P=new A.a("Po\xe7o","Well","Pozo")
B.y1=new A.a("Turno 1 \u2014 Zona A","Flow 1 \u2014 Zone A","Turno 1 \u2014 Zona A")
B.p6=new A.a("Turno 2 \u2014 Zona B","Flow 2 \u2014 Zone B","Turno 2 \u2014 Zona B")
B.nM=new A.a("Projeto","Project","Proyecto")
B.jy=new A.a("Cliente","Client","Cliente")
B.mr=new A.a("Local","Site","Lugar")
B.nL=new A.a("Projetista","Designer","Proyectista")
B.n5=new A.a("Notas","Notes","Notas")
B.qp=new A.a("Hidr\xe1ulica","Hydraulics","Hidr\xe1ulica")
B.lv=new A.a("F\xf3rmula de perda de carga","Head-loss formula","F\xf3rmula de p\xe9rdida de carga")
B.fl=new A.a("Hazen-Williams","Hazen-Williams","Hazen-Williams")
B.to=new A.a("Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)")
B.f6=new A.a("Temperatura da \xe1gua (\xb0C)","Water temperature (\xb0C)","Temperatura del agua (\xb0C)")
B.f5=new A.a("Vel. m\xe1x. lateral (m/s)","Max. lateral velocity (m/s)","Vel. m\xe1x. lateral (m/s)")
B.uF=new A.a("Vel. m\xe1x. zona (m/s)","Max. zone velocity (m/s)","Vel. m\xe1x. zona (m/s)")
B.j3=new A.a("Vel. m\xe1x. linha principal (m/s)","Max. mainline velocity (m/s)","Vel. m\xe1x. l\xednea principal (m/s)")
B.l2=new A.a("Perdas localizadas (% do comprimento)","Minor losses (% of length)","P\xe9rdidas localizadas (% de la longitud)")
B.wM=new A.a("Toler\xe2ncia de conex\xe3o (m)","Connection tolerance (m)","Tolerancia de conexi\xf3n (m)")
B.lX=new A.a("Aplicar perdas localizadas","Apply minor losses","Aplicar p\xe9rdidas localizadas")
B.uh=new A.a("Fator C: escala","C factor: scale","Factor C: escala")
B.mn=new A.a("Fator C: acr\xe9scimo","C factor: offset","Factor C: incremento")
B.pv=new A.a("Dimensionamento","Sizing","Dimensionamiento")
B.nu=new A.a("N\xba m\xe1x. de di\xe2metros no submain","Max. submain sizes","N.\xba m\xe1x. de di\xe1metros en el submain")
B.m2=new A.a("Densifica\xe7\xe3o do DEM (m)","DEM densification (m)","Densificaci\xf3n del MDT (m)")
B.ho=new A.a("Economia","Economics","Econom\xeda")
B.iR=new A.a("Balancear custo de capital vs. custo de energia","Trade capital cost vs. energy cost","Equilibrar costo de capital vs. costo de energ\xeda")
B.xA=new A.a("Juros (fra\xe7\xe3o/ano)","Interest (fraction/year)","Inter\xe9s (fracci\xf3n/a\xf1o)")
B.wP=new A.a("Prazo (anos)","Term (years)","Plazo (a\xf1os)")
B.qe=new A.a("Custo da energia ({c}/kWh)","Energy cost ({c}/kWh)","Costo de la energ\xeda ({c}/kWh)")
B.kk=new A.a("Efici\xeancia da bomba (fra\xe7\xe3o)","Pump efficiency (fraction)","Eficiencia de la bomba (fracci\xf3n)")
B.xa=new A.a("Horas de opera\xe7\xe3o/ano (linha principal)","Operating hours/year (mainline)","Horas de operaci\xf3n/a\xf1o (l\xednea principal)")
B.jZ=new A.a("Horas/ano por zona","Hours/year per zone","Horas/a\xf1o por zona")
B.mO=new A.a("Moeda","Currency","Moneda")
B.mC=new A.a("M\xe9trico","Metric","M\xe9trico")
B.nA=new A.a("US","US","EE. UU.")
B.rT=new A.a("Di\xe2metro","Diameter","Di\xe1metro")
B.h6=new A.a("Todas juntas","All together","Todas juntas")
B.qu=new A.a("Uma por vez","One at a time","Una a la vez")
B.tW=new A.a("+ Turno","+ Flow","+ Turno")
B.t3=new A.a("In\xedcio (h)","Start (h)","Inicio (h)")
B.cA=new A.a("Dura\xe7\xe3o (h)","Duration (h)","Duraci\xf3n (h)")
B.w7=new A.a("Sem turnos definidos: todas as zonas ser\xe3o consideradas operando juntas.","No system flows defined: all zones are assumed to run together.","Sin turnos definidos: se considera que todas las zonas funcionan juntas.")
B.wm=new A.a("Aspers\xe3o / microaspers\xe3o","Sprinkler / micro-sprinkler","Aspersi\xf3n / microaspersi\xf3n")
B.y3=new A.a("Gotejamento (fita/tubo)","Drip (tape/line)","Goteo (cinta/tuber\xeda)")
B.ml=new A.a("Laterais","Laterals","Laterales")
B.jL=new A.a("Espa\xe7amento entre emissores","Outlet spacing","Espaciamiento entre emisores")
B.uM=new A.a("Tubo da lateral","Lateral pipe","Tuber\xeda de la lateral")
B.jJ=new A.a("Espa\xe7amento entre laterais","Lateral spacing","Espaciamiento entre laterales")
B.lu=new A.a("Dire\xe7\xe3o das laterais (\xb0)","Lateral direction (\xb0)","Direcci\xf3n de las laterales (\xb0)")
B.pb=new A.a("Submain e v\xe1lvula","Submain and valve","Submain y v\xe1lvula")
B.jd=new A.a("Posi\xe7\xe3o do submain","Submain position","Posici\xf3n del submain")
B.rf=new A.a("In\xedcio das laterais","Start of laterals","Inicio de las laterales")
B.ti=new A.a("Centro (laterais pareadas)","Centre (paired laterals)","Centro (laterales pareadas)")
B.th=new A.a("Fim das laterais","End of laterals","Final de las laterales")
B.fd=new A.a("Tubo do submain","Submain pipe","Tuber\xeda del submain")
B.rH=new A.a("Posi\xe7\xe3o da v\xe1lvula","Valve position","Posici\xf3n de la v\xe1lvula")
B.bV=new A.a("In\xedcio","Start","Inicio")
B.jv=new A.a("Centro","Centre","Centro")
B.kJ=new A.a("Fim","End","Final")
B.j4=new A.a("Trecho at\xe9 a v\xe1lvula (stub)","Stub to the valve","Tramo hasta la v\xe1lvula")
B.wu=new A.a("Espa\xe7amento (% do di\xe2metro molhado)","Spacing (% of wetted diameter)","Espaciamiento (% del di\xe1metro mojado)")
B.nB=new A.a("Dire\xe7\xe3o (\xb0)","Direction (\xb0)","Direcci\xf3n (\xb0)")
B.o6=new A.a("Quadrado","Square","Cuadrado")
B.po=new A.a("Triangular","Triangular","Triangular")
B.rB=new A.a("Raio {r} m \u2192 espa\xe7amento {s} m; taxa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %","Radius {r} m \u2192 spacing {s} m; rate \u2248 {pr} mm/h; theoretical CU \u2248 {cu} %","Radio {r} m \u2192 espaciamiento {s} m; tasa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %")
B.nP=new A.a("Lateral com emissores","Lateral with outlets","Lateral con emisores")
B.lk=new A.a("Declividade (%; + desce)","Slope (%; + downhill)","Pendiente (%; + baja)")
B.ia=new A.a("Toler\xe2ncia abaixo (%)","Tolerance below (%)","Tolerancia por debajo (%)")
B.pA=new A.a("Toler\xe2ncia acima (%)","Tolerance above (%)","Tolerancia por encima (%)")
B.jN=new A.a("Vaz\xe3o de entrada","Inlet flow","Caudal de entrada")
B.k7=new A.a("Perda de carga total","Total head loss","P\xe9rdida de carga total")
B.qr=new A.a("Press\xe3o no fim","End pressure","Presi\xf3n al final")
B.kj=new A.a("Press\xe3o m\xedn / m\xe1x","Min / max pressure","Presi\xf3n m\xedn / m\xe1x")
B.ua=new A.a("Varia\xe7\xe3o de press\xe3o","Pressure variation","Variaci\xf3n de presi\xf3n")
B.u0=new A.a("Velocidade m\xe1x.","Max. velocity","Velocidad m\xe1x.")
B.nz=new A.a("CU / DU / EU / Us","CU / DU / EU / Us","CU / DU / EU / Us")
B.wt=new A.a("qvar","qvar","qvar")
B.ii=new A.a("Comprimento m\xe1ximo (janela \xb1)","Maximum length (\xb1 window)","Longitud m\xe1xima (ventana \xb1)")
B.uk=new A.a("Altura est\xe1tica","Static head","Altura est\xe1tica")
B.l8=new A.a("Adutora","Delivery main","Conducci\xf3n")
B.ig=new A.a("Horas/ano","Hours/year","Horas/a\xf1o")
B.c9=new A.a("Ponto de opera\xe7\xe3o","Operating point","Punto de operaci\xf3n")
B.ja=new A.a("A bomba n\xe3o vence a altura est\xe1tica.","The pump cannot overcome the static head.","La bomba no supera la altura est\xe1tica.")
B.tH=new A.a("Altura manom\xe9trica","Total head","Altura manom\xe9trica")
B.lK=new A.a("Velocidade na adutora","Velocity in the main","Velocidad en la conducci\xf3n")
B.wp=new A.a("Pot\xeancia hidr\xe1ulica","Hydraulic power","Potencia hidr\xe1ulica")
B.u5=new A.a("Pot\xeancia no eixo (\u03b7 {e} %)","Shaft power (\u03b7 {e} %)","Potencia en el eje (\u03b7 {e} %)")
B.hG=new A.a("Energia anual","Annual energy","Energ\xeda anual")
B.vy=new A.a("Shutoff / runout","Shutoff / runout","Shutoff / runout")
B.o2=new A.a("Velocidade (m/s)","Velocity (m/s)","Velocidad (m/s)")
B.vc=new A.a("Tempo de fechamento (s)","Closure time (s)","Tiempo de cierre (s)")
B.xj=new A.a("Press\xe3o est\xe1tica","Static pressure","Presi\xf3n est\xe1tica")
B.pw=new A.a("Resultado (Joukowsky)","Result (Joukowsky)","Resultado (Joukowsky)")
B.rj=new A.a("Celeridade","Wave celerity","Celeridad")
B.qg=new A.a("Sobrepress\xe3o m\xe1xima (fechamento instant\xe2neo)","Maximum surge (instantaneous closure)","Sobrepresi\xf3n m\xe1xima (cierre instant\xe1neo)")
B.mi=new A.a("Tempo cr\xedtico 2L/a","Critical time 2L/a","Tiempo cr\xedtico 2L/a")
B.f8=new A.a("Sobrepress\xe3o estimada (fechamento {s} s)","Estimated surge (closure {s} s)","Sobrepresi\xf3n estimada (cierre {s} s)")
B.qn=new A.a("Press\xe3o total","Total pressure","Presi\xf3n total")
B.kh=new A.a("Classe do tubo","Pipe class","Clase de la tuber\xeda")
B.bX=new A.a("Fitas","Tapes","Cintas")
B.pB=new A.a("Uso","Use","Uso")
B.jW=new A.a("DN","DN","DN")
B.q0=new A.a("DI mm","ID mm","DI mm")
B.jo=new A.a("C","C","C")
B.y4=new A.a("PN (m)","PN (m)","PN (m)")
B.fy=new A.a("{c}/m","{c}/m","{c}/m")
B.fr=new A.a("k (L/h\xb7m^-x)","k (L/h\xb7m^-x)","k (L/h\xb7m^-x)")
B.y0=new A.a("x","x","x")
B.wj=new A.a("P padr\xe3o","Default P","P predeterminada")
B.jn=new A.a("CV","CV","CV")
B.tM=new A.a("Tol \xb1%","Tol \xb1%","Tol \xb1%")
B.qT=new A.a("{c}","{c}","{c}")
B.wn=new A.a("Esp. m","Spacing m","Esp. m")
B.xZ=new A.a("q nom L/h","q nom L/h","q nom L/h")
B.m5=new A.a("Kd","Kd","Kd")
B.ck=new A.a("Tipo","Type","Tipo")
B.jM=new A.a("K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)")
B.vB=new A.a("n","n","n")
B.hL=new A.a("Q m\xe1x m\xb3/h","Max Q m\xb3/h","Q m\xe1x m\xb3/h")
B.p2=new A.a("Pontos (Q m\xb3/h @ H m)","Points (Q m\xb3/h @ H m)","Puntos (Q m\xb3/h @ H m)")
B.np=new A.a("\u03b7","\u03b7","\u03b7")
B.p0=new A.a("Submersa","Submersible","Sumergible")
B.oY=new A.a("Edite e pressione Enter em cada campo. Valores hidr\xe1ulicos internos em SI; vaz\xf5es em L/h ou m\xb3/h conforme indicado.","Edit and press Enter in each field. Internal hydraulic values are SI; flows in L/h or m\xb3/h as indicated.","Edite y pulse Intro en cada campo. Valores hidr\xe1ulicos internos en SI; caudales en L/h o m\xb3/h seg\xfan se indica.")
B.nC=new A.a("PVC","PVC","PVC")
B.nV=new A.a("PEAD/PE100","HDPE/PE100","PEAD/PE100")
B.nv=new A.a("PEBD","LDPE","PEBD")
B.t7=new A.a("A\xe7o","Steel","Acero")
B.fe=new A.a("Ferro d\xfactil","Ductile iron","Fundici\xf3n d\xfactil")
B.iC=new A.a("Alum\xednio","Aluminium","Aluminio")
B.vl=new A.a("Concreto","Concrete","Hormig\xf3n")
B.wh=new A.a("C\xe1lculo n\xe3o convergiu","Calculation did not converge","El c\xe1lculo no convergi\xf3")
B.yh=new A.a("N\xe3o foi poss\xedvel atender a janela de press\xe3o com os tubos dispon\xedveis","Could not meet the pressure window with the available pipes","No se pudo cumplir la ventana de presi\xf3n con las tuber\xedas disponibles")
B.nq=new A.a("Linha principal n\xe3o consegue atender a press\xe3o das v\xe1lvulas","Mainline cannot meet the valve pressures","La l\xednea principal no puede cumplir la presi\xf3n de las v\xe1lvulas")
B.i2=new A.a("Nenhuma fonte de \xe1gua conectada","No water supply connected","Ninguna fuente de agua conectada")
B.qU=new A.a("Emissor acima da press\xe3o admiss\xedvel","Outlet above allowable pressure","Emisor por encima de la presi\xf3n admisible")
B.xW=new A.a("Emissor abaixo da press\xe3o admiss\xedvel","Outlet below allowable pressure","Emisor por debajo de la presi\xf3n admisible")
B.rG=new A.a("Press\xe3o acima da classe do tubo","Pressure above the pipe rating","Presi\xf3n por encima de la clase de la tuber\xeda")
B.wk=new A.a("Bomba fora da faixa de opera\xe7\xe3o","Pump outside its operating range","Bomba fuera del rango de operaci\xf3n")
B.oG=new A.a("Suc\xe7\xe3o da bomba acima do limite pr\xe1tico: instale a bomba mais perto do n\xedvel da \xe1gua ou use uma bomba submersa","Pump suction lift above the practical limit: install the pump closer to the water level or use a submersible pump","Succi\xf3n de la bomba por encima del l\xedmite pr\xe1ctico: instale la bomba m\xe1s cerca del nivel del agua o use una bomba sumergible")
B.uX=new A.a("Vaz\xe3o da fonte excedida","Supply flow exceeded","Caudal de la fuente excedido")
B.i3=new A.a("Press\xe3o m\xe1xima da fonte excedida","Supply maximum pressure exceeded","Presi\xf3n m\xe1xima de la fuente excedida")
B.kl=new A.a("Vaz\xe3o fora da faixa da v\xe1lvula","Flow outside the valve range","Caudal fuera del rango de la v\xe1lvula")
B.mK=new A.a("V\xe1lvula n\xe3o encontrada","Valve not found","V\xe1lvula no encontrada")
B.vq=new A.a("Press\xe3o insuficiente na v\xe1lvula","Insufficient pressure at the valve","Presi\xf3n insuficiente en la v\xe1lvula")
B.oZ=new A.a("V\xe1lvula n\xe3o alcan\xe7ada pela linha principal","Valve not reached by the mainline","V\xe1lvula no alcanzada por la l\xednea principal")
B.rn=new A.a("Velocidade m\xe1xima excedida","Maximum velocity exceeded","Velocidad m\xe1xima excedida")
B.u6=new A.a("Zona sem tubos ou emissores","Zone without pipes or outlets","Zona sin tuber\xedas ni emisores")
B.tB=new A.a("Zonas conectadas entre si sem v\xe1lvula","Zones connected without a valve","Zonas conectadas entre s\xed sin v\xe1lvula")
B.hO=new A.a("V\xe1lvula sem tubos de zona","Valve without zone pipes","V\xe1lvula sin tuber\xedas de zona")
B.vG=new A.a("Emissor sem modelo no cat\xe1logo","Outlet without a catalog model","Emisor sin modelo en el cat\xe1logo")
B.lJ=new A.a("Fita sem modelo no cat\xe1logo","Tape without a catalog model","Cinta sin modelo en el cat\xe1logo")
B.v8=new A.a("Bomba sem modelo no cat\xe1logo","Pump without a catalog model","Bomba sin modelo en el cat\xe1logo")
B.nY=new A.a("Acess\xf3rio sem modelo no cat\xe1logo","Device without a catalog model","Accesorio sin modelo en el cat\xe1logo")
B.tF=new A.a("Rede sem fonte de carga fixa","Network without a fixed-head source","Red sin fuente de carga fija")
B.fO=new A.a("P\xe1gina de dados ausente no DWG","Missing data page in DWG","P\xe1gina de datos ausente en el DWG")
B.qd=new A.a("OpenCADIrrigation \u2014 CAD para projeto de irriga\xe7\xe3o pressurizada.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lise de laterais passo a passo, dimensionamento por velocidade e por janela de press\xe3o com crit\xe9rio econ\xf4mico.\nRoda no navegador, sem instala\xe7\xe3o.","OpenCADIrrigation \u2014 CAD for pressurised irrigation design.\nHydraulic engine: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), step-by-step lateral analysis, velocity and pressure-window pipe sizing with economic trade-off.\nRuns in the browser, nothing to install.","OpenCADIrrigation \u2014 CAD para el dise\xf1o de riego presurizado.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lisis de laterales paso a paso, dimensionamiento por velocidad y por ventana de presi\xf3n con criterio econ\xf3mico.\nFunciona en el navegador, sin instalaci\xf3n.")
B.pR=new A.a("Vers\xe3o {v}","Version {v}","Versi\xf3n {v}")
B.wJ=new A.a("Site do projeto","Project site","Sitio del proyecto")
B.wB=new A.a("Arco (3 pontos)","Arc (3 points)","Arco (3 puntos)")
B.rw=new A.a("Spline (curva suave)","Spline (smooth curve)","Spline (curva suave)")
B.lg=new A.a("Hachura","Hatch","Sombreado")
B.c7=new A.a("S\xedmbolo","Symbol","S\xedmbolo")
B.lj=new A.a("Cota angular","Angular dimension","Cota angular")
B.y2=new A.a("Cota radial","Radial dimension","Cota radial")
B.fD=new A.a("Chamada (leader)","Leader","Llamada (leader)")
B.cg=new A.a("Rotacionar","Rotate","Rotar")
B.rL=new A.a("Espelhar","Mirror","Simetr\xeda")
B.bU=new A.a("Escalar","Scale","Escalar")
B.q2=new A.a("Deslocar (offset)","Offset","Desfasar (offset)")
B.iU=new A.a("Aparar","Trim","Recortar")
B.kr=new A.a("Estender","Extend","Alargar")
B.y7=new A.a("Cortar tubo","Cut pipe","Cortar tuber\xeda")
B.x3=new A.a("Perfil de eleva\xe7\xe3o","Elevation profile","Perfil de elevaci\xf3n")
B.tb=new A.a("Clique no in\xedcio, em um ponto do arco e no fim","Click start, a point on the arc, then end","Clic en el inicio, un punto del arco y el final")
B.lU=new A.a("Clique nos pontos da curva; Enter termina","Click curve points; Enter ends","Clic en los puntos de la curva; Intro termina")
B.he=new A.a("Clique nos v\xe9rtices da \xe1rea a hachurar; Enter fecha","Click the hatch boundary vertices; Enter closes","Clic en los v\xe9rtices del \xe1rea; Intro cierra")
B.p4=new A.a("Clique para inserir o s\xedmbolo (tipo e tamanho no painel)","Click to insert the symbol (kind and size in the panel)","Clic para insertar el s\xedmbolo (tipo y tama\xf1o en el panel)")
B.fc=new A.a("Clique no v\xe9rtice, nos dois lados e na posi\xe7\xe3o do arco","Click the vertex, both sides, then the arc position","Clic en el v\xe9rtice, los dos lados y la posici\xf3n del arco")
B.lt=new A.a("Clique no c\xedrculo (ou centro) e depois no ponto da cota","Click the circle (or centre) then the dimension point","Clic en el c\xedrculo (o centro) y luego en el punto de la cota")
B.fv=new A.a("Clique na ponta da seta e nos v\xe9rtices; Enter abre o texto","Click the arrow tip and the vertices; Enter opens the text","Clic en la punta de la flecha y los v\xe9rtices; Intro abre el texto")
B.xG=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (Ctrl = copiar)","Selection: click base point, reference, then target (Ctrl = copy)","Selecci\xf3n: clic en el punto base, la referencia y el destino (Ctrl = copiar)")
B.m0=new A.a("Sele\xe7\xe3o: clique nos dois pontos da linha de espelho","Selection: click the two points of the mirror line","Selecci\xf3n: clic en los dos puntos del eje de simetr\xeda")
B.xR=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (fator = raz\xe3o)","Selection: click base point, reference, then target (factor = ratio)","Selecci\xf3n: clic en el punto base, la referencia y el destino (factor = raz\xf3n)")
B.xc=new A.a("Clique no objeto e depois no lado do deslocamento (dist\xe2ncia no painel)","Click the object then the offset side (distance in the panel)","Clic en el objeto y luego en el lado del desfase (distancia en el panel)")
B.uS=new A.a("Clique na parte a remover; a sele\xe7\xe3o define as arestas de corte","Click the part to remove; the selection defines the cutting edges","Clic en la parte a quitar; la selecci\xf3n define las aristas de corte")
B.pT=new A.a("Clique perto da extremidade a estender at\xe9 a pr\xf3xima aresta","Click near the end to extend to the next edge","Clic cerca del extremo a alargar hasta la siguiente arista")
B.mk=new A.a("Clique no ponto do tubo/lateral onde cortar","Click the point of the pipe/lateral to cut","Clic en el punto de la tuber\xeda/lateral donde cortar")
B.pd=new A.a("Clique os pontos do caminho; Enter (ou Concluir) mostra o perfil na aba Perfil; Esc limpa a linha roxa","Click the path points; Enter (or Done) shows the profile in the Profile tab; Esc clears the purple line","Clic en los puntos del camino; Intro (o Terminar) muestra el perfil en la pesta\xf1a Perfil; Esc borra la l\xednea morada")
B.mN=new A.a("Modificar","Modify","Modificar")
B.wz=new A.a("Matriz (array)\u2026","Array\u2026","Matriz (array)\u2026")
B.yf=new A.a("Envelope do submain (laterais selecionadas)","Submain envelope (selected laterals)","Envolvente del submain (laterales seleccionadas)")
B.j1=new A.a("Matriz da sele\xe7\xe3o","Array of the selection","Matriz de la selecci\xf3n")
B.p9=new A.a("Retangular","Rectangular","Rectangular")
B.nI=new A.a("Polar","Polar","Polar")
B.mq=new A.a("Linhas","Rows","Filas")
B.jz=new A.a("Colunas","Columns","Columnas")
B.iw=new A.a("Espa\xe7amento em X","Column spacing","Espaciamiento en X")
B.xs=new A.a("Espa\xe7amento em Y","Row spacing","Espaciamiento en Y")
B.rD=new A.a("\xc2ngulo da matriz (\xb0)","Array angle (\xb0)","\xc1ngulo de la matriz (\xb0)")
B.is=new A.a("N\xfamero de itens","Number of items","N\xfamero de elementos")
B.tI=new A.a("Centro (X, Y)","Centre (X, Y)","Centro (X, Y)")
B.fP=new A.a("\xc2ngulo total (\xb0)","Total angle (\xb0)","\xc1ngulo total (\xb0)")
B.r2=new A.a("Rotacionar itens","Rotate items","Rotar elementos")
B.w5=new A.a("{n} itens selecionados","{n} selected items","{n} elementos seleccionados")
B.rg=new A.a("A camada est\xe1 bloqueada","The layer is locked","La capa est\xe1 bloqueada")
B.fg=new A.a("Nenhuma interse\xe7\xe3o encontrada","No intersection found","No se encontr\xf3 intersecci\xf3n")
B.xP=new A.a("Selecione uma ou mais laterais (sprayline ou fita)","Select one or more laterals (sprayline or tape)","Seleccione una o m\xe1s laterales (sprayline o cinta)")
B.xp=new A.a("Envelope calculado para {n} laterais (verde = posi\xe7\xe3o admiss\xedvel)","Envelope computed for {n} laterals (green = allowable position)","Envolvente calculada para {n} laterales (verde = posici\xf3n admisible)")
B.tg=new A.a("{n} itens criados","{n} items created","{n} elementos creados")
B.og=new A.a("Marcar press\xe3o m\xedn/m\xe1x por zona","Mark min/max pressure per zone","Marcar presi\xf3n m\xedn/m\xe1x por zona")
B.fV=new A.a("Mapa base","Base map","Mapa base")
B.n1=new A.a("Nenhum","None","Ninguno")
B.hH=new A.a("Ruas (OpenStreetMap)","Streets (OpenStreetMap)","Calles (OpenStreetMap)")
B.rV=new A.a("Sat\xe9lite (Esri World Imagery)","Satellite (Esri World Imagery)","Sat\xe9lite (Esri World Imagery)")
B.m_=new A.a("Topogr\xe1fico (OpenTopoMap)","Topographic (OpenTopoMap)","Topogr\xe1fico (OpenTopoMap)")
B.va=new A.a("Ruas claras (CARTO Voyager)","Light streets (CARTO Voyager)","Calles claras (CARTO Voyager)")
B.vI=new A.a("Ruas (Esri World Street Map)","Streets (Esri World Street Map)","Calles (Esri World Street Map)")
B.fB=new A.a("Topogr\xe1fico (Esri World Topo Map)","Topographic (Esri World Topo Map)","Topogr\xe1fico (Esri World Topo Map)")
B.mU=new A.a("Google Maps \u2013 mapa","Google Maps \u2013 roadmap","Google Maps \u2013 mapa")
B.ix=new A.a("Google Maps \u2013 sat\xe9lite","Google Maps \u2013 satellite","Google Maps \u2013 sat\xe9lite")
B.fL=new A.a("Google Maps \u2013 h\xedbrido (sat\xe9lite + vias)","Google Maps \u2013 hybrid (satellite + roads)","Google Maps \u2013 h\xedbrido (sat\xe9lite + v\xedas)")
B.ie=new A.a("Google Maps \u2013 relevo","Google Maps \u2013 terrain","Google Maps \u2013 relieve")
B.l_=new A.a("Personalizado (URL XYZ)","Custom (XYZ URL)","Personalizado (URL XYZ)")
B.xx=new A.a("Chave da API do Google Maps\u2026","Google Maps API key\u2026","Clave de la API de Google Maps\u2026")
B.yp=new A.a("URL do mapa personalizado\u2026","Custom map URL\u2026","URL del mapa personalizado\u2026")
B.pk=new A.a("Chave da API do Google Maps","Google Maps API key","Clave de la API de Google Maps")
B.fY=new A.a("Os mapas do Google s\xe3o servidos pela Map Tiles API da Google Maps Platform com a sua pr\xf3pria chave: o uso \xe9 contabilizado (e cobrado al\xe9m da cota gratuita) na sua conta Google Cloud.","Google maps come from the Map Tiles API of the Google Maps Platform with your own key: usage is counted (and billed beyond the free quota) on your Google Cloud account.","Los mapas de Google los sirve la Map Tiles API de Google Maps Platform con su propia clave: el uso se contabiliza (y se cobra m\xe1s all\xe1 de la cuota gratuita) en su cuenta de Google Cloud.")
B.yr=new A.a('1. No Google Cloud Console, crie um projeto e ative a "Map Tiles API".   2. Em Credenciais, crie uma chave de API.   3. Restrinja a chave aos sites (referenciadores HTTP) em que usa o app.','1. In the Google Cloud Console create a project and enable the "Map Tiles API".   2. Under Credentials create an API key.   3. Restrict the key to the sites (HTTP referrers) where you use the app.','1. En Google Cloud Console cree un proyecto y active la "Map Tiles API".   2. En Credenciales cree una clave de API.   3. Restrinja la clave a los sitios (referentes HTTP) donde usa la app.')
B.r5=new A.a("Abrir Google Cloud Console","Open Google Cloud Console","Abrir Google Cloud Console")
B.pL=new A.a("Como obter a chave","How to get a key","C\xf3mo obtener la clave")
B.na=new A.a("Chave da API","API key","Clave de la API")
B.jb=new A.a("A chave fica guardada s\xf3 neste navegador e \xe9 enviada apenas ao Google.","The key is kept in this browser only and sent to Google only.","La clave se guarda solo en este navegador y se env\xeda \xfanicamente a Google.")
B.qs=new A.a("Remover chave","Remove key","Quitar clave")
B.oI=new A.a("Google Maps: informe a chave da API em Ver \u2192 Mapa base","Google Maps: enter the API key under View \u2192 Base map","Google Maps: indique la clave de la API en Ver \u2192 Mapa base")
B.vM=new A.a("Google Maps: {e}","Google Maps: {e}","Google Maps: {e}")
B.tC=new A.a("Mapa base personalizado","Custom base map","Mapa base personalizado")
B.w9=new A.a("Endere\xe7o dos tiles no padr\xe3o XYZ (Web Mercator): um servidor pr\xf3prio, um provedor com chave ou um WMTS.","Address of the tiles in the XYZ pattern (Web Mercator): your own server, a keyed provider or a WMTS.","Direcci\xf3n de los tiles en el patr\xf3n XYZ (Web Mercator): un servidor propio, un proveedor con clave o un WMTS.")
B.wQ=new A.a("Modelo de URL","URL template","Plantilla de URL")
B.lP=new A.a("Marcadores: {z} zoom, {x} coluna, {y} linha ({-y} para TMS), {s} subdom\xednio a/b/c. A chave do provedor, se houver, vai na pr\xf3pria URL.","Placeholders: {z} zoom, {x} column, {y} row ({-y} for TMS), {s} subdomain a/b/c. The provider key, if any, goes in the URL itself.","Marcadores: {z} zoom, {x} columna, {y} fila ({-y} para TMS), {s} subdominio a/b/c. La clave del proveedor, si la hay, va en la propia URL.")
B.iN=new A.a("A URL precisa come\xe7ar com http(s):// e conter {z}, {x} e {y}","The URL must start with http(s):// and contain {z}, {x} and {y}","La URL debe empezar con http(s):// y contener {z}, {x} e {y}")
B.lq=new A.a("Defina a georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia) para mostrar o mapa base","Set the georeference (File \u2192 Georeference) to show the base map","Defina la georreferencia (Archivo \u2192 Georreferencia) para mostrar el mapa base")
B.oB=new A.a("Al\xe7as de edi\xe7\xe3o","Edit grips","Pinzamientos de edici\xf3n")
B.rR=new A.a("Envelope de posi\xe7\xe3o do submain","Allowable submain position","Posici\xf3n admisible del submain")
B.ks=new A.a("Camada atual","Current layer","Capa actual")
B.jc=new A.a("Bloquear","Lock","Bloquear")
B.vt=new A.a("Nova camada","New layer","Nueva capa")
B.oq=new A.a("Renomear","Rename","Renombrar")
B.hc=new A.a("Excluir camada (itens v\xe3o para DRAWING)","Delete layer (items move to DRAWING)","Eliminar capa (los elementos van a DRAWING)")
B.jE=new A.a("Cor","Colour","Color")
B.ik=new A.a("Nome da camada","Layer name","Nombre de la capa")
B.w6=new A.a("J\xe1 existe uma camada com esse nome","A layer with that name already exists","Ya existe una capa con ese nombre")
B.lO=new A.a("Clique no olho para mostrar/ocultar, no cadeado para bloquear, na cor para alterar; duplo clique renomeia; o c\xedrculo marca a camada atual.","Click the eye to show/hide, the padlock to lock, the colour to change it; double-click renames; the dot marks the current layer.","Clic en el ojo para mostrar/ocultar, en el candado para bloquear, en el color para cambiarlo; doble clic renombra; el c\xedrculo marca la capa actual.")
B.jT=new A.a("Edi\xe7\xe3o em lote ({n} {type})","Batch edit ({n} {type})","Edici\xf3n en lote ({n} {type})")
B.rX=new A.a("(valores diferentes)","(mixed values)","(valores distintos)")
B.q5=new A.a("Tamanho (m)","Size (m)","Tama\xf1o (m)")
B.iY=new A.a("\xc2ngulo da hachura (\xb0)","Hatch angle (\xb0)","\xc1ngulo del sombreado (\xb0)")
B.im=new A.a("Espa\xe7amento da hachura (m)","Hatch spacing (m)","Espaciamiento del sombreado (m)")
B.ll=new A.a("Preenchimento s\xf3lido","Solid fill","Relleno s\xf3lido")
B.ni=new A.a("Opacidade","Opacity","Opacidad")
B.lM=new A.a("Largura (m)","Width (m)","Ancho (m)")
B.kE=new A.a("Altura (m)","Height (m)","Alto (m)")
B.ij=new A.a("Emissores por planta (0 = padr\xe3o do projeto)","Emitters per plant (0 = project default)","Emisores por planta (0 = valor del proyecto)")
B.lH=new A.a("Balan\xe7o h\xeddrico (ETo \xd7 Kc, solo)","Water balance (ETo \xd7 Kc, soil)","Balance h\xeddrico (ETo \xd7 Kc, suelo)")
B.k_=new A.a("ETo (mm/dia)","ETo (mm/day)","ETo (mm/d\xeda)")
B.m4=new A.a("Kc","Kc","Kc")
B.qK=new A.a("Kc por cultura (FAO-56)","Kc by crop (FAO-56)","Kc por cultivo (FAO-56)")
B.ok=new A.a("\xc1gua dispon\xedvel (mm/m)","Available water (mm/m)","Agua disponible (mm/m)")
B.tR=new A.a("Profundidade radicular (m)","Root depth (m)","Profundidad radicular (m)")
B.oR=new A.a("Fra\xe7\xe3o de esgotamento (MAD)","Allowed depletion (MAD)","Fracci\xf3n de agotamiento (MAD)")
B.pK=new A.a("Fra\xe7\xe3o molhada","Wetted fraction","Fracci\xf3n mojada")
B.nh=new A.a("Espa\xe7amento entre plantas (m)","Plant spacing (m)","Espaciamiento entre plantas (m)")
B.k0=new A.a("Espa\xe7amento entre linhas (m)","Row spacing (m)","Espaciamiento entre hileras (m)")
B.wR=new A.a("ETc (mm/dia)","ETc (mm/day)","ETc (mm/d\xeda)")
B.fa=new A.a("Intervalo (dias)","Interval (days)","Intervalo (d\xedas)")
B.ub=new A.a("Dist\xe2ncia do offset","Offset distance","Distancia del desfase")
B.vH=new A.a("Manter original (copiar)","Keep original (copy)","Mantener original (copiar)")
B.wK=new A.a("Manter original","Keep source","Mantener original")
B.wq=new A.a("Dividir tubo ao inserir sobre ele","Split pipe when inserted on it","Dividir tuber\xeda al insertar sobre ella")
B.uV=new A.a("Curva fechada","Closed curve","Curva cerrada")
B.pF=new A.a("\xc2ngulo (\xb0)","Angle (\xb0)","\xc1ngulo (\xb0)")
B.rl=new A.a("Texto da chamada","Leader text","Texto de la llamada")
B.hP=new A.a("Raio do arco de cota (m)","Dimension arc radius (m)","Radio del arco de cota (m)")
B.hf=new A.a("Camada bloqueada: edi\xe7\xe3o desativada","Locked layer: editing disabled","Capa bloqueada: edici\xf3n desactivada")
B.qv=new A.a("Vaz\xe3o de lavagem no fim (0 = autom\xe1tica)","End flushing flow (0 = automatic)","Caudal de lavado al final (0 = autom\xe1tico)")
B.xD=new A.a("Envelope do submain","Submain envelope","Envolvente del submain")
B.rm=new A.a("Melhor posi\xe7\xe3o: {f} % do in\xedcio (\u0394p {v})","Best position: {f} % from the start (\u0394p {v})","Mejor posici\xf3n: {f} % desde el inicio (\u0394p {v})")
B.ke=new A.a("Admiss\xedvel: {a} % a {b} %","Allowable: {a} % to {b} %","Admisible: {a} % a {b} %")
B.ur=new A.a("Nenhuma posi\xe7\xe3o atende \xe0 janela de press\xe3o","No position meets the pressure window","Ninguna posici\xf3n cumple la ventana de presi\xf3n")
B.o3=new A.a("Seta norte","North arrow","Flecha norte")
B.hT=new A.a("\xc1rvore","Tree","\xc1rbol")
B.pr=new A.a("Edifica\xe7\xe3o","Building","Edificaci\xf3n")
B.c_=new A.a("Reservat\xf3rio","Tank","Dep\xf3sito")
B.uN=new A.a("Caixa de v\xe1lvula","Valve box","Arqueta de v\xe1lvula")
B.wr=new A.a("Casa de bombas","Pump house","Caseta de bombeo")
B.rW=new A.a("Port\xe3o","Gate","Port\xf3n")
B.xh=new A.a("Esta\xe7\xe3o de filtragem","Filter station","Estaci\xf3n de filtrado")
B.cE=new A.a("Caf\xe9","Coffee","Caf\xe9")
B.bJ=new A.a("Banana","Banana","Banano")
B.mD=new A.a("Manga","Mango","Mango")
B.u_=new A.a("Ma\xe7\xe3","Apple","Manzana")
B.cl=new A.a("Tomate","Tomato","Tomate")
B.bx=new A.a("Milho","Maize","Ma\xedz")
B.bI=new A.a("Cana-de-a\xe7\xfacar","Sugarcane","Ca\xf1a de az\xfacar")
B.c0=new A.a("Hortali\xe7as","Vegetables","Hortalizas")
B.bD=new A.a("Grama","Turf","C\xe9sped")
B.nE=new A.a("Pastagem","Pasture","Pasto")
B.jg=new A.a("Personalizado","Custom","Personalizado")
B.vv=new A.a("Lavagem (flushing)","Flushing","Lavado (flushing)")
B.qw=new A.a("Golpe de ar\xedete","Water hammer","Golpe de ariete")
B.w1=new A.a("Agronomia","Agronomy","Agronom\xeda")
B.ys=new A.a("Programa\xe7\xe3o","Schedule","Programaci\xf3n")
B.cb=new A.a("Perfil","Profile","Perfil")
B.cz=new A.a("C\xf3digo","Code","C\xf3digo")
B.uf=new A.a("V alvo (m/s)","Target V (m/s)","V objetivo (m/s)")
B.ju=new A.a("Celeridade","Celerity","Celeridad")
B.xk=new A.a("Sobrepress\xe3o","Surge","Sobrepresi\xf3n")
B.m1=new A.a("P m\xe1x regime","Max steady P","P m\xe1x r\xe9gimen")
B.nb=new A.a("P total","Total P","P total")
B.vD=new A.a("2L/a (s)","2L/a (s)","2L/a (s)")
B.iI=new A.a("AFD","RAW","ARA")
B.xo=new A.a("Intervalo (d)","Interval (d)","Intervalo (d)")
B.vb=new A.a("L\xedquida/evento","Net/event","Neta/evento")
B.rS=new A.a("Bruta/evento","Gross/event","Bruta/evento")
B.mV=new A.a("Horas/evento","Hours/event","Horas/evento")
B.q9=new A.a("CU sobrep. %","Overlap CU %","CU solap. %")
B.qH=new A.a("Zonas","Zones","Zonas")
B.kI=new A.a("Fim","End","Fin")
B.vm=new A.a("Dist\xe2ncia","Distance","Distancia")
B.ft=new A.a("Use a ferramenta Perfil (PR) ou selecione um tubo/lateral para ver o perfil do terreno","Use the Profile tool (PR) or select a pipe/lateral to see the ground profile","Use la herramienta Perfil (PR) o seleccione una tuber\xeda/lateral para ver el perfil del terreno")
B.tv=new A.a("Declividade m\xe9dia {s} %  \xb7  desn\xedvel {d} m  \xb7  comprimento {l}","Mean slope {s} %  \xb7  rise {d} m  \xb7  length {l}","Pendiente media {s} %  \xb7  desnivel {d} m  \xb7  longitud {l}")
B.mu=new A.a("Luva","Coupler","Manguito")
B.vY=new A.a("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0")
B.qJ=new A.a("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0")
B.oP=new A.a("T\xea","Tee","Te")
B.jH=new A.a("Cruzeta","Cross","Cruz")
B.lb=new A.a("Redu\xe7\xe3o","Reducer","Reducci\xf3n")
B.w8=new A.a("Tamp\xe3o","End cap","Tap\xf3n")
B.iO=new A.a("Adaptador","Adapter","Adaptador")
B.wA=new A.a("Conector inicial de lateral","Lateral take-off","Conector inicial de lateral")
B.hv=new A.a("Final de linha","Line end","Final de l\xednea")
B.i_=new A.a("Haste / tubo de subida","Riser","Tubo de subida")
B.bz=new A.a("Conex\xf5es","Fittings","Conexiones")
B.jQ=new A.a("Conectores de lateral","Lateral connectors","Conectores de lateral")
B.lQ=new A.a("Hastes e tubos de subida","Risers","Tubos de subida")
B.pl=new A.a("Tipo","Kind","Tipo")
B.vC=new A.a("DN 2","Size 2","DN 2")
B.kP=new A.a("Fornecedor","Supplier","Proveedor")
B.tS=new A.a("+ Adicionar","+ Add","+ A\xf1adir")
B.k8=new A.a("Duplicar","Duplicate","Duplicar")
B.xV=new A.a("Importar (JSON/CSV)\u2026","Import (JSON/CSV)\u2026","Importar (JSON/CSV)\u2026")
B.x5=new A.a("Exportar JSON","Export JSON","Exportar JSON")
B.j5=new A.a("Exportar CSV desta aba","Export CSV of this tab","Exportar CSV de esta pesta\xf1a")
B.fA=new A.a("Restaurar padr\xe3o","Restore default","Restaurar predeterminado")
B.rZ=new A.a("Usar como padr\xe3o para novos projetos","Use as default for new projects","Usar como predeterminado en proyectos nuevos")
B.vh=new A.a("JSON no formato do cat\xe1logo (exportado daqui) ou CSV com cabe\xe7alho; colunas reconhecidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tubos); id, name, kind, sizeMm, size2Mm, cost (conex\xf5es); id, name, idMm, spacing, qLph, headM, x, cost (fitas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emissores).","JSON in the catalog format (exported from here) or CSV with a header; recognised columns: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (pipes); id, name, kind, sizeMm, size2Mm, cost (fittings); id, name, idMm, spacing, qLph, headM, x, cost (tapes); id, name, kind, sizeMm, k, n, maxQm3h, cost (valves); id, name, points (Q@H;\u2026), eff, cost (pumps); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (outlets).","JSON en el formato del cat\xe1logo (exportado desde aqu\xed) o CSV con encabezado; columnas reconocidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tuber\xedas); id, name, kind, sizeMm, size2Mm, cost (conexiones); id, name, idMm, spacing, qLph, headM, x, cost (cintas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emisores).")
B.y9=new A.a('Remover "{n}" do cat\xe1logo? Itens do projeto que o usam ficar\xe3o sem modelo.','Remove "{n}" from the catalog? Project items using it will lose their model.','\xbfQuitar "{n}" del cat\xe1logo? Los elementos del proyecto que lo usan quedar\xe1n sin modelo.')
B.qI=new A.a("em uso: {n}","in use: {n}","en uso: {n}")
B.ih=new A.a("Cat\xe1logo: {n} itens importados","Catalog: {n} items imported","Cat\xe1logo: {n} elementos importados")
B.tp=new A.a("Cat\xe1logo salvo como padr\xe3o para novos projetos","Catalog saved as default for new projects","Cat\xe1logo guardado como predeterminado para proyectos nuevos")
B.tx=new A.a("Cat\xe1logo padr\xe3o restaurado","Default catalog restored","Cat\xe1logo predeterminado restaurado")
B.oD=new A.a("LP sem solu\xe7\xe3o com os tubos habilitados (m\xe9todo guloso usado)","LP infeasible with the enabled pipes (greedy method used)","LP sin soluci\xf3n con las tuber\xedas habilitadas (se us\xf3 el m\xe9todo voraz)")
B.vZ=new A.a("Conex\xe3o sem item no cat\xe1logo","Fitting without a catalog item","Conexi\xf3n sin elemento en el cat\xe1logo")
B.v2=new A.a("Golpe de ar\xedete acima da classe do tubo","Water hammer above the pipe class","Golpe de ariete por encima de la clase de la tuber\xeda")
B.vJ=new A.a("Turno sem \xe1rea irrigada: dura\xe7\xe3o mantida","System flow without an irrigated area: duration kept","Turno sin \xe1rea regada: duraci\xf3n mantenida")
B.uj=new A.a("Programa\xe7\xe3o excede 24 h no dia","Schedule exceeds 24 h in a day","La programaci\xf3n supera 24 h en el d\xeda")
B.px=new A.a("Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, imagens)\u2026","Import (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, images)\u2026","Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, im\xe1genes)\u2026")
B.ud=new A.a("Pontos: {n} cotas importadas{geo}","Points: {n} spot heights imported{geo}","Puntos: {n} cotas importadas{geo}")
B.pV=new A.a(u.h,"SHP: {r} records, {n} entities ({crs})",u.h)
B.uu=new A.a("Imagem {w}\xd7{h} px inserida na vista (ajuste com as al\xe7as ou Georreferenciar imagem)","Image {w}\xd7{h} px placed in the view (adjust with grips or Georeference image)","Imagen {w}\xd7{h} px insertada en la vista (ajuste con las pinzas o Georreferenciar imagen)")
B.uO=new A.a("Imagem georreferenciada {w}\xd7{h} px ({crs})","Georeferenced image {w}\xd7{h} px ({crs})","Imagen georreferenciada {w}\xd7{h} px ({crs})")
B.i1=new A.a("resposta inv\xe1lida do servidor de eleva\xe7\xe3o","invalid answer from the elevation server","respuesta no v\xe1lida del servidor de elevaci\xf3n")
B.ya=new A.a("bloco de eleva\xe7\xe3o inv\xe1lido recebido do servidor","invalid elevation tile received from the server","tesela de elevaci\xf3n no v\xe1lida recibida del servidor")
B.v9=new A.a("o servidor devolveu um n\xfamero de eleva\xe7\xf5es diferente do pedido","the server returned a different number of elevations than requested","el servidor devolvi\xf3 un n\xfamero de elevaciones distinto del pedido")
B.hX=new A.a("Arquivo de pontos vazio","Empty points file","Archivo de puntos vac\xedo")
B.tj=new A.a("N\xe3o foi poss\xedvel identificar as colunas X, Y (e Z)","Could not identify the X, Y (and Z) columns","No se pudieron identificar las columnas X, Y (y Z)")
B.oi=new A.a("Arquivo SHP inv\xe1lido","Invalid SHP file","Archivo SHP no v\xe1lido")
B.nZ=new A.a("O ZIP n\xe3o cont\xe9m um arquivo .shp","The ZIP has no .shp file","El ZIP no contiene un archivo .shp")
B.rs=new A.a("O ZIP n\xe3o cont\xe9m imagem","The ZIP has no image","El ZIP no contiene imagen")
B.nW=new A.a("Imagem n\xe3o reconhecida","Image not recognised","Imagen no reconocida")
B.oy=new A.a("Georreferenciar imagem selecionada\u2026","Georeference selected image\u2026","Georreferenciar imagen seleccionada\u2026")
B.w_=new A.a("Georreferenciar imagem","Georeference image","Georreferenciar imagen")
B.wi=new A.a("Informe as coordenadas locais (m) do canto inferior esquerdo, o tamanho real e a rota\xe7\xe3o da imagem.","Enter the local coordinates (m) of the bottom-left corner, the real size and the rotation of the image.","Indique las coordenadas locales (m) de la esquina inferior izquierda, el tama\xf1o real y la rotaci\xf3n de la imagen.")
B.hA=new A.a("Manter propor\xe7\xe3o","Keep aspect ratio","Mantener proporci\xf3n")
B.hg=new A.a("M\xe9todo de dimensionamento","Sizing method","M\xe9todo de dimensionamiento")
B.qk=new A.a("Programa\xe7\xe3o linear (LP: custo de tubo + energia + topografia)","Linear programming (LP: pipe cost + energy + topography)","Programaci\xf3n lineal (LP: costo de tuber\xeda + energ\xeda + topograf\xeda)")
B.vn=new A.a("Guloso (velocidade \u2192 janela de press\xe3o \u2192 economia)","Greedy (velocity \u2192 pressure window \u2192 economics)","Voraz (velocidad \u2192 ventana de presi\xf3n \u2192 econom\xeda)")
B.t0=new A.a("N\xba m\xe1x. de di\xe2metros por lateral","Max. sizes per lateral","N.\xba m\xe1x. de di\xe1metros por lateral")
B.lm=new A.a("N\xba m\xe1x. de di\xe2metros por tubo principal","Max. sizes per mainline pipe","N.\xba m\xe1x. de di\xe1metros por tuber\xeda principal")
B.rO=new A.a("Emissores por planta (EU)","Emitters per plant (EU)","Emisores por planta (EU)")
B.jk=new A.a("N\xf3s de emissores por lateral (m\xe1x.)","Emitter nodes per lateral (max.)","Nudos de emisores por lateral (m\xe1x.)")
B.tw=new A.a("Varia\xe7\xe3o m\xe1x. de press\xe3o na zona (%; 0 = s\xf3 toler\xe2ncia)","Max. zone pressure variation (%; 0 = tolerance only)","Variaci\xf3n m\xe1x. de presi\xf3n en la zona (%; 0 = solo tolerancia)")
B.hU=new A.a("Lavagem e golpe de ar\xedete","Flushing and water hammer","Lavado y golpe de ariete")
B.vr=new A.a("Velocidade de lavagem (m/s)","Flushing velocity (m/s)","Velocidad de lavado (m/s)")
B.mb=new A.a("Press\xe3o m\xedn. no fim da fita (m)","Min. pressure at the tape end (m)","Presi\xf3n m\xedn. al final de la cinta (m)")
B.xf=new A.a("Verificar golpe de ar\xedete (classe do tubo)","Check water hammer (pipe class)","Verificar golpe de ariete (clase de tuber\xeda)")
B.hb=new A.a("Tempo de fechamento de v\xe1lvula (s; 0 = instant\xe2neo)","Valve closure time (s; 0 = instantaneous)","Tiempo de cierre de v\xe1lvula (s; 0 = instant\xe1neo)")
B.iq=new A.a("Selecionar conex\xf5es automaticamente","Select fittings automatically","Seleccionar conexiones autom\xe1ticamente")
B.n6=new A.a("Comprimento da barra de tubo (m; luvas por barra, 0 = nenhuma)","Pipe stick length (m; couplers per stick, 0 = none)","Longitud de la barra de tuber\xeda (m; manguitos por barra, 0 = ninguno)")
B.rt=new A.a("Selecionar bomba\u2026","Select pump\u2026","Seleccionar bomba\u2026")
B.iA=new A.a("Vista 3D do terreno\u2026","3D terrain view\u2026","Vista 3D del terreno\u2026")
B.pq=new A.a("Sele\xe7\xe3o autom\xe1tica de bomba","Automatic pump selection","Selecci\xf3n autom\xe1tica de bomba")
B.l4=new A.a("Ponto de trabalho: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}","Duty: {q} at {h}  \xb7  static lift \u2248 {s}","Punto de trabajo: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}")
B.hx=new A.a("Bombas do cat\xe1logo ordenadas por adequa\xe7\xe3o e custo (compra + 5 anos de energia)","Catalog pumps ranked by suitability and cost (purchase + 5 years of energy)","Bombas del cat\xe1logo ordenadas por idoneidad y costo (compra + 5 a\xf1os de energ\xeda)")
B.pY=new A.a("H na vaz\xe3o","H at duty","H al caudal")
B.mF=new A.a("Margem","Margin","Margen")
B.r_=new A.a("Pot\xeancia","Power","Potencia")
B.j8=new A.a("Em paralelo","In parallel","En paralelo")
B.qS=new A.a("Inserir na fonte","Insert at the supply","Insertar en la fuente")
B.x7=new A.a("Aplicar \xe0 bomba existente","Apply to the existing pump","Aplicar a la bomba existente")
B.pg=new A.a("Execute o projeto com uma fonte de \xe1gua de press\xe3o calculada para obter o ponto de trabalho.","Run the design with a calculated-pressure water supply to get the duty point.","Ejecute el dise\xf1o con una fuente de agua de presi\xf3n calculada para obtener el punto de trabajo.")
B.h9=new A.a("insuficiente","insufficient","insuficiente")
B.v_=new A.a("suc\xe7\xe3o excessiva","suction lift too high","succi\xf3n excesiva")
B.fj=new A.a("Bomba {n} aplicada; execute o projeto novamente","Pump {n} applied; run the design again","Bomba {n} aplicada; vuelva a ejecutar el dise\xf1o")
B.t6=new A.a("Vista 3D do terreno (DEM)","3D terrain view (DEM)","Vista 3D del terreno (MDT)")
B.oO=new A.a("Exagero vertical","Vertical exaggeration","Exageraci\xf3n vertical")
B.oJ=new A.a("Arraste para girar; roda do mouse para aproximar. Tubos e laterais s\xe3o drapejados sobre o terreno.","Drag to rotate; mouse wheel zooms. Pipes and laterals are draped on the terrain.","Arrastre para girar; rueda del rat\xf3n para acercar. Las tuber\xedas y laterales se drapean sobre el terreno.")
B.lF=new A.a("Sem dados de eleva\xe7\xe3o: desenhe curvas de n\xedvel ou cotas, ou importe topografia.","No elevation data: draw contours or spot heights, or import a survey.","Sin datos de elevaci\xf3n: dibuje curvas de nivel o cotas, o importe topograf\xeda.")
B.ry=new A.a("Eleva\xe7\xe3o {a} a {b} m","Elevation {a} to {b} m","Elevaci\xf3n {a} a {b} m")
B.iJ=new A.a("Projetos recentes","Recent projects","Proyectos recientes")
B.w3=new A.a("(nenhum)","(none)","(ninguno)")
B.tm=new A.a("Hist\xf3rico de vers\xf5es\u2026","Version history\u2026","Historial de versiones\u2026")
B.oS=new A.a("Salvar automaticamente no navegador","Autosave in the browser","Guardar autom\xe1ticamente en el navegador")
B.lG=new A.a("Recuperar projeto","Recover project","Recuperar proyecto")
B.te=new A.a("Foram encontrados projetos salvos automaticamente que n\xe3o foram salvos em arquivo. Deseja recuper\xe1-los?","Autosaved projects that were never saved to a file were found. Recover them?","Se encontraron proyectos guardados autom\xe1ticamente que no se guardaron en archivo. \xbfDesea recuperarlos?")
B.on=new A.a("Recuperar","Recover","Recuperar")
B.k1=new A.a("Descartar","Discard","Descartar")
B.lL=new A.a("Depois","Later","Despu\xe9s")
B.o4=new A.a("{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)")
B.x4=new A.a("{n} projetos recuperados","{n} projects recovered","{n} proyectos recuperados")
B.vT=new A.a('Vers\xf5es de "{name}"','Versions of "{name}"','Versiones de "{name}"')
B.wI=new A.a("Nenhuma vers\xe3o guardada ainda: cada Salvar cria uma vers\xe3o (at\xe9 10, no navegador).","No versions kept yet: every Save records a version (up to 10, in the browser).","A\xfan no hay versiones: cada Guardar crea una versi\xf3n (hasta 10, en el navegador).")
B.or=new A.a("Restaurar","Restore","Restaurar")
B.tO=new A.a("v{v} \u2014 {when}","v{v} \u2014 {when}","v{v} \u2014 {when}")
B.n8=new A.a("Vers\xe3o {v} restaurada","Version {v} restored","Versi\xf3n {v} restaurada")
B.vj=new A.a("Turnos","System flows","Turnos")
B.vK=new A.a("Programa\xe7\xe3o do controlador","Controller programme","Programaci\xf3n del controlador")
B.oc=new A.a("Aplicar dura\xe7\xf5es calculadas aos turnos","Apply computed durations to the flows","Aplicar duraciones calculadas a los turnos")
B.vR=new A.a("Exportar programa\xe7\xe3o (CSV)","Export programme (CSV)","Exportar programaci\xf3n (CSV)")
B.tJ=new A.a("Dias","Days","D\xedas")
B.xL=new A.a("In\xedcio do dia (h)","Day start (h)","Inicio del d\xeda (h)")
B.mM=new A.a("Usar os hor\xe1rios de in\xedcio dos turnos","Use the flows' own start hours","Usar las horas de inicio de los turnos")
B.xB=new A.a("M\xe1ximo de horas em um dia: {h}","Maximum hours in one day: {h}","M\xe1ximo de horas en un d\xeda: {h}")
B.hr=new A.a("Execute o projeto para calcular as dura\xe7\xf5es a partir das \xe1reas irrigadas.","Run the design to compute durations from the irrigated areas.","Ejecute el dise\xf1o para calcular las duraciones a partir de las \xe1reas regadas.")
B.ye=new A.a("{name}: {h} h por evento","{name}: {h} h per event","{name}: {h} h por evento")
B.uG=new A.a("Edi\xe7\xe3o (alias \u23ce)","Editing (alias \u23ce)","Edici\xf3n (alias \u23ce)")
B.ff=new A.a("Remover v\xe9rtice (Ctrl + clique na al\xe7a)","Remove vertex (Ctrl + click on a grip)","Quitar v\xe9rtice (Ctrl + clic en la pinza)")
B.wv=new A.a("Inserir v\xe9rtice (arrastar a al\xe7a do meio do segmento)","Insert vertex (drag the segment midpoint grip)","Insertar v\xe9rtice (arrastrar la pinza del medio del segmento)")
B.qG=new A.a("Toque: pin\xe7a para zoom, dois dedos para mover, um dedo para desenhar","Touch: pinch to zoom, two fingers to pan, one finger to draw","T\xe1ctil: pellizco para zoom, dos dedos para mover, un dedo para dibujar")
B.yx=new A.a("Piv\xf4 central / lateral m\xf3vel","Centre pivot / linear move","Pivote central / lateral de avance")
B.h5=new A.a("Clique o ponto do piv\xf4 (entrada de \xe1gua, sobre a linha principal) e depois o fim da lateral; Esc cancela","Click the pivot point (water inlet, on the mainline) and then the end of the span; Esc cancels","Clic en el punto del pivote (entrada de agua, sobre la l\xednea principal) y luego el fin de la lateral; Esc cancela")
B.jS=new A.a("Alinhar por 2 pontos","Align by 2 points","Alinear por 2 puntos")
B.lV=new A.a("Com a imagem/objetos selecionados: clique o ponto A na origem, onde A deve ficar, o ponto B na origem e onde B deve ficar","With the image/objects selected: click point A on the source, where A must go, point B on the source and where B must go","Con la imagen/objetos seleccionados: clic en el punto A de origen, d\xf3nde debe quedar A, el punto B de origen y d\xf3nde debe quedar B")
B.up=new A.a("Ponto A na imagem/desenho a alinhar","Point A on the image/drawing to align","Punto A en la imagen/dibujo a alinear")
B.iz=new A.a("Onde o ponto A deve ficar (destino)","Where point A must go (target)","D\xf3nde debe quedar el punto A (destino)")
B.xl=new A.a("Ponto B na imagem/desenho a alinhar","Point B on the image/drawing to align","Punto B en la imagen/dibujo a alinear")
B.yy=new A.a("Onde o ponto B deve ficar (define escala e rota\xe7\xe3o)","Where point B must go (sets scale and rotation)","D\xf3nde debe quedar el punto B (define escala y rotaci\xf3n)")
B.hj=new A.a("Manter a escala (s\xf3 mover e girar)","Keep the scale (move and rotate only)","Mantener la escala (solo mover y girar)")
B.mg=new A.a("Alinhado: escala \xd7{s}, rota\xe7\xe3o {r}\xb0","Aligned: scale \xd7{s}, rotation {r}\xb0","Alineado: escala \xd7{s}, rotaci\xf3n {r}\xb0")
B.wD=new A.a("Selecione antes a imagem ou os objetos a alinhar","Select the image or the objects to align first","Seleccione antes la imagen o los objetos a alinear")
B.fQ=new A.a("Caminho do perfil removido do desenho","Profile path removed from the drawing","Camino del perfil quitado del dibujo")
B.c2=new A.a("Eleva\xe7\xe3o","Elevation","Elevaci\xf3n")
B.hp=new A.a("Eleva\xe7\xe3o da curva de n\xedvel","Contour elevation","Elevaci\xf3n de la curva de nivel")
B.hS=new A.a("Eleva\xe7\xe3o da cota","Spot height elevation","Elevaci\xf3n de la cota")
B.c8=new A.a("Intervalo entre curvas (m)","Contour interval (m)","Intervalo entre curvas (m)")
B.vk=new A.a("Pr\xf3xima curva: somar o intervalo","Next contour: add the interval","Pr\xf3xima curva: sumar el intervalo")
B.kU=new A.a("Perguntar a eleva\xe7\xe3o ao terminar cada curva/cota","Ask for the elevation after each contour/spot","Preguntar la elevaci\xf3n al terminar cada curva/cota")
B.n2=new A.a('Uma curva de n\xedvel liga pontos de mesma altitude. Informe a altitude desta curva. Com "somar o intervalo", a pr\xf3xima curva j\xe1 vem com a eleva\xe7\xe3o seguinte.','A contour joins points of the same altitude. Enter the altitude of this line. With "add the interval", the next contour comes with the following elevation.','Una curva de nivel une puntos de la misma altitud. Indique la altitud de esta curva. Con "sumar el intervalo", la pr\xf3xima curva ya viene con la elevaci\xf3n siguiente.')
B.n3=new A.a("Cota de ponto: altitude do terreno neste lugar (po\xe7o, casa de bombas, canto do talh\xe3o).","Spot height: ground altitude at this place (well, pump house, field corner).","Cota de punto: altitud del terreno en este lugar (pozo, casa de bombas, esquina de la parcela).")
B.cj=new A.a("Terreno","Terrain","Terreno")
B.tf=new A.a("Baixar eleva\xe7\xe3o da internet (MDT)\u2026","Download elevation from the internet (DEM)\u2026","Descargar elevaci\xf3n de internet (MDT)\u2026")
B.qz=new A.a("Gerar curvas de n\xedvel do modelo\u2026","Generate contours from the model\u2026","Generar curvas de nivel del modelo\u2026")
B.oN=new A.a("Interpola\xe7\xe3o do terreno","Terrain interpolation","Interpolaci\xf3n del terreno")
B.wf=new A.a("Triangula\xe7\xe3o (TIN / MDT)","Triangulation (TIN / DTM)","Triangulaci\xf3n (TIN / MDT)")
B.xX=new A.a("Inverso da dist\xe2ncia (IDW)","Inverse distance (IDW)","Inverso de la distancia (IDW)")
B.f7=new A.a("Limpar perfil do desenho","Clear profile from the drawing","Limpiar perfil del dibujo")
B.yl=new A.a("Modelo do terreno: {n} pontos, eleva\xe7\xe3o {a} a {b} m","Terrain model: {n} points, elevation {a} to {b} m","Modelo del terreno: {n} puntos, elevaci\xf3n {a} a {b} m")
B.h1=new A.a("Sem dados de eleva\xe7\xe3o","No elevation data","Sin datos de elevaci\xf3n")
B.mp=new A.a("Interpola\xe7\xe3o do terreno (MDT)","Terrain interpolation (DTM)","Interpolaci\xf3n del terreno (MDT)")
B.ow=new A.a("Eleva\xe7\xe3o da internet (MDT online)","Elevation from the internet (online DEM)","Elevaci\xf3n de internet (MDT en l\xednea)")
B.mL=new A.a("Baixa a altitude de uma grade de pontos sobre o projeto a partir de um modelo digital de eleva\xe7\xe3o p\xfablico e cria cotas de ponto. Precisa de georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia). Resolu\xe7\xe3o de 30\u201390 m: bom para o relevo geral, n\xe3o substitui um levantamento.","Downloads the altitude of a grid of points over the project from a public digital elevation model and creates spot heights. Needs a georeference (File \u2192 Georeference). 30\u201390 m resolution: good for the general relief, not a replacement for a survey.","Descarga la altitud de una malla de puntos sobre el proyecto desde un modelo digital de elevaci\xf3n p\xfablico y crea cotas de punto. Necesita georreferencia (Archivo \u2192 Georreferencia). Resoluci\xf3n de 30\u201390 m: buena para el relieve general, no sustituye un levantamiento.")
B.kO=new A.a("Fonte","Source","Fuente")
B.iv=new A.a("Espa\xe7amento da grade (m)","Grid spacing (m)","Espaciado de la malla (m)")
B.fJ=new A.a("\xc1rea {w} \xd7 {h} m \u2192 {n} pontos em {r} requisi\xe7\xf5es","Area {w} \xd7 {h} m \u2192 {n} points in {r} requests","\xc1rea {w} \xd7 {h} m \u2192 {n} puntos en {r} solicitudes")
B.rP=new A.a("Substituir cotas baixadas anteriormente","Replace previously downloaded spot heights","Reemplazar cotas descargadas antes")
B.p1=new A.a("O projeto j\xe1 tem {n} cotas e {m} curvas pr\xf3prias ({a} a {b} m).","The project already has {n} spot heights and {m} contours of its own ({a} to {b} m).","El proyecto ya tiene {n} cotas y {m} curvas propias ({a} a {b} m).")
B.qP=new A.a("Substituir essas cotas e curvas pelo modelo baixado","Replace them with the downloaded model","Reemplazarlas por el modelo descargado")
B.qY=new A.a("Mantidas, elas entram no mesmo modelo que o MDT. Se estiverem noutro datum (ex.: dados de exemplo a 100 m) o terreno fica cheio de picos.","Kept, they join the same model as the DEM. On another datum (e.g. example data at 100 m) the terrain turns into spikes.","Si se mantienen, entran en el mismo modelo que el MDT. En otro datum (p. ej. datos de ejemplo a 100 m) el terreno se llena de picos.")
B.pj=new A.a("Cotas existentes fora do datum do MDT","Existing heights off the DEM datum","Cotas existentes fuera del datum del MDT")
B.hC=new A.a("As cotas e curvas do projeto ({a} a {b} m) n\xe3o batem com o modelo baixado ({c} a {d} m): o terreno ficaria cheio de picos. Remover as cotas e curvas existentes? (Ctrl+Z desfaz.)","The project's own heights and contours ({a} to {b} m) do not match the downloaded model ({c} to {d} m): the terrain would be full of spikes. Remove the existing heights and contours? (Ctrl+Z undoes it.)","Las cotas y curvas del proyecto ({a} a {b} m) no coinciden con el modelo descargado ({c} a {d} m): el terreno quedar\xeda lleno de picos. \xbfQuitar las cotas y curvas existentes? (Ctrl+Z deshace.)")
B.mE=new A.a("Manter","Keep","Mantener")
B.m6=new A.a("Limite do servidor: aguardando {s} s\u2026","Server limit: waiting {s} s\u2026","L\xedmite del servidor: esperando {s} s\u2026")
B.tX=new A.a("Tempo estimado: {t}","Estimated time: {t}","Tiempo estimado: {t}")
B.rY=new A.a("O Open-Meteo aceita cerca de 600 pontos por minuto; para \xe1reas grandes a fonte Terrain Tiles \xe9 muito mais r\xe1pida (poucas requisi\xe7\xf5es, sem limite).","Open-Meteo takes about 600 points per minute; for large areas the Terrain Tiles source is much faster (a few requests, no limit).","Open-Meteo acepta unos 600 puntos por minuto; para \xe1reas grandes la fuente Terrain Tiles es mucho m\xe1s r\xe1pida (pocas solicitudes, sin l\xedmite).")
B.r7=new A.a("Download cancelado","Download cancelled","Descarga cancelada")
B.wc=new A.a("{n} pontos sem dados","{n} points without data","{n} puntos sin datos")
B.mW=new A.a('As cotas v\xe3o para a camada "MDT baixado" (pode ser ocultada em Camadas).','The points go to the "Downloaded DEM" layer (it can be hidden in Layers).','Las cotas van a la capa "MDT descargado" (puede ocultarse en Capas).')
B.o_=new A.a("Usar a \xe1rea vis\xedvel em vez dos limites do projeto","Use the visible area instead of the project extent","Usar el \xe1rea visible en lugar de los l\xedmites del proyecto")
B.j7=new A.a("Baixar","Download","Descargar")
B.qj=new A.a("Baixando {i} de {n}\u2026","Downloading {i} of {n}\u2026","Descargando {i} de {n}\u2026")
B.xK=new A.a("{n} cotas importadas ({s})","{n} spot heights imported ({s})","{n} cotas importadas ({s})")
B.hm=new A.a("Defina antes a georrefer\xeancia do projeto (Arquivo \u2192 Georrefer\xeancia): latitude/longitude de um ponto do desenho.","Set the project georeference first (File \u2192 Georeference): latitude/longitude of a drawing point.","Defina antes la georreferencia del proyecto (Archivo \u2192 Georreferencia): latitud/longitud de un punto del dibujo.")
B.i6=new A.a("Falha ao baixar eleva\xe7\xf5es: {e}","Failed to download elevations: {e}","Error al descargar elevaciones: {e}")
B.it=new A.a("Desenhe algo (ou use a \xe1rea vis\xedvel) para definir a regi\xe3o.","Draw something (or use the visible area) to define the region.","Dibuje algo (o use el \xe1rea visible) para definir la regi\xf3n.")
B.bF=new A.a("Gerar curvas de n\xedvel","Generate contours","Generar curvas de nivel")
B.kd=new A.a("Cria curvas de n\xedvel a partir do modelo digital do terreno (triangula\xe7\xe3o das cotas e curvas existentes). \xdatil depois de importar pontos ou baixar eleva\xe7\xe3o da internet. As curvas geradas s\xe3o s\xf3 desenho: n\xe3o alteram o modelo.","Creates contours from the digital terrain model (triangulation of the existing spot heights and contours). Useful after importing points or downloading elevation. Generated contours are drawing only: they do not change the model.","Crea curvas de nivel a partir del modelo digital del terreno (triangulaci\xf3n de las cotas y curvas existentes). \xdatil despu\xe9s de importar puntos o descargar elevaci\xf3n. Las curvas generadas son solo dibujo: no cambian el modelo.")
B.ym=new A.a("Intervalo (m)","Interval (m)","Intervalo (m)")
B.mH=new A.a("Remover curvas geradas anteriormente","Remove previously generated contours","Quitar curvas generadas antes")
B.nQ=new A.a("{n} curvas entre {a} e {b} m","{n} contours between {a} and {b} m","{n} curvas entre {a} y {b} m")
B.hV=new A.a("{n} curvas de n\xedvel geradas","{n} contours generated","{n} curvas de nivel generadas")
B.l3=new A.a("Gerar","Generate","Generar")
B.pi=new A.a("Terreno","Ground","Terreno")
B.xJ=new A.a("Tubo (com profundidade)","Pipe (with depth)","Tuber\xeda (con profundidad)")
B.vQ=new A.a("Linha piezom\xe9trica (press\xe3o + cota)","Hydraulic grade line (pressure + elevation)","L\xednea piezom\xe9trica (presi\xf3n + cota)")
B.nU=new A.a("Ponto mais baixo","Lowest point","Punto m\xe1s bajo")
B.wN=new A.a("Ponto mais alto","Highest point","Punto m\xe1s alto")
B.vz=new A.a("Como usar: Perfil (PR) \u2192 clique os pontos do caminho \u2192 Enter (ou Concluir). Ou selecione um tubo/lateral. A linha roxa no desenho \xe9 o caminho: Limpar (ou Esc com a ferramenta Perfil) a remove.","How to use: Profile (PR) \u2192 click the path points \u2192 Enter (or Done). Or select a pipe/lateral. The purple line on the drawing is the path: Clear (or Esc with the Profile tool) removes it.","C\xf3mo usar: Perfil (PR) \u2192 clic en los puntos del camino \u2192 Intro (o Terminar). O seleccione una tuber\xeda/lateral. La l\xednea morada en el dibujo es el camino: Limpiar (o Esc con la herramienta Perfil) la quita.")
B.ki=new A.a("Sem dados de eleva\xe7\xe3o: o perfil sai plano. Desenhe curvas de n\xedvel (CT) ou cotas (SP), importe topografia ou baixe eleva\xe7\xe3o da internet (Projeto \u2192 Terreno).","No elevation data: the profile is flat. Draw contours (CT) or spot heights (SP), import a survey or download elevation from the internet (Design \u2192 Terrain).","Sin datos de elevaci\xf3n: el perfil sale plano. Dibuje curvas de nivel (CT) o cotas (SP), importe topograf\xeda o descargue elevaci\xf3n de internet (Dise\xf1o \u2192 Terreno).")
B.rh=new A.a("Esta\xe7\xe3o","Station","Estaci\xf3n")
B.t2=new A.a("Piv\xf4s","Pivots","Pivotes")
B.k6=new A.a("Piv\xf4","Pivot","Pivote")
B.cm=new A.a("Torres","Towers","Torres")
B.xb=new A.a("P dispon\xedvel","P available","P disponible")
B.kg=new A.a("Desn\xedvel","Rise","Desnivel")
B.jV=new A.a("L\xe2mina/ciclo","Depth/cycle","L\xe1mina/ciclo")
B.xt=new A.a("Horas/ciclo","Hours/cycle","Horas/ciclo")
B.mR=new A.a("Taxa aplic. pico","Peak app. rate","Tasa aplic. pico")
B.aG=new A.a("Piv\xf4 central","Centre pivot","Pivote central")
B.oK=new A.a("Lateral m\xf3vel (linear)","Linear move","Lateral de avance (linear)")
B.xd=new A.a("torres","towers","torres")
B.q_=new A.a("Piv\xf4s e laterais m\xf3veis","Pivots and linear moves","Pivotes y laterales de avance")
B.pf=new A.a("Press\xe3o insuficiente na entrada do piv\xf4","Not enough pressure at the pivot inlet","Presi\xf3n insuficiente en la entrada del pivote")
B.nO=new A.a("Taxa de aplica\xe7\xe3o na ponta acima do limite do solo","Application rate at the end above the soil limit","Tasa de aplicaci\xf3n en la punta por encima del l\xedmite del suelo")
B.uW=new A.a("Piv\xf4 sem vaz\xe3o (l\xe2mina ou horas por ciclo zeradas)","Pivot without flow (depth or hours per cycle are zero)","Pivote sin caudal (l\xe1mina u horas por ciclo en cero)")
B.hz=new A.a("Piv\xf4 sem press\xe3o de ponta definida","Pivot without an end pressure","Pivote sin presi\xf3n de punta definida")
B.kZ=new A.a("Tipo de m\xe1quina","Machine type","Tipo de m\xe1quina")
B.jR=new A.a("Comprimento da lateral (m)","Span pipe length (m)","Longitud de la lateral (m)")
B.lp=new A.a("V\xe3o entre torres (m)","Span between towers (m)","Vano entre torres (m)")
B.ky=new A.a("Percurso da lateral m\xf3vel (m)","Linear travel length (m)","Recorrido de la lateral (m)")
B.wg=new A.a("Tubo dos v\xe3os (cat\xe1logo)","Span pipe (catalogue)","Tubo de los vanos (cat\xe1logo)")
B.q1=new A.a("Di\xe2metro interno do tubo (mm)","Pipe inner diameter (mm)","Di\xe1metro interior del tubo (mm)")
B.lI=new A.a("C de Hazen-Williams","Hazen-Williams C","C de Hazen-Williams")
B.yc=new A.a("Altura do tubo (m)","Pipe height (m)","Altura del tubo (m)")
B.iB=new A.a("Press\xe3o na ponta","End pressure","Presi\xf3n en la punta")
B.lE=new A.a("Vaz\xe3o do canh\xe3o final","End gun flow","Caudal del ca\xf1\xf3n final")
B.no=new A.a("Press\xe3o do canh\xe3o final","End gun pressure","Presi\xf3n del ca\xf1\xf3n final")
B.qb=new A.a("Alcance al\xe9m da ponta (m)","Throw beyond the end (m)","Alcance m\xe1s all\xe1 de la punta (m)")
B.o1=new A.a("L\xe2mina bruta por ciclo (mm)","Gross depth per cycle (mm)","L\xe1mina bruta por ciclo (mm)")
B.xq=new A.a("Horas por ciclo (volta/passada)","Hours per cycle (revolution/pass)","Horas por ciclo (vuelta/pasada)")
B.ra=new A.a("Largura molhada na ponta (m)","Wetted width at the end (m)","Ancho mojado en la punta (m)")
B.lT=new A.a("Perdas da m\xe1quina (m)","Machine losses (m)","P\xe9rdidas de la m\xe1quina (m)")
B.jK=new A.a("Taxa m\xe1x. do solo (mm/h; 0 = n\xe3o verificar)","Soil max. rate (mm/h; 0 = no check)","Tasa m\xe1x. del suelo (mm/h; 0 = no verificar)")
B.fR=new A.a("Setor irrigado (\xb0)","Irrigated sector (\xb0)","Sector regado (\xb0)")
B.qN=new A.a("Custo da m\xe1quina","Machine cost","Costo de la m\xe1quina")
B.oM=new A.a("\xc2ngulo de desenho (\xb0)","Drawing angle (\xb0)","\xc1ngulo de dibujo (\xb0)")
B.os=new A.a("Resultado","Result","Resultado")
B.jl=new A.a("Press\xe3o necess\xe1ria na entrada","Required inlet pressure","Presi\xf3n necesaria en la entrada")
B.u3=new A.a("Gerada do modelo (n\xe3o entra no MDT)","Generated from the model (not used by the DTM)","Generada del modelo (no entra al MDT)")
B.io=new A.a("Verifica\xe7\xe3o do projeto (Design Check)","Design check","Verificaci\xf3n del dise\xf1o (Design Check)")
B.fw=new A.a("Varre o desenho procurando erros que impedem ou distorcem o c\xe1lculo hidr\xe1ulico: itens desconectados, tubos que se cruzam sem jun\xe7\xe3o, pontas soltas, zonas sem emissores, duplicados e dados de cat\xe1logo faltando. Clique num item para localiz\xe1-lo.","Sweeps the drawing for errors that stop or distort the hydraulic calculation: disconnected items, pipes crossing without a junction, dead ends, zones without emitters, duplicates and missing catalogue data. Click an item to locate it.","Recorre el dibujo buscando errores que impiden o distorsionan el c\xe1lculo hidr\xe1ulico: elementos desconectados, tuber\xedas que se cruzan sin nudo, extremos sueltos, zonas sin emisores, duplicados y datos de cat\xe1logo faltantes. Haga clic en un \xedtem para ubicarlo.")
B.v3=new A.a("{e} erro(s), {w} aviso(s), {i} nota(s)","{e} error(s), {w} warning(s), {i} note(s)","{e} error(es), {w} aviso(s), {i} nota(s)")
B.qD=new A.a("Nenhum erro encontrado: o projeto est\xe1 pronto para o c\xe1lculo (F5).","No errors found: the design is ready to run (F5).","No se encontraron errores: el dise\xf1o est\xe1 listo para calcular (F5).")
B.um=new A.a("Verificar novamente","Run again","Verificar de nuevo")
B.ko=new A.a("Erro","Error","Error")
B.j_=new A.a("Aviso","Warning","Aviso")
B.n4=new A.a("Nota","Note","Nota")
B.kV=new A.a("Nenhum item hidr\xe1ulico no desenho","No hydraulic items in the drawing","Ning\xfan elemento hidr\xe1ulico en el dibujo")
B.m3=new A.a("Falta a fonte de \xe1gua (WS)","Water supply missing (WS)","Falta la fuente de agua (WS)")
B.o9=new A.a("H\xe1 laterais/emissores mas nenhuma v\xe1lvula de controle (V)","There are laterals/outlets but no control valve (V)","Hay laterales/emisores pero ninguna v\xe1lvula de control (V)")
B.t1=new A.a("Item desconectado da rede","Item not connected to the network","Elemento desconectado de la red")
B.n0=new A.a("Zona sem emissores","Zone without emitters","Zona sin emisores")
B.ts=new A.a("V\xe1lvulas com o mesmo nome de zona","Valves with the same zone name","V\xe1lvulas con el mismo nombre de zona")
B.fX=new A.a("Ponta solta na linha principal (tubo sem sa\xedda)","Dead end on the mainline (pipe with no outlet)","Extremo suelto en la l\xednea principal (tuber\xeda sin salida)")
B.lB=new A.a("Tubo de zona terminando sem lateral","Zone pipe ending without a lateral","Tuber\xeda de zona que termina sin lateral")
B.l1=new A.a("Tubo de comprimento zero","Zero-length pipe","Tuber\xeda de longitud cero")
B.hK=new A.a("Segmento menor que a toler\xe2ncia de conex\xe3o","Segment shorter than the connection tolerance","Segmento menor que la tolerancia de conexi\xf3n")
B.vL=new A.a("Itens duplicados na mesma posi\xe7\xe3o","Duplicated items at the same position","Elementos duplicados en la misma posici\xf3n")
B.ht=new A.a("Tubos se cruzam sem jun\xe7\xe3o (n\xe3o est\xe3o conectados)","Pipes cross without a junction (not connected)","Tuber\xedas se cruzan sin nudo (no est\xe1n conectadas)")
B.nj=new A.a("Modelo do cat\xe1logo n\xe3o encontrado","Catalogue model not found","Modelo del cat\xe1logo no encontrado")
B.yd=new A.a("Fonte com press\xe3o fixa igual a zero","Supply with a fixed pressure of zero","Fuente con presi\xf3n fija igual a cero")
B.rk=new A.a("Piv\xf4 fora da linha principal","Pivot not on the mainline","Pivote fuera de la l\xednea principal")
B.u1=new A.a("Sem dados de eleva\xe7\xe3o: o terreno \xe9 considerado plano","No elevation data: the ground is taken as flat","Sin datos de elevaci\xf3n: el terreno se considera plano")
B.hD=new A.a("Linha principal em anel (rede malhada) \u2014 resolvida pelo solver","Looped mainline (meshed network) \u2014 solved by the solver","L\xednea principal en anillo (red mallada) \u2014 resuelta por el solver")
B.rI=new A.a("\xc1rea sem emissores dentro","Area with no emitters inside","\xc1rea sin emisores dentro")
B.lZ=new A.a("Verifica\xe7\xe3o do projeto\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o\u2026")
B.lw=new A.a("Cat\xe1logos de fabricantes\u2026","Manufacturer catalogues\u2026","Cat\xe1logos de fabricantes\u2026")
B.oe=new A.a("Produtos representativos com dados t\xedpicos de cat\xe1logo (vaz\xe3o, expoente, raio, faixa de press\xe3o). Os pre\xe7os ficam em zero: exporte para Excel, preencha com a tabela local e importe de volta. Confirme sempre na folha de dados do fabricante.","Representative products with typical catalogue data (flow, exponent, radius, pressure range). Prices are left at zero: export to Excel, fill in the local price list and import it back. Always confirm with the manufacturer data sheet.","Productos representativos con datos t\xedpicos de cat\xe1logo (caudal, exponente, radio, rango de presi\xf3n). Los precios quedan en cero: exporte a Excel, complete con la lista local e importe de vuelta. Confirme siempre con la hoja de datos del fabricante.")
B.xz=new A.a("Adicionar","Add","A\xf1adir")
B.vi=new A.a("{n} itens adicionados de {b}","{n} items added from {b}","{n} \xedtems a\xf1adidos de {b}")
B.pZ=new A.a("{n} itens","{n} items","{n} \xedtems")
B.tE=new A.a("Exportar Excel","Export Excel","Exportar Excel")
B.tl=new A.a("Importar (JSON, CSV, Excel)\u2026","Import (JSON, CSV, Excel)\u2026","Importar (JSON, CSV, Excel)\u2026")
B.fu=new A.a("Menu","Menu","Men\xfa")
B.jB=new A.a("Concluir","Done","Terminar")
B.wT=new A.a("Toque para desenhar \xb7 pin\xe7a para zoom \xb7 dois dedos para mover","Tap to draw \xb7 pinch to zoom \xb7 two fingers to pan","Toque para dibujar \xb7 pellizco para zoom \xb7 dos dedos para mover")
B.n_=new A.a("Navegar","Navigate","Navegar")
B.nK=new A.a("Principal","Mainline","Principal")
B.iD=new A.a("{n} selecionado(s)","{n} selected","{n} seleccionado(s)")
B.hq=new A.a("No celular: bot\xf5es Concluir/Cancelar substituem Enter/Esc; menu \u2630 re\xfane os menus","On a phone: Done/Cancel buttons replace Enter/Esc; the \u2630 menu gathers the menus","En el m\xf3vil: los botones Terminar/Cancelar reemplazan Intro/Esc; el men\xfa \u2630 re\xfane los men\xfas")
B.rb=new A.a("Laterais seguem a linha selecionada ({n}): laterais curvas","Laterals follow the selected line ({n}): curved laterals","Laterales siguen la l\xednea seleccionada ({n}): laterales curvas")
B.tD=new A.a("Hist\xf3rico","History","Historial")
B.uU=new A.a("Clique num passo para voltar (ou avan\xe7ar) no tempo; uma nova edi\xe7\xe3o descarta os passos \xe0 frente.","Click a step to go back (or forward) in time; a new edit discards the steps ahead.","Haga clic en un paso para volver (o avanzar) en el tiempo; una nueva edici\xf3n descarta los pasos siguientes.")
B.hd=new A.a("Estado inicial","Initial state","Estado inicial")
B.kW=new A.a("Edi\xe7\xe3o","Edit","Edici\xf3n")
B.wo=new A.a("Adicionar {n}","Add {n}","A\xf1adir {n}")
B.uT=new A.a("Adicionar {n} itens","Add {n} items","A\xf1adir {n} elementos")
B.pu=new A.a("Excluir {n} item(ns)","Delete {n} item(s)","Eliminar {n} elemento(s)")
B.mQ=new A.a("Mover","Move","Mover")
B.kq=new A.a("Espelhar","Mirror","Reflejar")
B.us=new A.a("Transformar {n} item(ns)","Transform {n} item(s)","Transformar {n} elemento(s)")
B.p8=new A.a("Copiar {n} item(ns)","Copy {n} item(s)","Copiar {n} elemento(s)")
B.mG=new A.a("Matriz","Array","Matriz")
B.lA=new A.a("Importar","Import","Importar")
B.iH=new A.a("Projetar (dimensionar)","Design (size pipes)","Dise\xf1ar (dimensionar)")
B.xI=new A.a("Eleva\xe7\xe3o importada","Elevation imported","Elevaci\xf3n importada")
B.ut=new A.a("Remover cotas pr\xf3prias","Remove own heights","Quitar cotas propias")
B.iT=new A.a("Alinhar","Align","Alinear")
B.of=new A.a("Lista de materiais na prancha","Bill of materials on the sheet","Lista de materiales en la l\xe1mina")
B.ov=new A.a("Qtd.","Qty","Cant.")
B.hF=new A.a("\u2026 mais {n} itens (ver relat\xf3rio)","\u2026 {n} more items (see report)","\u2026 {n} \xedtems m\xe1s (ver informe)")
B.oF=new A.a("GeoTIFF de eleva\xe7\xe3o: {n} cotas de {w}\xd7{h} px ({crs})","Elevation GeoTIFF: {n} spot heights from {w}\xd7{h} px ({crs})","GeoTIFF de elevaci\xf3n: {n} cotas de {w}\xd7{h} px ({crs})")
B.v0=new A.a("V\xe3os do piv\xf4","Pivot spans","Vanos del pivote")
B.kC=new A.a("V\xe3o","Span","Vano")
B.i8=new A.a("R inicial","R start","R inicial")
B.y_=new A.a("R final","R end","R final")
B.iX=new A.a("Aspersores","Sprinklers","Aspersores")
B.pS=new A.a("q por aspersor","q per sprinkler","q por aspersor")
B.fp=new A.a("P no v\xe3o","P at span","P en el vano")
B.hu=new A.a("Bocal sugerido","Suggested nozzle","Boquilla sugerida")
B.h8=new A.a("Espa\xe7amento dos aspersores (m)","Sprinkler spacing (m)","Espaciado de los aspersores (m)")
B.rA=new A.a("Aspersor do piv\xf4 (cat\xe1logo)","Pivot sprinkler (catalogue)","Aspersor del pivote (cat\xe1logo)")
B.xN=new A.a("Regulador de press\xe3o (cat\xe1logo)","Pressure regulator (catalogue)","Regulador de presi\xf3n (cat\xe1logo)")
B.hW=new A.a("Custo por torre","Cost per tower","Costo por torre")
B.r4=new A.a("Aspersores do piv\xf4","Pivot sprinklers","Aspersores del pivote")
B.od=new A.a("Canh\xe3o final","End gun","Ca\xf1\xf3n final")
B.l6=new A.a("Suavizar curva (spline pelos pontos)","Smooth contour (spline through the points)","Suavizar curva (spline por los puntos)")
B.li=new A.a("M\xe1x. de pontos","Max. points","M\xe1x. de puntos")
B.mP=new A.a("Motor","Motor","Motor")
B.qC=new A.a("Linha principal em anel: o dimensionamento LP usa caminhos em \xe1rvore (aproxima\xe7\xe3o); a an\xe1lise final confere as press\xf5es","Looped mainline: LP sizing uses tree paths (approximation); the final analysis checks the pressures","L\xednea principal en anillo: el dimensionamiento LP usa caminos en \xe1rbol (aproximaci\xf3n); el an\xe1lisis final verifica las presiones")
B.o8=new A.a("Inclu\xeddos no app","Bundled with the app","Incluidos en la app")
B.j6=new A.a("Carregados agora","Loaded now","Cargados ahora")
B.kv=new A.a("Importar pacote (.oci.cat)\u2026","Import pack (.oci.cat)\u2026","Importar paquete (.oci.cat)\u2026")
B.x2=new A.a("URL de um pacote ou de um \xedndice (index.json)","URL of a pack or of an index (index.json)","URL de un paquete o de un \xedndice (index.json)")
B.la=new A.a("Carregar da URL","Load from URL","Cargar de la URL")
B.w0=new A.a("Carregando\u2026","Loading\u2026","Cargando\u2026")
B.py=new A.a("{n} pacote(s) carregado(s)","{n} pack(s) loaded","{n} paquete(s) cargado(s)")
B.kx=new A.a("N\xe3o foi poss\xedvel carregar: {e}","Could not load: {e}","No se pudo cargar: {e}")
B.tZ=new A.a("Exportar pacote .oci.cat\u2026","Export pack .oci.cat\u2026","Exportar paquete .oci.cat\u2026")
B.wa=new A.a("Exportar cat\xe1logo como pacote","Export catalogue as a pack","Exportar cat\xe1logo como paquete")
B.fI=new A.a("Gera um arquivo .oci.cat com os itens deste cat\xe1logo, para compartilhar ou publicar num reposit\xf3rio da comunidade. O formato (JSON aberto) est\xe1 documentado em catalogs/README.md.","Writes an .oci.cat file with the items of this catalogue, to share or publish in a community repository. The format (open JSON) is documented in catalogs/README.md.","Genera un archivo .oci.cat con los \xedtems de este cat\xe1logo, para compartir o publicar en un repositorio de la comunidad. El formato (JSON abierto) est\xe1 documentado en catalogs/README.md.")
B.kw=new A.a("Fabricante","Manufacturer","Fabricante")
B.je=new A.a("Nome do pacote","Pack name","Nombre del paquete")
B.yB=new A.a("Descri\xe7\xe3o (linhas de produto)","Description (product lines)","Descripci\xf3n (l\xedneas de producto)")
B.p5=new A.a("Fonte (URL da folha de dados)","Source (data sheet URL)","Fuente (URL de la hoja de datos)")
B.pN=new A.a("Pacote {f} exportado ({n} itens)","Pack {f} exported ({n} items)","Paquete {f} exportado ({n} \xedtems)")
B.vS=new A.a("Pacotes s\xe3o arquivos JSON abertos (.oci.cat): fabricantes, revendas e a comunidade podem public\xe1-los num reposit\xf3rio e voc\xea os carrega por arquivo ou URL. Formato em catalogs/README.md.","Packs are open JSON files (.oci.cat): manufacturers, dealers and the community can publish them in a repository and you load them from a file or a URL. Format in catalogs/README.md.","Los paquetes son archivos JSON abiertos (.oci.cat): fabricantes, distribuidores y la comunidad pueden publicarlos en un repositorio y usted los carga desde un archivo o una URL. Formato en catalogs/README.md.")
B.ro=new A.a("de {o}","from {o}","de {o}")
B.rN=new A.a("O JSON n\xe3o \xe9 um cat\xe1logo nem um pacote .oci.cat","The JSON is neither a catalogue nor an .oci.cat pack","El JSON no es un cat\xe1logo ni un paquete .oci.cat")
B.ve=new A.a("Este arquivo \xe9 um \xedndice de pacotes, n\xe3o um pacote (carregue-o pela URL)","This file is a pack index, not a pack (load it by URL)","Este archivo es un \xedndice de paquetes, no un paquete (c\xe1rguelo por URL)")
B.vV=new A.a("O JSON n\xe3o \xe9 um \xedndice de pacotes","The JSON is not a pack index","El JSON no es un \xedndice de paquetes")
B.vN=new A.a("Pacote gravado por uma vers\xe3o mais nova do formato","Pack written by a newer format version","Paquete escrito por una versi\xf3n m\xe1s nueva del formato")
B.wY=new A.a("Coordenada do local (lat, lon)","Site coordinate (lat, lon)","Coordenada del sitio (lat, lon)")
B.my=new A.a("-22.9068, -43.1729 \xb7 link do Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 Google Maps link \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 enlace de Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W")
B.yt=new A.a("Sem desenho ainda? Cole a coordenada do terreno: a origem do projeto vai para l\xe1 e a eleva\xe7\xe3o \xe9 baixada num quadrado ao redor.","No drawing yet? Paste the site coordinate: the project origin goes there and the elevation is downloaded over a square around it.","\xbfSin dibujo todav\xeda? Pegue la coordenada del terreno: el origen del proyecto va all\xed y la elevaci\xf3n se descarga en un cuadrado alrededor.")
B.vu=new A.a("Usar coordenada","Use coordinate","Usar coordenada")
B.pe=new A.a("Lado da \xe1rea (m)","Area side (m)","Lado del \xe1rea (m)")
B.iL=new A.a("Coordenada n\xe3o reconhecida","Coordinate not recognised","Coordenada no reconocida")
B.fk=new A.a("Gerar curvas de n\xedvel ap\xf3s baixar","Generate contours after downloading","Generar curvas de nivel tras descargar")
B.h3=new A.a("Intervalo (m; 0 = autom\xe1tico)","Interval (m; 0 = automatic)","Intervalo (m; 0 = autom\xe1tico)")
B.y6=new A.a("{n} cotas importadas ({s}); {c} curvas de n\xedvel a cada {i} m","{n} spot heights imported ({s}); {c} contours every {i} m","{n} cotas importadas ({s}); {c} curvas de nivel cada {i} m")
B.vE=new A.a("Georrefer\xeancia definida em {lat}, {lon} ({crs})","Georeference set at {lat}, {lon} ({crs})","Georreferencia definida en {lat}, {lon} ({crs})")
B.kt=new A.a("Exemplos","Examples","Ejemplos")
B.jm=new A.a("Boas-vindas e galeria de exemplos\u2026","Welcome and example gallery\u2026","Bienvenida y galer\xeda de ejemplos\u2026")
B.xw=new A.a("Bem-vindo ao OpenCADIrrigation","Welcome to OpenCADIrrigation","Bienvenido a OpenCADIrrigation")
B.ic=new A.a("CAD para projeto de irriga\xe7\xe3o pressurizada, direto no navegador. Comece por um exemplo pronto ou fa\xe7a o tutorial interativo: cerca de 50 passos curtos em que voc\xea mesmo navega, desenha, monta a rede e projeta; cada passo reconhece quando voc\xea o completou e avan\xe7a sozinho. Leva uns 15 minutos e pode ser pulado a qualquer momento (Ajuda \u2192 Tutorial interativo reabre depois).","CAD for pressurised irrigation design, right in the browser. Start from a ready example or take the interactive tutorial: about 50 short steps in which you navigate, draw, build the network and design it yourself; each step recognises when you have completed it and moves on. It takes about 15 minutes and can be skipped at any time (Help \u2192 Interactive tutorial reopens it).","CAD para dise\xf1o de riego presurizado, directamente en el navegador. Empiece por un ejemplo listo o haga el tutorial interactivo: unos 50 pasos cortos en los que usted mismo navega, dibuja, arma la red y dise\xf1a; cada paso reconoce cuando lo complet\xf3 y avanza solo. Tarda unos 15 minutos y puede omitirse en cualquier momento (Ayuda \u2192 Tutorial interactivo lo reabre).")
B.vp=new A.a("Comece por um exemplo","Start from an example","Empiece por un ejemplo")
B.kB=new A.a("Cada projeto abre pronto para calcular: pressione F5 ou \u25b6 e veja zonas, press\xf5es, di\xe2metros e lista de materiais. Arquivo \u2192 Exemplos reabre qualquer um deles.","Each project opens ready to design: press F5 or \u25b6 and see zones, pressures, pipe sizes and the bill of materials. File \u2192 Examples reopens any of them.","Cada proyecto se abre listo para calcular: pulse F5 o \u25b6 y vea zonas, presiones, di\xe1metros y lista de materiales. Archivo \u2192 Ejemplos reabre cualquiera de ellos.")
B.oa=new A.a("Iniciar tutorial","Start tutorial","Iniciar tutorial")
B.xg=new A.a("Come\xe7ar do zero","Start from scratch","Empezar de cero")
B.nJ=new A.a("Pomar","Orchard","Huerto")
B.jj=new A.a("Microaspers\xe3o em citros e gotejamento em uva, po\xe7o com bomba e filtro, terreno em declive.","Micro-sprinklers on citrus and drip on grapes, well with pump and filter, sloping ground.","Microaspersi\xf3n en c\xedtricos y goteo en uva, pozo con bomba y filtro, terreno en pendiente.")
B.kT=new A.a("2 zonas \xb7 1,1 ha \xb7 po\xe7o + bomba","2 zones \xb7 1.1 ha \xb7 well + pump","2 zonas \xb7 1,1 ha \xb7 pozo + bomba")
B.bH=new A.a("Jardim residencial","Residential garden","Jard\xedn residencial")
B.kA=new A.a("Sprays pop-up no gramado da frente, rotores nos fundos e gotejamento nos canteiros, ligados \xe0 rede p\xfablica com hidr\xf4metro e anti-refluxo.","Pop-up sprays on the front lawn, rotors at the back and drip in the beds, fed by the mains with a meter and a backflow preventer.","Difusores emergentes en el c\xe9sped frontal, rotores atr\xe1s y goteo en los canteros, conectados a la red p\xfablica con contador y antirretorno.")
B.qQ=new A.a("3 zonas \xb7 640 m\xb2 \xb7 rede p\xfablica","3 zones \xb7 640 m\xb2 \xb7 mains supply","3 zonas \xb7 640 m\xb2 \xb7 red p\xfablica")
B.cx=new A.a("Campo de futebol","Football pitch","Campo de f\xfatbol")
B.iM=new A.a("Campo oficial 105 \xd7 68 m com aspersores de impacto em cinco linhas, reservat\xf3rio, bomba e turnos noturnos.","Full-size 105 \xd7 68 m pitch with impact sprinklers in five rows, reservoir, pump and night-time shifts.","Campo oficial de 105 \xd7 68 m con aspersores de impacto en cinco filas, dep\xf3sito, bomba y turnos nocturnos.")
B.xE=new A.a("5 zonas \xb7 40 aspersores \xb7 bomba","5 zones \xb7 40 sprinklers \xb7 pump","5 zonas \xb7 40 aspersores \xb7 bomba")
B.fx=new A.a("Lavoura gotejada","Drip row crop","Cultivo en hileras con goteo")
B.oz=new A.a("Quatro talh\xf5es de tomate com fita gotejadora, submains com v\xe1lvulas, filtro de tela, bomba e terreno em declive.","Four tomato blocks on drip tape, submains with valves, screen filter, pump and sloping ground.","Cuatro parcelas de tomate con cinta de goteo, submains con v\xe1lvulas, filtro de malla, bomba y terreno en pendiente.")
B.yu=new A.a("4 zonas \xb7 2,9 ha \xb7 filtro + bomba","4 zones \xb7 2.9 ha \xb7 filter + pump","4 zonas \xb7 2,9 ha \xb7 filtro + bomba")
B.uC=new A.a("Piv\xf4 de 300 m em milho alimentado por adutora, po\xe7o e bomba; relat\xf3rio de torres, v\xe3os e bocais.","A 300 m pivot on maize fed by a mainline, well and pump; tower, span and sprinkler report.","Pivote de 300 m en ma\xedz alimentado por conducci\xf3n, pozo y bomba; informe de torres, tramos y boquillas.")
B.iP=new A.a("1 piv\xf4 \xb7 28 ha \xb7 po\xe7o + bomba","1 pivot \xb7 28 ha \xb7 well + pump","1 pivote \xb7 28 ha \xb7 pozo + bomba")
B.i7=new A.a("Turno {n} \u2014 {z}","Shift {n} \u2014 {z}","Turno {n} \u2014 {z}")
B.il=new A.a("Resid\xeancia Exemplo","Example Residence","Residencia Ejemplo")
B.i0=new A.a("Lote 16 \xd7 40 m","Lot 16 \xd7 40 m","Lote 16 \xd7 40 m")
B.rM=new A.a("Jardim residencial \u2014 exemplo OpenCADIrrigation","Residential garden \u2014 OpenCADIrrigation example","Jard\xedn residencial \u2014 ejemplo OpenCADIrrigation")
B.ms=new A.a("Lote","Lot","Lote")
B.jt=new A.a("Casa","House","Casa")
B.k9=new A.a("Gramado da frente","Front lawn","C\xe9sped frontal")
B.uw=new A.a("Gramado dos fundos","Back lawn","C\xe9sped trasero")
B.js=new A.a("Canteiro","Bed","Cantero")
B.fb=new A.a("Zona 1 \u2014 sprays","Zone 1 \u2014 sprays","Zona 1 \u2014 difusores")
B.mm=new A.a("Zona 2 \u2014 rotores","Zone 2 \u2014 rotors","Zona 2 \u2014 rotores")
B.lY=new A.a("Zona 3 \u2014 gotejamento","Zone 3 \u2014 drip","Zona 3 \u2014 goteo")
B.pJ=new A.a("Rede p\xfablica","Mains supply","Red p\xfablica")
B.iW=new A.a("Arbustos","Shrubs","Arbustos")
B.oA=new A.a("Rua","Street","Calle")
B.cJ=new A.a("Clube Exemplo","Example Club","Club Ejemplo")
B.hE=new A.a("Campo oficial 105 \xd7 68 m","Full-size pitch 105 \xd7 68 m","Campo oficial 105 \xd7 68 m")
B.i4=new A.a("Campo de futebol \u2014 exemplo OpenCADIrrigation","Football pitch \u2014 OpenCADIrrigation example","Campo de f\xfatbol \u2014 ejemplo OpenCADIrrigation")
B.jq=new A.a("Campo","Pitch","Campo")
B.qE=new A.a("Linha {n}","Row {n}","Fila {n}")
B.a5=new A.a("Reservat\xf3rio","Reservoir","Dep\xf3sito")
B.cc=new A.a("Casa de bombas","Pump house","Casa de bombas")
B.bY=new A.a("Grama esportiva","Sports turf","C\xe9sped deportivo")
B.rU=new A.a("Lavoura gotejada","Drip row crop","Cultivo con goteo")
B.tV=new A.a("S\xedtio Exemplo","Example Farm","Finca Ejemplo")
B.wX=new A.a("Talh\xf5es 1 a 4","Blocks 1 to 4","Parcelas 1 a 4")
B.vg=new A.a("Lavoura de tomate gotejada \u2014 exemplo OpenCADIrrigation","Drip-irrigated tomato field \u2014 OpenCADIrrigation example","Cultivo de tomate con goteo \u2014 ejemplo OpenCADIrrigation")
B.Q=new A.a("Talh\xe3o {n}","Block {n}","Parcela {n}")
B.cn=new A.a("Tronco","Trunk","Tronco")
B.aJ=new A.a("Ramal oeste","West branch","Ramal oeste")
B.av=new A.a("Ramal leste","East branch","Ramal este")
B.O=new A.a("Estrada","Road","Camino")
B.r=new A.a("Gleba","Field","Campo")
B.pz=new A.a("Piv\xf4 1 \u2014 raio 300 m","Pivot 1 \u2014 300 m radius","Pivote 1 \u2014 radio 300 m")
B.hM=new A.a("Piv\xf4 central \u2014 exemplo OpenCADIrrigation","Centre pivot \u2014 OpenCADIrrigation example","Pivote central \u2014 ejemplo OpenCADIrrigation")
B.ug=new A.a("Piv\xf4 1","Pivot 1","Pivote 1")
B.G=new A.a("Adutora","Mainline","Conducci\xf3n")
B.cr=new A.a("\xc1rea do piv\xf4","Pivot area","\xc1rea del pivote")
B.cC=new A.a("Estufa de hortali\xe7as","Vegetable greenhouse","Invernadero de hortalizas")
B.ql=new A.a("Quatro t\xfaneis de piment\xe3o com tubo gotejador autocompensante, uma zona por t\xfanel, reservat\xf3rio, bomba pequena e filtro de discos.","Four pepper tunnels on pressure-compensating dripline, one zone per tunnel, tank, small pump and disc filter.","Cuatro t\xfaneles de pimiento con tuber\xeda de goteo autocompensante, una zona por t\xfanel, dep\xf3sito, bomba peque\xf1a y filtro de discos.")
B.hR=new A.a("4 zonas \xb7 1.800 m\xb2 \xb7 reservat\xf3rio + bomba","4 zones \xb7 1,800 m\xb2 \xb7 tank + pump","4 zonas \xb7 1.800 m\xb2 \xb7 dep\xf3sito + bomba")
B.bE=new A.a("Viveiro de mudas","Plant nursery","Vivero de plantas")
B.tL=new A.a("Tr\xeas canteiros de 12 \xd7 48 m com microaspersores suspensos em malha 4 \xd7 4 m, uma zona por canteiro, caixa d\u2019\xe1gua elevada, bomba pequena e filtro de discos.","Three 12 \xd7 48 m beds under overhead micro-sprinklers on a 4 \xd7 4 m grid, one zone per bed, elevated tank, small pump and disc filter.","Tres canteros de 12 \xd7 48 m con microaspersores suspendidos en malla de 4 \xd7 4 m, una zona por cantero, tanque elevado, bomba peque\xf1a y filtro de discos.")
B.i5=new A.a("3 zonas \xb7 108 microaspersores \xb7 bomba","3 zones \xb7 108 micro-sprinklers \xb7 pump","3 zonas \xb7 108 microaspersores \xb7 bomba")
B.bZ=new A.a("Cafezal em curvas de n\xedvel","Coffee on contour lines","Cafetal en curvas de nivel")
B.qx=new A.a("Tr\xeas talh\xf5es de caf\xe9 em encosta com laterais curvas que seguem as curvas de n\xedvel (bloco guiado), tubo gotejador PC, po\xe7o e bomba no p\xe9 do morro.","Three coffee blocks on a hillside with curved laterals following the contours (guided block), PC dripline, well and pump at the foot of the slope.","Tres parcelas de caf\xe9 en ladera con laterales curvos que siguen las curvas de nivel (bloque guiado), tuber\xeda de goteo PC, pozo y bomba al pie de la pendiente.")
B.uR=new A.a("3 zonas \xb7 2,7 ha \xb7 po\xe7o + bomba","3 zones \xb7 2.7 ha \xb7 well + pump","3 zonas \xb7 2,7 ha \xb7 pozo + bomba")
B.cH=new A.a("Bananal","Banana plantation","Platanal")
B.rr=new A.a("Dois talh\xf5es de banana com microaspersores autocompensantes em 5 \xd7 5 m, po\xe7o com bomba submersa, filtro de discos e terreno em declive.","Two banana blocks under pressure-compensating micro-sprinklers at 5 \xd7 5 m, well with submersible pump, disc filter and sloping ground.","Dos parcelas de banano con microaspersores autocompensantes a 5 \xd7 5 m, pozo con bomba sumergible, filtro de discos y terreno en pendiente.")
B.tt=new A.a("2 zonas \xb7 1,2 ha \xb7 bomba submersa","2 zones \xb7 1.2 ha \xb7 submersible pump","2 zonas \xb7 1,2 ha \xb7 bomba sumergible")
B.cd=new A.a("Cana-de-a\xe7\xfacar subsuperficial","Subsurface drip sugarcane","Ca\xf1a de az\xfacar con goteo subterr\xe1neo")
B.mc=new A.a("Dois talh\xf5es de cana com tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, submains enterrados, reservat\xf3rio, bomba, filtro de tela e ventosa.","Two sugarcane blocks on 20 mm PC dripline buried 0.3 m deep, 180 m laterals, buried submains, reservoir, pump, screen filter and air valve.","Dos parcelas de ca\xf1a con tuber\xeda de goteo PC de 20 mm enterrada a 0,3 m, laterales de 180 m, submains enterrados, dep\xf3sito, bomba, filtro de malla y ventosa.")
B.jx=new A.a("2 zonas \xb7 3,2 ha \xb7 filtro + bomba","2 zones \xb7 3.2 ha \xb7 filter + pump","2 zonas \xb7 3,2 ha \xb7 filtro + bomba")
B.by=new A.a("Gotejamento por gravidade","Gravity-fed drip","Goteo por gravedad")
B.h7=new A.a("Reservat\xf3rio 40 m acima de dois talh\xf5es de hortali\xe7as gotejados, sem bomba: registro, v\xe1lvula reguladora de press\xe3o e filtro de discos na adutora; curvas de n\xedvel da encosta.","A reservoir 40 m above two drip-irrigated vegetable blocks, no pump: gate valve, pressure reducing valve and disc filter on the mainline; hillside contours.","Dep\xf3sito 40 m por encima de dos parcelas de hortalizas con goteo, sin bomba: v\xe1lvula de compuerta, reguladora de presi\xf3n y filtro de discos en la conducci\xf3n; curvas de nivel de la ladera.")
B.fF=new A.a("2 zonas \xb7 1,2 ha \xb7 sem bomba","2 zones \xb7 1.2 ha \xb7 no pump","2 zonas \xb7 1,2 ha \xb7 sin bomba")
B.cD=new A.a("Pastagem em aspers\xe3o","Sprinkler-irrigated pasture","Pastura con aspersi\xf3n")
B.fn=new A.a("Tr\xeas piquetes de 72 \xd7 72 m com linhas de aspersores de impacto em 12 \xd7 18 m, submains com v\xe1lvulas, reservat\xf3rio, bomba e v\xe1lvula de reten\xe7\xe3o.","Three 72 \xd7 72 m paddocks with impact-sprinkler spray lines at 12 \xd7 18 m, submains with valves, reservoir, pump and check valve.","Tres potreros de 72 \xd7 72 m con l\xedneas de aspersores de impacto a 12 \xd7 18 m, submains con v\xe1lvulas, dep\xf3sito, bomba y v\xe1lvula de retenci\xf3n.")
B.h2=new A.a("3 zonas \xb7 1,6 ha \xb7 72 aspersores","3 zones \xb7 1.6 ha \xb7 72 sprinklers","3 zonas \xb7 1,6 ha \xb7 72 aspersores")
B.bP=new A.a("Buraco de golfe","Golf hole","Hoyo de golf")
B.wl=new A.a("Tee com sprays, fairway com rotores em malha triangular (duas zonas) e green com rotores no per\xedmetro, lago com bomba e turnos noturnos.","Tee with sprays, fairway with rotors on a triangular grid (two zones) and green with rotors around the edge, pond with pump and night-time shifts.","Tee con difusores, fairway con rotores en malla triangular (dos zonas) y green con rotores en el per\xedmetro, laguna con bomba y turnos nocturnos.")
B.h4=new A.a("4 zonas \xb7 64 emissores \xb7 lago + bomba","4 zones \xb7 64 heads \xb7 pond + pump","4 zonas \xb7 64 emisores \xb7 laguna + bomba")
B.oX=new A.a("Piv\xf4 setorial com canh\xe3o","Sector pivot with end gun","Pivote sectorial con ca\xf1\xf3n")
B.yk=new A.a("Piv\xf4 de 250 m em soja que gira 270\xb0, deixando livre o quadrante da sede, com canh\xe3o final de 12 m\xb3/h; lago, bomba de 30 cv e registro.","A 250 m pivot on soybean sweeping 270\xb0, leaving the farmstead quadrant free, with a 12 m\xb3/h end gun; pond, 30 hp pump and gate valve.","Pivote de 250 m en soja que gira 270\xb0, dejando libre el cuadrante del casco, con ca\xf1\xf3n final de 12 m\xb3/h; laguna, bomba de 30 CV y v\xe1lvula de compuerta.")
B.qV=new A.a("1 piv\xf4 \xb7 15,7 ha \xb7 lago + bomba","1 pivot \xb7 15.7 ha \xb7 pond + pump","1 pivote \xb7 15,7 ha \xb7 laguna + bomba")
B.ct=new A.a("Piv\xf4 linear","Linear move","Pivote lineal")
B.r3=new A.a("Lateral m\xf3vel de 392 m em trigo percorrendo 800 m ao longo de um canal, capta\xe7\xe3o com bomba de 30 cv e v\xe1lvula de reten\xe7\xe3o; relat\xf3rio de torres e bocais.","A 392 m lateral-move machine on wheat travelling 800 m along a canal, intake with a 30 hp pump and check valve; tower and sprinkler report.","Lateral de avance frontal de 392 m en trigo que recorre 800 m a lo largo de un canal, toma con bomba de 30 CV y v\xe1lvula de retenci\xf3n; informe de torres y boquillas.")
B.oh=new A.a("1 linear \xb7 32 ha \xb7 canal + bomba","1 linear \xb7 32 ha \xb7 canal + pump","1 lineal \xb7 32 ha \xb7 canal + bomba")
B.xe=new A.a("Hortifruti Exemplo","Example Growers","Hortalizas Ejemplo")
B.xm=new A.a("T\xfaneis 1 a 4","Tunnels 1 to 4","T\xfaneles 1 a 4")
B.q4=new A.a("Estufa de hortali\xe7as \u2014 exemplo OpenCADIrrigation","Vegetable greenhouse \u2014 OpenCADIrrigation example","Invernadero de hortalizas \u2014 ejemplo OpenCADIrrigation")
B.ci=new A.a("Terreno","Site","Terreno")
B.oE=new A.a("T\xfanel {n}","Tunnel {n}","T\xfanel {n}")
B.xn=new A.a("Piment\xe3o","Bell pepper","Pimiento")
B.qF=new A.a("Viveiro Exemplo","Example Nursery","Vivero Ejemplo")
B.uA=new A.a("Canteiros 1 a 3","Beds 1 to 3","Canteros 1 a 3")
B.ip=new A.a("Viveiro de mudas \u2014 exemplo OpenCADIrrigation","Plant nursery \u2014 OpenCADIrrigation example","Vivero de plantas \u2014 ejemplo OpenCADIrrigation")
B.pX=new A.a("Canteiro {n}","Bed {n}","Cantero {n}")
B.mT=new A.a("Mudas","Seedlings","Plantines")
B.ol=new A.a("Caixa d\u2019\xe1gua","Tank","Tanque")
B.kS=new A.a("Encosta norte \u2014 talh\xf5es 1 a 3","North slope \u2014 blocks 1 to 3","Ladera norte \u2014 parcelas 1 a 3")
B.ob=new A.a("Cafezal em curvas de n\xedvel \u2014 exemplo OpenCADIrrigation","Coffee on contour lines \u2014 OpenCADIrrigation example","Cafetal en curvas de nivel \u2014 ejemplo OpenCADIrrigation")
B.aI=new A.a("Talh\xf5es 1 e 2","Blocks 1 and 2","Parcelas 1 y 2")
B.v5=new A.a("Bananal \u2014 exemplo OpenCADIrrigation","Banana plantation \u2014 OpenCADIrrigation example","Platanal \u2014 ejemplo OpenCADIrrigation")
B.mS=new A.a("Usina Exemplo","Example Mill","Ingenio Ejemplo")
B.pI=new A.a("Cana-de-a\xe7\xfacar em gotejamento subsuperficial \u2014 exemplo OpenCADIrrigation","Subsurface drip sugarcane \u2014 OpenCADIrrigation example","Ca\xf1a de az\xfacar con goteo subterr\xe1neo \u2014 ejemplo OpenCADIrrigation")
B.yg=new A.a("S\xedtio Exemplo","Example Smallholding","Finca Ejemplo")
B.xr=new A.a("Gotejamento por gravidade \u2014 exemplo OpenCADIrrigation","Gravity-fed drip \u2014 OpenCADIrrigation example","Goteo por gravedad \u2014 ejemplo OpenCADIrrigation")
B.vo=new A.a("Reservat\xf3rio no alto","Hilltop reservoir","Dep\xf3sito en lo alto")
B.vX=new A.a("V\xe1lvula reguladora de press\xe3o","Pressure reducing valve","V\xe1lvula reguladora de presi\xf3n")
B.fE=new A.a("Piquetes 1 a 3","Paddocks 1 to 3","Potreros 1 a 3")
B.nm=new A.a("Pastagem em aspers\xe3o \u2014 exemplo OpenCADIrrigation","Sprinkler-irrigated pasture \u2014 OpenCADIrrigation example","Pastura con aspersi\xf3n \u2014 ejemplo OpenCADIrrigation")
B.pG=new A.a("Piquete {n}","Paddock {n}","Potrero {n}")
B.nF=new A.a("Pastagem","Pasture","Pastura")
B.jw=new A.a("Cerca","Fence","Cerco")
B.uo=new A.a("Buraco 1 \u2014 par 4","Hole 1 \u2014 par 4","Hoyo 1 \u2014 par 4")
B.uE=new A.a("Buraco de golfe \u2014 exemplo OpenCADIrrigation","Golf hole \u2014 OpenCADIrrigation example","Hoyo de golf \u2014 ejemplo OpenCADIrrigation")
B.ph=new A.a("Tee","Tee","Tee")
B.kF=new A.a("Fairway","Fairway","Fairway")
B.lW=new A.a("Fairway {n}","Fairway {n}","Fairway {n}")
B.l7=new A.a("Green","Green","Green")
B.vw=new A.a("Bunker","Bunker","B\xfanker")
B.c5=new A.a("Lago","Pond","Laguna")
B.mh=new A.a("Piv\xf4 setorial","Sector pivot","Pivote sectorial")
B.qM=new A.a("Piv\xf4 2 \u2014 raio 250 m, setor de 270\xb0","Pivot 2 \u2014 250 m radius, 270\xb0 sector","Pivote 2 \u2014 radio 250 m, sector de 270\xb0")
B.l9=new A.a("Piv\xf4 setorial com canh\xe3o final \u2014 exemplo OpenCADIrrigation","Sector pivot with end gun \u2014 OpenCADIrrigation example","Pivote sectorial con ca\xf1\xf3n final \u2014 ejemplo OpenCADIrrigation")
B.o0=new A.a("Piv\xf4 2","Pivot 2","Pivote 2")
B.oW=new A.a("Soja","Soybean","Soja")
B.oT=new A.a("Sede","Farmstead","Casco")
B.ld=new A.a("Linear 1 \u2014 392 \xd7 800 m","Linear 1 \u2014 392 \xd7 800 m","Lineal 1 \u2014 392 \xd7 800 m")
B.uI=new A.a("Piv\xf4 linear \u2014 exemplo OpenCADIrrigation","Linear move \u2014 OpenCADIrrigation example","Pivote lineal \u2014 ejemplo OpenCADIrrigation")
B.wV=new A.a("Linear 1","Linear 1","Lineal 1")
B.pp=new A.a("Trigo","Wheat","Trigo")
B.jr=new A.a("Canal","Canal","Canal")
B.un=new A.a("Capta\xe7\xe3o","Intake","Toma")
B.dL=new A.b8(B.dO,[B.kX,B.ne,B.bM,B.iV,B.kH,B.xM,B.c6,B.aw,B.bT,B.cq,B.bR,B.F,B.t,B.cw,B.lc,B.bW,B.bG,B.bB,B.fC,B.n7,B.hk,B.hN,B.hy,B.rc,B.hw,B.fq,B.wx,B.rE,B.jD,B.om,B.bN,B.wL,B.xv,B.r6,B.nH,B.bS,B.hQ,B.v7,B.jA,B.hi,B.fU,B.lS,B.nf,B.jO,B.rC,B.hJ,B.iQ,B.t8,B.mB,B.kz,B.qf,B.qc,B.iF,B.pW,B.m9,B.tT,B.q3,B.pH,B.iu,B.tc,B.k4,B.h0,B.jY,B.pc,B.oC,B.oL,B.nS,B.ta,B.o5,B.fM,B.wH,B.qa,B.uy,B.lr,B.ng,B.ns,B.ty,B.pC,B.qX,B.v1,B.mz,B.u2,B.ux,B.kD,B.pM,B.kf,B.iS,B.iy,B.aF,B.ou,B.kL,B.oH,B.tr,B.nD,B.ot,B.ri,B.fK,B.aN,B.vf,B.tP,B.nG,B.ku,B.yA,B.bQ,B.kp,B.kN,B.nk,B.nt,B.pE,B.x8,B.mo,B.tU,B.pt,B.rK,B.yj,B.p3,B.f9,B.tQ,B.k2,B.a3,B.jG,B.t9,B.q6,B.vA,B.ka,B.jf,B.km,B.wW,B.A,B.aN,B.wb,B.tY,B.ay,B.cp,B.hn,B.iG,B.cI,B.td,B.k3,B.oo,B.lf,B.ww,B.kb,B.jh,B.vx,B.n9,B.c1,B.cI,B.aN,B.ox,B.qo,B.yz,B.hh,B.bL,B.lx,B.qt,B.mZ,B.xS,B.yn,B.vd,B.rv,B.qh,B.qA,B.pQ,B.ib,B.nc,B.iE,B.kY,B.ln,B.mt,B.le,B.qZ,B.hs,B.a4,B.wS,B.wC,B.xH,B.r8,B.oQ,B.fG,B.aA,B.A,B.uD,B.m7,B.a4,B.fm,B.xU,B.mJ,B.ma,B.uL,B.wd,B.fZ,B.ny,B.ul,B.oU,B.re,B.uq,B.h_,B.qm,B.kc,B.a3,B.jF,B.p7,B.qy,B.aK,B.ji,B.wy,B.hB,B.c3,B.a2,B.jX,B.lR,B.ax,B.uZ,B.nr,B.cu,B.bA,B.mI,B.fs,B.tu,B.ue,B.me,B.vF,B.fW,B.uz,B.ui,B.qi,B.mf,B.x9,B.mx,B.w2,B.fH,B.mA,B.nN,B.oV,B.c1,B.nl,B.u9,B.fT,B.ps,B.aL,B.bS,B.rJ,B.jp,B.aD,B.cy,B.uB,B.lD,B.a2,B.bK,B.wO,B.v6,B.x6,B.uK,B.t_,B.t4,B.rQ,B.op,B.ru,B.bC,B.F,B.kR,B.vO,B.yw,B.yC,B.qO,B.kM,B.xQ,B.ax,B.ca,B.cG,B.nT,B.aM,B.r1,B.a3,B.fS,B.hl,B.kG,B.ha,B.i9,B.jI,B.bO,B.aH,B.A,B.lN,B.ce,B.wZ,B.m8,B.nR,B.yq,B.xi,B.fo,B.cB,B.yo,B.r0,B.yv,B.xO,B.tA,B.F,B.t,B.aB,B.pP,B.vP,B.aC,B.j9,B.y5,B.rF,B.lh,B.iK,B.pO,B.iZ,B.u7,B.j2,B.md,B.tK,B.uP,B.u8,B.lz,B.nn,B.ws,B.lo,B.q8,B.v4,B.r9,B.tG,B.qL,B.xu,B.we,B.rp,B.y8,B.rd,B.kK,B.F,B.bC,B.A,B.aB,B.hI,B.pD,B.cB,B.cF,B.ch,B.xT,B.uc,B.uQ,B.yb,B.vs,B.j0,B.jC,B.kn,B.ly,B.cy,B.jU,B.c4,B.nX,B.mj,B.u4,B.fN,B.fh,B.qR,B.l5,B.nx,B.a2,B.mY,B.x_,B.yi,B.aE,B.lC,B.id,B.q7,B.cs,B.az,B.ax,B.cG,B.rq,B.x0,B.tn,B.xy,B.vU,B.hZ,B.uH,B.ir,B.qq,B.oj,B.w4,B.qW,B.tk,B.wE,B.jP,B.x1,B.nd,B.nw,B.vW,B.uv,B.o7,B.t5,B.pm,B.pa,B.wG,B.tz,B.xY,B.aH,B.rz,B.fi,B.fz,B.l0,B.mX,B.qB,B.wU,B.xC,B.aA,B.ls,B.A,B.cv,B.cp,B.ay,B.F,B.az,B.rx,B.p_,B.pn,B.c4,B.aH,B.bB,B.a3,B.aE,B.wF,B.pU,B.z,B.hY,B.k5,B.tN,B.mv,B.mw,B.uJ,B.tq,B.cf,B.co,B.kQ,B.uY,B.xF,B.P,B.y1,B.p6,B.nM,B.jy,B.mr,B.nL,B.n5,B.qp,B.lv,B.fl,B.to,B.f6,B.f5,B.uF,B.j3,B.l2,B.wM,B.lX,B.uh,B.mn,B.pv,B.nu,B.m2,B.ho,B.iR,B.xA,B.wP,B.qe,B.kk,B.xa,B.jZ,B.mO,B.mC,B.nA,B.bO,B.aB,B.aC,B.rT,B.h6,B.qu,B.tW,B.aD,B.t3,B.cA,B.w7,B.wm,B.y3,B.ml,B.jL,B.uM,B.jJ,B.lu,B.pb,B.jd,B.rf,B.ti,B.th,B.fd,B.rH,B.bV,B.jv,B.kJ,B.j4,B.wu,B.nB,B.o6,B.po,B.rB,B.c3,B.nP,B.lk,B.ia,B.pA,B.ce,B.A,B.jN,B.k7,B.qr,B.kj,B.ua,B.u0,B.nz,B.wt,B.ii,B.uk,B.ca,B.l8,B.ig,B.c9,B.ja,B.tH,B.lK,B.wp,B.u5,B.hG,B.vy,B.o2,B.vc,B.xj,B.pw,B.rj,B.qg,B.mi,B.f8,B.qn,B.kh,B.aA,B.A,B.bX,B.cv,B.ay,B.pB,B.aD,B.jW,B.q0,B.jo,B.y4,B.fy,B.a2,B.bK,B.fr,B.y0,B.cF,B.ch,B.wj,B.jn,B.tM,B.qT,B.wn,B.xZ,B.m5,B.ck,B.jM,B.vB,B.hL,B.p2,B.np,B.p0,B.oY,B.nC,B.nV,B.nv,B.t7,B.fe,B.iC,B.vl,B.wh,B.yh,B.nq,B.i2,B.qU,B.xW,B.rG,B.wk,B.oG,B.uX,B.i3,B.kl,B.mK,B.vq,B.oZ,B.rn,B.u6,B.tB,B.hO,B.vG,B.lJ,B.v8,B.nY,B.tF,B.fO,B.qd,B.pR,B.wJ,B.wB,B.rw,B.lg,B.c7,B.lj,B.y2,B.fD,B.cg,B.rL,B.bU,B.q2,B.iU,B.kr,B.y7,B.x3,B.tb,B.lU,B.he,B.p4,B.fc,B.lt,B.fv,B.xG,B.m0,B.xR,B.xc,B.uS,B.pT,B.mk,B.pd,B.mN,B.wz,B.yf,B.j1,B.p9,B.nI,B.mq,B.jz,B.iw,B.xs,B.rD,B.is,B.tI,B.fP,B.r2,B.w5,B.rg,B.fg,B.xP,B.xp,B.tg,B.og,B.fV,B.n1,B.hH,B.rV,B.m_,B.va,B.vI,B.fB,B.mU,B.ix,B.fL,B.ie,B.l_,B.xx,B.yp,B.pk,B.fY,B.yr,B.r5,B.pL,B.na,B.jb,B.qs,B.oI,B.vM,B.tC,B.w9,B.wQ,B.lP,B.iN,B.lq,B.oB,B.rR,B.ks,B.jc,B.vt,B.oq,B.hc,B.jE,B.ik,B.w6,B.lO,B.jT,B.rX,B.c7,B.q5,B.iY,B.im,B.ll,B.ni,B.lM,B.kE,B.aw,B.ij,B.lH,B.k_,B.m4,B.qK,B.ok,B.tR,B.oR,B.pK,B.nh,B.k0,B.wR,B.fa,B.ub,B.vH,B.wK,B.wq,B.uV,B.pF,B.rl,B.hP,B.hf,B.qv,B.xD,B.rm,B.ke,B.ur,B.o3,B.hT,B.pr,B.c_,B.P,B.uN,B.wr,B.rW,B.xh,B.cf,B.co,B.cE,B.bJ,B.mD,B.u_,B.cl,B.bx,B.bI,B.c0,B.bD,B.nE,B.jg,B.vv,B.qw,B.w1,B.ys,B.cb,B.cz,B.bX,B.uf,B.ju,B.xk,B.m1,B.nb,B.vD,B.iI,B.xo,B.vb,B.rS,B.mV,B.q9,B.bQ,B.aE,B.qH,B.bV,B.kI,B.cA,B.vm,B.aM,B.ft,B.tv,B.mu,B.vY,B.qJ,B.oP,B.jH,B.lb,B.w8,B.iO,B.wA,B.hv,B.i_,B.bz,B.jQ,B.lQ,B.bz,B.pl,B.vC,B.kP,B.cz,B.tS,B.k8,B.aF,B.xV,B.x5,B.j5,B.fA,B.rZ,B.vh,B.y9,B.qI,B.ih,B.tp,B.tx,B.oD,B.vZ,B.v2,B.vJ,B.uj,B.px,B.ud,B.pV,B.uu,B.uO,B.i1,B.ya,B.v9,B.hX,B.tj,B.oi,B.nZ,B.rs,B.nW,B.oy,B.w_,B.wi,B.hA,B.hg,B.qk,B.vn,B.t0,B.lm,B.rO,B.jk,B.tw,B.hU,B.vr,B.mb,B.xf,B.hb,B.a4,B.iq,B.n6,B.rt,B.iA,B.pq,B.l4,B.az,B.hx,B.pY,B.mF,B.c9,B.r_,B.j8,B.cs,B.qS,B.x7,B.pg,B.h9,B.v_,B.fj,B.t6,B.oO,B.oJ,B.lF,B.ry,B.iJ,B.w3,B.tm,B.oS,B.lG,B.te,B.on,B.k1,B.lL,B.o4,B.x4,B.vT,B.wI,B.or,B.tO,B.n8,B.vj,B.vK,B.oc,B.vR,B.tJ,B.xL,B.mM,B.xB,B.hr,B.ye,B.uG,B.ff,B.wv,B.qG,B.yx,B.h5,B.jS,B.lV,B.up,B.iz,B.xl,B.yy,B.hj,B.mg,B.wD,B.fQ,B.c2,B.hp,B.hS,B.aM,B.c8,B.vk,B.kU,B.n2,B.n3,B.cj,B.tf,B.qz,B.oN,B.wf,B.xX,B.f7,B.yl,B.h1,B.mp,B.ow,B.mL,B.kO,B.iv,B.fJ,B.rP,B.p1,B.qP,B.qY,B.pj,B.hC,B.aF,B.mE,B.m6,B.tX,B.rY,B.r7,B.wc,B.mW,B.o_,B.j7,B.qj,B.xK,B.hm,B.i6,B.it,B.bF,B.kd,B.ym,B.mH,B.nQ,B.hV,B.l3,B.c6,B.pi,B.xJ,B.vQ,B.nU,B.wN,B.vz,B.ki,B.rh,B.aC,B.cb,B.t2,B.k6,B.ck,B.cm,B.xb,B.kg,B.jV,B.xt,B.mR,B.aG,B.oK,B.xd,B.q_,B.pf,B.nO,B.uW,B.hz,B.kZ,B.jR,B.lp,B.ky,B.wg,B.q1,B.lI,B.yc,B.iB,B.lE,B.no,B.qb,B.o1,B.xq,B.ra,B.lT,B.jK,B.fR,B.qN,B.oM,B.os,B.aK,B.jl,B.c8,B.u3,B.io,B.fw,B.v3,B.qD,B.um,B.ko,B.j_,B.n4,B.kV,B.m3,B.o9,B.t1,B.n0,B.ts,B.fX,B.lB,B.l1,B.hK,B.vL,B.ht,B.nj,B.yd,B.rk,B.u1,B.hD,B.rI,B.lZ,B.lw,B.oe,B.xz,B.vi,B.pZ,B.tE,B.tl,B.fu,B.jB,B.bM,B.aL,B.bW,B.wT,B.n_,B.bR,B.bT,B.cj,B.F,B.nK,B.iD,B.cw,B.aw,B.cq,B.bG,B.hq,B.rb,B.tD,B.uU,B.hd,B.kW,B.wo,B.uT,B.pu,B.mQ,B.cg,B.bU,B.kq,B.us,B.p8,B.mG,B.cu,B.bA,B.aL,B.lA,B.iH,B.bF,B.xI,B.ut,B.bN,B.c2,B.iT,B.bL,B.of,B.a4,B.ov,B.hF,B.oF,B.v0,B.kC,B.i8,B.y_,B.iX,B.pS,B.fp,B.hu,B.h8,B.rA,B.xN,B.hW,B.cm,B.r4,B.od,B.l6,B.li,B.mP,B.qC,B.o8,B.j6,B.kv,B.x2,B.la,B.w0,B.py,B.kx,B.tZ,B.wa,B.fI,B.kw,B.je,B.yB,B.p5,B.pN,B.vS,B.ro,B.rN,B.ve,B.vV,B.vN,B.wY,B.my,B.yt,B.vu,B.pe,B.iL,B.fk,B.h3,B.y6,B.vE,B.kt,B.jm,B.xw,B.ic,B.vp,B.kB,B.oa,B.xg,B.nJ,B.jj,B.kT,B.bH,B.kA,B.qQ,B.cx,B.iM,B.xE,B.fx,B.oz,B.yu,B.aG,B.uC,B.iP,B.i7,B.bH,B.il,B.i0,B.rM,B.ms,B.jt,B.k9,B.uw,B.js,B.fb,B.mm,B.lY,B.pJ,B.bD,B.iW,B.t,B.oA,B.cx,B.cJ,B.hE,B.i4,B.jq,B.qE,B.a5,B.cc,B.bY,B.t,B.rU,B.tV,B.wX,B.vg,B.Q,B.cl,B.a5,B.cn,B.aJ,B.av,B.O,B.r,B.aG,B.z,B.pz,B.hM,B.ug,B.P,B.bx,B.G,B.cr,B.r,B.cC,B.ql,B.hR,B.bE,B.tL,B.i5,B.bZ,B.qx,B.uR,B.cH,B.rr,B.tt,B.cd,B.mc,B.jx,B.by,B.h7,B.fF,B.cD,B.fn,B.h2,B.bP,B.wl,B.h4,B.oX,B.yk,B.qV,B.ct,B.r3,B.oh,B.cC,B.xe,B.xm,B.q4,B.ci,B.oE,B.xn,B.c_,B.t,B.bE,B.qF,B.uA,B.ip,B.ci,B.pX,B.mT,B.ol,B.t,B.bZ,B.z,B.kS,B.ob,B.Q,B.cE,B.P,B.G,B.r,B.cH,B.z,B.aI,B.v5,B.Q,B.bJ,B.P,B.r,B.O,B.G,B.cd,B.mS,B.aI,B.pI,B.Q,B.bI,B.r,B.O,B.a5,B.cn,B.aJ,B.av,B.by,B.yg,B.aI,B.xr,B.Q,B.c0,B.vo,B.vX,B.r,B.G,B.aJ,B.av,B.cD,B.z,B.fE,B.nm,B.pG,B.nF,B.jw,B.O,B.a5,B.t,B.bP,B.cJ,B.uo,B.uE,B.ph,B.kF,B.lW,B.l7,B.vw,B.c5,B.bY,B.cc,B.t,B.mh,B.z,B.qM,B.l9,B.o0,B.oW,B.c5,B.oT,B.cr,B.r,B.O,B.G,B.ct,B.z,B.ld,B.uI,B.wV,B.pp,B.jr,B.un,B.aK,B.r,B.G],A.X("b8<c,+(c,c,c)>"))
B.a0={}
B.bo=new A.b8(B.a0,[],A.X("b8<c,p<+(I,e)>>"))
B.aq=new A.b8(B.a0,[],A.X("b8<c,c>"))
B.dN={DRAWING:0,TEXT:1,DIMENSIONS:2,CONTOURS:3,SPOT_HEIGHTS:4,DEM:5,ZONE_PIPES:6,MAINLINE_PIPES:7,SPRAYLINES:8,TAPES:9,OUTLETS:10,WETTED_RADII:11,CONTROL_VALVES:12,WATER_SUPPLY:13,PUMPS:14,MISC_HYDRAULIC:15,JUNCTIONS:16,AREAS:17,LABELS:18,IMAGES:19,HATCHES:20,SYMBOLS:21,PIVOTS:22}
B.dM=new A.b8(B.dN,[4289773253,4293718001,4287669422,4287458915,4288776319,4286483095,4282557941,4280191205,4280731354,4284922730,4280923894,1428797174,4294944550,4286470082,4293874512,4294953512,4286091420,867095937,4291811548,4294967295,4286091420,4289773253,4283283116],A.X("b8<c,f>"))
B.au=new A.A(0,0)
B.dY=new A.cO(0,0,0,1)
B.dZ=new A.m(0.0016666666666666666,12)
B.e_=new A.m(0.011111111111111112,65)
B.bu=new A.m(0,0)
B.e0=new A.m(0,110)
B.e1=new A.m(0,27)
B.e2=new A.m(0,37)
B.e3=new A.m(0,45)
B.e4=new A.m(0,50)
B.e5=new A.m(0,53)
B.e6=new A.m(0,58)
B.e7=new A.m(0,60)
B.e8=new A.m(0,63)
B.e9=new A.m(0,70)
B.ea=new A.m(0,72)
B.bv=new A.m(0,78)
B.eb=new A.m(0,80)
B.ec=new A.m(0,82)
B.ed=new A.m(0,85)
B.bw=new A.m(0,90)
B.ee=new A.m(0.044444444444444446,55)
B.ef=new A.m(0.041666666666666664,78)
B.eg=new A.m(0.002777777777777778,18)
B.eh=new A.m(0.0011111111111111111,20)
B.ei=new A.m(0.0005555555555555556,25)
B.ej=new A.m(0.06388888888888888,38)
B.ek=new A.m(0.001388888888888889,41)
B.el=new A.m(0.03333333333333333,55)
B.em=new A.m(0.022222222222222223,31)
B.en=new A.m(0.03888888888888889,40)
B.eo=new A.m(0.0022222222222222222,55)
B.ep=new A.m(0.006944444444444444,60)
B.eq=new A.m(0.005555555555555556,53)
B.er=new A.m(0.003333333333333333,36)
B.es=new A.m(0.0011111111111111111,68)
B.et=new A.m("","")
B.eu=new A.m(0.0019444444444444444,28)
B.ev=new A.m(0.03194444444444444,72)
B.ew=new A.m(0.015277777777777777,45)
B.ex=new A.m(0.016666666666666666,30)
B.ey=new A.m(0.005555555555555556,80)
B.ez=new A.m(0.011666666666666667,27)
B.eA=new A.m(0.016666666666666666,42)
B.eB=new A.m(0.011111111111111112,45)
B.eC=new A.m(0.0075,26)
B.eD=new A.m(0.0016666666666666666,80)
B.eE=new A.m(0.09166666666666666,42)
B.eF=new A.m(0.0077777777777777776,55)
B.eG=new A.m(0.027777777777777776,33)
B.eH=new A.m(0.0077777777777777776,40)
B.eI=new A.m(0.0025,46)
B.eJ=new A.m(0.0038888888888888888,49)
B.eK=new A.m(0.022222222222222223,52)
B.eL=new A.m(0.009722222222222222,40)
B.eM=new A.m(0.004166666666666667,25)
B.eN=new A.m(0.027777777777777776,60)
B.eO=new A.m(0.013888888888888888,74)
B.eP=new A.m(0.11666666666666667,45)
B.eQ=new A.m(0.022222222222222223,66)
B.eR=new A.m(0.0077777777777777776,98)
B.eS=new A.m(0.019444444444444445,48)
B.eT=new A.m(0.005,42)
B.eU=new A.m(0.08333333333333333,65)
B.eV=new A.m(0.002777777777777778,35)
B.eW=new A.m(0,1/0)
B.eX=new A.m(0.003333333333333333,72)
B.eY=new A.m(0.05,38)
B.eZ=new A.m(0.016666666666666666,64)
B.f_=new A.m(0.06388888888888888,60)
B.f0=new A.m(0.015277777777777777,80)
B.f1=new A.m(0.0009722222222222222,34)
B.f2=new A.m(0.005,38)
B.f3=new A.m(0.003333333333333333,65)
B.f4=new A.m(0.009722222222222222,58)
B.yD=new A.cX([0,0,0,0])
B.dP={pump_s3:0,pump_s5:1,pump_sub:2,pump_s15:3,pump_s25:4,pump_s30:5}
B.yE=new A.bP(B.dP,6,t.lq)
B.yG=new A.bP(B.a0,0,t.lq)
B.yF=new A.bP(B.a0,0,A.X("bP<f>"))
B.yS=A.bh("qk")
B.yT=A.bh("ql")
B.yU=A.bh("nR")
B.yV=A.bh("bv")
B.yW=A.bh("nS")
B.yX=A.bh("nT")
B.yY=A.bh("nU")
B.yZ=A.bh("J")
B.z_=A.bh("oq")
B.z0=A.bh("or")
B.z1=A.bh("os")
B.z2=A.bh("l6")
B.cK=new A.dF(0,0,0,0,0,0,0,0,0,0)
B.cL=new A.eV(B.bh,B.bd,B.bt,B.aX)})();(function staticFields(){$.jO=null
$.aU=A.d([],A.X("o<J>"))
$.lT=null
$.lz=null
$.ly=null
$.mR=null
$.mI=null
$.n2=null
$.kc=null
$.kn=null
$.ln=null
$.jT=A.d([],A.X("o<p<J>?>"))
$.cZ=null
$.dY=null
$.dZ=null
$.lf=!1
$.a6=B.u
$.k4=A.n(t.N,A.X("es"))
$.l1=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"qn","n7",()=>A.kg("_$dart_dartClosure"))
s($,"qm","lq",()=>A.kg("_$dart_dartClosure_dartJSInterop"))
s($,"qH","nm",()=>A.d([new J.ek()],A.X("o<dy>")))
s($,"qt","na",()=>A.bH(A.jm({
toString:function(){return"$receiver$"}})))
s($,"qu","nb",()=>A.bH(A.jm({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"qv","nc",()=>A.bH(A.jm(null)))
s($,"qw","nd",()=>A.bH(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"qz","ng",()=>A.bH(A.jm(void 0)))
s($,"qA","nh",()=>A.bH(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"qy","nf",()=>A.bH(A.m9(null)))
s($,"qx","ne",()=>A.bH(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"qC","nj",()=>A.bH(A.m9(void 0)))
s($,"qB","ni",()=>A.bH(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"qD","lr",()=>A.ov())
s($,"qF","nl",()=>A.o1(A.p6(A.d([-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-1,-2,-2,-2,-2,-2,62,-2,62,-2,63,52,53,54,55,56,57,58,59,60,61,-2,-2,-2,-1,-2,-2,-2,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-2,-2,-2,-2,63,-2,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,-2,-2,-2,-2,-2],t.X))))
s($,"qE","nk",()=>A.o2(0))
s($,"qo","n8",()=>A.of("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"qG","fw",()=>A.mZ(B.yZ))
s($,"qq","n9",()=>A.kV(0,"",B.au,B.f))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.cI,SharedArrayBuffer:A.cI,ArrayBufferView:A.du,DataView:A.ey,Float32Array:A.ez,Float64Array:A.eA,Int16Array:A.eB,Int32Array:A.eC,Int8Array:A.eD,Uint16Array:A.eE,Uint32Array:A.eF,Uint8ClampedArray:A.dv,CanvasPixelArray:A.dv,Uint8Array:A.eG})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.cJ.$nativeSuperclassTag="ArrayBufferView"
A.dL.$nativeSuperclassTag="ArrayBufferView"
A.dM.$nativeSuperclassTag="ArrayBufferView"
A.ds.$nativeSuperclassTag="ArrayBufferView"
A.dN.$nativeSuperclassTag="ArrayBufferView"
A.dO.$nativeSuperclassTag="ArrayBufferView"
A.dt.$nativeSuperclassTag="ArrayBufferView"})()
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
var s=A.q4
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()