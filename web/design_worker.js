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
if(a[b]!==s){A.qw(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.d(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.lt(b)
return new s(c,this)}:function(){if(s===null)s=A.lt(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.lt(a).prototype
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
ly(a,b,c,d){return{i:a,p:b,e:c,x:d}},
lu(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.lw==null){A.qc()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.l(A.mj("Return interceptor for "+A.A(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.jX
if(o==null)o=$.jX=A.kp(n)
p=q[o]}if(p!=null)return p
p=A.qh(a)
if(p!=null)return p
if(typeof a=="function")return B.ey
s=Object.getPrototypeOf(a)
if(s==null)return B.bu
if(s===Object.prototype)return B.bu
if(typeof q=="function"){o=$.jX
if(o==null)o=$.jX=A.kp(n)
Object.defineProperty(q,o,{value:B.aQ,enumerable:false,writable:true,configurable:true})
return B.aQ}return B.aQ},
lU(a,b){if(a<0||a>4294967295)throw A.l(A.aR(a,0,4294967295,"length",null))
return J.o6(new Array(a),b)},
lV(a,b){if(a<0)throw A.l(A.d6("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("o<0>"))},
en(a,b){if(a<0)throw A.l(A.d6("Length must be a non-negative integer: "+a,null))
return A.d(new Array(a),b.j("o<0>"))},
o6(a,b){var s=A.d(a,b.j("o<0>"))
s.$flags=1
return s},
o7(a,b){var s=t.bP
return J.lD(s.a(a),s.a(b))},
lW(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
o8(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.lW(r))break;++b}return b},
o9(a,b){var s,r,q
for(s=a.length;b>0;b=r){r=b-1
if(!(r<s))return A.b(a,r)
q=a.charCodeAt(r)
if(q!==32&&q!==13&&!J.lW(q))break}return b},
cA(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.di.prototype
return J.ep.prototype}if(typeof a=="string")return J.ci.prototype
if(a==null)return J.dj.prototype
if(typeof a=="boolean")return J.eo.prototype
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bW.prototype
if(typeof a=="symbol")return J.dm.prototype
if(typeof a=="bigint")return J.dk.prototype
return a}if(a instanceof A.K)return a
return J.lu(a)},
a9(a){if(typeof a=="string")return J.ci.prototype
if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bW.prototype
if(typeof a=="symbol")return J.dm.prototype
if(typeof a=="bigint")return J.dk.prototype
return a}if(a instanceof A.K)return a
return J.lu(a)},
a1(a){if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.bW.prototype
if(typeof a=="symbol")return J.dm.prototype
if(typeof a=="bigint")return J.dk.prototype
return a}if(a instanceof A.K)return a
return J.lu(a)},
q6(a){if(typeof a=="number")return J.ch.prototype
if(a==null)return a
if(!(a instanceof A.K))return J.cs.prototype
return a},
q7(a){if(typeof a=="number")return J.ch.prototype
if(typeof a=="string")return J.ci.prototype
if(a==null)return a
if(!(a instanceof A.K))return J.cs.prototype
return a},
aY(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.cA(a).Y(a,b)},
lB(a,b){if(typeof a=="number"&&typeof b=="number")return a-b
return J.q6(a).R(a,b)},
d3(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.qg(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.a9(a).h(a,b)},
l0(a,b,c){return J.a1(a).i(a,b,c)},
bO(a,b){return J.a1(a).k(a,b)},
lC(a,b){return J.a1(a).B(a,b)},
nw(a,b){return J.a1(a).b_(a,b)},
lD(a,b){return J.q7(a).T(a,b)},
fz(a,b){return J.a1(a).I(a,b)},
nx(a,b,c,d){return J.a1(a).W(a,b,c,d)},
bP(a){return J.a1(a).gu(a)},
aK(a){return J.cA(a).gK(a)},
lE(a){return J.a9(a).gF(a)},
ny(a){return J.a9(a).ga8(a)},
ac(a){return J.a1(a).gt(a)},
l1(a){return J.a1(a).gM(a)},
au(a){return J.a9(a).gm(a)},
nz(a){return J.a1(a).gcw(a)},
nA(a){return J.cA(a).gO(a)},
aE(a,b,c){return J.a1(a).aI(a,b,c)},
nB(a,b){return J.a9(a).sm(a,b)},
lF(a,b){return J.a1(a).a4(a,b)},
d4(a){return J.cA(a).q(a)},
el:function el(){},
eo:function eo(){},
dj:function dj(){},
dl:function dl(){},
bX:function bX(){},
eL:function eL(){},
cs:function cs(){},
bW:function bW(){},
dk:function dk(){},
dm:function dm(){},
o:function o(a){this.$ti=a},
em:function em(){},
il:function il(a){this.$ti=a},
c7:function c7(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
ch:function ch(){},
di:function di(){},
ep:function ep(){},
ci:function ci(){}},A={l5:function l5(){},
lK(a,b,c){if(t.Y.b(a))return new A.dL(a,b.j("@<0>").A(c).j("dL<1,2>"))
return new A.c8(a,b.j("@<0>").A(c).j("c8<1,2>"))},
lY(a){return new A.ev("Field '"+a+"' has been assigned during initialization.")},
bG(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
jk(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
cz(a,b,c){return a},
lx(a){var s,r
for(s=$.aW.length,r=0;r<s;++r)if(a===$.aW[r])return!0
return!1},
c_(a,b,c,d){A.cQ(b,"start")
if(c!=null){A.cQ(c,"end")
if(b>c)A.bv(A.aR(b,0,c,"start",null))}return new A.dG(a,b,c,d.j("dG<0>"))},
l8(a,b,c,d){if(t.Y.b(a))return new A.cd(a,b,c.j("@<0>").A(d).j("cd<1,2>"))
return new A.be(a,b,c.j("@<0>").A(d).j("be<1,2>"))},
mf(a,b,c){if(t.Y.b(a)){A.ka(b)
return void 1}A.ka(b)
return void 1},
ka(a){A.nC(a,"count",t.S)},
av(){return new A.dF("No element")},
c1:function c1(){},
d8:function d8(a,b){this.a=a
this.$ti=b},
c8:function c8(a,b){this.a=a
this.$ti=b},
dL:function dL(a,b){this.a=a
this.$ti=b},
dK:function dK(){},
ae:function ae(a,b){this.a=a
this.$ti=b},
ev:function ev(a){this.a=a},
j9:function j9(){},
z:function z(){},
w:function w(){},
dG:function dG(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aO:function aO(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
be:function be(a,b,c){this.a=a
this.b=b
this.$ti=c},
cd:function cd(a,b,c){this.a=a
this.b=b
this.$ti=c},
dt:function dt(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
u:function u(a,b,c){this.a=a
this.b=b
this.$ti=c},
C:function C(a,b,c){this.a=a
this.b=b
this.$ti=c},
dJ:function dJ(a,b,c){this.a=a
this.b=b
this.$ti=c},
dB:function dB(a,b,c){this.a=a
this.b=b
this.$ti=c},
i9:function i9(a,b,c){this.a=a
this.b=b
this.$ti=c},
dC:function dC(a,b,c){this.a=a
this.b=b
this.$ti=c},
db:function db(a){this.$ti=a},
dc:function dc(a){this.$ti=a},
ct:function ct(a,b){this.a=a
this.$ti=b},
bK:function bK(a,b){this.a=a
this.$ti=b},
W:function W(){},
br:function br(a,b){this.a=a
this.$ti=b},
dY:function dY(){},
lN(){throw A.l(A.bs("Cannot modify unmodifiable Map"))},
lO(){throw A.l(A.bs("Cannot modify constant Set"))},
nf(a){var s=A.ne(a)
if(s!=null)return s
return"minified:"+a},
qg(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.dX.b(a)},
A(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.d4(a)
return s},
eN(a){var s,r=$.m1
if(r==null)r=$.m1=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
oj(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.b(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
eO(a){var s,r,q,p
if(a instanceof A.K)return A.aD(A.ax(a),null)
s=J.cA(a)
if(s===B.ex||s===B.ez||t.cx.b(a)){r=B.aS(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.aD(A.ax(a),null)},
m8(a){var s,r,q
if(a==null||typeof a=="number"||A.ln(a))return J.d4(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.az)return a.q(0)
if(a instanceof A.b7)return a.cf(!0)
s=$.nv()
for(r=0;r<1;++r){q=s[r].e5(a)
if(q!=null)return q}return"Instance of '"+A.eO(a)+"'"},
ok(a,b,c){var s,r,q,p
if(c<=500&&b===0&&c===a.length)return String.fromCharCode.apply(null,a)
for(s=b,r="";s<c;s=q){q=s+500
p=q<c?q:c
r+=String.fromCharCode.apply(null,a.subarray(s,p))}return r},
ar(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aW(s,10)|55296)>>>0,s&1023|56320)}throw A.l(A.aR(a,0,1114111,null,null))},
ol(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.b8(h,1000)
g+=B.c.bp(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
aP(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
eM(a){return a.c?A.aP(a).getUTCFullYear()+0:A.aP(a).getFullYear()+0},
m6(a){return a.c?A.aP(a).getUTCMonth()+1:A.aP(a).getMonth()+1},
m2(a){return a.c?A.aP(a).getUTCDate()+0:A.aP(a).getDate()+0},
m3(a){return a.c?A.aP(a).getUTCHours()+0:A.aP(a).getHours()+0},
m5(a){return a.c?A.aP(a).getUTCMinutes()+0:A.aP(a).getMinutes()+0},
m7(a){return a.c?A.aP(a).getUTCSeconds()+0:A.aP(a).getSeconds()+0},
m4(a){return a.c?A.aP(a).getUTCMilliseconds()+0:A.aP(a).getMilliseconds()+0},
oi(a){var s=a.$thrownJsError
if(s==null)return null
return A.cB(s)},
bu(a){throw A.l(A.mT(a))},
b(a,b){if(a==null)J.au(a)
throw A.l(A.fu(a,b))},
fu(a,b){var s,r="index"
if(!A.mI(b))return new A.bk(!0,b,r,null)
s=A.aV(J.au(a))
if(b<0||b>=s)return A.ik(b,s,a,r)
return A.lb(b,r)},
mT(a){return new A.bk(!0,a,null,null)},
lr(a){return a},
l(a){return A.aa(a,new Error())},
aa(a,b){var s
if(a==null)a=new A.bI()
b.dartException=a
s=A.qy
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
qy(){return J.d4(this.dartException)},
bv(a,b){throw A.aa(a,b==null?new Error():b)},
ab(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.bv(A.pg(a,b,c),s)},
pg(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.dI("'"+s+"': Cannot "+o+" "+l+k+n)},
k(a){throw A.l(A.am(a))},
bJ(a){var s,r,q,p,o,n
a=A.nc(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.d([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.ju(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
jv(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
mi(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
l6(a,b){var s=b==null,r=s?null:b.method
return new A.er(a,r,s?null:b.receiver)},
bN(a){var s
if(a==null)return new A.iL(a)
if(a instanceof A.dd){s=a.a
return A.c6(a,s==null?A.dZ(s):s)}if(typeof a!=="object")return a
if("dartException" in a)return A.c6(a,a.dartException)
return A.pQ(a)},
c6(a,b){if(t.fz.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
pQ(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aW(r,16)&8191)===10)switch(q){case 438:return A.c6(a,A.l6(A.A(s)+" (Error "+q+")",null))
case 445:case 5007:A.A(s)
return A.c6(a,new A.dy())}}if(a instanceof TypeError){p=$.nj()
o=$.nk()
n=$.nl()
m=$.nm()
l=$.np()
k=$.nq()
j=$.no()
$.nn()
i=$.ns()
h=$.nr()
g=p.aa(s)
if(g!=null)return A.c6(a,A.l6(A.D(s),g))
else{g=o.aa(s)
if(g!=null){g.method="call"
return A.c6(a,A.l6(A.D(s),g))}else if(n.aa(s)!=null||m.aa(s)!=null||l.aa(s)!=null||k.aa(s)!=null||j.aa(s)!=null||m.aa(s)!=null||i.aa(s)!=null||h.aa(s)!=null){A.D(s)
return A.c6(a,new A.dy())}}return A.c6(a,new A.eY(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.dE()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.c6(a,new A.bk(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.dE()
return a},
cB(a){var s
if(a instanceof A.dd)return a.b
if(a==null)return new A.dS(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.dS(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
n7(a){if(a==null)return J.aK(a)
if(typeof a=="object")return A.eN(a)
return J.aK(a)},
q4(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.i(0,a[s],a[r])}return b},
q5(a,b){var s,r=a.length
for(s=0;s<r;++s)b.k(0,a[s])
return b},
pq(a,b,c,d,e,f){t.Z.a(a)
switch(A.aV(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.l(new A.jM("Unsupported number of arguments for wrapped closure"))},
ft(a,b){var s=a.$identity
if(!!s)return s
s=A.pW(a,b)
a.$identity=s
return s},
pW(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.pq)},
nP(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.eR().constructor.prototype):Object.create(new A.cE(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.lM(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.nL(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.lM(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
nL(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.l("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.nD)}throw A.l("Error in functionType of tearoff")},
nM(a,b,c,d){var s=A.lJ
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
lM(a,b,c,d){if(c)return A.nO(a,b,d)
return A.nM(b.length,d,a,b)},
nN(a,b,c,d){var s=A.lJ,r=A.nE
switch(b?-1:a){case 0:throw A.l(new A.eQ("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
nO(a,b,c){var s,r
if($.lH==null)$.lH=A.lG("interceptor")
if($.lI==null)$.lI=A.lG("receiver")
s=b.length
r=A.nN(s,c,a,b)
return r},
lt(a){return A.nP(a)},
nD(a,b){return A.dW(v.typeUniverse,A.ax(a.a),b)},
lJ(a){return a.a},
nE(a){return a.b},
lG(a){var s,r,q,p=new A.cE("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.l(A.d6("Field name "+a+" not found.",null))},
kp(a){return v.getIsolateTag(a)},
qh(a){var s,r,q,p,o,n=A.D($.n_.$1(a)),m=$.kl[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.kw[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=A.x($.mR.$2(a,n))
if(q!=null){m=$.kl[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.kw[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.kC(s)
$.kl[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.kw[n]=s
return s}if(p==="-"){o=A.kC(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.na(a,s)
if(p==="*")throw A.l(A.mj(n))
if(v.leafTags[n]===true){o=A.kC(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.na(a,s)},
na(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.ly(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
kC(a){return J.ly(a,!1,null,!!a.$iaN)},
qj(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.kC(s)
else return J.ly(s,c,null,null)},
qc(){if(!0===$.lw)return
$.lw=!0
A.qd()},
qd(){var s,r,q,p,o,n,m,l
$.kl=Object.create(null)
$.kw=Object.create(null)
A.qb()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.nb.$1(o)
if(n!=null){m=A.qj(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
qb(){var s,r,q,p,o,n,m=B.cZ()
m=A.d1(B.d_,A.d1(B.d0,A.d1(B.aT,A.d1(B.aT,A.d1(B.d1,A.d1(B.d2,A.d1(B.d3(B.aS),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.n_=new A.kt(p)
$.mR=new A.ku(o)
$.nb=new A.kv(n)},
d1(a,b){return a(b)||b},
oY(a,b){var s,r
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.b(b,s)
if(!J.aY(r,b[s]))return!1}return!0},
pY(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
oa(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.l(A.bc("Illegal RegExp pattern ("+String(o)+")",a,null))},
q1(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
nc(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
qu(a,b,c){var s=A.qv(a,b,c)
return s},
qv(a,b,c){var s,r,q
if(b===""){if(a==="")return c
s=a.length
for(r=c,q=0;q<s;++q)r=r+a[q]+c
return r.charCodeAt(0)==0?r:r}if(a.indexOf(b,0)<0)return a
if(a.length<500||c.indexOf("$",0)>=0)return a.split(b).join(c)
return a.replace(new RegExp(A.nc(b),"g"),A.q1(c))},
n:function n(a,b){this.a=a
this.b=b},
a:function a(a,b,c){this.a=a
this.b=b
this.c=c},
cY:function cY(a){this.a=a},
aU:function aU(a){this.a=a},
d9:function d9(){},
aM:function aM(a,b,c){this.a=a
this.b=b
this.$ti=c},
dM:function dM(a,b){this.a=a
this.$ti=b},
cv:function cv(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
da:function da(){},
bR:function bR(a,b,c){this.a=a
this.b=b
this.$ti=c},
ek:function ek(){},
cg:function cg(a,b){this.a=a
this.$ti=b},
dA:function dA(){},
ju:function ju(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dy:function dy(){},
er:function er(a,b,c){this.a=a
this.b=b
this.c=c},
eY:function eY(a){this.a=a},
iL:function iL(a){this.a=a},
dd:function dd(a,b){this.a=a
this.b=b},
dS:function dS(a){this.a=a
this.b=null},
az:function az(){},
e7:function e7(){},
e8:function e8(){},
eT:function eT(){},
eR:function eR(){},
cE:function cE(a,b){this.a=a
this.b=b},
eQ:function eQ(a){this.a=a},
bA:function bA(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
im:function im(a){this.a=a},
iq:function iq(a,b){var _=this
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
O:function O(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
M:function M(a,b){this.a=a
this.$ti=b},
ah:function ah(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
kt:function kt(a){this.a=a},
ku:function ku(a){this.a=a},
kv:function kv(a){this.a=a},
b7:function b7(){},
cW:function cW(){},
cX:function cX(){},
cx:function cx(){},
eq:function eq(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
k0:function k0(a){this.b=a},
ph(a){return a},
oc(a){return new Int8Array(a)},
od(a){return new Uint8Array(a)},
bL(a,b,c){if(a>>>0!==a||a>=c)throw A.l(A.fu(b,a))},
cJ:function cJ(){},
dw:function dw(){},
eA:function eA(){},
cK:function cK(){},
du:function du(){},
dv:function dv(){},
eB:function eB(){},
eC:function eC(){},
eD:function eD(){},
eE:function eE(){},
eF:function eF(){},
eG:function eG(){},
eH:function eH(){},
dx:function dx(){},
eI:function eI(){},
dN:function dN(){},
dO:function dO(){},
dP:function dP(){},
dQ:function dQ(){},
lc(a,b){var s=b.c
return s==null?b.c=A.dU(a,"bn",[b.x]):s},
me(a){var s=a.w
if(s===6||s===7)return A.me(a.x)
return s===11||s===12},
or(a){return a.as},
n9(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
T(a){return A.k6(v.typeUniverse,a,!1)},
qf(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.c5(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
c5(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.c5(a1,s,a3,a4)
if(r===s)return a2
return A.mt(a1,r,!0)
case 7:s=a2.x
r=A.c5(a1,s,a3,a4)
if(r===s)return a2
return A.ms(a1,r,!0)
case 8:q=a2.y
p=A.d0(a1,q,a3,a4)
if(p===q)return a2
return A.dU(a1,a2.x,p)
case 9:o=a2.x
n=A.c5(a1,o,a3,a4)
m=a2.y
l=A.d0(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.lj(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.d0(a1,j,a3,a4)
if(i===j)return a2
return A.mu(a1,k,i)
case 11:h=a2.x
g=A.c5(a1,h,a3,a4)
f=a2.y
e=A.pN(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.mr(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.d0(a1,d,a3,a4)
o=a2.x
n=A.c5(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.lk(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.l(A.e4("Attempted to substitute unexpected RTI kind "+a0))}},
d0(a,b,c,d){var s,r,q,p,o=b.length,n=A.k7(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.c5(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
pO(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.k7(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.c5(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
pN(a,b,c,d){var s,r=b.a,q=A.d0(a,r,c,d),p=b.b,o=A.d0(a,p,c,d),n=b.c,m=A.pO(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.f5()
s.a=q
s.b=o
s.c=m
return s},
d(a,b){a[v.arrayRti]=b
return a},
kk(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.q9(s)
return a.$S()}return null},
qe(a,b){var s
if(A.me(b))if(a instanceof A.az){s=A.kk(a)
if(s!=null)return s}return A.ax(a)},
ax(a){if(a instanceof A.K)return A.i(a)
if(Array.isArray(a))return A.t(a)
return A.lm(J.cA(a))},
t(a){var s=a[v.arrayRti],r=t.dG
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.lm(a)},
lm(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.po(a,s)},
po(a,b){var s=a instanceof A.az?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.p7(v.typeUniverse,s.name)
b.$ccache=r
return r},
q9(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.k6(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
q8(a){return A.bM(A.i(a))},
lv(a){var s=A.kk(a)
return A.bM(s==null?A.ax(a):s)},
lq(a){var s
if(a instanceof A.b7)return A.q2(a.$r,a.aN())
s=a instanceof A.az?A.kk(a):null
if(s!=null)return s
if(t.aJ.b(a))return J.nA(a).a
if(Array.isArray(a))return A.t(a)
return A.ax(a)},
bM(a){var s=a.r
return s==null?a.r=new A.k5(a):s},
q2(a,b){var s,r,q=b,p=q.length
if(p===0)return t.aK
if(0>=p)return A.b(q,0)
s=A.dW(v.typeUniverse,A.lq(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.b(q,r)
s=A.mw(v.typeUniverse,s,A.lq(q[r]))}return A.dW(v.typeUniverse,s,a)},
bj(a){return A.bM(A.k6(v.typeUniverse,a,!1))},
pn(a){var s=this
s.b=A.pL(s)
return s.b(a)},
pL(a){var s,r,q,p,o
if(a===t.K)return A.pw
if(A.cC(a))return A.pA
s=a.w
if(s===6)return A.pl
if(s===1)return A.mK
if(s===7)return A.pr
r=A.pK(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.cC)){a.f="$i"+q
if(q==="q")return A.pu
if(a===t.m)return A.pt
return A.pz}}else if(s===10){p=A.pY(a.x,a.y)
o=p==null?A.mK:p
return o==null?A.dZ(o):o}return A.pj},
pK(a){if(a.w===8){if(a===t.S)return A.mI
if(a===t.i||a===t.H)return A.pv
if(a===t.N)return A.py
if(a===t.y)return A.ln}return null},
pm(a){var s=this,r=A.pi
if(A.cC(s))r=A.pc
else if(s===t.K)r=A.dZ
else if(A.d2(s)){r=A.pk
if(s===t.aV)r=A.mz
else if(s===t.bl)r=A.x
else if(s===t.o9)r=A.Y
else if(s===t.jh)r=A.y
else if(s===t.jX)r=A.pa
else if(s===t.mU)r=A.pb}else if(s===t.S)r=A.aV
else if(s===t.N)r=A.D
else if(s===t.y)r=A.p9
else if(s===t.H)r=A.at
else if(s===t.i)r=A.S
else if(s===t.m)r=A.mA
s.a=r
return s.a(a)},
pj(a){var s=this
if(a==null)return A.d2(s)
return A.n2(v.typeUniverse,A.qe(a,s),s)},
pl(a){if(a==null)return!0
return this.x.b(a)},
pz(a){var s,r=this
if(a==null)return A.d2(r)
s=r.f
if(a instanceof A.K)return!!a[s]
return!!J.cA(a)[s]},
pu(a){var s,r=this
if(a==null)return A.d2(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.K)return!!a[s]
return!!J.cA(a)[s]},
pt(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.K)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
mJ(a){if(typeof a=="object"){if(a instanceof A.K)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
pi(a){var s=this
if(a==null){if(A.d2(s))return a}else if(s.b(a))return a
throw A.aa(A.mF(a,s),new Error())},
pk(a){var s=this
if(a==null||s.b(a))return a
throw A.aa(A.mF(a,s),new Error())},
mF(a,b){return new A.cZ("TypeError: "+A.mm(a,A.aD(b,null)))},
mV(a,b,c,d){if(A.n2(v.typeUniverse,a,b))return a
throw A.aa(A.p_("The type argument '"+A.aD(a,null)+"' is not a subtype of the type variable bound '"+A.aD(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
mm(a,b){return A.ee(a)+": type '"+A.aD(A.lq(a),null)+"' is not a subtype of type '"+b+"'"},
p_(a){return new A.cZ("TypeError: "+a)},
b8(a,b){return new A.cZ("TypeError: "+A.mm(a,b))},
pr(a){var s=this
return s.x.b(a)||A.lc(v.typeUniverse,s).b(a)},
pw(a){return a!=null},
dZ(a){if(a!=null)return a
throw A.aa(A.b8(a,"Object"),new Error())},
pA(a){return!0},
pc(a){return a},
mK(a){return!1},
ln(a){return!0===a||!1===a},
p9(a){if(!0===a)return!0
if(!1===a)return!1
throw A.aa(A.b8(a,"bool"),new Error())},
Y(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.aa(A.b8(a,"bool?"),new Error())},
S(a){if(typeof a=="number")return a
throw A.aa(A.b8(a,"double"),new Error())},
pa(a){if(typeof a=="number")return a
if(a==null)return a
throw A.aa(A.b8(a,"double?"),new Error())},
mI(a){return typeof a=="number"&&Math.floor(a)===a},
aV(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.aa(A.b8(a,"int"),new Error())},
mz(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.aa(A.b8(a,"int?"),new Error())},
pv(a){return typeof a=="number"},
at(a){if(typeof a=="number")return a
throw A.aa(A.b8(a,"num"),new Error())},
y(a){if(typeof a=="number")return a
if(a==null)return a
throw A.aa(A.b8(a,"num?"),new Error())},
py(a){return typeof a=="string"},
D(a){if(typeof a=="string")return a
throw A.aa(A.b8(a,"String"),new Error())},
x(a){if(typeof a=="string")return a
if(a==null)return a
throw A.aa(A.b8(a,"String?"),new Error())},
mA(a){if(A.mJ(a))return a
throw A.aa(A.b8(a,"JSObject"),new Error())},
pb(a){if(a==null)return a
if(A.mJ(a))return a
throw A.aa(A.b8(a,"JSObject?"),new Error())},
mO(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.aD(a[q],b)
return s},
pF(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.mO(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.aD(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
mG(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
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
if(l===8){p=A.pP(a.x)
o=a.y
return o.length>0?p+("<"+A.mO(o,b)+">"):p}if(l===10)return A.pF(a,b)
if(l===11)return A.mG(a,b,null)
if(l===12)return A.mG(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.b(b,n)
return b[n]}return"?"},
pP(a){var s=A.ne(a)
if(s!=null)return s
return"minified:"+a},
p8(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
p7(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.k6(a,b,!1)
else if(typeof m=="number"){s=m
r=A.dV(a,5,"#")
q=A.k7(s)
for(p=0;p<s;++p)q[p]=r
o=A.dU(a,b,q)
n[b]=o
return o}else return m},
p6(a,b){return A.mx(a.tR,b)},
p5(a,b){return A.mx(a.eT,b)},
k6(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.mv(a,null,b,!1)
r.set(b,s)
return s},
dW(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.mv(a,b,c,!0)
q.set(c,r)
return r},
mw(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.lj(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
mv(a,b,c,d){return A.oW(A.oQ(a,b,c,d))},
c3(a,b){b.a=A.pm
b.b=A.pn
return b},
dV(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.bi(null,null)
s.w=b
s.as=c
r=A.c3(a,s)
a.eC.set(c,r)
return r},
mt(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.p3(a,b,r,c)
a.eC.set(r,s)
return s},
p3(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.cC(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.d2(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.bi(null,null)
q.w=6
q.x=b
q.as=c
return A.c3(a,q)},
ms(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.p1(a,b,r,c)
a.eC.set(r,s)
return s},
p1(a,b,c,d){var s,r
if(d){s=b.w
if(A.cC(b)||b===t.K)return b
else if(s===1)return A.dU(a,"bn",[b])
else if(b===t.a||b===t.T)return t.gK}r=new A.bi(null,null)
r.w=7
r.x=b
r.as=c
return A.c3(a,r)},
p4(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.bi(null,null)
s.w=13
s.x=b
s.as=q
r=A.c3(a,s)
a.eC.set(q,r)
return r},
dT(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
p0(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
dU(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.dT(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.bi(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.c3(a,r)
a.eC.set(p,q)
return q},
lj(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.dT(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.bi(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.c3(a,o)
a.eC.set(q,n)
return n},
mu(a,b,c){var s,r,q="+"+(b+"("+A.dT(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.bi(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.c3(a,s)
a.eC.set(q,r)
return r},
mr(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.dT(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.dT(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.p0(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.bi(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.c3(a,p)
a.eC.set(r,o)
return o},
lk(a,b,c,d){var s,r=b.as+("<"+A.dT(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.p2(a,b,c,r,d)
a.eC.set(r,s)
return s},
p2(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.k7(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.c5(a,b,r,0)
m=A.d0(a,c,r,0)
return A.lk(a,n,m,c!==m)}}l=new A.bi(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.c3(a,l)},
oQ(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
oW(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.oS(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.mo(a,r,l,k,!1)
else if(q===46)r=A.mo(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.cw(a.u,a.e,k.pop()))
break
case 94:k.push(A.p4(a.u,k.pop()))
break
case 35:k.push(A.dV(a.u,5,"#"))
break
case 64:k.push(A.dV(a.u,2,"@"))
break
case 126:k.push(A.dV(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.oU(a,k)
break
case 38:A.oT(a,k)
break
case 63:p=a.u
k.push(A.mt(p,A.cw(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.ms(p,A.cw(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.oR(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.mp(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.oX(a.u,a.e,o)
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
return A.cw(a.u,a.e,m)},
oS(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
mo(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.p8(s,o.x)[p]
if(n==null)A.bv('No "'+p+'" in "'+A.or(o)+'"')
d.push(A.dW(s,o,n))}else d.push(p)
return m},
oU(a,b){var s,r=a.u,q=A.mn(a,b),p=b.pop()
if(typeof p=="string")b.push(A.dU(r,p,q))
else{s=A.cw(r,a.e,p)
switch(s.w){case 11:b.push(A.lk(r,s,q,a.n))
break
default:b.push(A.lj(r,s,q))
break}}},
oR(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.mn(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.cw(p,a.e,o)
q=new A.f5()
q.a=s
q.b=n
q.c=m
b.push(A.mr(p,r,q))
return
case-4:b.push(A.mu(p,b.pop(),s))
return
default:throw A.l(A.e4("Unexpected state under `()`: "+A.A(o)))}},
oT(a,b){var s=b.pop()
if(0===s){b.push(A.dV(a.u,1,"0&"))
return}if(1===s){b.push(A.dV(a.u,4,"1&"))
return}throw A.l(A.e4("Unexpected extended operation "+A.A(s)))},
mn(a,b){var s=b.splice(a.p)
A.mp(a.u,a.e,s)
a.p=b.pop()
return s},
cw(a,b,c){if(typeof c=="string")return A.dU(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.oV(a,b,c)}else return c},
mp(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.cw(a,b,c[s])},
oX(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.cw(a,b,c[s])},
oV(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.l(A.e4("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.l(A.e4("Bad index "+c+" for "+b.q(0)))},
n2(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.a8(a,b,null,c,null)
r.set(c,s)}return s},
a8(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.cC(d))return!0
s=b.w
if(s===4)return!0
if(A.cC(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.a8(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.a8(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.a8(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.a8(a,b.x,c,d,e))return!1
return A.a8(a,A.lc(a,b),c,d,e)}if(s===6)return A.a8(a,p,c,d,e)&&A.a8(a,b.x,c,d,e)
if(q===7){if(A.a8(a,b,c,d.x,e))return!0
return A.a8(a,b,c,A.lc(a,d),e)}if(q===6)return A.a8(a,b,c,p,e)||A.a8(a,b,c,d.x,e)
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
if(!A.a8(a,j,c,i,e)||!A.a8(a,i,e,j,c))return!1}return A.mH(a,b.x,c,d.x,e)}if(q===11){if(b===t.dY)return!0
if(p)return!1
return A.mH(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.ps(a,b,c,d,e)}if(o&&q===10)return A.px(a,b,c,d,e)
return!1},
mH(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
ps(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.dW(a,b,r[o])
return A.my(a,p,null,c,d.y,e)}return A.my(a,b.y,null,c,d.y,e)},
my(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.a8(a,b[s],d,e[s],f))return!1
return!0},
px(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.a8(a,r[s],c,q[s],e))return!1
return!0},
d2(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.cC(a))if(s!==6)r=s===7&&A.d2(a.x)
return r},
cC(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.iD},
mx(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
k7(a){return a>0?new Array(a):v.typeUniverse.sEA},
bi:function bi(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
f5:function f5(){this.c=this.b=this.a=null},
k5:function k5(a){this.a=a},
f4:function f4(){},
cZ:function cZ(a){this.a=a},
oG(){var s,r,q
if(self.scheduleImmediate!=null)return A.pS()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.ft(new A.jH(s),1)).observe(r,{childList:true})
return new A.jG(s,r,q)}else if(self.setImmediate!=null)return A.pT()
return A.pU()},
oH(a){self.scheduleImmediate(A.ft(new A.jI(t.M.a(a)),0))},
oI(a){self.setImmediate(A.ft(new A.jJ(t.M.a(a)),0))},
oJ(a){A.oz(B.cX,t.M.a(a))},
oz(a,b){return A.oZ(0,b)},
oZ(a,b){var s=new A.k3()
s.cN(a,b)
return s},
mL(a){return new A.f_(new A.ag($.a6,a.j("ag<0>")),a.j("f_<0>"))},
mE(a,b){a.$2(0,null)
b.b=!0
return b.a},
mB(a,b){A.pd(a,b)},
mD(a,b){var s,r,q=b.$ti
q.j("1/?").a(a)
s=a==null?q.c.a(a):a
if(!b.b)b.a.bN(s)
else{r=b.a
if(q.j("bn<1>").b(s))r.bR(s)
else r.bS(s)}},
mC(a,b){var s=A.bN(a),r=A.cB(a),q=b.b,p=b.a
if(q)p.be(new A.b9(s,r))
else p.bO(new A.b9(s,r))},
pd(a,b){var s,r,q=new A.k8(b),p=new A.k9(b)
if(a instanceof A.ag)a.cd(q,p,t.z)
else{s=t.z
if(a instanceof A.ag)a.cA(q,p,s)
else{r=new A.ag($.a6,t._)
r.a=8
r.c=a
r.cd(q,p,s)}}},
mQ(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.a6.cv(new A.kg(s),t.r,t.S,t.z)},
mq(a,b,c){return 0},
l2(a){var s
if(t.fz.b(a)){s=a.gaK()
if(s!=null)return s}return B.d5},
lh(a,b,c){var s,r,q,p,o={},n=o.a=a
for(s=t._;r=n.a,(r&4)!==0;n=a){a=s.a(n.c)
o.a=a}if(n===b){s=A.ou()
b.bO(new A.b9(new A.bk(!0,n,null,"Cannot complete a future with itself"),s))
return}q=b.a&1
s=n.a=r|q
if((s&24)===0){p=t.F.a(b.c)
b.a=b.a&1|4
b.c=n
n.c6(p)
return}if(!c)if(b.c==null)n=(s&16)===0||q!==0
else n=!1
else n=!0
if(n){p=b.aU()
b.aM(o.a)
A.cV(b,p)
return}b.a^=2
A.fr(null,null,b.b,t.M.a(new A.jQ(o,b)))},
cV(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d={},c=d.a=a
for(s=t.t,r=t.F;;){q={}
p=c.a
o=(p&16)===0
n=!o
if(b==null){if(n&&(p&1)===0){m=s.a(c.c)
A.lp(m.a,m.b)}return}q.a=b
l=b.a
for(c=b;l!=null;c=l,l=k){c.a=null
A.cV(d.a,c)
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
A.lp(j.a,j.b)
return}g=$.a6
if(g!==h)$.a6=h
else g=null
c=c.c
if((c&15)===8)new A.jU(q,d,n).$0()
else if(o){if((c&1)!==0)new A.jT(q,j).$0()}else if((c&2)!==0)new A.jS(d,q).$0()
if(g!=null)$.a6=g
c=q.c
if(c instanceof A.ag){p=q.a.$ti
p=p.j("bn<2>").b(c)||!p.y[1].b(c)}else p=!1
if(p){f=q.a.b
if((c.a&24)!==0){e=r.a(f.c)
f.c=null
b=f.aV(e)
f.a=c.a&30|f.a&1
f.c=c.c
d.a=c
continue}else A.lh(c,f,!0)
return}}f=q.a.b
e=r.a(f.c)
f.c=null
b=f.aV(e)
c=q.b
p=q.c
if(!c){f.$ti.c.a(p)
f.a=8
f.c=p}else{s.a(p)
f.a=f.a&1|16
f.c=p}d.a=f
c=f}},
pG(a,b){var s
if(t.ng.b(a))return b.cv(a,t.z,t.K,t.l)
s=t.mq
if(s.b(a))return s.a(a)
throw A.l(A.e2(a,"onError",u.c))},
pC(){var s,r
for(s=$.d_;s!=null;s=$.d_){$.e0=null
r=s.b
$.d_=r
if(r==null)$.e_=null
s.a.$0()}},
pM(){$.lo=!0
try{A.pC()}finally{$.e0=null
$.lo=!1
if($.d_!=null)$.lA().$1(A.mU())}},
mP(a){var s=new A.f0(a),r=$.e_
if(r==null){$.d_=$.e_=s
if(!$.lo)$.lA().$1(A.mU())}else $.e_=r.b=s},
pJ(a){var s,r,q,p=$.d_
if(p==null){A.mP(a)
$.e0=$.e_
return}s=new A.f0(a)
r=$.e0
if(r==null){s.b=p
$.d_=$.e0=s}else{q=r.b
s.b=q
$.e0=r.b=s
if(q==null)$.e_=s}},
qH(a,b){A.cz(a,"stream",t.K)
return new A.fl(b.j("fl<0>"))},
lp(a,b){A.pJ(new A.kf(a,b))},
mN(a,b,c,d,e){var s,r=$.a6
if(r===c)return d.$0()
$.a6=c
s=r
try{r=d.$0()
return r}finally{$.a6=s}},
pI(a,b,c,d,e,f,g){var s,r=$.a6
if(r===c)return d.$1(e)
$.a6=c
s=r
try{r=d.$1(e)
return r}finally{$.a6=s}},
pH(a,b,c,d,e,f,g,h,i){var s,r=$.a6
if(r===c)return d.$2(e,f)
$.a6=c
s=r
try{r=d.$2(e,f)
return r}finally{$.a6=s}},
fr(a,b,c,d){t.M.a(d)
if(B.u!==c){d=c.dn(d)
d=d}A.mP(d)},
jH:function jH(a){this.a=a},
jG:function jG(a,b,c){this.a=a
this.b=b
this.c=c},
jI:function jI(a){this.a=a},
jJ:function jJ(a){this.a=a},
k3:function k3(){},
k4:function k4(a,b){this.a=a
this.b=b},
f_:function f_(a,b){this.a=a
this.b=!1
this.$ti=b},
k8:function k8(a){this.a=a},
k9:function k9(a){this.a=a},
kg:function kg(a){this.a=a},
cy:function cy(a,b){var _=this
_.a=a
_.e=_.d=_.c=_.b=null
_.$ti=b},
c2:function c2(a,b){this.a=a
this.$ti=b},
b9:function b9(a,b){this.a=a
this.b=b},
cu:function cu(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
ag:function ag(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
jN:function jN(a,b){this.a=a
this.b=b},
jR:function jR(a,b){this.a=a
this.b=b},
jQ:function jQ(a,b){this.a=a
this.b=b},
jP:function jP(a,b){this.a=a
this.b=b},
jO:function jO(a,b){this.a=a
this.b=b},
jU:function jU(a,b,c){this.a=a
this.b=b
this.c=c},
jV:function jV(a,b){this.a=a
this.b=b},
jW:function jW(a){this.a=a},
jT:function jT(a,b){this.a=a
this.b=b},
jS:function jS(a,b){this.a=a
this.b=b},
f0:function f0(a){this.a=a
this.b=null},
fl:function fl(a){this.$ti=a},
dX:function dX(){},
fh:function fh(){},
k2:function k2(a,b){this.a=a
this.b=b},
kf:function kf(a,b){this.a=a
this.b=b},
ir(a,b){return new A.bA(a.j("@<0>").A(b).j("bA<1,2>"))},
V(a,b,c){return b.j("@<0>").A(c).j("lZ<1,2>").a(A.q4(a,new A.bA(b.j("@<0>").A(c).j("bA<1,2>"))))},
m(a,b){return new A.bA(a.j("@<0>").A(b).j("bA<1,2>"))},
ex(a){return new A.bt(a.j("bt<0>"))},
L(a){return new A.bt(a.j("bt<0>"))},
ai(a,b){return b.j("m_<0>").a(A.q5(a,new A.bt(b.j("bt<0>"))))},
li(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
as(a,b,c){var s=new A.R(a,b,c.j("R<0>"))
s.c=a.e
return s},
ob(a,b,c){var s=A.ir(b,c)
a.X(0,new A.is(s,b,c))
return s},
X(a,b,c){var s=A.ir(b,c)
s.B(0,a)
return s},
cH(a,b){var s,r,q=A.ex(b)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.k)(a),++r)q.k(0,b.a(a[r]))
return q},
dp(a,b){var s=A.ex(b)
s.B(0,a)
return s},
l7(a){var s,r
if(A.lx(a))return"{...}"
s=new A.cS("")
try{r={}
B.a.k($.aW,a)
s.a+="{"
r.a=!0
a.X(0,new A.iv(r,s))
s.a+="}"}finally{if(0>=$.aW.length)return A.b($.aW,-1)
$.aW.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
bt:function bt(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
fb:function fb(a){this.a=a
this.c=this.b=null},
R:function R(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
is:function is(a,b,c){this.a=a
this.b=b
this.c=c},
H:function H(){},
a2:function a2(){},
iu:function iu(a){this.a=a},
iv:function iv(a,b){this.a=a
this.b=b},
bY:function bY(){},
dR:function dR(){},
pE(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.bN(r)
q=A.bc(String(s),null,null)
throw A.l(q)}q=A.kb(p)
return q},
kb(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.f7(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.kb(a[s])
return a},
oN(a,b,c,d,e,f,g,a0){var s,r,q,p,o,n,m,l,k,j,i=a0>>>2,h=3-(a0&3)
for(s=b.length,r=a.length,q=f.$flags|0,p=c,o=0;p<d;++p){if(!(p<s))return A.b(b,p)
n=b[p]
o|=n
i=(i<<8|n)&16777215;--h
if(h===0){m=g+1
l=i>>>18&63
if(!(l<r))return A.b(a,l)
q&2&&A.ab(f)
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
q&2&&A.ab(f)
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
q&2&&A.ab(f)
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
throw A.l(A.e2(b,"Not a byte value at index "+p+": 0x"+B.c.bE(b[p],16),null))},
oM(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i="Invalid encoding before padding",h="Invalid character",g=B.c.aW(a1,2),f=a1&3,e=$.nu()
for(s=a.length,r=e.length,q=d.$flags|0,p=b,o=0;p<c;++p){if(!(p<s))return A.b(a,p)
n=a.charCodeAt(p)
o|=n
m=n&127
if(!(m<r))return A.b(e,m)
l=e[m]
if(l>=0){g=(g<<6|l)&16777215
f=f+1&3
if(f===0){k=a0+1
q&2&&A.ab(d)
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
if(f===3){if((g&3)!==0)throw A.l(A.bc(i,a,p))
k=a0+1
q&2&&A.ab(d)
s=d.length
if(!(a0<s))return A.b(d,a0)
d[a0]=g>>>10
if(!(k<s))return A.b(d,k)
d[k]=g>>>2}else{if((g&15)!==0)throw A.l(A.bc(i,a,p))
q&2&&A.ab(d)
if(!(a0<d.length))return A.b(d,a0)
d[a0]=g>>>4}j=(3-f)*3
if(n===37)j+=2
return A.ml(a,p+1,c,-j-1)}throw A.l(A.bc(h,a,p))}if(o>=0&&o<=127)return(g<<2|f)>>>0
for(p=b;p<c;++p){if(!(p<s))return A.b(a,p)
if(a.charCodeAt(p)>127)break}throw A.l(A.bc(h,a,p))},
oK(a,b,c,d){var s=A.oL(a,b,c),r=(d&3)+(s-b),q=B.c.aW(r,2)*3,p=r&3
if(p!==0&&s<c)q+=p-1
if(q>0)return new Uint8Array(q)
return $.nt()},
oL(a,b,c){var s,r=a.length,q=c,p=q,o=0
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
ml(a,b,c,d){var s,r,q
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
if(b===c)break}if(b!==c)throw A.l(A.bc("Invalid padding character",a,b))
return-s-1},
lX(a,b,c){return new A.dn(a,b)},
pf(a){return a.n()},
oO(a,b){return new A.jY(a,[],A.pX())},
oP(a,b,c){var s,r=new A.cS(""),q=A.oO(r,b)
q.b7(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
f7:function f7(a,b){this.a=a
this.b=b
this.c=null},
f8:function f8(a){this.a=a},
d7:function d7(){},
fB:function fB(){},
jL:function jL(a){this.a=0
this.b=a},
fA:function fA(){},
jK:function jK(){this.a=0},
bQ:function bQ(){},
ea:function ea(){},
dn:function dn(a,b){this.a=a
this.b=b},
et:function et(a,b){this.a=a
this.b=b},
es:function es(){},
ip:function ip(a){this.b=a},
io:function io(a){this.a=a},
jZ:function jZ(){},
k_:function k_(a,b){this.a=a
this.b=b},
jY:function jY(a,b,c){this.c=a
this.a=b
this.b=c},
fv(a){var s=A.oj(a,null)
if(s!=null)return s
throw A.l(A.bc(a,null,null))},
o_(a,b){a=A.aa(a,new Error())
if(a==null)a=A.dZ(a)
a.stack=b.q(0)
throw a},
bd(a,b,c,d){var s,r=c?J.lV(a,d):J.lU(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
ey(a,b,c){var s,r=A.d([],c.j("o<0>"))
for(s=J.ac(a);s.l();)B.a.k(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
p(a,b){var s,r
if(Array.isArray(a))return A.d(a.slice(0),b.j("o<0>"))
s=A.d([],b.j("o<0>"))
for(r=J.ac(a);r.l();)B.a.k(s,r.gp())
return s},
ow(a){var s
A.cQ(0,"start")
s=A.ox(a,0,null)
return s},
ox(a,b,c){var s=a.length
if(b>=s)return""
return A.ok(a,b,s)},
oq(a){return new A.eq(a,A.oa(a,!1,!0,!1,!1,""))},
mg(a,b,c){var s=J.ac(b)
if(!s.l())return a
if(c.length===0){do a+=A.A(s.gp())
while(s.l())}else{a+=A.A(s.gp())
while(s.l())a=a+c+A.A(s.gp())}return a},
ou(){return A.cB(new Error())},
nQ(a,b,c,d,e,f,g,h,i){var s="microsecond",r=A.ol(a,b,c,d,e,f,g,h,i)
if(r==null)return null
if(h>999)A.bv(A.aR(h,0,999,s,null))
if(r<-864e13||r>864e13)A.bv(A.aR(r,-864e13,864e13,"millisecondsSinceEpoch",null))
if(r===864e13&&h!==0)A.bv(A.e2(h,s,"Time including microseconds is outside valid range"))
A.cz(i,"isUtc",t.y)
return new A.bw(r,h,i)},
nS(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.nh().dI(a)
if(c!=null){s=new A.hh()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.fv(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.fv(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.fv(q)
if(4>=r.length)return A.b(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.b(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.b(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.b(r,7)
j=new A.hi().$1(r[7])
i=B.c.bp(j,1000)
q=r.length
if(8>=q)return A.b(r,8)
h=r[8]!=null
if(h){if(9>=q)return A.b(r,9)
g=r[9]
if(g!=null){f=g==="-"?-1:1
if(10>=q)return A.b(r,10)
q=r[10]
q.toString
e=A.fv(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.nQ(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.l(A.bc("Time out of range",a,null))
return d}else throw A.l(A.bc("Invalid date format",a,null))},
lQ(a){var s,r
try{s=A.nS(a)
return s}catch(r){if(A.bN(r) instanceof A.df)return null
else throw r}},
lP(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
nR(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
hg(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
bx(a){if(a>=10)return""+a
return"0"+a},
af(a,b,c){var s,r,q
for(s=a.length,r=0;r<s;++r){q=a[r]
if(q.b===b)return q}throw A.l(A.e2(b,"name","No enum value with that name"))},
ee(a){if(typeof a=="number"||A.ln(a)||a==null)return J.d4(a)
if(typeof a=="string")return JSON.stringify(a)
return A.m8(a)},
o0(a,b){A.cz(a,"error",t.K)
A.cz(b,"stackTrace",t.l)
A.o_(a,b)},
e4(a){return new A.e3(a)},
d6(a,b){return new A.bk(!1,null,b,a)},
e2(a,b,c){return new A.bk(!0,a,b,c)},
nC(a,b,c){return a},
lb(a,b){return new A.dz(null,null,!0,a,b,"Value not in range")},
aR(a,b,c,d,e){return new A.dz(b,c,!0,a,d,"Invalid value")},
md(a,b,c){if(0>a||a>c)throw A.l(A.aR(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.l(A.aR(b,a,c,"end",null))
return b}return c},
cQ(a,b){if(a<0)throw A.l(A.aR(a,0,null,b,null))
return a},
ik(a,b,c,d){return new A.ej(b,!0,a,d,"Index out of range")},
bs(a){return new A.dI(a)},
mj(a){return new A.eW(a)},
ld(a){return new A.dF(a)},
am(a){return new A.e9(a)},
bc(a,b,c){return new A.df(a,b,c)},
o5(a,b,c){var s,r
if(A.lx(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.d([],t.s)
B.a.k($.aW,a)
try{A.pB(a,s)}finally{if(0>=$.aW.length)return A.b($.aW,-1)
$.aW.pop()}r=A.mg(b,t.e7.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
l4(a,b,c){var s,r
if(A.lx(a))return b+"..."+c
s=new A.cS(b)
B.a.k($.aW,a)
try{r=s
r.a=A.mg(r.a,a,", ")}finally{if(0>=$.aW.length)return A.b($.aW,-1)
$.aW.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
pB(a,b){var s,r,q,p,o,n,m,l=a.gt(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.l())return
s=A.A(l.gp())
B.a.k(b,s)
k+=s.length+2;++j}if(!l.l()){if(j<=5)return
if(0>=b.length)return A.b(b,-1)
r=b.pop()
if(0>=b.length)return A.b(b,-1)
q=b.pop()}else{p=l.gp();++j
if(!l.l()){if(j<=4){B.a.k(b,A.A(p))
return}r=A.A(p)
if(0>=b.length)return A.b(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.l();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2;--j}B.a.k(b,"...")
return}}q=A.A(p)
r=A.A(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.a.k(b,m)
B.a.k(b,q)
B.a.k(b,r)},
cM(a,b,c,d){var s
if(B.f===c){s=J.aK(a)
b=J.aK(b)
return A.jk(A.bG(A.bG($.fy(),s),b))}if(B.f===d){s=J.aK(a)
b=J.aK(b)
c=J.aK(c)
return A.jk(A.bG(A.bG(A.bG($.fy(),s),b),c))}s=J.aK(a)
b=J.aK(b)
c=J.aK(c)
d=J.aK(d)
d=A.jk(A.bG(A.bG(A.bG(A.bG($.fy(),s),b),c),d))
return d},
oe(a){var s,r,q=$.fy()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.k)(a),++r)q=A.bG(q,J.aK(a[r]))
return A.jk(q)},
bw:function bw(a,b,c){this.a=a
this.b=b
this.c=c},
hh:function hh(){},
hi:function hi(){},
cc:function cc(){},
f3:function f3(){},
Q:function Q(){},
e3:function e3(a){this.a=a},
bI:function bI(){},
bk:function bk(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dz:function dz(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
ej:function ej(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
dI:function dI(a){this.a=a},
eW:function eW(a){this.a=a},
dF:function dF(a){this.a=a},
e9:function e9(a){this.a=a},
eK:function eK(){},
dE:function dE(){},
jM:function jM(a){this.a=a},
df:function df(a,b,c){this.a=a
this.b=b
this.c=c},
h:function h(){},
aj:function aj(a,b,c){this.a=a
this.b=b
this.$ti=c},
ap:function ap(){},
K:function K(){},
fm:function fm(){},
cS:function cS(a){this.a=a},
ii:function ii(a){this.a=a},
ij:function ij(a){this.a=a},
nU(a){var s,r,q,p=t.P.a(a.h(0,"project")),o=A.x(a.h(0,"lang"))
if(o==null)o="en"
s=t.av
if(s.b(a.h(0,"strings"))){r=t.N
r=A.m(r,r)
for(s=s.a(a.h(0,"strings")).gaH(),s=s.gt(s);s.l();){q=s.gp()
r.i(0,A.A(q.a),A.A(q.b))}s=r}else s=null
r=A.Y(a.h(0,"sizeZones"))
q=A.Y(a.h(0,"sizeMain"))
return new A.hl(p,o,s,r!==!1,q!==!1)},
pD(){var s=new A.ag($.a6,t.cU)
s.bN(null)
return s},
kE(a,b){var s=null
return A.qp(a,b)},
qp(a,a0){var s=0,r=A.mL(t.r),q=1,p=[],o,n,m,l,k,j,i,h,g,f,e,d,c,b
var $async$kE=A.mQ(function(a1,a2){if(a1===1){p.push(a2)
s=q}for(;;)switch(s){case 0:c=null
q=3
o=A.nU(a)
n=A.om(o.a)
if(o.c!=null&&!$.kd.E(o.b)){g=o.b
f=o.c
f.toString
$.kd.i(0,g,new A.eu(f))}g=o.b
m=new A.ii(B.a.v(B.eP,g)?g:"en")
l=A.nV(n,new A.kF(m))
g=o.d
f=o.e
e=c
if(e==null)e=A.q0()
s=6
return A.mB(l.b0(new A.kG(a0),f,g,e),$async$kE)
case 6:k=a2
j=A.m(t.N,t.z)
J.l0(j,"type","done")
J.lC(j,new A.hm(k,n.e,n.r).n())
a0.$1(j)
q=1
s=5
break
case 3:q=2
b=p.pop()
i=A.bN(b)
h=A.cB(b)
a0.$1(A.V(["type","error","message",A.A(i),"stack",A.A(h)],t.N,t.z))
s=5
break
case 2:s=1
break
case 5:return A.mD(null,r)
case 1:return A.mC(p.at(-1),r)}})
return A.mE($async$kE,r)},
hl:function hl(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
hm:function hm(a,b,c){this.a=a
this.b=b
this.c=c},
hn:function hn(){},
kF:function kF(a){this.a=a},
kG:function kG(a){this.a=a},
nV(a,b){var s=Date.now(),r=t.N,q=A.d([],t.lT),p=A.d([],t.s),o=A.d([],t.o6),n=A.d([],t.p4),m=A.d([],t.cu),l=A.l9(a).bs()
return new A.ec(a,b,l,new A.eb(new A.bw(s,0,!1),A.m(r,t.kV),A.m(r,t.oY),q,p,o,n,m,A.L(r)),A.m(r,r),A.m(r,t.x))},
bl:function bl(a,b){this.a=a
this.b=b},
ca:function ca(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
ec:function ec(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=null},
hA:function hA(){},
hH:function hH(){},
hT:function hT(){},
hS:function hS(){},
hU:function hU(a,b,c){this.a=a
this.b=b
this.c=c},
hu:function hu(a){this.a=a},
hB:function hB(){},
hG:function hG(a){this.a=a},
hF:function hF(){},
hI:function hI(a){this.a=a},
hv:function hv(a){this.a=a},
hw:function hw(){},
hx:function hx(a){this.a=a},
hy:function hy(){},
hz:function hz(a){this.a=a},
hR:function hR(a){this.a=a},
hW:function hW(){},
hX:function hX(a,b,c){this.a=a
this.b=b
this.c=c},
hE:function hE(a){this.a=a},
hC:function hC(a,b,c,d,e,f,g,h,i,j){var _=this
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
hD:function hD(){},
i4:function i4(){},
i3:function i3(a,b,c){this.a=a
this.b=b
this.c=c},
i5:function i5(a){this.a=a},
i6:function i6(a){this.a=a},
i7:function i7(){},
i8:function i8(){},
hL:function hL(a,b,c){this.a=a
this.b=b
this.c=c},
hM:function hM(a,b){this.a=a
this.b=b},
hJ:function hJ(a){this.a=a},
hK:function hK(){},
hN:function hN(a,b,c){this.a=a
this.b=b
this.c=c},
hO:function hO(a,b){this.a=a
this.b=b},
hP:function hP(a,b){this.a=a
this.b=b},
hQ:function hQ(a){this.a=a},
hV:function hV(a,b){this.a=a
this.b=b},
i2:function i2(a){this.a=a},
hY:function hY(a){this.a=a},
hZ:function hZ(){},
i_:function i_(a){this.a=a},
i0:function i0(){},
i1:function i1(){},
mZ(a,b,c,d){var s,r=new A.ko()
if(c>0&&Math.abs(c-b)>0.5)s=A.A(r.$1(b))+" \xd7 "+A.A(r.$1(c))+" mm"
else s=b>0?A.A(r.$1(b))+" mm":""
return B.d.aJ(A.A(d.$1("fit."+a.b))+" "+s)},
qr(f5,f6,f7,f8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7=null,e8=f5.c,e9=t.N,f0=A.m(e9,t.kh),f1=new A.kR(f0),f2=new A.kT(e8,f7),f3=new A.kQ(),f4=A.m(e9,t.h)
for(s=f5.e,r=s.length,q=0;p=s.length,q<p;s.length===r||(0,A.k)(s),++q){o=s[q]
f4.i(0,o.a,o)}r=A.L(e9)
for(q=0;q<s.length;s.length===p||(0,A.k)(s),++q){o=s[q]
if(o instanceof A.al||o instanceof A.aB)r.k(0,o.a)}for(p=f6.a,n=A.i(p).j("O<2>"),m=new A.O(p,p.r,p.e,n),l=t.n,k=t.C;m.l();){j=m.d
i=j.w
h=A.t(i)
g=h.j("v(1)")
h=h.j("C<1>")
f=h.j("h.E")
e=A.p(new A.C(i,g.a(new A.kI(f2)),h),f)
d=A.t(e)
c=d.j("v(1)")
d=d.j("C<1>")
b=d.j("h.E")
a=A.p(new A.C(e,c.a(new A.kJ(r)),d),b)
a0=A.p(new A.C(e,c.a(new A.kK(r)),d),b)
for(d=j.r,c=A.i(d),b=new A.R(d,d.r,c.j("R<1>")),b.c=d.e,c=c.c,a1=e7,a2=a1,a3=a2,a4=a3;b.l();){d=b.d
o=f4.h(0,d==null?c.a(d):d)
if(o instanceof A.ba){a4=o
continue}if(o instanceof A.b_||o instanceof A.bq){a3=o
continue}if(o instanceof A.aC){a2=o
continue}if(o instanceof A.b0){a1=o
continue}continue}a5=A.p(new A.C(i,g.a(new A.kL()),h),f)
i=a5.length
if(i!==0)h=a4!=null||a3!=null
else h=!1
if(h)for(h=a3 instanceof A.b_,g=a4!=null,f=j.a,d=A.t(a),c=d.j("e(1)"),d=d.j("u<1,e>"),q=0;q<a5.length;a5.length===i||(0,A.k)(a5),++q){if(a5[q].b!==f)continue
if(g){b=e8.a3(a4.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}else a6=0
if(h){b=e8.a3(a3.e)
a6=b==null?e7:b.f
if(a6==null)a6=0}if(a.length!==0)a7=new A.u(a,c.a(f2),d).L(0,B.q)
else a7=a0.length!==0?f2.$1(B.a.gu(a0)):0
if(a6<=0)a6=a7
b=a6>0
if(b)f1.$3$qty(B.am,a6,2)
if(a7>0&&b&&Math.abs(a7-a6)>0.5)f1.$4$qty$size2(B.v,Math.max(a7,a6),2,Math.min(a7,a6))}if(a.length===0)continue
i=A.t(a)
h=i.j("u<1,e>")
a8=A.p(new A.u(a,i.j("e(1)").a(f2),h),h.j("w.E"))
a9=B.a.L(a8,B.q)
b0=a.length
b1=a4!=null||a3!=null||a2!=null||a1!=null
if(b0===1){if(!b1&&a0.length===0&&a5.length===0)f1.$2(B.K,B.a.gu(a8))
if(a1!=null){b2=e8.a_(a1.f)
if(b2!=null)f1.$2(B.m,b2.w)}continue}if(b0===2){if(0>=b0)return A.b(a,0)
b3=a[0]
if(1>=b0)return A.b(a,1)
b4=a[1]
j=j.a
b5=f3.$2(b3,j)
b6=f3.$2(b4,j)
j=b5.a
i=b5.b
b7=Math.acos(B.b.a1(-j*b6.a+-i*b6.b,-1,1))*180/3.141592653589793
b8=f2.$1(b3)
b9=f2.$1(b4)
c0=Math.abs(b8-b9)>0.5
if(b7>60)f1.$2(B.aj,a9)
else if(b7>15)f1.$2(B.ak,a9)
else if(b3.f!==b4.f&&!c0&&a5.length===0)f1.$2(B.V,a9)
if(c0)f1.$3$size2(B.v,Math.max(b8,b9),Math.min(b8,b9))
if(a1!=null){b2=e8.a_(a1.f)
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
if(b2<i)f1.$3$size2(B.v,a9,b2)}}c8=A.m(e9,t.cr)
for(f4=new A.O(p,p.r,p.e,n);f4.l();){p=f4.d
n=p.b
c8.i(0,B.b.ae(n.a,3)+"|"+B.b.ae(n.b,3)+"|"+p.d.b,p)}c9=new A.kS(c8)
d0=new A.kO(r)
for(f4=s.length,r=f6.z,p=f5.b.ok,n=p>0,m=f6.b,l=A.t(m),k=l.j("v(1)"),l=l.j("C<1>"),j=l.j("h.E"),q=0;q<s.length;s.length===f4||(0,A.k)(s),++q){o=s[q]
if(r.v(0,o.a))continue
A:{i={}
i.a=null
h=o instanceof A.al
if(h)i.a=o
if(h){d1=new A.C(m,k.a(new A.kM(i)),l)
if(!d1.gt(0).l())break A
d2=d1.gt(0)
if(!d2.l())A.bv(A.av())
h=d2.gp().x
h=e8.N(h==null?i.a.e:h)
d3=h==null?e7:h.e
if(d3==null)d3=16
d4=d0.$2(c9.$2(J.bP(i.a.d),B.h),i.a.a)
d5=d0.$2(c9.$2(J.l1(i.a.d),B.h),i.a.a)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.K,d3)
if(!d5)f1.$2(B.K,d3)
a1=e8.a_(i.a.r)
if(a1!=null&&i.a.gb5()>0)f1.$3$qty(B.m,a1.w,i.a.gb5())
break A}i=o instanceof A.aB
d6=i?o:e7
if(i){d7=e8.ad(d6.e)
d3=d7==null?e7:d7.e
if(d3==null)d3=16
i=d6.d
h=J.a1(i)
g=c9.$2(h.gu(i),B.h)
f=d6.a
d4=d0.$2(g,f)
d5=d0.$2(c9.$2(h.gM(i),B.h),f)
if(d4)f1.$2(B.w,d3)
if(d5)f1.$2(B.w,d3)
if(!d4)f1.$2(B.L,d3)
if(!d5)f1.$2(B.L,d3)
break A}i={}
i.a=null
h=o instanceof A.aH
if(h)i.a=o
if(h){if(n){d1=A.p(new A.C(m,k.a(new A.kN(i)),l),j)
if(d1.length===0)break A
h=f7.$1(B.a.gu(d1))
d3=h==null?e7:h.e
if(d3==null)d3=0
d8=B.b.J(A.aX(i.a.d)/p)
if(d3>0&&d8>0)f1.$3$qty(B.V,d3,d8)}break A}break A}}d9=A.m(e9,t.q)
e0=A.d([],t.e0)
e1=new A.kH()
for(e9=new A.O(f0,f0.r,f0.e,f0.$ti.j("O<2>"));e9.l();){f4=e9.d
d8=f4.a
e2=f4.b
f4=d8.a
s=d8.b
r=d8.c
e3=e8.dH(f4,s,r)
if(e3==null){B.a.k(e0,d8)
e4=A.mZ(f4,s,r,f8)+" *"
e5="generic|"+e4
e6=d9.h(0,e5)
if(e6!=null)e6.d+=e2
else d9.i(0,e5,new A.ad(e1.$1(f4),e4,"un",e2,0,e7,"",""))
continue}s=e3.a
e6=d9.h(0,s)
if(e6!=null)e6.d+=e2
else d9.i(0,s,new A.ad(e1.$1(f4),e3.b,"un",e2,e3.w,s,e3.d,e3.c))}for(e9=d9.$ti,f4=new A.O(d9,d9.r,d9.e,e9.j("O<2>"));f4.l();){s=f4.d
s.d=Math.ceil(s.d)}e9=e9.j("ao<2>")
e9=A.p(new A.ao(d9,e9),e9.j("h.E"))
return new A.ie(e9,e0)},
de:function de(a,b,c){this.a=a
this.b=b
this.c=c},
ie:function ie(a,b){this.a=a
this.b=b},
ko:function ko(){},
kR:function kR(a){this.a=a},
kT:function kT(a,b){this.a=a
this.b=b},
kQ:function kQ(){},
kI:function kI(a){this.a=a},
kJ:function kJ(a){this.a=a},
kK:function kK(a){this.a=a},
kL:function kL(){},
kS:function kS(a){this.a=a},
kO:function kO(a){this.a=a},
kP:function kP(a,b){this.a=a
this.b=b},
kM:function kM(a){this.a=a},
kN:function kN(a){this.a=a},
kH:function kH(){},
qs(c2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7={},b8=c2.b,b9=b8.length,c0=c2.c,c1=c0.length
if(b9===0)return new A.cI(B.N,B.bk,0,0)
s=A.d([],t.ot)
r=A.d([],t.n)
for(q=c0.length,p=0,o=0,n=0;n<c0.length;c0.length===q||(0,A.k)(c0),++n){m=c0[n]
l=m.b
k=m.c
if(k<0){k=-k
switch(l.a){case 0:j=B.bo
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
f=J.en(c1,t.kI)
for(e=0;e<c1;++e)f[e]=new Float64Array(g)
q=t.S
d=A.bd(c1,-1,!1,q)
c=A.d([],t.X)
for(b=i,a=b9,a0=0;a0<c1;++a0){if(!(a0<c0.length))return A.b(c0,a0)
m=c0[a0]
a1=m.c<0?-1:1
if(!(a0<f.length))return A.b(f,a0)
a2=f[a0]
m.a.X(0,new A.kU(b9,a2,a1))
if(!(a0<r.length))return A.b(r,a0)
j=r[a0]
a2.$flags&2&&A.ab(a2)
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
a6=new A.kV(f,g,c1,d)
a7=new A.kX(b7,new A.kW(g,h,c1,d,f),50*(c1+h)+1000,1e-9,h,c1,f,d,a6)
c0=c.length
if(c0!==0){a8=new Float64Array(g)
for(n=0;n<c0;++n){a9=c[n]
if(!(a9<g))return A.b(a8,a9)
a8[a9]=1}b0=a7.$2(a8,B.DD)
if(b0===B.bp)return new A.cI(b0,A.bd(b9,0,!1,t.i),0,b7.a)
for(b1=0,a0=0;a0<c1;++a0)if(B.a.v(c,d[a0])){if(!(a0<f.length))return A.b(f,a0)
c0=f[a0]
if(!(h<c0.length))return A.b(c0,h)
b1+=c0[h]}if(b1>0.000001)return new A.cI(B.f3,A.bd(b9,0,!1,t.i),0,b7.a)
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
b4[b3]=j}b0=a7.$2(b4,A.cH(c,q))
b5=A.bd(b9,0,!1,t.i)
for(a0=0;a0<c1;++a0){c0=d[a0]
if(c0<b9){if(!(a0<f.length))return A.b(f,a0)
q=f[a0]
if(!(h<q.length))return A.b(q,h)
B.a.i(b5,c0,q[h])}}for(c0=b8.length,b6=0,b3=0;b3<b9;++b3){if(!(b3<c0))return A.b(b8,b3)
b6+=b8[b3]*b5[b3]}b8=b0===B.N?B.N:b0
return new A.cI(b8,b5,b6,b7.a)},
cm:function cm(a,b){this.a=a
this.b=b},
cl:function cl(a,b,c){this.a=a
this.b=b
this.c=c},
it:function it(a,b,c){this.b=a
this.c=b
this.d=c},
cI:function cI(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bB:function bB(a,b){this.a=a
this.b=b},
kU:function kU(a,b,c){this.a=a
this.b=b
this.c=c},
kW:function kW(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
kV:function kV(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kX:function kX(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
n3(b9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3=t.N,b4=A.m(b3,t.dV),b5=t.n,b6=A.d([],b5),b7=A.d([],t.cH),b8=A.d([],t.s)
for(s=b9.a,r=s.length,q=b9.w,p=b9.x,o=b9.r,n=t.S,m=b9.c,l=b9.b,k=0;k<s.length;s.length===r||(0,A.k)(s),++k){j=s[k]
i=l.h(0,j)
if(i==null)i=B.bn
h=m.h(0,j)
if(h==null)h=0
g=A.m(b3,n)
for(f=i.length,e=j+":",d=0;d<i.length;i.length===f||(0,A.k)(i),++d){c=i[d]
b=p.$1(c)
if(b==null)b=c.Q
if(typeof b!=="number")return b.af()
a=q?o:1
a0=c.a
B.a.k(b6,b*h*a)
B.a.k(b8,e+a0)
g.i(0,a0,b6.length-1)}b4.i(0,j,g)}a1=A.m(n,n)
for(r=b9.e,p=t.i,o=t.jq,a2=0;a2<r.length;++a2){a3=r[a2]
if(a3.b!=null)continue
a4=a3.a
a4=a4>0?a4:0.001
B.a.k(b6,q?a4:Math.max(a4,0.001))
B.a.k(b8,"H"+a3.d)
a1.i(0,a2,b6.length-1)
m=a3.c
if(m!=null&&m>0){f=a1.h(0,a2)
f.toString
B.a.k(b7,new A.cl(o.a(A.V([f,1],n,p)),B.a_,m))}}for(q=s.length,k=0;k<s.length;s.length===q||(0,A.k)(s),++k){g=b4.h(0,s[k])
if(g.a===0)continue
m=A.m(n,p)
for(f=new A.O(g,g.r,g.e,A.i(g).j("O<2>"));f.l();)m.i(0,f.d,1)
B.a.k(b7,new A.cl(o.a(m),B.ap,1))}for(q=b9.f,m=q.length,k=0;k<q.length;q.length===m||(0,A.k)(q),++k){a5=q[k]
a6=A.m(n,p)
f=a5.a
if(!(f<r.length))return A.b(r,f)
e=r[f].b
if(e!=null)a7=0+e
else{f=a1.h(0,f)
f.toString
a6.i(0,f,1)
a7=0}a5.b.X(0,new A.ky(b4,a6))
if(a6.a===0)continue
f=a5.d
if(f!=null){e=A.ir(n,p)
e.B(0,a6)
B.a.k(b7,new A.cl(o.a(e),B.bo,f+a5.c-a7))}f=a5.e
if(f!=null&&isFinite(f)){e=A.ir(n,p)
e.B(0,a6)
B.a.k(b7,new A.cl(o.a(e),B.a_,f+a5.c-a7))}}if(b6.length===0){b3=A.d([],b5)
for(b5=r.length,k=0;k<r.length;r.length===b5||(0,A.k)(r),++k){b6=r[k].b
b3.push(b6==null?0:b6)}return new A.dq(!0,B.br)}a8=A.qs(new A.it(b6,b7,b8))
if(a8.a!==B.N)return new A.dq(!1,B.br)
a9=A.m(b3,t.x)
for(b3=s.length,b6=b9.d,b7=a8.b,b8=b7.length,q=t.an,k=0;k<s.length;s.length===b3||(0,A.k)(s),++k){j=s[k]
p=b4.h(0,j)
p.toString
i=l.h(0,j)
if(i==null)i=B.bn
if(p.a===0)continue
b0=A.d([],q)
for(o=i.length,d=0;d<i.length;i.length===o||(0,A.k)(i),++d){c=i[d]
n=p.h(0,c.a)
n.toString
if(!(n>=0&&n<b8))return A.b(b7,n)
b1=b7[n]
if(b1>0.02)B.a.k(b0,new A.n(c,b1))}if(b0.length===0)B.a.k(b0,new A.n(B.a.gM(i),1))
B.a.ao(b0,new A.kz())
p=b6.h(0,j)
a9.i(0,j,A.qo(b0,p==null?1:p))}b2=A.d([],b5)
for(a2=0;a2<r.length;++a2){b3=r[a2].b
if(b3==null){b3=a1.h(0,a2)
b3.toString
if(!(b3>=0&&b3<b8))return A.b(b7,b3)
b3=b7[b3]}B.a.k(b2,b3)}return new A.dq(!0,a9)},
qo(a,b){var s,r,q,p,o,n,m=Math.max(1,b)
if(a.length<=m)return A.mM(a)
s=A.t(a).c
r=A.c_(a,0,A.cz(m,"count",t.S),s).cB(0)
for(s=A.c_(a,m,null,s),q=s.$ti,s=new A.aO(s,s.gm(0),q.j("aO<w.E>")),q=q.j("w.E"),p=0;s.l();){o=s.d
p+=(o==null?q.a(o):o).b}n=B.a.gM(r)
B.a.i(r,r.length-1,new A.n(n.a,n.b+p))
return A.mM(r)},
mM(a){var s,r,q,p,o=B.a.W(a,0,new A.kc(),t.i)
if(o<=0)return a
s=A.d([],t.an)
for(r=a.length,q=0;q<a.length;a.length===r||(0,A.k)(a),++q){p=a[q]
s.push(new A.n(p.a,p.b/o))}return s},
ds:function ds(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dr:function dr(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
ez:function ez(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
dq:function dq(a,b){this.a=a
this.b=b},
ky:function ky(a,b){this.a=a
this.b=b},
kx:function kx(a,b){this.a=a
this.b=b},
kz:function kz(){},
kc:function kc(){},
l3(a,b,c,d){return new A.aZ(b,c,a,d,A.d([],t.hz),A.L(t.N),A.d([],t.I))},
lT(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return new A.I(h,g,s,i,n,f,o,j,l,r,c,a0,k,d,p,a1,m,q,a,b,e)},
l9(a){var s=t.N,r=t.Q
return new A.iw(a,new A.iJ(A.m(s,t.cr),A.d([],t.I),A.m(s,t.kM),A.m(s,s),A.m(s,s),A.m(s,r),A.m(s,r),A.L(s),A.L(s),A.d([],t.s),A.L(s)),A.m(t.S,t.g2))},
bU:function bU(a,b){this.a=a
this.b=b},
bb:function bb(a,b,c,d,e,f,g,h,i,j){var _=this
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
aZ:function aZ(a,b,c,d,e,f,g){var _=this
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
iJ:function iJ(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
iw:function iw(a,b,c){var _=this
_.a=a
_.d=_.c=_.b=$
_.e=b
_.f=c
_.r=0},
iy:function iy(){},
iz:function iz(){},
iF:function iF(){},
iH:function iH(){},
iG:function iG(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
iA:function iA(a,b,c){this.a=a
this.b=b
this.c=c},
iB:function iB(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
iC:function iC(a){this.a=a},
iD:function iD(){},
iE:function iE(a){this.a=a},
iI:function iI(a){this.a=a},
ix:function ix(){},
ll(a,b){var s=a.f/1000
if(b<=0||s<=0)return 0
switch(a.x.a){case 0:return A.n1(a.r,s,b,1)
case 1:return A.mX(s,b,a.y,1,a.w/1000)}},
km(a,b){var s,r=a.gbH(),q=a.c+a.ax
if(r<=0||q<=0)return 0
s=B.b.a1(b/q,0,1)
return a.a===B.E?r*(1-s*s):r*(1-s)},
kn(a,b){var s,r,q,p,o,n,m
if(b<=0)return 0
s=Math.max(4,200)
r=b/s
for(q=a.as,p=0,o=0;o<s;){n=o*r;++o
m=o*r
p+=(A.ll(a,A.km(a,n)+q)+4*A.ll(a,A.km(a,(n+m)/2)+q)+A.ll(a,A.km(a,m)+q))/6*r}return p},
pR(c9,d0,d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8=A.d([],t.s),b9=d0==null?new A.kh():d0,c0=c9.gbH(),c1=c9.as,c2=c0+c1,c3=c9.c,c4=A.kn(c9,c3),c5=b9.$1(c3),c6=c9.Q,c7=c1>0?c9.at:0,c8=Math.max(c6,c7)
c7=c9.z
s=c9.cx
r=c8+c4+c5+c7+s
q=A.d([],t.i5)
p=c9.gcC()
o=A.d([0],t.n)
for(n=c9.e,m=1;m<=p;++m)o.push(m*n)
if(c3-c9.gcC()*n>0.000001)o.push(c3)
for(l=o.length,k=0;j=o.length,k<j;o.length===l||(0,A.k)(o),++k){i=o[k]
j=A.kn(c9,i)
h=b9.$1(i)
if(typeof h!=="number")return A.bu(h)
g=c6+j+h+c7+s
if(g>r)r=g}for(l=r-c7-s,f=0,k=0;k<o.length;o.length===j||(0,A.k)(o),++k,f=d){i=o[k]
h=A.kn(c9,i)
e=b9.$1(i)
if(typeof e!=="number")return A.bu(e)
d=f+1
B.a.k(q,new A.co(f,i,A.km(c9,i)+c1,l-h-e,b9.$1(i)))}c=c9.f/1000
b=c>0?A.fw(c,c2):0
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
a8=A.kn(c9,b1)
b2=b9.$1(b1)
if(typeof b2!=="number")return A.bu(b2)
b3=l-a8-b2
b4=b0/a9
a8=d3.length
b5=""
if(a8!==0&&b4>0)for(b6=1/0,k=0;k<d3.length;d3.length===a8||(0,A.k)(d3),++k){b2=d3[k]
b7=b2.a
c=Math.abs(b2.b.a7(Math.max(b3,0.1))-b4)
if(c<b6){b6=c
b5=b7}}++m
B.a.k(a3,new A.bC(m,a5,a7,a9,b4,b3,b5))}}return new A.cN(d1,a3,d2,o,c2,c1,r,c4,c5,c8,c7,s,p,q,c9.gcm(),c9.ay,c9.ch,a1,a2,b,b8)},
qa(a,b,c,d){return new A.ks(A.m(t.S,t.i),a,72,c,d,b,d.$1(b))},
cn:function cn(a,b){this.a=a
this.b=b},
iW:function iW(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2){var _=this
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
co:function co(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
bC:function bC(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cN:function cN(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){var _=this
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
iT:function iT(){},
iU:function iU(){},
iV:function iV(){},
kh:function kh(){},
ks:function ks(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
lg(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){return new A.cU(a0,a4,d,q,f,a1,p,j,i,b,a,k,r,o,l,e,a3,s,a2,g,n,c,m,h)},
bg:function bg(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
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
bS:function bS(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
cU:function cU(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4){var _=this
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
jC:function jC(){},
jB:function jB(){},
jD:function jD(){},
jE:function jE(){},
jF:function jF(){},
cq:function cq(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
aT:function aT(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b6:function b6(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
jg:function jg(){},
jh:function jh(){},
ji:function ji(){},
jj:function jj(){},
ad:function ad(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
ce:function ce(a,b,c,d,e,f,g,h,i,j){var _=this
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
bF:function bF(a,b,c,d,e,f,g,h,i,j){var _=this
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
eb:function eb(a,b,c,d,e,f,g,h,i){var _=this
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
ho:function ho(){},
hp:function hp(){},
hq:function hq(){},
hr:function hr(){},
hs:function hs(){},
ht:function ht(){},
lS(a){var s,r=A.at(a.h(0,"k")),q=A.at(a.h(0,"x")),p=A.y(a.h(0,"ra"))
if(p==null)p=null
if(p==null)p=0
s=A.y(a.h(0,"rb"))
if(s==null)s=null
return new A.bT(r,q,p,s==null?0:s)},
n0(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(a<=0||b<=0||c<=0)return 0
s=A.d([],t.n)
for(r=0;r<24;++r)for(q=(r+0.5)/24*b,p=0;p<24;++p){o=(p+0.5)/24*c
for(n=0,m=-2;m<=3;++m)for(l=m*b,k=-2;k<=3;++k){j=q-l
i=o-k*c
h=Math.sqrt(j*j+i*i)
if(h<a)n+=1-h/a}B.a.k(s,n)}g=B.a.L(s,new A.kq())/s.length
if(g<=0)return 0
return 100*(1-B.a.W(s,0,new A.kr(g),t.i)/s.length/g)},
bT:function bT(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kq:function kq(){},
kr:function kr(a){this.a=a},
n1(a,b,c,d){var s
if(c===0||d===0)return 0
s=10.67*d*Math.pow(Math.abs(c),1.852)/(Math.pow(a,1.852)*Math.pow(b,4.871))
return c<0?-s:s},
fw(a,b){return b/(3.141592653589793*a*a/4)},
mW(a,b){var s,r,q,p,o,n
if(b<=0)return 0
if(b<2000)return 64/b
if(b<4000){s=a/3.7+5.74/Math.pow(4000,0.9)
r=-0.8685889638065035*Math.log(s)
q=Math.pow(r,-2)
p=q*(2-0.00514215/(s*r))
o=b/2000
return 7*q-p+o*(0.128-17*q+2.5*p+o*(-0.128+13*q-2*p+o*(0.032-3*q+0.5*p)))}n=Math.log(a/3.7+5.74/Math.pow(b,0.9))/2.302585092994046
return 0.25/(n*n)},
mX(a,b,c,d,e){var s,r
if(b===0||d===0)return 0
s=A.fw(a,Math.abs(b))
r=A.mW(e/a,s*a/c)*(d/a)*s*s/19.6133
return b<0?-r:r},
mY(a,b,c,d,e,f,g){switch(f.a){case 0:return A.n1(a,b,c,e)
case 1:return A.mX(b,c,d,e,g)}},
cf:function cf(a,b){this.a=a
this.b=b},
n6(a,b,c){var s=A.fw(a,Math.abs(b)),r=c*s*s/19.6133
return b<0?-r:r},
qm(a,b){var s=3.141592653589793*a*a/4
return b/(19.6133*s*s)},
aF:function aF(a,b,c){this.a=a
this.b=b
this.c=c},
ef(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.dg(f,d,n,g,c,h,e,l,i,a,k,b,j,B.n)},
m0(a,b){return new A.iK(b,a)},
dh:function dh(a,b){this.a=a
this.b=b},
bo:function bo(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=d
_.f=e
_.r=f
_.w=g},
bV:function bV(a,b){this.a=a
this.b=b},
cG:function cG(a,b){this.a=a
this.b=b},
dg:function dg(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
iK:function iK(a,b){this.a=a
this.b=b},
eJ:function eJ(a,b){this.a=a
this.b=b},
ew:function ew(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.e=d},
cL:function cL(a,b,c){this.a=a
this.c=b
this.d=c},
eh:function eh(a,b,c){this.a=a
this.b=b
this.c=c},
ih:function ih(){},
mc(a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.t(a4),a2=a1.j("C<1>"),a3=A.p(new A.C(a4,a1.j("v(1)").a(new A.j5()),a2),a2.j("h.E"))
a1=a3.length
if(a1===0)return B.fj
if(a1===1){s=B.a.gu(a3)
r=s.a
q=s.b
return A.mc(A.d([new A.n(0,1.33*q),new A.n(r,q),new A.n(2*r,0)],t.fU))}if(a1===2){if(0>=a1)return A.b(a3,0)
p=a3[0]
o=p.a
n=p.b
if(1>=a1)return A.b(a3,1)
m=a3[1]
l=(m.b-n)/(m.a-o)
return new A.cP(0,l,n-l*o,1)}for(k=0,j=0,i=0,h=0,g=0,f=0,a2=0,e=0;e<a1;++e){d=a3[e]
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
a0=A.on(A.d([A.d([h,i,j,a2],d),A.d([i,j,k,f],d),A.d([j,k,a1,g],d)],t.iA))
d=a0.length
if(0>=d)return A.b(a0,0)
g=a0[0]
if(1>=d)return A.b(a0,1)
a1=a0[1]
if(2>=d)return A.b(a0,2)
return new A.cP(g,a1,a0[2],1)},
on(a){var s,r,q,p,o,n,m,l,k,j
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
fs(a,b){var s
if(b<=0)return 1
if(a<=0)return 1/b
s=Math.pow(1+a,b)
return a*s/(s-1)},
mS(a,b,c,d,e){return 9788.99803*b*c/Math.max(e,0.05)/1000*d*a},
cP:function cP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
j6:function j6(){},
j5:function j5(){},
os(a){var s,r,q,p=J.en(a,t.jq)
for(s=t.S,r=t.i,q=0;q<a;++q)p[q]=A.m(s,r)
return new A.ja(a,p,A.bd(a,0,!1,r))},
ja:function ja(a,b,c){this.a=a
this.b=b
this.c=c},
jb:function jb(){},
jc:function jc(){},
jd:function jd(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
je:function je(a,b,c){this.a=a
this.b=b
this.c=c},
jf:function jf(){},
oE(a,b,c){var s,r,q,p,o,n,m,l,k,j,i=A.t(a),h=i.j("C<1>"),g=A.p(new A.C(a,i.j("v(1)").a(new A.jw()),h),h.j("h.E"))
i=g.length
if(i===0)return B.cR
s=B.a.L(g,new A.jx())/i
h=t.i
r=A.ey(g,!0,h)
B.a.a0(r)
q=B.a.gu(r)
p=B.a.gM(r)
if(s<=0)return new A.dH(i,s,q,p,0,0,0,0,0,0)
o=B.a.W(g,0,new A.jy(s),h)
n=Math.max(1,B.b.aq(i/4))
m=A.c_(r,0,A.cz(n,"count",t.S),A.t(r).c).L(0,new A.jz())/n
h=B.a.W(g,0,new A.jA(s),h)
l=Math.sqrt(h/(i>1?i-1:1))/s
h=Math.sqrt(Math.max(1,b))
k=Math.sqrt(l*l+c*c)
j=p>0?100*(p-q)/p:0
return new A.dH(i,s,q,p,100*(1-o/i/s),100*m/s,100*(1-1.27*c/h)*(m/s),100*(1-k),j,l)},
dH:function dH(a,b,c,d,e,f,g,h,i,j){var _=this
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
jw:function jw(){},
jx:function jx(){},
jy:function jy(a){this.a=a},
jz:function jz(){},
jA:function jA(a){this.a=a},
b1:function b1(a,b,c){this.c=a
this.a=b
this.b=c},
n8(a,b){return $.kd.h(0,a)==null?null:B.aq.h(0,b)},
eu:function eu(a){this.a=a},
ig:function ig(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aq(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.J(e,h,l,a,i,f,g,d,k,j,n,b,m,c)},
oh(a){var s,r,q,p,o,n,m,l,k,j,i,h=null,g=A.D(a.h(0,"id")),f=A.D(a.h(0,"name")),e=A.x(a.h(0,"sup"))
if(e==null)e=""
s=A.x(a.h(0,"code"))
if(s==null)s=""
r=A.at(a.h(0,"nominalMm"))
q=A.at(a.h(0,"idMm"))
p=A.x(a.h(0,"material"))
if(p==null)p="pvc"
p=A.af(B.eJ,p,t.f7)
o=A.y(a.h(0,"c"))
if(o==null)o=h
if(o==null)o=150
n=A.y(a.h(0,"roughMm"))
if(n==null)n=h
if(n==null)n=0.0015
m=A.y(a.h(0,"ratingM"))
if(m==null)m=h
if(m==null)m=60
l=A.y(a.h(0,"wallMm"))
if(l==null)l=h
if(l==null)l=2
k=A.y(a.h(0,"cost"))
if(k==null)k=h
if(k==null)k=0
j=t.O.a(a.h(0,"usage"))
if(j==null)j=["zone","mainline"]
j=J.aE(j,new A.iR(),t.W).au(0)
i=A.Y(a.h(0,"enabled"))
return A.aq(s,k,i!==!1,o,g,q,p,f,r,m,n,e,j,l)},
of(a){var s,r,q,p,o,n,m,l=A.D(a.h(0,"id")),k=A.D(a.h(0,"name")),j=A.x(a.h(0,"sup"))
if(j==null)j=""
s=A.x(a.h(0,"code"))
if(s==null)s=""
r=A.af(B.eH,A.D(a.h(0,"kind")),t.hF)
q=J.aE(t.j.a(a.h(0,"nozzles")),new A.iM(),t.mP)
q=A.p(q,q.$ti.j("w.E"))
p=A.y(a.h(0,"cost"))
if(p==null)p=null
if(p==null)p=0
o=A.y(a.h(0,"inletMm"))
if(o==null)o=null
if(o==null)o=20
n=A.y(a.h(0,"riser"))
if(n==null)n=null
if(n==null)n=0
m=A.Y(a.h(0,"enabled"))
return new A.a3(l,k,j,s,r,q,p,o,n,m!==!1)},
cT(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){return new A.aS(j,n,r,b,o,k,g,f,a,d,m,l,e,a0,s,p,q,i,c,h)},
ak(a,b,c,d,e,f,g,h,i,j,k,l){return new A.aQ(e,h,l,a,j,k,i,A.mc(i),c,g,f,b,d)},
oo(a){var s,r,q,p,o,n,m,l,k,j,i=null,h=A.D(a.h(0,"id")),g=A.Y(a.h(0,"sub"))
if(g==null)g=B.DC.v(0,a.h(0,"id"))
s=A.D(a.h(0,"name"))
r=A.x(a.h(0,"sup"))
if(r==null)r=""
q=A.x(a.h(0,"code"))
if(q==null)q=""
p=A.y(a.h(0,"kw"))
if(p==null)p=i
if(p==null)p=0
o=J.aE(t.j.a(a.h(0,"points")),new A.j7(),t.aL)
o=A.p(o,o.$ti.j("w.E"))
n=A.y(a.h(0,"eff"))
if(n==null)n=i
if(n==null)n=0.7
m=A.y(a.h(0,"minQ"))
if(m==null)m=i
if(m==null)m=0
l=A.y(a.h(0,"maxQ"))
if(l==null)l=i
if(l==null)l=1
k=A.y(a.h(0,"cost"))
if(k==null)k=i
if(k==null)k=0
j=A.Y(a.h(0,"enabled"))
return A.ak(q,k,n,j!==!1,h,l,m,s,o,p,g,r)},
lL(a,b,c,d,e,f){return new A.fC(c,b,e,f,d,a)},
nK(a){var s,r,q,p,o=t.O,n=o.a(a.h(0,"pipes"))
if(n==null)n=[]
n=J.aE(n,new A.fM(),t.p)
n=A.p(n,n.$ti.j("w.E"))
s=o.a(a.h(0,"outlets"))
if(s==null)s=[]
s=J.aE(s,new A.fN(),t.fa)
s=A.p(s,s.$ti.j("w.E"))
r=o.a(a.h(0,"tapes"))
if(r==null)r=[]
r=J.aE(r,new A.fO(),t.gs)
r=A.p(r,r.$ti.j("w.E"))
q=o.a(a.h(0,"valves"))
if(q==null)q=[]
q=J.aE(q,new A.fP(),t.e4)
q=A.p(q,q.$ti.j("w.E"))
p=o.a(a.h(0,"pumps"))
if(p==null)p=[]
p=J.aE(p,new A.fQ(),t.dz)
p=A.p(p,p.$ti.j("w.E"))
o=o.a(a.h(0,"fittings"))
if(o==null)o=[]
o=J.aE(o,new A.fR(),t.kN)
o=A.p(o,o.$ti.j("w.E"))
return A.lL(o,s,n,p,r,q)},
nI(){var s=A.nG("en"),r=A.q3("BRL","BRL")
if(r!=null)A.qq(s,r)
return s},
nG(a7){var s,r,q,p,o,n,m,l,k,j="Microaspersor 360\xb0",i="Microaspersor PC",h='Aspersor de impacto 3/4"',g=1500,f='V\xe1lvula hidr\xe1ulica 3"',e='V\xe1lvula hidr\xe1ulica 4"',d='V\xe1lvula hidr\xe1ulica 6"',c='Filtro de discos 2" (120 mesh)',b='Filtro de discos 3" (120 mesh)',a='Filtro de discos 4" (120 mesh)',a0='Ventosa 1"',a1='Ventosa 2"',a2='Ventosa 3"',a3=new A.fE(a7),a4=new A.fF(),a5=t.W,a6=A.d([A.aq("",0.9,!0,140,"pe16",13.6,B.au,"PE 16 mm (PN 4)",16,40,0.003,"",A.ai([B.p],a5),1.2),A.aq("",1.3,!0,140,"pe20",17,B.au,"PE 20 mm (PN 4)",20,40,0.003,"",A.ai([B.p],a5),1.5),A.aq("",2.1,!0,145,"pe25",21,B.y,"PE 25 mm (PN 6)",25,60,0.003,"",A.ai([B.p,B.j],a5),2),A.aq("",3.2,!0,145,"pe32",27.2,B.y,"PE 32 mm (PN 6)",32,60,0.003,"",A.ai([B.p,B.j],a5),2.4),A.aq("",4.9,!0,145,"pe40",34,B.y,"PE 40 mm (PN 6)",40,60,0.003,"",A.ai([B.j],a5),3),A.aq("",7.4,!0,145,"pe50",42.6,B.y,"PE 50 mm (PN 6)",50,60,0.003,"",A.ai([B.j],a5),3.7),A.aq("",4.5,!0,150,"pvc35",32,B.o,"PVC DN 35 PN 80",35,80,0.0015,"",A.ai([B.j,B.k],a5),1.5),A.aq("",7.2,!0,150,"pvc50",46.4,B.o,"PVC DN 50 PN 80",50,80,0.0015,"",A.ai([B.j,B.k],a5),1.8),A.aq("",14.5,!0,150,"pvc75",70.6,B.o,"PVC DN 75 PN 80",75,80,0.0015,"",A.ai([B.j,B.k],a5),2.2),A.aq("",24,!0,150,"pvc100",96,B.o,"PVC DN 100 PN 80",100,80,0.0015,"",A.ai([B.j,B.k],a5),2.5),A.aq("",36,!0,150,"pvc125",118.6,B.o,"PVC DN 125 PN 80",125,80,0.0015,"",A.ai([B.k],a5),3.2),A.aq("",52,!0,150,"pvc150",144,B.o,"PVC DN 150 PN 80",150,80,0.0015,"",A.ai([B.k],a5),3.8),A.aq("",88,!0,150,"pvc200",191.6,B.o,"PVC DN 200 PN 80",200,80,0.0015,"",A.ai([B.k],a5),4.9),A.aq("",135,!0,150,"pvc250",239.4,B.o,"PVC DN 250 PN 80",250,80,0.0015,"",A.ai([B.k],a5),6.2),A.aq("",42,!0,150,"pead110",96.8,B.y,"PEAD 110 mm PN 10",110,100,0.002,"",A.ai([B.k],a5),6.6),A.aq("",85,!0,150,"pead160",141,B.y,"PEAD 160 mm PN 10",160,100,0.002,"",A.ai([B.k],a5),9.5),A.aq("",160,!1,120,"steel150",154,B.bt,a3.$3('A\xe7o galvanizado 6"','Galvanised steel 6"','Acero galvanizado 6"'),150,200,0.15,"",A.ai([B.k],a5),4.5)],t.D)
a5=t.nB
s=A.d([new A.a3("drip_pc",a3.$3("Gotejador PC (bot\xe3o)","PC dripper (button)","Gotero PC (bot\xf3n)"),"","",B.as,A.d([new A.F("pc2","2 L/h PC",a4.$3(2,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.F("pc4","4 L/h PC",a4.$3(4,10,0.03),360,5,40,10,0.03,0.05,0.05),new A.F("pc8","8 L/h PC",a4.$3(8,10,0.03),360,5,40,10,0.03,0.05,0.05)],a5),0.6,0,0,!0),new A.a3("drip_turb",a3.$3("Gotejador turbulento","Turbulent dripper","Gotero turbulento"),"","",B.as,A.d([new A.F("t2","2 L/h",a4.$3(2,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.F("t4","4 L/h",a4.$3(4,10,0.5),360,5,25,10,0.04,0.05,0.05),new A.F("t8","8 L/h",a4.$3(8,10,0.5),360,5,25,10,0.04,0.05,0.05)],a5),0.35,0,0,!0),new A.a3("micro",a3.$3(j,"Micro-sprinkler 360\xb0",j),"","",B.ar,A.d([new A.F("m35",a3.$3("35 L/h (raio 3,0 m)","35 L/h (radius 3.0 m)","35 L/h (radio 3,0 m)"),a4.$4$radiusM(35,15,0.5,3),360,10,30,15,0.05,0.05,0.05),new A.F("m50",a3.$3("50 L/h (raio 3,5 m)","50 L/h (radius 3.5 m)","50 L/h (radio 3,5 m)"),a4.$4$radiusM(50,15,0.5,3.5),360,10,30,15,0.05,0.05,0.05),new A.F("m70",a3.$3("70 L/h (raio 4,0 m)","70 L/h (radius 4.0 m)","70 L/h (radio 4,0 m)"),a4.$4$radiusM(70,15,0.5,4),360,10,30,15,0.05,0.05,0.05),new A.F("m120",a3.$3("120 L/h (raio 5,0 m)","120 L/h (radius 5.0 m)","120 L/h (radio 5,0 m)"),a4.$4$radiusM(120,20,0.5,5),360,15,35,20,0.05,0.05,0.05)],a5),2.8,0,0.3,!0),new A.a3("micro_pc",a3.$3(i,"PC micro-sprinkler",i),"","",B.ar,A.d([new A.F("mpc40",a3.$3("40 L/h PC (raio 3,5 m)","40 L/h PC (radius 3.5 m)","40 L/h PC (radio 3,5 m)"),a4.$4$radiusM(40,15,0.05,3.5),360,12,40,20,0.05,0.05,0.05),new A.F("mpc70",a3.$3("70 L/h PC (raio 4,5 m)","70 L/h PC (radius 4.5 m)","70 L/h PC (radio 4,5 m)"),a4.$4$radiusM(70,15,0.05,4.5),360,12,40,20,0.05,0.05,0.05)],a5),3.9,0,0.3,!0),new A.a3("impact34",a3.$3(h,'Impact sprinkler 3/4"',h),"","",B.a1,A.d([new A.F("i3.5",a3.$3("Bocal 3,5 mm (0,9 m\xb3/h, R 12 m)","Nozzle 3.5 mm (0.9 m\xb3/h, R 12 m)","Boquilla 3,5 mm (0,9 m\xb3/h, R 12 m)"),a4.$4$radiusM(900,30,0.5,12),360,20,45,30,0.03,0.05,0.05),new A.F("i4.0",a3.$3("Bocal 4,0 mm (1,2 m\xb3/h, R 13 m)","Nozzle 4.0 mm (1.2 m\xb3/h, R 13 m)","Boquilla 4,0 mm (1,2 m\xb3/h, R 13 m)"),a4.$4$radiusM(1200,30,0.5,13),360,20,45,30,0.03,0.05,0.05),new A.F("i4.5",a3.$3("Bocal 4,5 mm (1,5 m\xb3/h, R 14 m)","Nozzle 4.5 mm (1.5 m\xb3/h, R 14 m)","Boquilla 4,5 mm (1,5 m\xb3/h, R 14 m)"),a4.$4$radiusM(g,30,0.5,14),360,20,45,30,0.03,0.05,0.05),new A.F("i5.0",a3.$3("Bocal 5,0 mm (1,9 m\xb3/h, R 15 m)","Nozzle 5.0 mm (1.9 m\xb3/h, R 15 m)","Boquilla 5,0 mm (1,9 m\xb3/h, R 15 m)"),a4.$4$radiusM(1900,30,0.5,15),360,25,50,35,0.03,0.05,0.05)],a5),18,20,1,!0),new A.a3("gun",a3.$3('Canh\xe3o hidr\xe1ulico 1,5"','Big gun 1.5"','Ca\xf1\xf3n de riego 1,5"'),"","",B.bs,A.d([new A.F("g14",a3.$3("Bocal 14 mm (15 m\xb3/h, R 32 m)","Nozzle 14 mm (15 m\xb3/h, R 32 m)","Boquilla 14 mm (15 m\xb3/h, R 32 m)"),a4.$4$radiusM(15e3,40,0.5,32),360,30,70,40,0.03,0.05,0.05),new A.F("g18",a3.$3("Bocal 18 mm (25 m\xb3/h, R 40 m)","Nozzle 18 mm (25 m\xb3/h, R 40 m)","Boquilla 18 mm (25 m\xb3/h, R 40 m)"),a4.$4$radiusM(25e3,45,0.5,40),360,35,80,45,0.03,0.05,0.05)],a5),420,40,1.5,!0),new A.a3("rotor",a3.$3('Rotor de jardim 1/2"','Turf rotor 1/2"','Rotor de jard\xedn 1/2"'),"","",B.a1,A.d([new A.F("r1.5","#1.5 (0,35 m\xb3/h, R 8 m)",a4.$4$radiusM(350,25,0.5,8),360,17,45,25,0.03,0.05,0.05),new A.F("r3","#3 (0,70 m\xb3/h, R 10 m)",a4.$4$radiusM(700,25,0.5,10),360,17,45,25,0.03,0.05,0.05),new A.F("r3_180","#3 180\xb0 (0,35 m\xb3/h, R 10 m)",a4.$4$radiusM(350,25,0.5,10),180,17,45,25,0.03,0.05,0.05),new A.F("r3_90","#3 90\xb0 (0,18 m\xb3/h, R 10 m)",a4.$4$radiusM(180,25,0.5,10),90,17,45,25,0.03,0.05,0.05)],a5),45,15,0.1,!0),new A.a3("spray",a3.$3('Spray pop-up 4"','Pop-up spray 4"','Difusor emergente 4"'),"","",B.a1,A.d([new A.F("s12","12F (0,60 m\xb3/h, R 3,7 m)",a4.$4$radiusM(600,20,0.5,3.7),360,10,30,20,0.04,0.05,0.05),new A.F("s12h","12H (0,30 m\xb3/h, R 3,7 m)",a4.$4$radiusM(300,20,0.5,3.7),180,10,30,20,0.04,0.05,0.05),new A.F("s12q","12Q (0,15 m\xb3/h, R 3,7 m)",a4.$4$radiusM(150,20,0.5,3.7),90,10,30,20,0.04,0.05,0.05),new A.F("s15","15F (0,84 m\xb3/h, R 4,6 m)",a4.$4$radiusM(840,20,0.5,4.6),360,10,30,20,0.04,0.05,0.05)],a5),12,15,0,!0),new A.a3("demand",a3.$3("Ponto de demanda","Demand point","Punto de demanda"),"","",B.at,A.d([new A.F("d5","5 m\xb3/h @ 20 m",a4.$3(5000,20,0),360,20,80,20,0,0.5,0.5),new A.F("d10","10 m\xb3/h @ 20 m",a4.$3(1e4,20,0),360,20,80,20,0,0.5,0.5),new A.F("d20","20 m\xb3/h @ 25 m",a4.$3(2e4,25,0),360,25,80,25,0,0.5,0.5)],a5),0,50,0,!0)],t.dO)
a5=a3.$3("Fita gotejadora 16 mm, 1,0 L/h @ 0,30 m","Drip tape 16 mm, 1.0 L/h @ 0.30 m","Cinta de goteo 16 mm, 1,0 L/h @ 0,30 m")
a5=A.cT(0.3,"",0.45,0.03,8,a4.$3(1,7,0.5),0.3,!0,140,"tape16_10_30",15.6,12,4,a5,16,15,0.002,"",20,30)
r=a3.$3("Fita gotejadora 16 mm, 1,6 L/h @ 0,20 m","Drip tape 16 mm, 1.6 L/h @ 0.20 m","Cinta de goteo 16 mm, 1,6 L/h @ 0,20 m")
r=A.cT(0.3,"",0.55,0.03,8,a4.$3(1.6,7,0.5),0.2,!0,140,"tape16_16_20",15.6,12,4,r,16,15,0.002,"",20,30)
q=a3.$3("Tubo gotejador 16 mm, 1,6 L/h @ 0,50 m","Dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo 16 mm, 1,6 L/h @ 0,50 m")
q=A.cT(0.4,"",1.1,0.03,10,a4.$3(1.6,10,0.5),0.5,!0,140,"drip16_16_50",13.8,25,5,q,16,30,0.002,"",20,30)
p=a3.$3("Tubo gotejador 16 mm, 2,4 L/h @ 0,75 m","Dripline 16 mm, 2.4 L/h @ 0.75 m","Tuber\xeda de goteo 16 mm, 2,4 L/h @ 0,75 m")
p=A.cT(0.4,"",1.05,0.03,10,a4.$3(2.4,10,0.5),0.75,!0,140,"drip16_24_75",13.8,25,5,p,16,30,0.002,"",20,30)
o=a3.$3("Tubo gotejador PC 16 mm, 1,6 L/h @ 0,50 m","PC dripline 16 mm, 1.6 L/h @ 0.50 m","Tuber\xeda de goteo PC 16 mm, 1,6 L/h @ 0,50 m")
o=A.cT(0.4,"",1.6,0.03,15,a4.$3(1.6,10,0.04),0.5,!0,140,"drip16pc_16_50",13.8,40,6,o,16,40,0.002,"",150,50)
n=a3.$3("Tubo gotejador PC 20 mm, 2,3 L/h @ 0,75 m","PC dripline 20 mm, 2.3 L/h @ 0.75 m","Tuber\xeda de goteo PC 20 mm, 2,3 L/h @ 0,75 m")
m=A.d([a5,r,q,p,o,A.cT(0.4,"",2.1,0.03,15,a4.$3(2.3,10,0.04),0.75,!0,140,"drip20pc_23_75",17.5,40,6,n,20,40,0.002,"",150,50)],t.kU)
n=new A.fD()
l=A.d([new A.E("ev25",a3.$3('V\xe1lvula el\xe9trica 1"','Solenoid valve 1"','Electrov\xe1lvula 1"'),"","",B.B,25,n.$2(6,25),0.00005555555555555556,0.0016666666666666666,120,0,!0),new A.E("ev40",a3.$3('V\xe1lvula el\xe9trica 1\xbd"','Solenoid valve 1\xbd"','Electrov\xe1lvula 1\xbd"'),"","",B.B,40,n.$2(5.5,40),0.0002777777777777778,0.0044444444444444444,260,0,!0),new A.E("ev50",a3.$3('V\xe1lvula el\xe9trica 2"','Solenoid valve 2"','Electrov\xe1lvula 2"'),"","",B.B,50,n.$2(5,50),0.0005555555555555556,0.008333333333333333,380,0,!0),new A.E("ev80",a3.$3(f,'Hydraulic valve 3"',f),"","",B.B,80,n.$2(4.5,80),0.001388888888888889,0.022222222222222223,900,0,!0),new A.E("ev100",a3.$3(e,'Hydraulic valve 4"',e),"","",B.B,100,n.$2(4,100),0.002777777777777778,0.03888888888888889,g,0,!0),new A.E("ev150",a3.$3(d,'Hydraulic valve 6"',d),"","",B.B,150,n.$2(3.5,150),0.006944444444444444,0.08333333333333333,2800,0,!0),new A.E("prv50",a3.$3('V\xe1lvula reguladora de press\xe3o 2"','Pressure reducing valve 2"','V\xe1lvula reguladora de presi\xf3n 2"'),"","",B.R,50,n.$2(3,50),0,0.008333333333333333,650,25,!0),new A.E("prv80",a3.$3('V\xe1lvula reguladora de press\xe3o 3"','Pressure reducing valve 3"','V\xe1lvula reguladora de presi\xf3n 3"'),"","",B.R,80,n.$2(3,80),0,0.022222222222222223,1200,30,!0),new A.E("prv100",a3.$3('V\xe1lvula reguladora de press\xe3o 4"','Pressure reducing valve 4"','V\xe1lvula reguladora de presi\xf3n 4"'),"","",B.R,100,n.$2(3,100),0,0.03888888888888889,2100,30,!0),new A.E("gate50",a3.$3('Registro gaveta 2"','Gate valve 2"','V\xe1lvula de compuerta 2"'),"","",B.S,50,n.$2(0.2,50),0,0.011111111111111112,90,0,!0),new A.E("gate80",a3.$3('Registro gaveta 3"','Gate valve 3"','V\xe1lvula de compuerta 3"'),"","",B.S,80,n.$2(0.2,80),0,0.025,220,0,!0),new A.E("gate100",a3.$3('Registro gaveta 4"','Gate valve 4"','V\xe1lvula de compuerta 4"'),"","",B.S,100,n.$2(0.2,100),0,0.041666666666666664,420,0,!0),new A.E("gate150",a3.$3('Registro gaveta 6"','Gate valve 6"','V\xe1lvula de compuerta 6"'),"","",B.S,150,n.$2(0.2,150),0,0.09722222222222222,900,0,!0),new A.E("check50",a3.$3('V\xe1lvula de reten\xe7\xe3o 2"','Check valve 2"','V\xe1lvula de retenci\xf3n 2"'),"","",B.T,50,n.$2(2,50),0,0.011111111111111112,150,0,!0),new A.E("check80",a3.$3('V\xe1lvula de reten\xe7\xe3o 3"','Check valve 3"','V\xe1lvula de retenci\xf3n 3"'),"","",B.T,80,n.$2(2,80),0,0.025,260,0,!0),new A.E("check100",a3.$3('V\xe1lvula de reten\xe7\xe3o 4"','Check valve 4"','V\xe1lvula de retenci\xf3n 4"'),"","",B.T,100,n.$2(2,100),0,0.041666666666666664,380,0,!0),new A.E("filter_disc50",a3.$3(c,'Disc filter 2" (120 mesh)',c),"","",B.C,50,new A.aF(62208,2,0),0,0.006944444444444444,850,0,!0),new A.E("filter_disc80",a3.$3(b,'Disc filter 3" (120 mesh)',b),"","",B.C,80,new A.aF(15552,2,0),0,0.013888888888888888,1600,0,!0),new A.E("filter_disc100",a3.$3(a,'Disc filter 4" (120 mesh)',a),"","",B.C,100,new A.aF(4800,2,0),0,0.025,2600,0,!0),new A.E("filter_screen80",a3.$3('Filtro de tela 3"','Screen filter 3"','Filtro de malla 3"'),"","",B.C,80,new A.aF(9000,2,0),0,0.016666666666666666,1400,0,!0),new A.E("filter_screen100",a3.$3('Filtro de tela 4"','Screen filter 4"','Filtro de malla 4"'),"","",B.C,100,new A.aF(3240,2,0),0,0.027777777777777776,2100,0,!0),new A.E("filter_screen150",a3.$3('Filtro de tela 6"','Screen filter 6"','Filtro de malla 6"'),"","",B.C,150,new A.aF(810,2,0),0,0.05555555555555555,3800,0,!0),new A.E("meter50",a3.$3('Hidr\xf4metro 2"','Water meter 2"','Contador de agua 2"'),"","",B.a7,50,n.$2(7,50),0,0.005555555555555556,700,0,!0),new A.E("meter80",a3.$3('Hidr\xf4metro 3"','Water meter 3"','Contador de agua 3"'),"","",B.a7,80,n.$2(7,80),0,0.016666666666666666,1100,0,!0),new A.E("meter100",a3.$3('Hidr\xf4metro 4"','Water meter 4"','Contador de agua 4"'),"","",B.a7,100,n.$2(7,100),0,0.03333333333333333,1600,0,!0),new A.E("backflow50",a3.$3('V\xe1lvula anti-refluxo 2"','Backflow preventer 2"','V\xe1lvula antirretorno 2"'),"","",B.aR,50,n.$2(8,50),0,0.006944444444444444,900,0,!0),new A.E("backflow80",a3.$3('V\xe1lvula anti-refluxo 3"','Backflow preventer 3"','V\xe1lvula antirretorno 3"'),"","",B.aR,80,n.$2(8,80),0,0.016666666666666666,g,0,!0),new A.E("air25",a3.$3(a0,'Air release valve 1"',a0),"","",B.a8,25,B.I,0,1,90,0,!0),new A.E("air50",a3.$3(a1,'Air release valve 2"',a1),"","",B.a8,50,B.I,0,1,180,0,!0),new A.E("air80",a3.$3(a2,'Air release valve 3"',a2),"","",B.a8,80,B.I,0,1,320,0,!0)],t.bD)
n=t.fU
k=A.d([A.ak("",900,0.45,!0,"pump_c1",0.0016666666666666666,0,a3.$3("Bomba centr\xedfuga 1 cv (4 m\xb3/h @ 20 m)","Centrifugal pump 1 hp (4 m\xb3/h @ 20 m)","Bomba centr\xedfuga 1 CV (4 m\xb3/h @ 20 m)"),A.d([B.fn,B.fE,B.fD,B.fk],n),0.75,!1,""),A.ak("",g,0.5,!0,"pump_c2",0.002777777777777778,0,a3.$3("Bomba centr\xedfuga 2 cv (7 m\xb3/h @ 28 m)","Centrifugal pump 2 hp (7 m\xb3/h @ 28 m)","Bomba centr\xedfuga 2 CV (7 m\xb3/h @ 28 m)"),A.d([B.fo,B.hn,B.fQ,B.fC],n),1.5,!1,""),A.ak("",2200,0.55,!0,"pump_small",0.004166666666666667,0,a3.$3("Bomba centr\xedfuga 3 cv (10 m\xb3/h @ 35 m)","Centrifugal pump 3 hp (10 m\xb3/h @ 35 m)","Bomba centr\xedfuga 3 CV (10 m\xb3/h @ 35 m)"),A.d([B.fp,B.fG,B.hg,B.h7],n),2.2,!1,""),A.ak("",3200,0.6,!0,"pump_c5",0.0075,0,a3.$3("Bomba centr\xedfuga 5 cv (18 m\xb3/h @ 38 m)","Centrifugal pump 5 hp (18 m\xb3/h @ 38 m)","Bomba centr\xedfuga 5 CV (18 m\xb3/h @ 38 m)"),A.d([B.fq,B.h3,B.ho,B.fY],n),3.7,!1,""),A.ak("",4500,0.62,!0,"pump_c7_5",0.011666666666666667,0,a3.$3("Bomba centr\xedfuga 7,5 cv (28 m\xb3/h @ 40 m)","Centrifugal pump 7.5 hp (28 m\xb3/h @ 40 m)","Bomba centr\xedfuga 7,5 CV (28 m\xb3/h @ 40 m)"),A.d([B.fr,B.h4,B.h2,B.fV],n),5.5,!1,""),A.ak("",6500,0.65,!0,"pump_mid",0.016666666666666666,0,a3.$3("Bomba centr\xedfuga 10 cv (40 m\xb3/h @ 45 m)","Centrifugal pump 10 hp (40 m\xb3/h @ 45 m)","Bomba centr\xedfuga 10 CV (40 m\xb3/h @ 45 m)"),A.d([B.fs,B.fM,B.fX,B.fT],n),7.5,!1,""),A.ak("",9000,0.68,!0,"pump_c15",0.022222222222222223,0,a3.$3("Bomba centr\xedfuga 15 cv (55 m\xb3/h @ 45 m)","Centrifugal pump 15 hp (55 m\xb3/h @ 45 m)","Bomba centr\xedfuga 15 CV (55 m\xb3/h @ 45 m)"),A.d([B.ft,B.h0,B.fS,B.fI],n),11,!1,""),A.ak("",12e3,0.7,!0,"pump_c20",0.027777777777777776,0,a3.$3("Bomba centr\xedfuga 20 cv (70 m\xb3/h @ 48 m)","Centrifugal pump 20 hp (70 m\xb3/h @ 48 m)","Bomba centr\xedfuga 20 CV (70 m\xb3/h @ 48 m)"),A.d([B.fu,B.hq,B.hd,B.h1],n),15,!1,""),A.ak("",18e3,0.72,!0,"pump_big",0.05,0,a3.$3("Bomba centr\xedfuga 30 cv (120 m\xb3/h @ 55 m)","Centrifugal pump 30 hp (120 m\xb3/h @ 55 m)","Bomba centr\xedfuga 30 CV (120 m\xb3/h @ 55 m)"),A.d([B.fv,B.hk,B.fH,B.hj],n),22,!1,""),A.ak("",28e3,0.74,!0,"pump_c50",0.06388888888888888,0,a3.$3("Bomba centr\xedfuga 50 cv (160 m\xb3/h @ 55 m)","Centrifugal pump 50 hp (160 m\xb3/h @ 55 m)","Bomba centr\xedfuga 50 CV (160 m\xb3/h @ 55 m)"),A.d([B.fw,B.hb,B.fA,B.fF],n),37,!1,""),A.ak("",4e4,0.76,!0,"pump_c75",0.09166666666666666,0,a3.$3("Bomba centr\xedfuga 75 cv (230 m\xb3/h @ 60 m)","Centrifugal pump 75 hp (230 m\xb3/h @ 60 m)","Bomba centr\xedfuga 75 CV (230 m\xb3/h @ 60 m)"),A.d([B.bx,B.fR,B.hl,B.h_],n),55,!1,""),A.ak("",55e3,0.78,!0,"pump_c100",0.11666666666666667,0,a3.$3("Bomba centr\xedfuga 100 cv (300 m\xb3/h @ 65 m)","Centrifugal pump 100 hp (300 m\xb3/h @ 65 m)","Bomba centr\xedfuga 100 CV (300 m\xb3/h @ 65 m)"),A.d([B.fz,B.fB,B.hf,B.ha],n),75,!1,""),A.ak("",2800,0.55,!0,"pump_s3",0.003333333333333333,0,a3.$3("Bomba submersa 3 cv (8 m\xb3/h @ 55 m)","Submersible pump 3 hp (8 m\xb3/h @ 55 m)","Bomba sumergible 3 CV (8 m\xb3/h @ 55 m)"),A.d([B.bx,B.fO,B.fK,B.fN],n),2.2,!0,""),A.ak("",3900,0.58,!0,"pump_s5",0.005,0,a3.$3("Bomba submersa 5 cv (12 m\xb3/h @ 65 m)","Submersible pump 5 hp (12 m\xb3/h @ 65 m)","Bomba sumergible 5 CV (12 m\xb3/h @ 65 m)"),A.d([B.by,B.fZ,B.hp,B.he],n),3.7,!0,""),A.ak("",5400,0.68,!0,"pump_sub",0.009722222222222222,0,a3.$3("Bomba submersa 7,5 cv (25 m\xb3/h @ 60 m)","Submersible pump 7.5 hp (25 m\xb3/h @ 60 m)","Bomba sumergible 7,5 CV (25 m\xb3/h @ 60 m)"),A.d([B.fx,B.hi,B.fL,B.h6],n),5.5,!0,""),A.ak("",9500,0.65,!0,"pump_s15",0.016666666666666666,0,a3.$3("Bomba submersa 15 cv (40 m\xb3/h @ 65 m)","Submersible pump 15 hp (40 m\xb3/h @ 65 m)","Bomba sumergible 15 CV (40 m\xb3/h @ 65 m)"),A.d([B.by,B.fU,B.fl,B.fW],n),11,!0,""),A.ak("",15e3,0.68,!0,"pump_s25",0.022222222222222223,0,a3.$3("Bomba submersa 25 cv (55 m\xb3/h @ 80 m)","Submersible pump 25 hp (55 m\xb3/h @ 80 m)","Bomba sumergible 25 CV (55 m\xb3/h @ 80 m)"),A.d([B.fm,B.hc,B.hm,B.h5],n),18.5,!0,""),A.ak("",19e3,0.72,!0,"pump_s30",0.03888888888888889,0,a3.$3("Bomba submersa 30 cv (100 m\xb3/h @ 60 m)","Submersible pump 30 hp (100 m\xb3/h @ 60 m)","Bomba sumergible 30 CV (100 m\xb3/h @ 60 m)"),A.d([B.fy,B.h9,B.h8,B.fJ],n),22,!0,"")],t.fH)
return A.lL(A.nJ(a6,a7),s,a6,k,m,l)},
nJ(a,b){var s=A.nH(a,b)
return s},
nH(a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d="Adaptador roscado",c="Conector inicial de lateral",b="Tubo de subida",a="Riser",a0=new A.fK(a6),a1=A.t(a5),a2=a1.j("e(1)"),a3=new A.u(a5,a2.a(new A.fG()),a1.j("u<1,e>")).au(0),a4=A.p(a3,A.i(a3).c)
B.a.a0(a4)
s=A.d([],t.eK)
r=new A.fJ()
q=new A.fL()
for(a3=a4.length,p=a3,o=0;o<p;h===a3||(0,A.k)(a4),++o,p=h){n=a4[o]
m=r.$1(n)
B.a.k(s,new A.Z("cpl"+m,A.A(a0.$3("Luva","Coupler","Manguito"))+" "+m+" mm","","",B.V,n,0,q.$2(4,n),!0,""))
B.a.k(s,new A.Z("el90_"+m,A.A(a0.$3("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0"))+" "+m+" mm","","",B.aj,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.Z("el45_"+m,A.A(a0.$3("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0"))+" "+m+" mm","","",B.ak,n,0,q.$2(6,n),!0,""))
B.a.k(s,new A.Z("tee"+m,A.A(a0.$3("T\xea","Tee","Te"))+" "+m+" mm","","",B.J,n,0,q.$2(8,n),!0,""))
B.a.k(s,new A.Z("cross"+m,A.A(a0.$3("Cruzeta","Cross","Cruz"))+" "+m+" mm","","",B.al,n,0,q.$2(11,n),!0,""))
B.a.k(s,new A.Z("cap"+m,A.A(a0.$3("Tamp\xe3o (cap)","End cap","Tap\xf3n"))+" "+m+" mm","","",B.K,n,0,q.$2(3,n),!0,""))
B.a.k(s,new A.Z("adp"+m,A.A(a0.$3(d,"Threaded adapter",d))+" "+m+" mm","","",B.am,n,0,q.$2(5,n),!0,""))
for(p=a4.length,l="red"+m+"x",k=n<=75,j="teer"+m+"x",i=0;h=a4.length,i<h;a4.length===p||(0,A.k)(a4),++i){g=a4[i]
if(g>=n)continue
f=r.$1(g)
B.a.k(s,new A.Z(l+f,A.A(a0.$3("Redu\xe7\xe3o","Reducer","Reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.v,n,g,q.$2(5,n),!0,""))
if(g>=20||k)B.a.k(s,new A.Z(j+f,A.A(a0.$3("T\xea de redu\xe7\xe3o","Reducing tee","Te de reducci\xf3n"))+" "+m+" \xd7 "+f+" mm","","",B.J,n,g,q.$2(9,n),!0,""))}}a3=A.ai([16,20],t.i)
a3.B(0,new A.be(new A.C(a5,a1.j("v(1)").a(new A.fH()),a1.j("C<1>")),a2.a(new A.fI()),a1.j("be<1,e>")))
e=A.p(a3,a3.$ti.c)
B.a.a0(e)
for(a1=e.length,o=0;o<e.length;e.length===a1||(0,A.k)(e),++o){n=e[o]
m=r.$1(n)
B.a.k(s,new A.Z("to"+m,A.A(a0.$3(c,"Lateral take-off",c))+" "+m+" mm","","",B.w,n,0,1.2,!0,""))
B.a.k(s,new A.Z("te"+m,A.A(a0.$3("Final de linha","Line end","Final de l\xednea"))+" "+m+" mm","","",B.L,n,0,0.9,!0,""))}B.a.k(s,new A.Z("riser_micro",a0.$3("Haste/tubinho de microaspersor","Micro-sprinkler stake/tube","Estaca/microtubo de microaspersor"),"","",B.m,0,0,1.1,!0,""))
B.a.k(s,new A.Z("riser20",A.A(a0.$3(b,a,b))+" 20 mm","","",B.m,20,0,6,!0,""))
B.a.k(s,new A.Z("riser25",A.A(a0.$3(b,a,b))+" 25 mm","","",B.m,25,0,8,!0,""))
B.a.k(s,new A.Z("riser40",A.A(a0.$3(b,a,b))+" 40 mm","","",B.m,40,0,18,!0,""))
return s},
b2:function b2(a,b){this.a=a
this.b=b},
J:function J(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
iS:function iS(){},
iR:function iR(){},
bf:function bf(a,b){this.a=a
this.b=b},
F:function F(a,b,c,d,e,f,g,h,i,j){var _=this
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
iN:function iN(a){this.a=a},
iO:function iO(a){this.a=a},
iP:function iP(){},
iM:function iM(){},
aS:function aS(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0){var _=this
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
E:function E(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
aQ:function aQ(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
j8:function j8(){},
j7:function j7(){},
a7:function a7(a,b){this.a=a
this.b=b},
Z:function Z(a,b,c,d,e,f,g,h,i,j){var _=this
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
fC:function fC(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
fU:function fU(a){this.a=a},
fV:function fV(){},
fS:function fS(a){this.a=a},
fT:function fT(){},
h6:function h6(a){this.a=a},
h7:function h7(){},
he:function he(a){this.a=a},
hf:function hf(){},
fY:function fY(a){this.a=a},
fZ:function fZ(){},
fW:function fW(a){this.a=a},
fX:function fX(){},
h8:function h8(){},
h9:function h9(){},
ha:function ha(){},
hb:function hb(){},
hc:function hc(){},
hd:function hd(){},
fM:function fM(){},
fN:function fN(){},
fO:function fO(){},
fP:function fP(){},
fQ:function fQ(){},
fR:function fR(){},
h5:function h5(){},
h3:function h3(){},
h4:function h4(){},
h_:function h_(){},
h0:function h0(a){this.a=a},
h1:function h1(a){this.a=a},
h2:function h2(a){this.a=a},
fE:function fE(a){this.a=a},
fF:function fF(){},
fD:function fD(){},
fK:function fK(a){this.a=a},
fG:function fG(){},
fJ:function fJ(){},
fL:function fL(){},
fH:function fH(){},
fI:function fI(){},
pZ(a){var s,r,q=B.d.aJ(a).toUpperCase()
for(s=0;s<77;++s){r=B.bj[s]
if(r.a===q)return r}return null},
q3(a,b){var s,r,q=B.d.aJ(a).toUpperCase(),p=B.d.aJ(b).toUpperCase()
if(q===p&&q.length!==0)return 1
s=B.bq.h(0,q)
r=B.bq.h(0,p)
if(s==null||r==null||s<=0)return null
return r/s},
q_(a){var s,r,q,p,o=B.d.aJ(a)
if(o.length===0)return null
s=A.pZ(o)
if(s!=null)return s.a
for(r=0;r<77;++r){q=B.bj[r]
if(q.b===o)return q.a}A:{if("$"===o){p="USD"
break A}if("\xa5"===o||"\u5186"===o){p="JPY"
break A}if("\u5143"===o||"\uffe5"===o){p="CNY"
break A}if("Rs."===o||"\u20a8"===o){p="PKR"
break A}if("S/."===o){p="PEN"
break A}if("\u0631.\u0633"===o||"\ufdfc"===o){p="SAR"
break A}if("\u062c.\u0645"===o){p="EGP"
break A}p=null
break A}return p},
qq(a,b){var s,r,q
if(b===1)return
for(s=a.a,r=s.length,q=0;q<r;++q)s[q].Q*=b
for(s=a.b,r=s.length,q=0;q<r;++q)s[q].r*=b
for(s=a.c,r=s.length,q=0;q<r;++q)s[q].cx*=b
for(s=a.d,r=s.length,q=0;q<r;++q)s[q].y*=b
for(s=a.e,r=s.length,q=0;q<r;++q)s[q].Q*=b
for(s=a.f,r=s.length,q=0;q<r;++q)s[q].w*=b},
r:function r(a,b){this.a=a
this.b=b},
nZ(b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=null,a6="rot",a7="scope",a8="spec",a9="depth",b0="zone",b1="mainline",b2=A.af(B.eM,A.D(b5.h(0,"type")),t.od),b3=A.D(b5.h(0,"id")),b4=A.x(b5.h(0,"layer"))
if(b4==null)b4="DRAWING"
s=A.x(b5.h(0,"name"))
if(s==null)s=""
r=new A.ic(b5)
q=new A.ib(b5)
p=new A.ia(b5)
switch(b2.a){case 0:r=t.j
return new A.ck(A.bE(r.a(b5.h(0,"a"))),A.bE(r.a(b5.h(0,"b"))),b3,b4,s)
case 1:r=r.$0()
q=A.Y(b5.h(0,"closed"))
return new A.cO(r,q===!0,b3,b4,s)
case 2:return new A.e6(q.$0(),p.$1("r"),b3,b4,s)
case 3:return new A.d5(q.$0(),p.$1("r"),p.$1("s"),p.$1("w"),b3,b4,s)
case 4:r=r.$0()
q=A.Y(b5.h(0,"closed"))
return new A.cR(r,q===!0,b3,b4,s)
case 5:r=r.$0()
q=p.$2("ang",45)
p=p.$2("sp",1)
o=A.Y(b5.h(0,"solid"))
return new A.eg(r,q,p,o===!0,b3,b4,s)
case 6:r=q.$0()
q=A.x(b5.h(0,"kind"))
if(q==null)q="tree"
return new A.eS(r,A.af(B.eR,q,t.ai),p.$2("size",2),p.$1(a6),b3,b4,s)
case 7:r=q.$0()
q=A.x(b5.h(0,"text"))
if(q==null)q=""
return new A.eV(r,q,p.$2("h",1),p.$1(a6),b3,b4,s)
case 8:r=t.j
return new A.ed(A.bE(r.a(b5.h(0,"a"))),A.bE(r.a(b5.h(0,"b"))),p.$2("off",1),b3,b4,s)
case 9:r=t.j
return new A.e1(A.bE(r.a(b5.h(0,"v"))),A.bE(r.a(b5.h(0,"a"))),A.bE(r.a(b5.h(0,"b"))),p.$2("r",2),b3,b4,s)
case 10:return new A.eP(A.bE(t.j.a(b5.h(0,"c"))),q.$0(),b3,b4,s)
case 11:r=r.$0()
q=A.x(b5.h(0,"text"))
if(q==null)q=""
return new A.cF(r,q,p.$2("h",1),b3,b4,s)
case 12:r=q.$0()
q=p.$2("w",1)
o=p.$2("h",1)
n=p.$1(a6)
p=p.$2("op",1)
m=A.x(b5.h(0,"mime"))
if(m==null)m="image/png"
l=b5.h(0,"data")!=null?B.cV.bt(A.D(b5.h(0,"data"))):a5
k=A.x(b5.h(0,"src"))
return new A.ei(r,q,o,n,p,m,l,k==null?"":k,b3,b4,s)
case 13:r=r.$0()
p=p.$1("z")
q=A.Y(b5.h(0,"gen"))
return new A.c9(r,p,q===!0,b3,b4,s)
case 14:return new A.dD(q.$0(),p.$1("z"),b3,b4,s)
case 15:r=r.$0()
q=A.af(B.D,A.D(b5.h(0,a7)),t.E)
o=A.x(b5.h(0,a8))
n=A.Y(b5.h(0,"auto"))
return A.og(n!==!1,p.$1(a9),b3,b4,s,o,r,q)
case 16:r=r.$0()
q=A.x(b5.h(0,a8))
o=A.Y(b5.h(0,"auto"))
n=A.x(b5.h(0,"outlet"))
if(n==null)n=""
m=A.x(b5.h(0,"nozzle"))
l=p.$2("head",20)
k=p.$2("sp",5)
j=p.$2("off",0)
i=p.$2("arc",360)
h=p.$1("riser")
return A.ot(i,o!==!1,p.$1(a9),l,b3,b4,s,m,j,n,q,r,h,k)
case 17:r=r.$0()
q=A.x(b5.h(0,a8))
if(q==null)q=""
o=p.$2("inlet",10)
n=A.Y(b5.h(0,"reg"))
m=p.$2("submin",0)
return A.oy(p.$1(a9),p.$1("flush"),b3,o,b4,s,r,n===!0,m,q)
case 18:r=q.$0()
q=A.x(b5.h(0,a7))
if(q==null)q=b0
q=A.af(B.D,q,t.E)
o=A.x(b5.h(0,"outlet"))
if(o==null)o=""
n=A.x(b5.h(0,"nozzle"))
m=p.$2("head",20)
l=p.$2("arc",360)
k=p.$1(a6)
p=p.$1("riser")
j=A.x(b5.h(0,b0))
return new A.b0(r,q,o,n,m,l,k,p,j==null?"":j,b3,b4,s)
case 19:r=q.$0()
q=A.x(b5.h(0,a8))
o=A.x(b5.h(0,b0))
if(o==null)o=s
n=p.$1(a6)
m=A.y(b5.h(0,"fixed"))
if(m==null)m=a5
return new A.ba(r,q,o,n,m,p.$1(a9),b3,b4,s)
case 20:r=q.$0()
q=A.Y(b5.h(0,"calc"))
return new A.aC(r,q!==!1,p.$1("dh"),p.$1("mh"),p.$1("dq"),p.$1("mq"),p.$1("wl"),b3,b4,s)
case 21:r=q.$0()
q=A.x(b5.h(0,a8))
o=p.$2("speed",1)
p=p.$1(a6)
n=A.x(b5.h(0,a7))
if(n==null)n=b1
return new A.bq(r,q,o,p,A.af(B.D,n,t.E),b3,b4,s)
case 22:r=q.$0()
q=A.x(b5.h(0,a8))
o=A.x(b5.h(0,a7))
if(o==null)o=b1
return new A.b_(r,q,A.af(B.D,o,t.E),p.$1("set"),p.$1(a6),b3,b4,s)
case 23:r=q.$0()
q=A.x(b5.h(0,a7))
if(q==null)q=b0
q=A.af(B.D,q,t.E)
p=A.y(b5.h(0,"z"))
return new A.cj(r,q,p==null?a5:p,b3,b4,s)
case 24:r=r.$0()
q=p.$2(a9,5)
o=p.$2("eff",0.9)
n=A.x(b5.h(0,"crop"))
if(n==null)n=""
m=A.y(b5.h(0,"epp"))
m=m==null?a5:B.b.ak(m)
if(m==null)m=0
l=A.Y(b5.h(0,"wb"))
return new A.cD(r,q,o,n,m,l===!0,p.$2("eto",5),p.$2("kc",1),p.$2("awc",120),p.$2("root",0.6),p.$2("mad",0.5),p.$1("psp"),p.$1("rsp"),p.$2("wf",1),b3,b4,s)
case 25:r=q.$0()
q=p.$2("r",400)
o=p.$1("ang")
n=A.x(b5.h(0,"kind"))
if(n==null)n="pivot"
n=A.af(B.eL,n,t.n7)
m=p.$1("travel")
l=p.$2("span",50)
k=A.x(b5.h(0,a8))
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
a4=A.x(b5.h(0,b0))
if(a4==null)a4=""
return new A.b3(p.$2("ssp",2.5),A.x(b5.h(0,"sspec")),A.x(b5.h(0,"rspec")),p.$1("tcost"),r,q,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,b3,b4,s)}},
c4(a){var s=J.aE(a,new A.ke(),t.bd)
s=A.p(s,s.$ti.j("w.E"))
return s},
og(a,b,c,d,e,f,g,h){return new A.aH(g,h,f,a,b,c,d,e)},
ot(a,b,c,d,e,f,g,h,i,j,k,l,m,n){return new A.al(l,k,b,j,h,d,n,i,a,m,c,e,f,g)},
oy(a,b,c,d,e,f,g,h,i,j){return new A.aB(g,j,d,h,i,a,b,c,e,f)},
nX(a){var s,r=a.gC()
A:{s=B.a9===r||B.aa===r||B.ab===r||B.ac===r||B.ad===r||B.ae===r||B.af===r||B.ag===r||B.ah===r||B.ai===r
break A}return s},
nW(a){var s
A:{s=null
if(a instanceof A.aH){s=a.e
break A}if(a instanceof A.al){s=B.h
break A}if(a instanceof A.aB){s=B.h
break A}if(a instanceof A.b0){s=a.e
break A}if(a instanceof A.ba)break A
if(a instanceof A.aC){s=B.i
break A}if(a instanceof A.bq){s=a.w
break A}if(a instanceof A.b_){s=a.f
break A}if(a instanceof A.cj){s=a.e
break A}if(a instanceof A.b3){s=B.i
break A}break A}return s},
nY(a){var s
A:{if(a instanceof A.ck){s=A.d([a.d,a.e],t.C)
break A}if(t.f.b(a)){s=a.gP()
break A}if(a instanceof A.d5){s=a.dY()
break A}s=null
break A}return s},
aG:function aG(a,b){this.a=a
this.b=b},
N:function N(a,b){this.a=a
this.b=b},
G:function G(){},
ic:function ic(a){this.a=a},
id:function id(){},
ib:function ib(a){this.a=a},
ia:function ia(a){this.a=a},
bh:function bh(){},
a5:function a5(){},
ke:function ke(){},
ck:function ck(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cO:function cO(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
e6:function e6(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
d5:function d5(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
cR:function cR(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
eg:function eg(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
aI:function aI(a,b){this.a=a
this.b=b},
eS:function eS(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eV:function eV(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
ed:function ed(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
e1:function e1(a,b,c,d,e,f,g){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.a=e
_.b=f
_.c=g},
eP:function eP(a,b,c,d,e){var _=this
_.d=a
_.e=b
_.a=c
_.b=d
_.c=e},
cF:function cF(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
ei:function ei(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
c9:function c9(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
dD:function dD(a,b,c,d,e){var _=this
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
al:function al(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
b0:function b0(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
ba:function ba(a,b,c,d,e,f,g,h,i){var _=this
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
bq:function bq(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
b_:function b_(a,b,c,d,e,f,g,h){var _=this
_.d=a
_.e=b
_.f=c
_.r=d
_.w=e
_.a=f
_.b=g
_.c=h},
cj:function cj(a,b,c,d,e,f){var _=this
_.d=a
_.e=b
_.f=c
_.a=d
_.b=e
_.c=f},
b3:function b3(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var _=this
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
cD:function cD(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
eZ:function eZ(){},
f1:function f1(){},
f2:function f2(){},
f6:function f6(){},
f9:function f9(){},
fa:function fa(){},
fc:function fc(){},
fd:function fd(){},
fe:function fe(){},
ff:function ff(){},
fg:function fg(){},
fi:function fi(){},
fj:function fj(){},
fk:function fk(){},
fn:function fn(){},
fo:function fo(){},
fp:function fp(){},
fq:function fq(){},
mb(a,b,c){var s=a.a,r=a.b
return new A.B(s+(b.a-s)*c,r+(b.b-r)*c)},
bE(a){var s=J.a9(a)
return new A.B(A.at(s.h(a,0)),A.at(s.h(a,1)))},
nF(a){var s,r,q,p,o,n
for(s=a.$ti,r=new A.aO(a,a.gm(0),s.j("aO<w.E>")),s=s.j("w.E"),q=B.cT;r.l();){p=r.d
if(p==null)p=s.a(p)
o=p.a
n=Math.min(q.a,o)
p=p.b
q=new A.e5(n,Math.min(q.b,p),Math.max(q.c,o),Math.max(q.d,p))}return q},
ls(a,b,c){var s,r=c.R(0,b),q=r.co(r)
if(q===0)return new A.n(b,0)
s=B.b.a1(a.R(0,b).co(r)/q,0,1)
return new A.n(b.al(0,r.af(0,s)),s)},
aX(a){var s,r,q,p,o,n
for(s=J.a9(a),r=0,q=1;q<s.gm(a);++q){p=s.h(a,q-1)
o=s.h(a,q)
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)}return r},
qn(a,b){var s,r,q,p,o,n,m,l,k,j,i,h
for(s=b.length,r=s-1,q=a.b,p=a.a,o=!1,n=0;n<s;m=n+1,r=n,n=m){l=b[n]
if(!(r>=0&&r<s))return A.b(b,r)
k=b[r]
j=l.b
i=k.b
if(j>q!==i>q){h=l.a
h=p<(k.a-h)*(q-j)/(i-j)+h
j=h}else j=!1
if(j)o=!o}return o},
kD(a,b){var s,r,q,p,o,n,m,l,k=J.a9(a)
if(k.gF(a))return B.av
for(s=b,r=1;r<k.gm(a);++r){q=r-1
p=k.h(a,q)
o=k.h(a,r)
n=p.a-o.a
o=p.b-o.b
m=Math.sqrt(n*n+o*o)
if(s<=m||r===k.gm(a)-1){l=m===0?0:B.b.a1(s/m,0,1)
return A.mb(k.h(a,q),k.h(a,r),l)}s-=m}return k.gM(a)},
nd(a,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.t(a0),c=d.j("C<1>"),b=A.p(new A.C(a0,d.j("v(1)").a(new A.kZ(a)),c),c.j("h.E"))
B.a.a0(b)
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
f=(b[p]-q)/j}e=A.mb(n,m,f)
B.a.k(r,e)
B.a.k(s,r)
r=A.d([e],c);++p}B.a.k(r,m)}B.a.k(s,r)
d=t.ji
d=A.p(new A.C(s,t.eV.a(new A.l_()),d),d.j("h.E"))
return d},
pV(c1,c2,c3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=J.a9(c1)
if(c0.gm(c1)<2){c0=A.p(c1,t.g)
return c0}if(c0.gm(c1)===2)return A.d([c0.h(c1,0),c0.h(c1,1)],t.C)
s=c0.gm(c1)
r=new A.ki(c2,c1,s)
q=A.d([],t.C)
p=c2?s:s-1
for(o=0;o<p;o=l){n=r.$1(o-1)
m=r.$1(o)
l=o+1
k=r.$1(l)
j=r.$1(o+2)
i=new A.kj()
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
B.a.k(q,new A.B(((d*a8+b*a9)*b0+b4*b9)*b1+(b4*b6+(a0*b7+a3*b8)*b2)*b3,((c*a8+a*a9)*b0+b5*b9)*b1+(b5*b6+(a1*b7+a4*b8)*b2)*b3))}}B.a.k(q,c2?c0.gu(c1):c0.gM(c1))
return q},
B:function B(a,b){this.a=a
this.b=b},
e5:function e5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
kZ:function kZ(a){this.a=a},
l_:function l_(){},
ki:function ki(a,b,c){this.a=a
this.b=b
this.c=c},
kj:function kj(){},
lR(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5){return new A.hj(b2,i,b4,a1,q,o,a2,a,c,m,a8,a4,a5,l,b5,b1,n,s,k,j,a9,d,e,a7,p,f,r,h,g,b,b3,a6,a3,a0,b0)},
nT(b8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=null,b7="currency"
if(b8==null)return A.lR(!0,!0,0.05,"R$","BRL",1,1,0.3,B.an,0,1,2000,0.1,1,2,3,2,100,3,0,1.5,5,6,0.75,0.65,!0,B.a6,10,5,B.aP,!0,B.cS,0,20,500)
s=new A.hk(b8)
r=A.oF(t.dZ.a(b8.h(0,"units")))
q=A.x(b8.h(0,"method"))
if(q==null)q="hazenWilliams"
q=A.af(B.eK,q,t.m1)
p=s.$2("temp",20)
o=s.$2("vZone",1.5)
n=s.$2("vMain",2)
m=s.$2("vLat",2)
l=s.$2("minorPct",5)
k=A.Y(b8.h(0,"minor"))
j=s.$2("tol",0.05)
i=s.$2("interest",0.1)
h=A.y(b8.h(0,"term"))
h=h==null?b6:B.b.ak(h)
if(h==null)h=10
g=s.$2("kwh",0.75)
f=s.$2("eff",0.65)
e=s.$2("hours",2000)
d=s.$2("zoneHours",500)
c=A.Y(b8.h(0,"trade"))
b=A.y(b8.h(0,"latSizes"))
b=b==null?b6:B.b.ak(b)
if(b==null)b=1
a=A.y(b8.h(0,"subSizes"))
a=a==null?b6:B.b.ak(a)
if(a==null)a=3
a0=s.$2("cScale",1)
a1=s.$2("cOffset",0)
a2=s.$2("densify",5)
a3=A.x(b8.h(0,b7))
if(a3==null)a3="R$"
a4=A.x(b8.h(0,"currencyCode"))
if(a4==null){a4=A.x(b8.h(0,b7))
a4=A.q_(a4==null?"R$":a4)}if(a4==null)a4=""
a5=A.x(b8.h(0,"sizing"))
if(a5==null)a5="lp"
a5=A.af(B.eN,a5,t.fA)
a6=A.y(b8.h(0,"mainSizes"))
a6=a6==null?b6:B.b.ak(a6)
if(a6==null)a6=3
a7=A.y(b8.h(0,"epp"))
a7=a7==null?b6:B.b.ak(a7)
if(a7==null)a7=1
a8=A.y(b8.h(0,"maxNodes"))
a8=a8==null?b6:B.b.ak(a8)
if(a8==null)a8=100
a9=s.$2("flushV",0.3)
b0=s.$2("flushH",1)
b1=A.Y(b8.h(0,"surge"))
b2=s.$2("closure",0)
b3=A.Y(b8.h(0,"fittings"))
b4=s.$2("stick",6)
s=s.$2("zoneVar",0)
b5=A.x(b8.h(0,"terrain"))
if(b5==null)b5="idw"
return A.lR(k!==!1,b1!==!1,j,a3,a4,a7,b0,a9,q,a1,a0,e,i,b,m,a6,n,a8,a,s,o,l,b4,g,f,b3!==!1,a5,h,a2,A.af(B.eO,b5,t.oW),c!==!1,r,b2,p,d)},
mh(a,b,c,d,e){return new A.b5(b,c,e,d,a)},
m9(a,b,c,d,e,f,g,h,i){var s
if(i==null){$.la=$.la+1
s="p"+B.c.bE(1000*Date.now(),36)+B.c.bE((A.cM(Date.now(),0,B.f,B.f)^$.la*2654435761)>>>0,36)}else s=i
return new A.iY(s,b==null?new A.bw(Date.now(),0,!1):b,e,f,a,h,c,g,d)},
ma(){var s,r,q,p=A.d([],t.j8)
for(s=0;s<23;++s){r=B.f2[s]
q=B.f6.h(0,r)
p.push(new A.aA(r,q==null?4294967295:q,!0,!1))}return p},
om(a){var s,r,q,p,o,n,m,l,k,j,i,h,g=null
if(!J.aY(a.h(0,"format"),"opencadirrigation")&&!J.aY(a.h(0,"format"),"irrigationcad"))throw A.l(B.et)
s=t.dZ
r=s.a(a.h(0,"meta"))
if(r==null)r=A.m9("",g,"",g,g,"New project","","",g)
else{q=A.x(r.h(0,"uid"))
p=A.x(r.h(0,"created"))
p=A.lQ(p==null?"":p)
o=A.x(r.h(0,"modified"))
o=A.lQ(o==null?"":o)
n=A.x(r.h(0,"name"))
if(n==null)n=""
m=A.x(r.h(0,"client"))
if(m==null)m=""
l=A.x(r.h(0,"site"))
if(l==null)l=""
k=A.x(r.h(0,"designer"))
if(k==null)k=""
j=A.x(r.h(0,"notes"))
if(j==null)j=""
if(r.h(0,"georef")!=null){r=t.P.a(r.h(0,"georef"))
i=B.b.ak(A.at(r.h(0,"zone")))
h=A.Y(r.h(0,"north"))
r=new A.ig(i,h!==!1,A.at(r.h(0,"e0")),A.at(r.h(0,"n0")))}else r=g
q=A.m9(m,p,k,r,o,n,j,l,q)
r=q}s=A.nT(s.a(a.h(0,"params")))
q=a.h(0,"catalog")!=null?A.nK(t.P.a(a.h(0,"catalog"))):A.nI()
p=t.O
o=p.a(a.h(0,"layers"))
if(o==null)o=[]
o=J.aE(o,new A.iZ(),t.df)
o=A.p(o,o.$ti.j("w.E"))
o=new A.j_().$1(o)
n=p.a(a.h(0,"entities"))
if(n==null)n=[]
n=J.aE(n,new A.j0(),t.h)
n=A.p(n,n.$ti.j("w.E"))
p=p.a(a.h(0,"systemFlows"))
if(p==null)p=[]
p=J.aE(p,new A.j1(),t.k)
p=A.p(p,p.$ti.j("w.E"))
m=A.y(a.h(0,"nextId"))
m=m==null?g:B.b.ak(m)
if(m==null)m=1
if(o==null)o=A.ma()
s=new A.iX(r,s,q,o,n,p,m)
r=A.x(a.h(0,"currentLayer"))
s.w=r==null?"DRAWING":r
return s},
aA:function aA(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cp:function cp(a,b){this.a=a
this.b=b},
hj:function hj(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5){var _=this
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
_.p2=b5},
hk:function hk(a){this.a=a},
b5:function b5(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
iY:function iY(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
iX:function iX(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w="DRAWING"},
j2:function j2(){},
j3:function j3(){},
j4:function j4(){},
iZ:function iZ(){},
j_:function j_(){},
j0:function j0(){},
j1:function j1(){},
qt(c2,c3,c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0=null,c1=A.nY(c2)
if(c1==null||J.au(c1)<2)return A.d([c2],t.u)
s=A.t(c3)
r=s.j("C<1>")
r=A.dp(new A.C(c3,s.j("v(1)").a(new A.kY(A.aX(c1))),r),r.j("h.E"))
q=A.p(r,A.i(r).c)
B.a.a0(q)
if(q.length===0)return A.d([c2],t.u)
p=A.nd(c1,q)
if(p.length<2)return A.d([c2],t.u)
s=t.u
o=A.d([],s)
for(r=c2 instanceof A.cF,n=c2 instanceof A.cR,m=c2 instanceof A.aB,l=c2 instanceof A.al,k=c2 instanceof A.aH,j=c2 instanceof A.c9,i=c2 instanceof A.cO,h=c2 instanceof A.ck,g=c2.c,f=g+" (",e=g.length===0,d=c2.a,c=0,b=0;b<p.length;++b){a=b===0
a0=a?d:c4.$0()
if(e)a1=""
else a1=a?g:f+(b+1)+")"
if(!(b<p.length))return A.b(p,b)
a2=p[b]
a3=A.aX(a2)
A:{a4=h?c2:c0
if(h){a=a4.b
a5=J.a1(a2)
B.a.k(o,new A.ck(a5.gu(a2),a5.gM(a2),a0,a,a1))
break A}a6=i?c2:c0
if(i){B.a.k(o,new A.cO(a2,!1,a0,a6.b,a1))
break A}a7=j?c2:c0
if(j){a=a7.b
B.a.k(o,new A.c9(a2,a7.e,!1,a0,a,a1))
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
b3=B.b.aq((c-b2)/a)
b4=b2+(b3<0?0:b3)*a
b5=(b4<c-1e-9?b4+a:b4)-c
a5=b1.b
a8=b1.e
a9=b1.f
b0=b1.r
b6=b1.w
b7=b1.x
b8=b5<=1e-9?1e-9:b5
B.a.k(o,new A.al(a2,a8,a9,b0,b6,b7,a,b8,b1.Q,b1.as,b1.at,a0,a5,a1))
break A}b9=m?c2:c0
if(m){a=b9.b
a5=b9.e
a8=b9.f
a9=b9.r
b0=b9.w
b6=b9.x
B.a.k(o,new A.aB(a2,a5,a8,a9,b0,b6,b===p.length-1?b9.y:0,a0,a,a1))
break A}b1=n?c2:c0
if(n){B.a.k(o,new A.cR(a2,!1,a0,b1.b,a1))
break A}a4=r?c2:c0
if(r){a=a4.b
B.a.k(o,new A.cF(a2,a4.e,a4.f,a0,a,a1))
break A}return A.d([c2],s)}c+=a3}return o},
kY:function kY(a){this.a=a},
cr:function cr(a,b){this.a=a
this.b=b},
bH:function bH(a,b){this.a=a
this.b=b},
eU:function eU(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=10
_.f=!1
_.r=null},
jl:function jl(){},
jm:function jm(){},
jn:function jn(){},
le(a,b,c,d){var s=new A.jo(a,b,c,d,A.m(t.S,t.J))
s.d2()
return s},
oA(c9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3=t.S,c4=A.m(t.N,c3),c5=t.n,c6=A.d([],c5),c7=A.d([],c5),c8=A.d([],c5)
for(c5=c9.length,s=0;s<c9.length;c9.length===c5||(0,A.k)(c9),++s){r=c9[s]
q=r.a
p=r.b
o=r.c
if(!isFinite(q)||!isFinite(p)||!isFinite(o))continue
n=""+B.b.a2(q*1000)+"|"+B.b.a2(p*1000)
m=c4.h(0,n)
if(m!=null){B.a.i(c8,m,o)
continue}c4.i(0,n,c6.length)
B.a.k(c6,q)
B.a.k(c7,p)
B.a.k(c8,o)}l=c6.length
if(l<3)return A.le(c6,c7,c8,A.d([],t.ae))
k=B.a.L(c6,B.H)
j=B.a.L(c6,B.q)
i=B.a.L(c7,B.H)
h=B.a.L(c7,B.q)
g=Math.max(Math.max(j-k,h-i),0.000001)
if(g<1e-9)return A.le(c6,c7,c8,A.d([],t.ae))
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
b=new A.jr(r,c5)
a=new A.c0(l,l+1,l+2)
b.$1(a)
B.a.k(c,a)
a0=J.en(l,c3)
for(m=0;m<l;++m)a0[m]=m
B.a.ao(a0,new A.js(new A.jq(r,k,g,B.c.a1(B.b.aq(Math.sqrt(l)/2),1,512),c5,i)))
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
b3=new A.jt(b1,b2)
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
a8=new A.c0(b7,b8,m)
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
B.a.k(b9,c2>0?a8:new A.c0(d,b5,a2))}return A.le(c6,c7,c8,b9)},
c0:function c0(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=0},
jo:function jo(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=1
_.w=_.r=0},
jr:function jr(a,b){this.a=a
this.b=b},
jq:function jq(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
js:function js(a){this.a=a},
jt:function jt(a,b){this.a=a
this.b=b},
jp:function jp(){},
fx(a){var s=B.b.a1(a,0,60)
return 0.000001792/(1+0.0337*s+0.000221*s*s)},
oF(a){var s,r,q,p
if(a==null)return B.cS
s=A.x(a.h(0,"length"))
if(s==null)s="m"
s=A.af(B.eY,s,t.hu)
r=A.x(a.h(0,"flow"))
if(r==null)r="lph"
r=A.af(B.f_,r,t.mf)
q=A.x(a.h(0,"pressure"))
if(q==null)q="mH2O"
q=A.af(B.eZ,q,t.c4)
p=A.x(a.h(0,"diameter"))
if(p==null)p="mm"
return new A.eX(s,r,q,A.af(B.eI,p,t.ks))},
bp:function bp(a,b){this.a=a
this.b=b},
bm:function bm(a,b){this.a=a
this.b=b},
bD:function bD(a,b){this.a=a
this.b=b},
cb:function cb(a,b){this.a=a
this.b=b},
eX:function eX(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
qi(){var s,r=v.G,q=new A.kB(r)
if(typeof q=="function")A.bv(A.d6("Attempting to rewrap a JS function.",null))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.pe,q)
s[$.lz()]=q
r.addEventListener("message",s)},
kB:function kB(a){this.a=a},
kA:function kA(a){this.a=a},
ne(a){return v.mangledGlobalNames[a]},
qw(a){throw A.aa(A.lY(a),new Error())},
qx(){throw A.aa(A.lY(""),new Error())},
pe(a,b,c){t.Z.a(a)
if(A.aV(c)>=1)return a.$1(b)
return a.$0()},
n5(a,b,c){A.mV(c,t.H,"T","min")
return Math.min(c.a(a),c.a(b))},
n4(a,b,c){A.mV(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.l5.prototype={}
J.el.prototype={
Y(a,b){return a===b},
gK(a){return A.eN(a)},
q(a){return"Instance of '"+A.eO(a)+"'"},
gO(a){return A.bM(A.lm(this))}}
J.eo.prototype={
q(a){return String(a)},
gK(a){return a?519018:218159},
gO(a){return A.bM(t.y)},
$iP:1,
$iv:1}
J.dj.prototype={
Y(a,b){return null==b},
q(a){return"null"},
gK(a){return 0},
$iP:1}
J.dl.prototype={$ia0:1}
J.bX.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.eL.prototype={}
J.cs.prototype={}
J.bW.prototype={
q(a){var s=a[$.ng()]
if(s==null)s=a[$.lz()]
if(s==null)return this.cM(a)
return"JavaScript function for "+J.d4(s)},
$ibz:1}
J.dk.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.dm.prototype={
gK(a){return 0},
q(a){return String(a)}}
J.o.prototype={
b_(a,b){return new A.ae(a,A.t(a).j("@<1>").A(b).j("ae<1,2>"))},
k(a,b){A.t(a).c.a(b)
a.$flags&1&&A.ab(a,29)
a.push(b)},
dZ(a,b){a.$flags&1&&A.ab(a,"removeAt",1)
if(b<0||b>=a.length)throw A.l(A.lb(b,null))
return a.splice(b,1)[0]},
dN(a,b,c){A.t(a).c.a(c)
a.$flags&1&&A.ab(a,"insert",2)
if(b<0||b>a.length)throw A.l(A.lb(b,null))
a.splice(b,0,c)},
U(a,b){var s
a.$flags&1&&A.ab(a,"remove",1)
for(s=0;s<a.length;++s)if(J.aY(a[s],b)){a.splice(s,1)
return!0}return!1},
B(a,b){var s
A.t(a).j("h<1>").a(b)
a.$flags&1&&A.ab(a,"addAll",2)
if(Array.isArray(b)){this.cP(a,b)
return}for(s=J.ac(b);s.l();)a.push(s.gp())},
cP(a,b){var s,r
t.dG.a(b)
s=b.length
if(s===0)return
if(a===b)throw A.l(A.am(a))
for(r=0;r<s;++r)a.push(b[r])},
V(a){a.$flags&1&&A.ab(a,"clear","clear")
a.length=0},
aI(a,b,c){var s=A.t(a)
return new A.u(a,s.A(c).j("1(2)").a(b),s.j("@<1>").A(c).j("u<1,2>"))},
dS(a,b){var s,r=A.bd(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.i(r,s,A.A(a[s]))
return r.join(b)},
a4(a,b){return A.c_(a,b,null,A.t(a).c)},
L(a,b){var s,r,q
A.t(a).j("1(1,1)").a(b)
s=a.length
if(s===0)throw A.l(A.av())
if(0>=s)return A.b(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.l(A.am(a))}return r},
W(a,b,c,d){var s,r,q
d.a(b)
A.t(a).A(d).j("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.l(A.am(a))}return r},
ai(a,b,c){var s,r,q,p=A.t(a)
p.j("v(1)").a(b)
p.j("1()?").a(c)
s=a.length
for(r=0;r<s;++r){q=a[r]
if(b.$1(q))return q
if(a.length!==s)throw A.l(A.am(a))}p=c.$0()
return p},
I(a,b){if(!(b>=0&&b<a.length))return A.b(a,b)
return a[b]},
cK(a,b,c){var s=a.length
if(b>s)throw A.l(A.aR(b,0,s,"start",null))
if(c<b||c>s)throw A.l(A.aR(c,b,s,"end",null))
if(b===c)return A.d([],A.t(a))
return A.d(a.slice(b,c),A.t(a))},
gu(a){if(a.length>0)return a[0]
throw A.l(A.av())},
gM(a){var s=a.length
if(s>0)return a[s-1]
throw A.l(A.av())},
Z(a,b){var s,r
A.t(a).j("v(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.l(A.am(a))}return!1},
gcw(a){return new A.br(a,A.t(a).j("br<1>"))},
ao(a,b){var s,r,q,p,o,n=A.t(a)
n.j("f(1,1)?").a(b)
a.$flags&2&&A.ab(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.pp()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cF()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.ft(b,2))
if(p>0)this.dc(a,p)},
a0(a){return this.ao(a,null)},
dc(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
cr(a,b){var s,r=a.length
if(0>=r)return-1
for(s=0;s<r;++s){if(!(s<a.length))return A.b(a,s)
if(J.aY(a[s],b))return s}return-1},
v(a,b){var s
for(s=0;s<a.length;++s)if(J.aY(a[s],b))return!0
return!1},
gF(a){return a.length===0},
ga8(a){return a.length!==0},
q(a){return A.l4(a,"[","]")},
gt(a){return new J.c7(a,a.length,A.t(a).j("c7<1>"))},
gK(a){return A.eN(a)},
gm(a){return a.length},
sm(a,b){a.$flags&1&&A.ab(a,"set length","change the length of")
if(b<0)throw A.l(A.aR(b,0,null,"newLength",null))
if(b>a.length)A.t(a).c.a(null)
a.length=b},
h(a,b){if(!(b>=0&&b<a.length))throw A.l(A.fu(a,b))
return a[b]},
i(a,b,c){A.t(a).c.a(c)
a.$flags&2&&A.ab(a)
if(!(b>=0&&b<a.length))throw A.l(A.fu(a,b))
a[b]=c},
$iz:1,
$ih:1,
$iq:1}
J.em.prototype={
e5(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.eO(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.il.prototype={}
J.c7.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.k(q)
throw A.l(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iU:1}
J.ch.prototype={
T(a,b){var s
A.at(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gb3(b)
if(this.gb3(a)===s)return 0
if(this.gb3(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gb3(a){return a===0?1/a<0:a<0},
ak(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.l(A.bs(""+a+".toInt()"))},
aq(a){var s,r
if(a>=0){if(a<=2147483647){s=a|0
return a===s?s:s+1}}else if(a>=-2147483648)return a|0
r=Math.ceil(a)
if(isFinite(r))return r
throw A.l(A.bs(""+a+".ceil()"))},
J(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.l(A.bs(""+a+".floor()"))},
a2(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.l(A.bs(""+a+".round()"))},
bA(a){if(a<0)return-Math.round(-a)
else return Math.round(a)},
a1(a,b,c){if(B.c.T(b,c)>0)throw A.l(A.mT(b))
if(this.T(a,b)<0)return b
if(this.T(a,c)>0)return c
return a},
ae(a,b){var s
if(b>20)throw A.l(A.aR(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gb3(a))return"-"+s
return s},
bE(a,b){var s,r,q,p,o
if(b<2||b>36)throw A.l(A.aR(b,2,36,"radix",null))
s=a.toString(b)
r=s.length
q=r-1
if(!(q>=0))return A.b(s,q)
if(s.charCodeAt(q)!==41)return s
p=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(s)
if(p==null)A.bv(A.bs("Unexpected toString result: "+s))
r=p.length
if(1>=r)return A.b(p,1)
s=p[1]
if(3>=r)return A.b(p,3)
o=+p[3]
r=p[2]
if(r!=null){s+=r
o-=r.length}return s+B.d.af("0",o)},
q(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gK(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
R(a,b){return a-b},
b8(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
if(b<0)return s-b
else return s+b},
bp(a,b){return(a|0)===a?a/b|0:this.dj(a,b)},
dj(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.l(A.bs("Result of truncating division is "+A.A(s)+": "+A.A(a)+" ~/ "+b))},
aW(a,b){var s
if(a>0)s=this.df(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
df(a,b){return b>31?0:a>>>b},
gO(a){return A.bM(t.H)},
$iaL:1,
$ie:1,
$iay:1}
J.di.prototype={
gO(a){return A.bM(t.S)},
$iP:1,
$if:1}
J.ep.prototype={
gO(a){return A.bM(t.i)},
$iP:1}
J.ci.prototype={
av(a,b,c){return a.substring(b,A.md(b,c,a.length))},
aJ(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(0>=o)return A.b(p,0)
if(p.charCodeAt(0)===133){s=J.o8(p,1)
if(s===o)return""}else s=0
r=o-1
if(!(r>=0))return A.b(p,r)
q=p.charCodeAt(r)===133?J.o9(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
af(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.l(B.d4)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
dX(a,b,c){var s=b-a.length
if(s<=0)return a
return this.af(c,s)+a},
T(a,b){var s
A.D(b)
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
gO(a){return A.bM(t.N)},
gm(a){return a.length},
h(a,b){if(b>=a.length)throw A.l(A.fu(a,b))
return a[b]},
$iP:1,
$iaL:1,
$iiQ:1,
$ic:1}
A.c1.prototype={
gt(a){return new A.d8(J.ac(this.ga5()),A.i(this).j("d8<1,2>"))},
gm(a){return J.au(this.ga5())},
gF(a){return J.lE(this.ga5())},
ga8(a){return J.ny(this.ga5())},
a4(a,b){var s=A.i(this)
return A.lK(J.lF(this.ga5(),b),s.c,s.y[1])},
I(a,b){return A.i(this).y[1].a(J.fz(this.ga5(),b))},
gu(a){return A.i(this).y[1].a(J.bP(this.ga5()))},
gM(a){return A.i(this).y[1].a(J.l1(this.ga5()))},
q(a){return J.d4(this.ga5())}}
A.d8.prototype={
l(){return this.a.l()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iU:1}
A.c8.prototype={
ga5(){return this.a}}
A.dL.prototype={$iz:1}
A.dK.prototype={
h(a,b){return this.$ti.y[1].a(J.d3(this.a,b))},
i(a,b,c){var s=this.$ti
J.l0(this.a,b,s.c.a(s.y[1].a(c)))},
sm(a,b){J.nB(this.a,b)},
k(a,b){var s=this.$ti
J.bO(this.a,s.c.a(s.y[1].a(b)))},
$iz:1,
$iq:1}
A.ae.prototype={
b_(a,b){return new A.ae(this.a,this.$ti.j("@<1>").A(b).j("ae<1,2>"))},
ga5(){return this.a}}
A.ev.prototype={
q(a){return"LateInitializationError: "+this.a}}
A.j9.prototype={}
A.z.prototype={}
A.w.prototype={
gt(a){var s=this
return new A.aO(s,s.gm(s),A.i(s).j("aO<w.E>"))},
gF(a){return this.gm(this)===0},
gu(a){if(this.gm(this)===0)throw A.l(A.av())
return this.I(0,0)},
gM(a){var s=this
if(s.gm(s)===0)throw A.l(A.av())
return s.I(0,s.gm(s)-1)},
bF(a,b){return this.cL(0,A.i(this).j("v(w.E)").a(b))},
aI(a,b,c){var s=A.i(this)
return new A.u(this,s.A(c).j("1(w.E)").a(b),s.j("@<w.E>").A(c).j("u<1,2>"))},
L(a,b){var s,r,q,p=this
A.i(p).j("w.E(w.E,w.E)").a(b)
s=p.gm(p)
if(s===0)throw A.l(A.av())
r=p.I(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.I(0,q))
if(s!==p.gm(p))throw A.l(A.am(p))}return r},
a4(a,b){return A.c_(this,b,null,A.i(this).j("w.E"))},
au(a){var s,r=this,q=A.ex(A.i(r).j("w.E"))
for(s=0;s<r.gm(r);++s)q.k(0,r.I(0,s))
return q}}
A.dG.prototype={
gcZ(){var s=J.au(this.a),r=this.c
if(r==null||r>s)return s
return r},
gdh(){var s=J.au(this.a),r=this.b
if(r>s)return s
return r},
gm(a){var s,r=J.au(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
I(a,b){var s=this,r=s.gdh()+b
if(b<0||r>=s.gcZ())throw A.l(A.ik(b,s.gm(0),s,"index"))
return J.fz(s.a,r)},
a4(a,b){var s,r,q=this
A.cQ(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.db(q.$ti.j("db<1>"))
return A.c_(q.a,s,r,q.$ti.c)},
e3(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.a9(n),l=m.gm(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=p.$ti.c
return b?J.lV(0,n):J.lU(0,n)}r=A.bd(s,m.I(n,o),b,p.$ti.c)
for(q=1;q<s;++q){B.a.i(r,q,m.I(n,o+q))
if(m.gm(n)<l)throw A.l(A.am(p))}return r},
cB(a){return this.e3(0,!0)}}
A.aO.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=J.a9(q),o=p.gm(q)
if(r.b!==o)throw A.l(A.am(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.I(q,s);++r.c
return!0},
$iU:1}
A.be.prototype={
gt(a){return new A.dt(J.ac(this.a),this.b,A.i(this).j("dt<1,2>"))},
gm(a){return J.au(this.a)},
gF(a){return J.lE(this.a)},
gu(a){return this.b.$1(J.bP(this.a))},
gM(a){return this.b.$1(J.l1(this.a))},
I(a,b){return this.b.$1(J.fz(this.a,b))}}
A.cd.prototype={$iz:1}
A.dt.prototype={
l(){var s=this,r=s.b
if(r.l()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iU:1}
A.u.prototype={
gm(a){return J.au(this.a)},
I(a,b){return this.b.$1(J.fz(this.a,b))}}
A.C.prototype={
gt(a){return new A.dJ(J.ac(this.a),this.b,this.$ti.j("dJ<1>"))}}
A.dJ.prototype={
l(){var s,r
for(s=this.a,r=this.b;s.l();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iU:1}
A.dB.prototype={
a4(a,b){this.b.al(0,A.ka(b))
return void 1},
gt(a){var s=this.a
return new A.dC(s.gt(s),this.b,A.i(this).j("dC<1>"))}}
A.i9.prototype={
gm(a){var s=this.a,r=B.c.R(s.gm(s),this.b)
if(r>=0)return r
return 0},
a4(a,b){this.b.al(0,A.ka(b))
return void 1},
$iz:1}
A.dC.prototype={
l(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.l()
this.b=0
return s.l()},
gp(){return this.a.gp()},
$iU:1}
A.db.prototype={
gt(a){return B.cY},
gF(a){return!0},
gm(a){return 0},
gu(a){throw A.l(A.av())},
gM(a){throw A.l(A.av())},
I(a,b){throw A.l(A.aR(b,0,0,"index",null))},
a4(a,b){A.cQ(b,"count")
return this}}
A.dc.prototype={
l(){return!1},
gp(){throw A.l(A.av())},
$iU:1}
A.ct.prototype={
gt(a){return new A.bK(J.ac(this.a),this.$ti.j("bK<1>"))}}
A.bK.prototype={
l(){var s,r
for(s=this.a,r=this.$ti.c;s.l();)if(r.b(s.gp()))return!0
return!1},
gp(){return this.$ti.c.a(this.a.gp())},
$iU:1}
A.W.prototype={
sm(a,b){throw A.l(A.bs("Cannot change the length of a fixed-length list"))},
k(a,b){A.ax(a).j("W.E").a(b)
throw A.l(A.bs("Cannot add to a fixed-length list"))}}
A.br.prototype={
gm(a){return J.au(this.a)},
I(a,b){var s=this.a,r=J.a9(s)
return r.I(s,r.gm(s)-1-b)}}
A.dY.prototype={}
A.n.prototype={$r:"+(1,2)",$s:1}
A.a.prototype={$r:"+(1,2,3)",$s:2}
A.cY.prototype={$r:"+(1,2,3,4)",$s:3}
A.aU.prototype={$r:"+run,stage,zoneId,zoneIndex(1,2,3,4)",$s:4}
A.d9.prototype={
gF(a){return this.gm(this)===0},
q(a){return A.l7(this)},
i(a,b,c){var s=A.i(this)
s.c.a(b)
s.y[1].a(c)
A.lN()},
U(a,b){A.lN()},
gaH(){return new A.c2(this.dF(),A.i(this).j("c2<aj<1,2>>"))},
dF(){var s=this
return function(){var r=0,q=1,p=[],o,n,m,l,k
return function $async$gaH(a,b,c){if(b===1){p.push(c)
r=q}for(;;)switch(r){case 0:o=s.ga9(),o=o.gt(o),n=A.i(s),m=n.y[1],n=n.j("aj<1,2>")
case 2:if(!o.l()){r=3
break}l=o.gp()
k=s.h(0,l)
r=4
return a.b=new A.aj(l,k==null?m.a(k):k,n),1
case 4:r=2
break
case 3:return 0
case 1:return a.c=p.at(-1),3}}}},
$ij:1}
A.aM.prototype={
gm(a){return this.b.length},
gbY(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
E(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.E(b))return null
return this.b[this.a[b]]},
X(a,b){var s,r,q,p
this.$ti.j("~(1,2)").a(b)
s=this.gbY()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])},
ga9(){return new A.dM(this.gbY(),this.$ti.j("dM<1>"))}}
A.dM.prototype={
gm(a){return this.a.length},
gF(a){return 0===this.a.length},
ga8(a){return 0!==this.a.length},
gt(a){var s=this.a
return new A.cv(s,s.length,this.$ti.j("cv<1>"))}}
A.cv.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c
if(r>=s.b){s.d=null
return!1}s.d=s.a[r]
s.c=r+1
return!0},
$iU:1}
A.da.prototype={
k(a,b){A.i(this).c.a(b)
A.lO()},
U(a,b){A.lO()}}
A.bR.prototype={
gm(a){return this.b},
gF(a){return this.b===0},
ga8(a){return this.b!==0},
gt(a){var s,r=this,q=r.$keys
if(q==null){q=Object.keys(r.a)
r.$keys=q}s=q
return new A.cv(s,s.length,r.$ti.j("cv<1>"))},
v(a,b){if(typeof b!="string")return!1
if("__proto__"===b)return!1
return this.a.hasOwnProperty(b)}}
A.ek.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.cg&&this.a.Y(0,b.a)&&A.lv(this)===A.lv(b)},
gK(a){return A.cM(this.a,A.lv(this),B.f,B.f)},
q(a){var s=B.a.dS([A.bM(this.$ti.c)],", ")
return this.a.q(0)+" with "+("<"+s+">")}}
A.cg.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.qf(A.kk(this.a),this.$ti)}}
A.dA.prototype={}
A.ju.prototype={
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
A.dy.prototype={
q(a){return"Null check operator used on a null value"}}
A.er.prototype={
q(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.eY.prototype={
q(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.iL.prototype={
q(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.dd.prototype={}
A.dS.prototype={
q(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$ibZ:1}
A.az.prototype={
q(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.nf(r==null?"unknown":r)+"'"},
$ibz:1,
ge9(){return this},
$C:"$1",
$R:1,
$D:null}
A.e7.prototype={$C:"$0",$R:0}
A.e8.prototype={$C:"$2",$R:2}
A.eT.prototype={}
A.eR.prototype={
q(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.nf(s)+"'"}}
A.cE.prototype={
Y(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.cE))return!1
return this.$_target===b.$_target&&this.a===b.a},
gK(a){return(A.n7(this.a)^A.eN(this.$_target))>>>0},
q(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.eO(this.a)+"'")}}
A.eQ.prototype={
q(a){return"RuntimeError: "+this.a}}
A.bA.prototype={
gm(a){return this.a},
gF(a){return this.a===0},
ga9(){return new A.a4(this,A.i(this).j("a4<1>"))},
gaH(){return new A.M(this,A.i(this).j("M<1,2>"))},
E(a){var s,r
if(typeof a=="string"){s=this.b
if(s==null)return!1
return s[a]!=null}else if(typeof a=="number"&&(a&0x3fffffff)===a){r=this.c
if(r==null)return!1
return r[a]!=null}else return this.dO(a)},
dO(a){var s=this.d
if(s==null)return!1
return this.b2(this.bV(s,a),a)>=0},
B(a,b){A.i(this).j("j<1,2>").a(b).X(0,new A.im(this))},
h(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.dP(b)},
dP(a){var s,r,q=this.d
if(q==null)return null
s=this.bV(q,a)
r=this.b2(s,a)
if(r<0)return null
return s[r].b},
i(a,b,c){var s,r,q=this,p=A.i(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.bI(s==null?q.b=q.bm():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.bI(r==null?q.c=q.bm():r,b,c)}else q.dR(b,c)},
dR(a,b){var s,r,q,p,o=this,n=A.i(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.bm()
r=o.bw(a)
q=s[r]
if(q==null)s[r]=[o.ba(a,b)]
else{p=o.b2(q,a)
if(p>=0)q[p].b=b
else q.push(o.ba(a,b))}},
ac(a,b){var s,r,q=this,p=A.i(q)
p.c.a(a)
p.j("2()").a(b)
if(q.E(a)){s=q.h(0,a)
return s==null?p.y[1].a(s):s}r=b.$0()
q.i(0,a,r)
return r},
U(a,b){var s=this
if(typeof b=="string")return s.bJ(s.b,b)
else if(typeof b=="number"&&(b&0x3fffffff)===b)return s.bJ(s.c,b)
else return s.dQ(b)},
dQ(a){var s,r,q,p,o=this,n=o.d
if(n==null)return null
s=o.bw(a)
r=n[s]
q=o.b2(r,a)
if(q<0)return null
p=r.splice(q,1)[0]
o.bK(p)
if(r.length===0)delete n[s]
return p.b},
V(a){var s=this
if(s.a>0){s.b=s.c=s.d=s.e=s.f=null
s.a=0
s.b9()}},
X(a,b){var s,r,q=this
A.i(q).j("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.l(A.am(q))
s=s.c}},
bI(a,b,c){var s,r=A.i(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.ba(b,c)
else s.b=c},
bJ(a,b){var s
if(a==null)return null
s=a[b]
if(s==null)return null
this.bK(s)
delete a[b]
return s.b},
b9(){this.r=this.r+1&1073741823},
ba(a,b){var s=this,r=A.i(s),q=new A.iq(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else{r=s.f
r.toString
q.d=r
s.f=r.c=q}++s.a
s.b9()
return q},
bK(a){var s=this,r=a.d,q=a.c
if(r==null)s.e=q
else r.c=q
if(q==null)s.f=r
else q.d=r;--s.a
s.b9()},
bw(a){return J.aK(a)&1073741823},
bV(a,b){return a[this.bw(b)]},
b2(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aY(a[r].a,b))return r
return-1},
q(a){return A.l7(this)},
bm(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ilZ:1}
A.im.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.i(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).j("~(1,2)")}}
A.iq.prototype={}
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
$iU:1}
A.ao.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.O(s,s.r,s.e,this.$ti.j("O<1>"))}}
A.O.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.am(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iU:1}
A.M.prototype={
gm(a){return this.a.a},
gF(a){return this.a.a===0},
gt(a){var s=this.a
return new A.ah(s,s.r,s.e,this.$ti.j("ah<1,2>"))}}
A.ah.prototype={
gp(){var s=this.d
s.toString
return s},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.l(A.am(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.aj(s.a,s.b,r.$ti.j("aj<1,2>"))
r.c=s.c
return!0}},
$iU:1}
A.kt.prototype={
$1(a){return this.a(a)},
$S:19}
A.ku.prototype={
$2(a,b){return this.a(a,b)},
$S:51}
A.kv.prototype={
$1(a){return this.a(A.D(a))},
$S:39}
A.b7.prototype={
q(a){return this.cf(!1)},
cf(a){var s,r,q,p,o,n=this.d_(),m=this.aN(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.b(m,q)
o=m[q]
l=a?l+A.m8(o):l+A.A(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
d_(){var s,r=this.$s
while($.k1.length<=r)B.a.k($.k1,null)
s=$.k1[r]
if(s==null){s=this.cV()
B.a.i($.k1,r,s)}return s},
cV(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.en(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.a.i(j,q,r[s])}}j=A.ey(j,!1,k)
j.$flags=3
return j}}
A.cW.prototype={
aN(){return[this.a,this.b]},
Y(a,b){if(b==null)return!1
return b instanceof A.cW&&this.$s===b.$s&&J.aY(this.a,b.a)&&J.aY(this.b,b.b)},
gK(a){return A.cM(this.$s,this.a,this.b,B.f)}}
A.cX.prototype={
aN(){return[this.a,this.b,this.c]},
Y(a,b){var s=this
if(b==null)return!1
return b instanceof A.cX&&s.$s===b.$s&&J.aY(s.a,b.a)&&J.aY(s.b,b.b)&&J.aY(s.c,b.c)},
gK(a){var s=this
return A.cM(s.$s,s.a,s.b,s.c)}}
A.cx.prototype={
aN(){return this.a},
Y(a,b){if(b==null)return!1
return b instanceof A.cx&&this.$s===b.$s&&A.oY(this.a,b.a)},
gK(a){return A.cM(this.$s,A.oe(this.a),B.f,B.f)}}
A.eq.prototype={
q(a){return"RegExp/"+this.a+"/"+this.b.flags},
dI(a){var s=this.b.exec(a)
if(s==null)return null
return new A.k0(s)},
$iiQ:1,
$iop:1}
A.k0.prototype={
h(a,b){var s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.cJ.prototype={
gO(a){return B.DQ},
$iP:1}
A.dw.prototype={}
A.eA.prototype={
gO(a){return B.DR},
$iP:1}
A.cK.prototype={
gm(a){return a.length},
$iaN:1}
A.du.prototype={
h(a,b){A.bL(b,a,a.length)
return a[b]},
i(a,b,c){A.S(c)
a.$flags&2&&A.ab(a)
A.bL(b,a,a.length)
a[b]=c},
$iz:1,
$ih:1,
$iq:1}
A.dv.prototype={
i(a,b,c){A.aV(c)
a.$flags&2&&A.ab(a)
A.bL(b,a,a.length)
a[b]=c},
$iz:1,
$ih:1,
$iq:1}
A.eB.prototype={
gO(a){return B.DS},
$iP:1}
A.eC.prototype={
gO(a){return B.DT},
$iP:1,
$iby:1}
A.eD.prototype={
gO(a){return B.DU},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1}
A.eE.prototype={
gO(a){return B.DV},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1}
A.eF.prototype={
gO(a){return B.DW},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1}
A.eG.prototype={
gO(a){return B.DY},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1}
A.eH.prototype={
gO(a){return B.DZ},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1}
A.dx.prototype={
gO(a){return B.E_},
gm(a){return a.length},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1}
A.eI.prototype={
gO(a){return B.E0},
gm(a){return a.length},
h(a,b){A.bL(b,a,a.length)
return a[b]},
$iP:1,
$ilf:1}
A.dN.prototype={}
A.dO.prototype={}
A.dP.prototype={}
A.dQ.prototype={}
A.bi.prototype={
j(a){return A.dW(v.typeUniverse,this,a)},
A(a){return A.mw(v.typeUniverse,this,a)}}
A.f5.prototype={}
A.k5.prototype={
q(a){return A.aD(this.a,null)}}
A.f4.prototype={
q(a){return this.a}}
A.cZ.prototype={$ibI:1}
A.jH.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:11}
A.jG.prototype={
$1(a){var s,r
this.a.a=t.M.a(a)
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:38}
A.jI.prototype={
$0(){this.a.$0()},
$S:2}
A.jJ.prototype={
$0(){this.a.$0()},
$S:2}
A.k3.prototype={
cN(a,b){if(self.setTimeout!=null)self.setTimeout(A.ft(new A.k4(this,b),0),a)
else throw A.l(A.bs("`setTimeout()` not found."))}}
A.k4.prototype={
$0(){this.b.$0()},
$S:0}
A.f_.prototype={}
A.k8.prototype={
$1(a){return this.a.$2(0,a)},
$S:71}
A.k9.prototype={
$2(a,b){this.a.$2(1,new A.dd(a,t.l.a(b)))},
$S:90}
A.kg.prototype={
$2(a,b){this.a(A.aV(a),b)},
$S:101}
A.cy.prototype={
gp(){var s=this.b
return s==null?this.$ti.c.a(s):s},
dd(a,b){var s,r,q
a=A.aV(a)
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
o.d=null}q=o.dd(m,n)
if(1===q)return!0
if(0===q){o.b=null
p=o.e
if(p==null||p.length===0){o.a=A.mq
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
o.a=A.mq
throw n
return!1}if(0>=p.length)return A.b(p,-1)
o.a=p.pop()
m=1
continue}throw A.l(A.ld("sync*"))}return!1},
eb(a){var s,r,q=this
if(a instanceof A.c2){s=a.a()
r=q.e
if(r==null)r=q.e=[]
B.a.k(r,q.a)
q.a=s
return 2}else{q.d=J.ac(a)
return 2}},
$iU:1}
A.c2.prototype={
gt(a){return new A.cy(this.a(),this.$ti.j("cy<1>"))}}
A.b9.prototype={
q(a){return A.A(this.a)},
$iQ:1,
gaK(){return this.b}}
A.cu.prototype={
dU(a){if((this.c&15)!==6)return!0
return this.b.b.bB(t.iW.a(this.d),a.a,t.y,t.K)},
dK(a){var s,r=this,q=r.e,p=null,o=t.z,n=t.K,m=a.a,l=r.b.b
if(t.ng.b(q))p=l.e0(q,m,a.b,o,n,t.l)
else p=l.bB(t.mq.a(q),m,o,n)
try{o=r.$ti.j("2/").a(p)
return o}catch(s){if(t.do.b(A.bN(s))){if((r.c&1)!==0)throw A.l(A.d6("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.l(A.d6("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.ag.prototype={
cA(a,b,c){var s,r,q=this.$ti
q.A(c).j("1/(2)").a(a)
s=$.a6
if(s===B.u){if(!t.ng.b(b)&&!t.mq.b(b))throw A.l(A.e2(b,"onError",u.c))}else{c.j("@<0/>").A(q.c).j("1(2)").a(a)
b=A.pG(b,s)}r=new A.ag(s,c.j("ag<0>"))
this.bb(new A.cu(r,3,a,b,q.j("@<1>").A(c).j("cu<1,2>")))
return r},
cd(a,b,c){var s,r=this.$ti
r.A(c).j("1/(2)").a(a)
s=new A.ag($.a6,c.j("ag<0>"))
this.bb(new A.cu(s,19,a,b,r.j("@<1>").A(c).j("cu<1,2>")))
return s},
de(a){this.a=this.a&1|16
this.c=a},
aM(a){this.a=a.a&30|this.a&1
this.c=a.c},
bb(a){var s,r=this,q=r.a
if(q<=3){a.a=t.F.a(r.c)
r.c=a}else{if((q&4)!==0){s=t._.a(r.c)
if((s.a&24)===0){s.bb(a)
return}r.aM(s)}A.fr(null,null,r.b,t.M.a(new A.jN(r,a)))}},
c6(a){var s,r,q,p,o,n,m=this,l={}
l.a=a
if(a==null)return
s=m.a
if(s<=3){r=t.F.a(m.c)
m.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){n=t._.a(m.c)
if((n.a&24)===0){n.c6(a)
return}m.aM(n)}l.a=m.aV(a)
A.fr(null,null,m.b,t.M.a(new A.jR(l,m)))}},
aU(){var s=t.F.a(this.c)
this.c=null
return this.aV(s)},
aV(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
bS(a){var s,r=this
r.$ti.c.a(a)
s=r.aU()
r.a=8
r.c=a
A.cV(r,s)},
cU(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.aU()
q.aM(a)
A.cV(q,r)},
be(a){var s=this.aU()
this.de(a)
A.cV(this,s)},
bN(a){var s=this.$ti
s.j("1/").a(a)
if(s.j("bn<1>").b(a)){this.bR(a)
return}this.cT(a)},
cT(a){var s=this
s.$ti.c.a(a)
s.a^=2
A.fr(null,null,s.b,t.M.a(new A.jP(s,a)))},
bR(a){A.lh(this.$ti.j("bn<1>").a(a),this,!1)
return},
bO(a){this.a^=2
A.fr(null,null,this.b,t.M.a(new A.jO(this,a)))},
$ibn:1}
A.jN.prototype={
$0(){A.cV(this.a,this.b)},
$S:0}
A.jR.prototype={
$0(){A.cV(this.b,this.a.a)},
$S:0}
A.jQ.prototype={
$0(){A.lh(this.a.a,this.b,!0)},
$S:0}
A.jP.prototype={
$0(){this.a.bS(this.b)},
$S:0}
A.jO.prototype={
$0(){this.a.be(this.b)},
$S:0}
A.jU.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.e_(t.mY.a(q.d),t.z)}catch(p){s=A.bN(p)
r=A.cB(p)
if(k.c&&t.t.a(k.b.a.c).a===s){q=k.a
q.c=t.t.a(k.b.a.c)}else{q=s
o=r
if(o==null)o=A.l2(q)
n=k.a
n.c=new A.b9(q,o)
q=n}q.b=!0
return}if(j instanceof A.ag&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=t.t.a(j.c)
q.b=!0}return}if(j instanceof A.ag){m=k.b.a
l=new A.ag(m.b,m.$ti)
j.cA(new A.jV(l,m),new A.jW(l),t.r)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.jV.prototype={
$1(a){this.a.cU(this.b)},
$S:11}
A.jW.prototype={
$2(a,b){A.dZ(a)
t.l.a(b)
this.a.be(new A.b9(a,b))},
$S:150}
A.jT.prototype={
$0(){var s,r,q,p,o,n,m,l
try{q=this.a
p=q.a
o=p.$ti
n=o.c
m=n.a(this.b)
q.c=p.b.b.bB(o.j("2/(1)").a(p.d),m,o.j("2/"),n)}catch(l){s=A.bN(l)
r=A.cB(l)
q=s
p=r
if(p==null)p=A.l2(q)
o=this.a
o.c=new A.b9(q,p)
o.b=!0}},
$S:0}
A.jS.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=t.t.a(l.a.a.c)
p=l.b
if(p.a.dU(s)&&p.a.e!=null){p.c=p.a.dK(s)
p.b=!1}}catch(o){r=A.bN(o)
q=A.cB(o)
p=t.t.a(l.a.a.c)
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.l2(p)
m=l.b
m.c=new A.b9(p,n)
p=m}p.b=!0}},
$S:0}
A.f0.prototype={}
A.fl.prototype={}
A.dX.prototype={$imk:1}
A.fh.prototype={
e1(a){var s,r,q
t.M.a(a)
try{if(B.u===$.a6){a.$0()
return}A.mN(null,null,this,a,t.r)}catch(q){s=A.bN(q)
r=A.cB(q)
A.lp(A.dZ(s),t.l.a(r))}},
dn(a){return new A.k2(this,t.M.a(a))},
h(a,b){return null},
e_(a,b){b.j("0()").a(a)
if($.a6===B.u)return a.$0()
return A.mN(null,null,this,a,b)},
bB(a,b,c,d){c.j("@<0>").A(d).j("1(2)").a(a)
d.a(b)
if($.a6===B.u)return a.$1(b)
return A.pI(null,null,this,a,b,c,d)},
e0(a,b,c,d,e,f){d.j("@<0>").A(e).A(f).j("1(2,3)").a(a)
e.a(b)
f.a(c)
if($.a6===B.u)return a.$2(b,c)
return A.pH(null,null,this,a,b,c,d,e,f)},
cv(a,b,c,d){return b.j("@<0>").A(c).A(d).j("1(2,3)").a(a)}}
A.k2.prototype={
$0(){return this.a.e1(this.b)},
$S:0}
A.kf.prototype={
$0(){A.o0(this.a,this.b)},
$S:0}
A.bt.prototype={
gt(a){var s=this,r=new A.R(s,s.r,A.i(s).j("R<1>"))
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
return t.R.a(r[b])!=null}else return this.cW(b)},
cW(a){var s=this.d
if(s==null)return!1
return this.bk(s[this.bf(a)],a)>=0},
gu(a){var s=this.e
if(s==null)throw A.l(A.ld("No elements"))
return A.i(this).c.a(s.a)},
gM(a){var s=this.f
if(s==null)throw A.l(A.ld("No elements"))
return A.i(this).c.a(s.a)},
k(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.bL(s==null?q.b=A.li():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.bL(r==null?q.c=A.li():r,b)}else return q.cO(b)},
cO(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.li()
r=p.bf(a)
q=s[r]
if(q==null)s[r]=[p.bn(a)]
else{if(p.bk(q,a)>=0)return!1
q.push(p.bn(a))}return!0},
U(a,b){var s=this
if(typeof b=="string"&&b!=="__proto__")return s.c9(s.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return s.c9(s.c,b)
else return s.da(b)},
da(a){var s,r,q,p,o=this,n=o.d
if(n==null)return!1
s=o.bf(a)
r=n[s]
q=o.bk(r,a)
if(q<0)return!1
p=r.splice(q,1)[0]
if(0===r.length)delete n[s]
o.cg(p)
return!0},
bL(a,b){A.i(this).c.a(b)
if(t.R.a(a[b])!=null)return!1
a[b]=this.bn(b)
return!0},
c9(a,b){var s
if(a==null)return!1
s=t.R.a(a[b])
if(s==null)return!1
this.cg(s)
delete a[b]
return!0},
bl(){this.r=this.r+1&1073741823},
bn(a){var s,r=this,q=new A.fb(A.i(r).c.a(a))
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.c=s
r.f=s.b=q}++r.a
r.bl()
return q},
cg(a){var s=this,r=a.c,q=a.b
if(r==null)s.e=q
else r.b=q
if(q==null)s.f=r
else q.c=r;--s.a
s.bl()},
bf(a){return J.aK(a)&1073741823},
bk(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aY(a[r].a,b))return r
return-1},
$im_:1}
A.fb.prototype={}
A.R.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.l(A.am(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.j("1?").a(r.a)
s.c=r.b
return!0}},
$iU:1}
A.is.prototype={
$2(a,b){this.a.i(0,this.b.a(a),this.c.a(b))},
$S:33}
A.H.prototype={
gt(a){return new A.aO(a,this.gm(a),A.ax(a).j("aO<H.E>"))},
I(a,b){return this.h(a,b)},
gF(a){return this.gm(a)===0},
ga8(a){return!this.gF(a)},
gu(a){if(this.gm(a)===0)throw A.l(A.av())
return this.h(a,0)},
gM(a){if(this.gm(a)===0)throw A.l(A.av())
return this.h(a,this.gm(a)-1)},
Z(a,b){var s,r
A.ax(a).j("v(H.E)").a(b)
s=this.gm(a)
for(r=0;r<s;++r){if(b.$1(this.h(a,r)))return!0
if(s!==this.gm(a))throw A.l(A.am(a))}return!1},
ai(a,b,c){var s,r,q,p=A.ax(a)
p.j("v(H.E)").a(b)
p.j("H.E()?").a(c)
s=this.gm(a)
for(r=0;r<s;++r){q=this.h(a,r)
if(b.$1(q))return q
if(s!==this.gm(a))throw A.l(A.am(a))}p=c.$0()
return p},
aI(a,b,c){var s=A.ax(a)
return new A.u(a,s.A(c).j("1(H.E)").a(b),s.j("@<H.E>").A(c).j("u<1,2>"))},
W(a,b,c,d){var s,r,q
d.a(b)
A.ax(a).A(d).j("1(1,H.E)").a(c)
s=this.gm(a)
for(r=b,q=0;q<s;++q){r=c.$2(r,this.h(a,q))
if(s!==this.gm(a))throw A.l(A.am(a))}return r},
a4(a,b){return A.c_(a,b,null,A.ax(a).j("H.E"))},
au(a){var s,r=A.ex(A.ax(a).j("H.E"))
for(s=0;s<this.gm(a);++s)r.k(0,this.h(a,s))
return r},
k(a,b){var s
A.ax(a).j("H.E").a(b)
s=this.gm(a)
this.sm(a,s+1)
this.i(a,s,b)},
b_(a,b){return new A.ae(a,A.ax(a).j("@<H.E>").A(b).j("ae<1,2>"))},
gcw(a){return new A.br(a,A.ax(a).j("br<H.E>"))},
q(a){return A.l4(a,"[","]")}}
A.a2.prototype={
X(a,b){var s,r,q,p=A.i(this)
p.j("~(a2.K,a2.V)").a(b)
for(s=this.ga9(),s=s.gt(s),p=p.j("a2.V");s.l();){r=s.gp()
q=this.h(0,r)
b.$2(r,q==null?p.a(q):q)}},
gaH(){return this.ga9().aI(0,new A.iu(this),A.i(this).j("aj<a2.K,a2.V>"))},
E(a){return this.ga9().v(0,a)},
gm(a){var s=this.ga9()
return s.gm(s)},
gF(a){var s=this.ga9()
return s.gF(s)},
q(a){return A.l7(this)},
$ij:1}
A.iu.prototype={
$1(a){var s=this.a,r=A.i(s)
r.j("a2.K").a(a)
s=s.h(0,a)
if(s==null)s=r.j("a2.V").a(s)
return new A.aj(a,s,r.j("aj<a2.K,a2.V>"))},
$S(){return A.i(this.a).j("aj<a2.K,a2.V>(a2.K)")}}
A.iv.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.A(a)
r.a=(r.a+=s)+": "
s=A.A(b)
r.a+=s},
$S:12}
A.bY.prototype={
gF(a){return this.gm(this)===0},
ga8(a){return this.gm(this)!==0},
B(a,b){var s
for(s=J.ac(A.i(this).j("h<1>").a(b));s.l();)this.k(0,s.gp())},
q(a){return A.l4(this,"{","}")},
dG(a,b){var s
A.i(this).j("v(1)").a(b)
for(s=this.gt(this);s.l();)if(!b.$1(s.gp()))return!1
return!0},
a4(a,b){return A.mf(this,b,A.i(this).c)},
gu(a){var s=this.gt(this)
if(!s.l())throw A.l(A.av())
return s.gp()},
gM(a){var s,r=this.gt(this)
if(!r.l())throw A.l(A.av())
do s=r.gp()
while(r.l())
return s},
I(a,b){var s,r
A.cQ(b,"index")
s=this.gt(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.l(A.ik(b,b-r,this,"index"))},
$iz:1,
$ih:1,
$ib4:1}
A.dR.prototype={}
A.f7.prototype={
h(a,b){var s,r=this.b
if(r==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.d8(b):s}},
gm(a){return this.b==null?this.c.a:this.aE().length},
gF(a){return this.gm(0)===0},
ga9(){if(this.b==null){var s=this.c
return new A.a4(s,A.i(s).j("a4<1>"))}return new A.f8(this)},
i(a,b,c){var s,r,q=this
A.D(b)
if(q.b==null)q.c.i(0,b,c)
else if(q.E(b)){s=q.b
s[b]=c
r=q.a
if(r==null?s!=null:r!==s)r[b]=null}else q.ci().i(0,b,c)},
E(a){if(this.b==null)return this.c.E(a)
if(typeof a!="string")return!1
return Object.prototype.hasOwnProperty.call(this.a,a)},
U(a,b){if(this.b!=null&&!this.E(b))return null
return this.ci().U(0,b)},
X(a,b){var s,r,q,p,o=this
t.lc.a(b)
if(o.b==null)return o.c.X(0,b)
s=o.aE()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.kb(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.l(A.am(o))}},
aE(){var s=t.O.a(this.c)
if(s==null)s=this.c=A.d(Object.keys(this.a),t.s)
return s},
ci(){var s,r,q,p,o,n=this
if(n.b==null)return n.c
s=A.m(t.N,t.z)
r=n.aE()
for(q=0;p=r.length,q<p;++q){o=r[q]
s.i(0,o,n.h(0,o))}if(p===0)B.a.k(r,"")
else B.a.V(r)
n.a=n.b=null
return n.c=s},
d8(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.kb(this.a[a])
return this.b[a]=s}}
A.f8.prototype={
gm(a){return this.a.gm(0)},
I(a,b){var s=this.a
if(s.b==null)s=s.ga9().I(0,b)
else{s=s.aE()
if(!(b>=0&&b<s.length))return A.b(s,b)
s=s[b]}return s},
gt(a){var s=this.a
if(s.b==null){s=s.ga9()
s=s.gt(s)}else{s=s.aE()
s=new J.c7(s,s.length,A.t(s).j("c7<1>"))}return s},
v(a,b){return this.a.E(b)}}
A.d7.prototype={
gbu(){return B.cW}}
A.fB.prototype={
bt(a){var s
t.J.a(a)
s=a.length
if(s===0)return""
s=new A.jL("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/").dE(a,0,s,!0)
s.toString
return A.ow(s)}}
A.jL.prototype={
dE(a,b,c,d){var s,r,q,p,o
t.J.a(a)
s=this.a
r=(s&3)+(c-b)
q=B.c.bp(r,3)
p=q*4
if(r-q*3>0)p+=4
o=new Uint8Array(p)
this.a=A.oN(this.b,a,b,c,!0,o,0,s)
if(p>0)return o
return null}}
A.fA.prototype={
bt(a){var s,r,q,p=A.md(0,null,a.length)
if(0===p)return new Uint8Array(0)
s=new A.jK()
r=s.dw(a,0,p)
r.toString
q=s.a
if(q<-1)A.bv(A.bc("Missing padding character",a,p))
if(q>0)A.bv(A.bc("Invalid length, must be multiple of four",a,p))
s.a=-1
return r}}
A.jK.prototype={
dw(a,b,c){var s,r=this,q=r.a
if(q<0){r.a=A.ml(a,b,c,q)
return null}if(b===c)return new Uint8Array(0)
s=A.oK(a,b,c,q)
r.a=A.oM(a,b,c,s,0,r.a)
return s}}
A.bQ.prototype={}
A.ea.prototype={}
A.dn.prototype={
q(a){var s=A.ee(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.et.prototype={
q(a){return"Cyclic error in JSON stringify"}}
A.es.prototype={
dv(a,b){var s=A.pE(a,this.gdz().a)
return s},
dD(a,b){var s=A.oP(a,this.gbu().b,null)
return s},
gbu(){return B.eB},
gdz(){return B.eA}}
A.ip.prototype={}
A.io.prototype={}
A.jZ.prototype={
cE(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.d.av(a,r,q)
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
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.d.av(a,r,q)
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
break}}else if(p===34||p===92){if(q>r)s.a+=B.d.av(a,r,q)
r=q+1
o=A.ar(92)
s.a+=o
o=A.ar(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.d.av(a,r,m)},
bd(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.l(new A.et(a,null))}B.a.k(s,a)},
b7(a){var s,r,q,p,o=this
if(o.cD(a))return
o.bd(a)
try{s=o.b.$1(a)
if(!o.cD(s)){q=A.lX(a,null,o.gc2())
throw A.l(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.bN(p)
q=A.lX(a,r,o.gc2())
throw A.l(q)}},
cD(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.q(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.cE(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.bd(a)
q.e7(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return!0}else if(t.av.b(a)){q.bd(a)
r=q.e8(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return r}else return!1},
e7(a){var s,r,q=this.c
q.a+="["
s=J.a9(a)
if(s.ga8(a)){this.b7(s.h(a,0))
for(r=1;r<s.gm(a);++r){q.a+=","
this.b7(s.h(a,r))}}q.a+="]"},
e8(a){var s,r,q,p,o,n,m=this,l={}
if(a.gF(a)){m.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.bd(s,null,!1,t.iD)
q=l.a=0
l.b=!0
a.X(0,new A.k_(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.cE(A.D(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.b(r,n)
m.b7(r[n])}p.a+="}"
return!0}}
A.k_.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.i(s,r.a++,a)
B.a.i(s,r.a++,b)},
$S:12}
A.jY.prototype={
gc2(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.bw.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.bw&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gK(a){return A.cM(this.a,this.b,B.f,B.f)},
T(a,b){var s
t.cs.a(b)
s=B.c.T(this.a,b.a)
if(s!==0)return s
return B.c.T(this.b,b.b)},
q(a){var s=this,r=A.lP(A.eM(s)),q=A.bx(A.m6(s)),p=A.bx(A.m2(s)),o=A.bx(A.m3(s)),n=A.bx(A.m5(s)),m=A.bx(A.m7(s)),l=A.hg(A.m4(s)),k=s.b,j=k===0?"":A.hg(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
bD(){var s=this,r=A.eM(s)>=-9999&&A.eM(s)<=9999?A.lP(A.eM(s)):A.nR(A.eM(s)),q=A.bx(A.m6(s)),p=A.bx(A.m2(s)),o=A.bx(A.m3(s)),n=A.bx(A.m5(s)),m=A.bx(A.m7(s)),l=A.hg(A.m4(s)),k=s.b,j=k===0?"":A.hg(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iaL:1}
A.hh.prototype={
$1(a){if(a==null)return 0
return A.fv(a)},
$S:13}
A.hi.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.b(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:13}
A.cc.prototype={
Y(a,b){if(b==null)return!1
return b instanceof A.cc},
gK(a){return B.c.gK(0)},
T(a,b){t.jS.a(b)
return 0},
q(a){return"0:00:00."+B.d.dX(B.c.q(0),6,"0")},
$iaL:1}
A.f3.prototype={
q(a){return this.G()},
$ia_:1}
A.Q.prototype={
gaK(){return A.oi(this)}}
A.e3.prototype={
q(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.ee(s)
return"Assertion failed"}}
A.bI.prototype={}
A.bk.prototype={
gbj(){return"Invalid argument"+(!this.a?"(s)":"")},
gbi(){return""},
q(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gbj()+q+o
if(!s.a)return n
return n+s.gbi()+": "+A.ee(s.gbx())},
gbx(){return this.b}}
A.dz.prototype={
gbx(){return A.y(this.b)},
gbj(){return"RangeError"},
gbi(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.A(q):""
else if(q==null)s=": Not greater than or equal to "+A.A(r)
else if(q>r)s=": Not in inclusive range "+A.A(r)+".."+A.A(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.A(r)
return s}}
A.ej.prototype={
gbx(){return A.aV(this.b)},
gbj(){return"RangeError"},
gbi(){if(A.aV(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gm(a){return this.f}}
A.dI.prototype={
q(a){return"Unsupported operation: "+this.a}}
A.eW.prototype={
q(a){return"UnimplementedError: "+this.a}}
A.dF.prototype={
q(a){return"Bad state: "+this.a}}
A.e9.prototype={
q(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.ee(s)+"."}}
A.eK.prototype={
q(a){return"Out of Memory"},
gaK(){return null},
$iQ:1}
A.dE.prototype={
q(a){return"Stack Overflow"},
gaK(){return null},
$iQ:1}
A.jM.prototype={
q(a){return"Exception: "+this.a}}
A.df.prototype={
q(a){var s,r,q,p,o,n,m,l,k,j,i,h=this.a,g=""!==h?"FormatException: "+h:"FormatException",f=this.c,e=this.b
if(typeof e=="string"){if(f!=null)s=f<0||f>e.length
else s=!1
if(s)f=null
if(f==null){if(e.length>78)e=B.d.av(e,0,75)+"..."
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
k=""}return g+l+B.d.av(e,i,j)+k+"\n"+B.d.af(" ",f-i+l.length)+"^\n"}else return f!=null?g+(" (at offset "+A.A(f)+")"):g}}
A.h.prototype={
b_(a,b){return A.lK(this,A.i(this).j("h.E"),b)},
aI(a,b,c){var s=A.i(this)
return A.l8(this,s.A(c).j("1(h.E)").a(b),s.j("h.E"),c)},
bF(a,b){var s=A.i(this)
return new A.C(this,s.j("v(h.E)").a(b),s.j("C<h.E>"))},
W(a,b,c,d){var s,r
d.a(b)
A.i(this).A(d).j("1(1,h.E)").a(c)
for(s=this.gt(this),r=b;s.l();)r=c.$2(r,s.gp())
return r},
Z(a,b){var s
A.i(this).j("v(h.E)").a(b)
for(s=this.gt(this);s.l();)if(b.$1(s.gp()))return!0
return!1},
gm(a){var s,r=this.gt(this)
for(s=0;r.l();)++s
return s},
gF(a){return!this.gt(this).l()},
ga8(a){return!this.gF(this)},
a4(a,b){return A.mf(this,b,A.i(this).j("h.E"))},
gu(a){var s=this.gt(this)
if(!s.l())throw A.l(A.av())
return s.gp()},
gM(a){var s,r=this.gt(this)
if(!r.l())throw A.l(A.av())
do s=r.gp()
while(r.l())
return s},
ai(a,b,c){var s,r
A.i(this).j("v(h.E)").a(b)
for(s=this.gt(this);s.l();){r=s.gp()
if(b.$1(r))return r}throw A.l(A.av())},
dJ(a,b){return this.ai(0,b,null)},
I(a,b){var s,r
A.cQ(b,"index")
s=this.gt(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.l(A.ik(b,b-r,this,"index"))},
q(a){return A.o5(this,"(",")")}}
A.aj.prototype={
q(a){return"MapEntry("+A.A(this.a)+": "+A.A(this.b)+")"}}
A.ap.prototype={
gK(a){return A.K.prototype.gK.call(this,0)},
q(a){return"null"}}
A.K.prototype={$iK:1,
Y(a,b){return this===b},
gK(a){return A.eN(this)},
q(a){return"Instance of '"+A.eO(this)+"'"},
gO(a){return A.q8(this)},
toString(){return this.q(this)}}
A.fm.prototype={
q(a){return""},
$ibZ:1}
A.cS.prototype={
gm(a){return this.a.length},
q(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$iov:1}
A.ii.prototype={
gd1(){var s,r=this.a
A:{if("pt"===r){s=0
break A}if("en"===r){s=1
break A}if("es"===r){s=2
break A}s=-1
break A}return s},
$2(a,b){var s,r,q,p={}
A.D(a)
t.md.a(b)
s=B.f5.h(0,a)
p.a=null
if(s==null)p.a=a
else{r=this.gd1()
A:{if(0===r){q=s.a
break A}if(2===r){q=s.c
break A}if(1===r){q=s.b
break A}q=$.kd.h(0,this.a)
q=q==null?null:q.a.h(0,a)
if(q==null)q=s.b
break A}p.a=q}if(b!=null)b.X(0,new A.ij(p))
return p.a},
$1(a){return this.$2(a,null)}}
A.ij.prototype={
$2(a,b){var s,r
A.D(a)
A.D(b)
s=this.a
r=s.a
return s.a=A.qu(r,"{"+a+"}",b)},
$S:41}
A.hl.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"project",r.a)
q.i(0,"lang",r.b)
s=r.c
if(s!=null)q.i(0,"strings",s)
q.i(0,"sizeZones",r.d)
q.i(0,"sizeMain",r.e)
return q}}
A.hm.prototype={
n(){var s=this.a.n(),r=this.b,q=A.t(r),p=q.j("u<1,j<c,@>>")
r=A.p(new A.u(r,q.j("j<c,@>(1)").a(new A.hn()),p),p.j("w.E"))
return A.V(["results",s,"entities",r,"nextId",this.c],t.N,t.z)}}
A.hn.prototype={
$1(a){return t.h.a(a).n()},
$S:14}
A.kF.prototype={
$1(a){return this.a.$1(A.D(a))},
$S:52}
A.kG.prototype={
$1(a){var s=A.m(t.N,t.z)
J.l0(s,"type","progress")
J.lC(s,a.n())
return this.a.$1(s)},
$S:60}
A.bl.prototype={
G(){return"DesignStage."+this.b}}
A.ca.prototype={
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
A.ec.prototype={
am(a){var s=this.c.c.h(0,a)
s=s==null?null:s.a
return s==null?this.c.e.h(0,a):s},
ck(a){var s,r,q,p,o,n,m,l=null,k=this.a,j=k.c,i=j.N(a.at),h=i==null,g=h?l:i.f
if(g==null)g=a.ax
k=k.b
s=h?l:i.w
if(s==null)s=a.ay
h=h?l:i.x
if(h==null)h=0.15
r=new A.iW(a.z,a.d,a.x,a.Q,a.as,g,s*k.cx+k.cy,h,k.b,A.fx(k.c),a.ch,a.CW,a.cx,a.cy,a.db,a.dx,a.dy,a.fr,a.fx,a.fy,a.go,Math.max(k.e,3))
q=this.c.Q
p=q==null||q.c.length===0?l:A.qa(r,a.w,a.y*3.141592653589793/180,q.gdC())
o=a.c
if(!(o.length!==0)){k=a.k1
o=k.length!==0?k:this.b.$1("tool.pivot")}k=A.d([],t.dD)
j=j.a_(a.e)
j=j==null?l:j.f
if(j==null)j=B.eV
h=j.length
n=0
for(;n<j.length;j.length===h||(0,A.k)(j),++n){m=j[n]
k.push(new A.n(m.b,m.c))}return A.pR(r,p,a.a,o,k)},
bg(a){var s,r,q,p,o=this
if(o.c.e.E(a)){s=o.a.a6(a)
if(!(s instanceof A.b3))return B.bw
r=o.d.d
q=r.h(0,a)
if(q==null)q=o.ck(s)
r.i(0,a,q)
return new A.n(q.e,q.r)}r=o.d.c
p=r.h(0,a)
if(p==null)p=o.aB(a)
r.i(0,a,p)
return new A.n(p.d,p.r)},
aX(a){var s=this.e.h(0,a.f)
if(s==null)s=a.x
return this.a.c.N(s)},
aw(a){var s,r,q=a.y
if(q!=null)return this.a.c.ad(q).f/1000
s=this.aX(a)
if(s!=null)return s.f/1000
r=this.a.c.ab(a.Q)
return r.length===0?0.05:B.a.gu(r).f/1000},
aA(a){var s
switch(a.Q.a){case 0:s=this.a.b.f
break
case 1:s=this.a.b.d
break
case 2:s=this.a.b.e
break
default:s=null}return s},
bh(a){var s=this.a.b
s=s.w&&a.Q!==B.p?1+s.r/100:1
return Math.max(a.w*s,0.001)},
ce(a){var s,r,q,p,o,n,m,l,k,j=this,i=null
switch(a.d.a){case 0:s=j.a
r=s.c.ad(a.y)
q=j.aX(a)
s=s.b
p=r==null
o=p?i:r.CW
if(o==null)o=q==null?i:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?i:q.x/1000
n=p==null?0.0000015:p}p=j.aw(a)
m=j.bh(a)
l=s.w?a.as:0
return A.ef(!1,i,p,a.b,o*s.cx+s.cy,a.a,B.ao,m,l,0,i,n,a,a.c)
case 1:q=j.a.c.a3(a.ay)
s=q==null?i:q.r
if(s==null)s=B.aX
return A.ef(!1,s,0.05,a.b,150,a.a,B.bh,1,0,0,i,0.0000015,a,a.c)
case 3:q=j.a.c.a3(a.ay)
s=q==null
k=s?i:q.r
if(k==null)k=B.I
p=k.a>0?k:B.aX
return A.ef((s?i:q.e)===B.T,p,0.05,a.b,150,a.a,B.bh,1,0,0,i,0.0000015,a,a.c)
case 4:q=j.a.c.a3(a.ay)
s=q==null?i:q.r
return A.ef(!1,s,0.05,a.b,150,a.a,B.M,1,0,a.ax,i,0.0000015,a,a.c)
case 2:q=j.a.c.ar(a.ch)
if(q==null)s=i
else{s=q.w
s=new A.cP(s.a,s.b,s.c,a.CW)}return A.ef(!1,i,0.05,a.b,150,a.a,B.bg,1,0,0,s,0.0000015,a,a.c)}},
bZ(a,b,c){var s,r,q,p
if(c<=0)return 0
s=this.a.b
r=b.f/1000
q=this.bh(a)
p=A.mY(b.w*s.cx+s.cy,r,c,A.fx(s.c),q,s.b,b.x/1000)
return p+(s.w&&a.as>0?A.n6(r,c,a.as):0)},
bT(a,b){var s,r,q,p,o,n,m,l,k=this
if(b<=0)return 0
s=k.a
r=s.c.ad(a.y)
q=k.aX(a)
s=s.b
p=r==null
o=p?null:r.CW
if(o==null)o=q==null?null:q.w
if(o==null)o=150
if(!p)n=r.ch/1000
else{p=q==null?null:q.x/1000
n=p==null?0.0000015:p}m=k.aw(a)
p=k.bh(a)
l=A.mY(o*s.cx+s.cy,m,b,A.fx(s.c),p,s.b,n)
return l+(s.w&&a.as>0?A.n6(m,b,a.as):0)},
aS(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.Q.a(c)
s=A.V([a,null],t.N,t.B)
r=A.d([a],t.s)
for(q=0;q<r.length;q=p){p=q+1
o=r[q]
if(o===b)break
for(n=this.c.a.h(0,o).w,m=n.length,l=0;l<n.length;n.length===m||(0,A.k)(n),++l){k=n[l]
if(!c.v(0,k.a))continue
j=k.b
if(o===j)j=k.c
if(!s.E(j)){s.i(0,j,k)
B.a.k(r,j)}}}if(!s.E(b))return B.eT
i=A.d([],t.I)
for(h=b;h!==a;){n=s.h(0,h)
n.toString
B.a.k(i,n)
g=n.b
h=h===g?n.c:g}n=t.g9
n=A.p(new A.br(i,n),n.j("w.E"))
return n},
aL(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g
t.bq.a(a)
t.Q.a(b)
s=t.N
r=A.m(s,t.B)
q=A.m(s,s)
p=A.m(s,t.S)
o=A.d([],t.s)
for(s=J.ac(a);s.l();){n=s.gp()
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
c3(a,b){var s,r,q,p
t.c8.a(a)
s=A.d([],t.I)
for(r=b;;){q=a.h(0,r)
if(q==null)break
B.a.k(s,q)
p=q.b
r=r===p?q.c:p}return s},
aR(a,b){var s,r,q,p
t.d.a(b)
for(s=b.length,r=a.f+1e-9,q=0;q<s;++q){p=b[q]
if(p.f>r)return p}return null},
S(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a.b
e=A.m0(A.fx(e.c),e.b)
s=t.N
r=A.m(s,t.b)
q=A.d([],t.lp)
p=new A.eh(e,r,q)
o=f.c.c.h(0,a).b
n=f.c.f.h(0,a)
if(n==null)n=A.L(s)
for(e=A.as(n,n.r,A.i(n).c),m=e.$ti.c;e.l();){l=e.d
if(l==null)l=m.a(l)
k=f.c.a.h(0,l)
k.toString
if(l===o){j=k.Q
i=j==null
h=i?k.c-k.e:j
r.i(0,l,new A.bo(l,B.Z,h,(i?k.c-k.e:j)+b,null,1,0))
continue}j=k.Q
g=new A.bo(l,B.Y,j==null?k.c-k.e:j,null,null,1,0)
r.i(0,l,g)
f.bP(p,g,k,c)}e=f.c.r.h(0,a)
if(e==null)e=A.L(s)
e=A.as(e,e.r,A.i(e).c)
s=e.$ti.c
while(e.l()){r=e.d
if(r==null)r=s.a(r)
r=f.c.aj(r)
r.toString
B.a.k(q,f.ce(r))}return p},
bP(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=c.f,e=f.length
if(e===0)return
if(!d){b.d=B.a.W(f,0,new A.hA(),t.i)
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
s.i(0,h,new A.bo(h,B.Y,g,null,j,k.d,k.x))
B.a.k(q,new A.dg("sat_"+h,r,h,B.ao,0.5,0.01,150,0.0000015,0,!1,null,null,0,B.n))
m=i}}}},
aQ(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this.c.f.h(0,a)
if(d==null)d=A.L(t.N)
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
n+=e}}if(n===0)return B.bw
return new A.n(p/n,o/n)},
ah(g3,g4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8=f6.a,f9=t.e.a(f8.a6(g3)),g0=t.s,g1=A.d([],g0),g2=f9==null
if(g2||!f6.c.c.E(g3)){f8=g2?f7:f9.f
if(f8==null)f8=""
return f6.bU(g3,f8,A.d(["valve_missing"],g0))}s=f6.c.c.h(0,g3)
r=s.a
q=s.b
g2=f6.c.a.h(0,q)
g2.toString
p=f6.c.f.h(0,g3)
if(p==null)p=A.L(t.N)
if(p.a>1){o=f6.c.r.h(0,g3)
o=o==null?f7:o.a===0
o=o!==!1}else o=!0
if(o)return f6.bU(g3,f9.f,A.d(["zone_empty"],g0))
n=f9.w
g0=n==null
if(!g0)m=f6.S(g3,n,g4).H()
else if(!g4){l=f6.aQ(g3,f6.S(g3,10,!1).H())
n=10+(l.b-l.a)
m=f6.S(g3,n,!1).H()}else{k=f6.aQ(g3,f6.S(g3,10,!1).H()).b
j=Math.max(k*3,5)
m=f6.S(g3,j,!0).H()
i=0
for(;;){if(!(f6.aQ(g3,m).a<k&&i<20))break
j*=2
m=f6.S(g3,j,!0).H();++i}for(h=0,g=0;g<28;++g){f=(h+j)/2
if(f6.aQ(g3,f6.S(g3,f,!0).H()).a>k)j=f
else h=f
if(j-h<0.001)break}n=(h+j)/2
m=f6.S(g3,n,!0).H()
g4=!0}if(!m.a)B.a.k(g1,"not_converged")
if(g0){g0=f6.d7(g3,m).a
e=g0[0]
d=g0[1]
c=g0[2]
b=g0[3]
if(d-e<=b-c+1e-9)g0=e<c-0.000001||d>b+0.000001
else g0=!1
if(g0){n+=(c+b)/2-(e+d)/2
m=f6.S(g3,n,g4).H()}}a=A.d([],t.w)
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
b1=a1.p1
if(b1>0&&d1>0){b1/=200
a5=Math.max(a5,d1*(1-b1))
a6=Math.min(a6,d1*(1+b1))}d2=g0?a9/a8:0
d3=f6.cY(a)
d4=A.oE(a0,d3,d2)
d5=A.d([],t.A)
d6=A.d([],t.c)
g0=f6.c.r.h(0,g3)
if(g0==null)g0=A.L(t.N)
g0=A.as(g0,g0.r,A.i(g0).c)
b1=m.d
b2=g0.$ti.c
f8=f8.c
b4=f6.e
while(g0.l()){b5=g0.d
if(b5==null)b5=b2.a(b5)
b6=f6.c.aj(b5)
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
if(b6.d===B.e){e0=b4.h(0,b7)
e1=f8.N(e0==null?b6.x:e0)
e2=f8.ad(b6.y)
e3=f6.aw(b6)
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
B.a.k(d5,new A.bg(b5,b7,b6.r,b6.cx,b6.cy,c7,e5,b6.w,e3,e7,e8,c1,e4,e9,d8-c5,d9-c6,c8,g3,e4>f6.aA(b6)+0.000001))
if(e4>f6.aA(b6)+0.000001)B.a.k(g1,"velocity_exceeded:"+b7)
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
B.a.k(d6,new A.bS(b7,b5,c1,c5,c6,d8-c9,d9-c4,e5.b,c7))
b5=c0.Q
c1=b5==null
c4=c1?c0.c-c0.e:b5
if(c1)b5=c0.c-c0.e
if(f6.cc(b6,d7,d8-c4,b5))B.a.k(g1,"pump_suction_lift:"+b7)}}for(g0=a.length,o=a5-0.000001,b1=a6+0.000001,b8=0;b8<g0;++b8){f0=a[b8]
b2=f0.e
if(!(b2>=o&&b2<=b1)){g0=f0.a
B.a.k(g1,b2<a5?"outlet_under_pressure:"+g0:"outlet_over_pressure:"+g0)
break}}f1=f8.a3(f9.e)
g0=f1==null
f2=g0?f7:f1.r.b4(a2)
if(f2==null)f2=0
if(!g0)o=a2>f1.x+1e-9||a2<f1.w-1e-9
else o=!1
if(o)B.a.k(g1,"valve_flow_out_of_range")
o=f6.c.r.h(0,g3)
if(o==null)o=A.L(t.N)
o=A.as(o,o.r,A.i(o).c)
b1=o.$ti.c
f3=0
while(o.l()){b2=o.d
if(b2==null)b2=b1.a(b2)
f4=f6.c.aj(b2)
if(f4.d!==B.e)continue
e2=f8.ad(f4.y)
b2=e2==null?f7:e2.cx
if(b2==null){e0=b4.h(0,f4.f)
b2=f8.N(e0==null?f4.x:e0)
b2=b2==null?f7:b2.Q}if(b2==null)b2=0
f3+=b2*f4.w}f8=n+f2
f5=A.mS(a1.Q,a2,f8,a1.ax,a1.as)
a1=f6.c.a.h(0,r)
a1.toString
o=f9.f
g2=g2.gaC()
b1=a1.gaC()
b2=A.cH(g1,t.N)
b2=A.p(b2,A.i(b2).c)
a1=a1.gaC()
g0=g0?f7:f1.b
if(g0==null)g0=""
b4=g4?f6.d6(g3,a):0
return A.lg(a6,a5,f5,m.a,d6,n,b0,d3,a4,a3,d1,a,b4,f3,d5,f8+(g2-b1),a2,d4,a1,g3,f2,g0,b2,o)},
aB(a){return this.ah(a,!0)},
cY(a){var s,r,q,p,o,n,m,l,k,j
t.ms.a(a)
if(a.length===0)return Math.max(1,this.a.b.fy)
for(s=this.a,r=B.a.gt(s.e),q=new A.bK(r,t.jc),p=t.mu;q.l();){o=p.a(r.gp())
n=o.w
if(n<=0||o.d.length<3)continue
for(m=a.length,o=o.d,l=0,k=0;j=a.length,k<j;a.length===m||(0,A.k)(a),++k)if(A.qn(a[k].c,o))++l
if(l*2>=j)return n}return Math.max(1,s.b.fy)},
d6(a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=null
t.ms.a(a8)
if(a8.length===0)return 0
s=A.t(a8)
r=new A.u(a8,s.j("c(1)").a(new A.hH()),s.j("u<1,c>")).au(0)
q=A.d([],t.h0)
p=A.d([],t.iv)
for(s=A.as(r,r.r,A.i(r).c),o=this.a,n=s.$ti.c;s.l();){m=s.d
l=o.a6(m==null?n.a(m):m)
if(l instanceof A.al)B.a.k(q,l)
if(l instanceof A.b0)B.a.k(p,l)}for(s=a8.length,k=0,j=0,i=0;i<s;++i){h=a8[i]
n=h.w
k+=h.e*n
j+=n}k=j>0?k/j:0
if(q.length!==0){g=B.a.gu(q)
s=o.c.a_(g.r)
f=s==null?a6:s.aD(g.w)
e=f==null?a6:f.c.cu(k)
if(e==null)e=0
if(e<=0)return 0
d=A.d([],t.n)
for(s=q.length,i=0;i<q.length;q.length===s||(0,A.k)(q),++i){c=q[i]
o=c.d
if(J.au(o)<2)continue
b=A.kD(o,A.aX(o)/2)
for(o=q.length,a=1/0,a0=0;a0<q.length;q.length===o||(0,A.k)(q),++a0){a1=q[a0]
if(c===a1)continue
a=Math.min(a,a1.dB(b))}if(isFinite(a))B.a.k(d,a)}if(d.length===0)return 0
B.a.a0(d)
s=d.length
o=s/2|0
if(!(o<s))return A.b(d,o)
return A.n0(e,g.y,d[o])}if(p.length>=4){h=B.a.gu(p)
s=o.c.a_(h.f)
f=s==null?a6:s.aD(h.r)
e=f==null?a6:f.c.cu(k)
if(e==null)e=0
if(e<=0)return 0
a2=A.d([],t.n)
a3=p.length>400?B.a.cK(p,0,400):p
for(s=a3.length,i=0;o=a3.length,i<o;a3.length===s||(0,A.k)(a3),++i){c=a3[i]
for(n=c.d,m=n.a,n=n.b,a=1/0,a0=0;a0<a3.length;a3.length===o||(0,A.k)(a3),++a0){a1=a3[a0]
if(c===a1)continue
a4=a1.d
a5=m-a4.a
a4=n-a4.b
a=Math.min(a,Math.sqrt(a5*a5+a4*a4))}if(isFinite(a))B.a.k(a2,a)}if(a2.length===0)return 0
B.a.a0(a2)
s=a2.length
o=s/2|0
if(!(o<s))return A.b(a2,o)
g=a2[o]
return A.n0(e,g,g)}return 0},
d7(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this.c.f.h(0,a)
if(c==null)c=A.L(t.N)
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
n=Math.min(n,f.r)}}if(!isFinite(q))return B.DB
return new A.cY([q,p,o,n])},
bU(a,b,c){return A.lg(0,0,0,!1,B.bl,0,0,1,0,0,0,B.eU,0,0,B.bm,0,0,B.cR,0,a,0,"",t.bF.a(c),b)},
bq(a){var s,r,q,p,o,n
t.bq.a(a)
s=A.m(t.N,t.e5)
for(r=A.as(a,a.r,A.i(a).c),q=this.a.c,p=r.$ti.c;r.l();){o=r.d
if(o==null)o=p.a(o)
n=this.c.aj(o)
if(n.d!==B.e||!n.z||n.y!=null)continue
if(q.ab(n.Q).length===0)continue
J.bO(s.ac(n.f,new A.hT()),n)}return s},
ag(a){var s=this.r
if(s==null)s=this.r=this.a.c.cI()
s=s.h(0,a.a)
return s==null?a.Q:s},
aO(a,b,c,d){var s,r,q,p,o,n
t.e5.a(a)
t.U.a(c)
t.hZ.a(d)
for(s=J.ac(a),r=b.f/1000,q=0;s.l();){p=s.gp()
if(!d.v(0,p))continue
o=this.aw(p)
n=c.h(0,p.a)
if(n==null)n=0
q+=Math.abs(n)*(1-Math.pow(o/r,4.871))}return q},
az(a){return J.nx(t.e5.a(a),0,new A.hS(),t.i)},
aZ(a,b){var s=this.a.c.ab(a.Q),r=A.t(s),q=r.j("C<1>"),p=A.p(new A.C(s,r.j("v(1)").a(new A.hU(this,b,a)),q),q.j("h.E"))
return p.length===0?A.d([B.a.gM(s)],t.D):p},
c1(a){var s
switch(a.Q.a){case 0:s=Math.max(1,this.a.b.ch)
break
case 1:s=Math.max(1,this.a.b.CW)
break
case 2:s=Math.max(1,this.a.b.fx)
break
default:s=null}return s},
bc(a){a.b.X(0,new A.hu(this))},
dk(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.L.a(b)
s=A.d([],t.s)
for(r=A.i(b),q=new A.M(b,r.j("M<1,2>")).gt(0),p=t.G,o=d.a.c,n=d.e;q.l();){m=q.d
n.i(0,m.a,B.a.gu(o.ab(p.a(J.bP(m.b)).Q)).a)}for(r=r.j("ah<1,2>"),l=0;l<4;++l){k=d.S(a,10,!1).H()
for(q=new A.ah(b,b.r,b.e,r),p=k.d,j=!1;q.l();){m=q.d
for(o=m.b,i=J.a1(o),h=i.gt(o),g=0;h.l();){f=p.h(0,h.gp().a)
f=f==null?null:f.a
g=Math.max(g,Math.abs(f==null?0:f))}e=B.a.gu(d.aZ(i.gu(o),g))
h=e.f/1000
if(g/(3.141592653589793*h*h/4)>d.aA(i.gu(o))+0.000001)B.a.k(s,"velocity_exceeded:"+m.a)
o=m.a
i=e.a
if(n.h(0,o)!==i){n.i(0,o,i)
j=!0}}if(!j)break}return s},
ca(a9,b0,b1,b2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=this
t.L.a(b0)
t.bF.a(b1)
s=a8.c.c.h(0,a9).b
r=a8.c.r.h(0,a9)
if(r==null)r=A.L(t.N)
q=a8.e
p=a8.f
o=A.i(b0).j("ah<1,2>")
n=a8.a.c
m=t.G
l=t.N
k=t.i
j=0
for(;;){if(j<400)i=!(b2.w>=b2.y-0.000001&&b2.x<=b2.z+0.000001)
else i=!1
if(!i)break
h=b2.gbz()
if(h==null)break
g=a8.bo(a9,h)
if(g==null)break
i=a8.aS(s,g,r)
f=A.cH(i,A.t(i).c)
i=A.m(l,k)
for(e=b2.at,d=e.length,c=0;c<e.length;e.length===d||(0,A.k)(e),++c){b=e[c]
i.i(0,b.a,b.at)}for(e=new A.ah(b0,b0.r,b0.e,o),a=null,a0=null,a1=0;e.l();){a2=e.d
d=a2.b
a3=J.a1(d)
if(!a3.Z(d,f.gaG(f)))continue
a4=m.a(a3.gu(d))
a5=q.h(0,a4.f)
a4=n.N(a5==null?a4.x:a5)
a4.toString
a6=a8.aR(a4,n.ab(m.a(a3.gu(d)).Q))
if(a6==null)continue
a7=a8.aO(d,a6,i,f)/Math.max((a8.ag(a6)-a8.ag(a4))*a8.az(d),0.000001)
if(a7>a1){a=a2.a
a1=a7
a0=a6}}if(a==null){B.a.k(b1,"cannot_meet_pressure_window")
break}q.i(0,a,a0.a)
p.U(0,a)
b2=a8.ah(a9,!1);++j}return b2},
cX(a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.dV.a(a2)
s=t.N
r=A.m(s,t.bF)
q=this.c.f.h(0,a1)
if(q==null)q=A.L(s)
q=A.as(q,q.r,A.i(q).c)
p=q.$ti.c
while(q.l()){o=q.d
if(o==null)o=p.a(o)
for(n=this.c.a.h(0,o).f,m=n.length,l=0;l<n.length;n.length===m||(0,A.k)(n),++l){k=n[l]
if(k.b===-2)continue
J.bO(r.ac(k.a,new A.hB()),o)}}j=A.L(s)
for(s=new A.O(r,r.r,r.e,r.$ti.j("O<2>")),q=t.s;s.l();){p=s.d
o=J.a9(p)
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
return A.c_(a0,0,A.cz(1500,"count",t.S),A.t(a0).c).au(0)}return j},
c_(d2,d3,d4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0=this,d1=null
t.L.a(d3)
t.Q.a(d4)
s=d0.c.c.h(0,d2).b
r=d0.c.r.h(0,d2)
if(r==null)r=A.L(t.N)
q=d0.S(d2,10,!1).H()
p=new A.hG(q)
o=d0.aL(A.d([s],t.s),r)
n=o.a
m=t.N
l=A.m(m,m)
for(k=A.i(d3),j=k.j("M<1,2>"),i=new A.M(d3,j).gt(0);i.l();){h=i.d
for(g=J.ac(h.b),f=h.a;g.l();)l.i(0,g.gp().a,f)}e=A.m(m,t.d)
d=A.m(m,t.i)
c=A.m(m,t.S)
for(j=new A.M(d3,j).gt(0);j.l();){h=j.d
for(i=h.b,g=J.a1(i),f=g.gt(i),b=0;f.l();)b=Math.max(b,A.lr(p.$1(f.gp())))
f=h.a
e.i(0,f,d0.aZ(g.gu(i),b))
d.i(0,f,d0.az(i))
c.i(0,f,d0.c1(g.gu(i)))}j=d0.c.f.h(0,d2)
if(j==null)j=A.L(m)
j=A.as(j,j.r,A.i(j).c)
i=j.$ti.c
a=0
while(j.l()){g=j.d
if(g==null)g=i.a(g)
for(g=d0.c.a.h(0,g).f,f=g.length,a0=0;a0<g.length;g.length===f||(0,A.k)(g),++a0){h=g[a0]
a+=h.c.a7(h.e)*h.d}}j=d0.a.b
i=j.ay
a1=i?A.mS(j.Q,a,1,j.ax,j.as):0
a2=d0.c.a.h(0,s).gaC()
g=A.dp(d0.cX(d2,o.c),m)
g.B(0,d4)
a3=A.d([],t.nE)
for(g=A.as(g,g.r,A.i(g).c),f=q.d,a4=t.U,a5=j.p1,a6=a5>0,a7=g.$ti.c,a5/=200,a8=1-a5,a5=1+a5;g.l();){a9=g.d
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
for(a9=d0.c3(n,a9),b1=a9.length,c1=0,a0=0;a0<a9.length;a9.length===b1||(0,A.k)(a9),++a0){c2=a9[a0]
b2=c2.a
c3=l.h(0,b2)
if(c3!=null){c4=c0.ac(c3,new A.hF())
for(b2=e.h(0,c3),b8=b2.length,c5=0;c5<b2.length;b2.length===b8||(0,A.k)(b2),++c5){c6=b2[c5]
c7=c6.a
c8=c4.h(0,c7)
if(c8==null)c8=0
c4.i(0,c7,c8+d0.bZ(c2,c6,p.$1(c2)))}}else if(c2.d===B.e)c1+=d0.bT(c2,p.$1(c2))
else{b2=f.h(0,b2)
b2=b2==null?d1:b2.c
c1+=b2==null?0:b2}}a9=b0.Q
c9=(a9==null?b0.c-b0.e:a9)+b5-a2
a9=isFinite(b3)?b3+c9:d1
B.a.k(a3,new A.dr(0,c0,c1,a9,isFinite(b4)?b4+c9:d1))}m=k.j("a4<1>")
m=A.p(new A.a4(d3,m),m.j("h.E"))
return A.n3(new A.ez(m,e,d,c,A.d([new A.ds(a1,d1,d1,"zone")],t.jv),a3,A.fs(j.y,j.z),i,d0.gc4()))},
d5(a,b){return this.c_(a,b,B.DE)},
cH(c4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1=this,c2=c1.a,c3=t.e.a(c2.a6(c4))
if(c3==null||!c1.c.c.E(c4))return c1.aB(c4)
s=c1.c.r.h(0,c4)
if(s==null)s=A.L(t.N)
r=c1.bq(s)
if(r.a===0)return c1.aB(c4)
q=c1.c.c.h(0,c4).b
p=A.d([],t.s)
B.a.B(p,c1.dk(c4,r))
o=c2.b
if(o.fr===B.a6){n=c1.d5(c4,r)
m=n.a
if(m){c1.bc(n)
l=c1.ah(c4,!1)
k=t.N
j=A.L(k)
i=t.w
h=0
for(;;){if(h<4)g=!(l.w>=l.y-0.000001&&l.x<=l.z+0.000001)
else g=!1
if(!g)break
f=A.L(k)
g=A.d([],i)
e=l.gbz()
if(e!=null)g.push(e)
e=l.gdV()
if(e!=null)g.push(e)
e=g.length
d=0
for(;d<g.length;g.length===e||(0,A.k)(g),++d){c=c1.bo(c4,g[d])
if(c!=null)f.k(0,c)}if(f.dG(0,j.gaG(j)))break
g=A.ex(k)
g.B(0,j)
g.B(0,f)
n=c1.c_(c4,r,g)
if(!n.a)break
c1.bc(n)
l=c1.ah(c4,!1);++h
j=g}}else{B.a.k(c1.d.f,"lp_infeasible:"+c3.f)
l=c1.ah(c4,!1)}}else{l=c1.ah(c4,!1)
m=!1}l=c1.ca(c4,r,p,l)
if(!m&&o.ay){b=A.fs(o.y,o.z)
for(k=c1.e,i=A.i(r).j("ah<1,2>"),g=o.ax,e=o.Q,o=o.as,c2=c2.c,a=t.G,a0=t.N,a1=t.i,a2=0;a2<200;++a2){a3=l.gbz()
if(a3==null)break
a4=c1.bo(c4,a3)
if(a4==null)break
a5=c1.aS(q,a4,s)
a6=A.cH(a5,A.t(a5).c)
a5=A.m(a0,a1)
for(a7=l.at,a8=a7.length,d=0;d<a7.length;a7.length===a8||(0,A.k)(a7),++d){a9=a7[d]
a5.i(0,a9.a,a9.at)}for(a7=new A.ah(r,r.r,r.e,i),a8=9788.99803*l.d,b0=null,b1=null,b2=0;a7.l();){b3=a7.d
b4=b3.b
b5=J.a1(b4)
if(!b5.Z(b4,a6.gaG(a6)))continue
b6=a.a(b5.gu(b4))
b7=k.h(0,b6.f)
b6=c2.N(b7==null?b6.x:b7)
b6.toString
b8=c1.aR(b6,c2.ab(a.a(b5.gu(b4)).Q))
if(b8==null)continue
b9=a8*c1.aO(b4,b8,a5,a6)/Math.max(o,0.05)/1000*g*e-(c1.ag(b8)-c1.ag(b6))*c1.az(b4)*b
if(b9>b2){b0=b3.a
b2=b9
b1=b8}}if(b0==null)break
k.i(0,b0,b1.a)
l=c1.ah(c4,!1)}}c1.c7(q,s,r)
c1.br(r)
c0=c1.ah(c4,!0)
c2=A.dp(p,t.N)
c2.B(0,c0.ch)
c2=A.p(c2,A.i(c2).c)
return c0.cn(c2)},
bo(a,b){var s,r,q,p,o,n,m,l,k=this.c.f.h(0,a)
if(k==null)k=A.L(t.N)
k=A.as(k,k.r,A.i(k).c)
s=b.a
r=b.b
q=k.$ti.c
while(k.l()){p=k.d
if(p==null)p=q.a(p)
for(o=this.c.a.h(0,p).f,n=o.length,m=0;m<n;++m){l=o[m]
if(l.a===s&&l.b===r)return p}}return null},
c7(b1,b2,b3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this
t.Q.a(b2)
t.L.a(b3)
s=t.N
r=A.m(s,s)
for(q=new A.M(b3,A.i(b3).j("M<1,2>")).gt(0);q.l();){p=q.d
for(o=J.ac(p.b),n=p.a;o.l();)r.i(0,o.gp().a,n)}m=A.V([b1,null],s,t.B)
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
B.a.k(l,e)}}}for(s=t.g9,q=s.j("aO<w.E>"),o=b0.a.c,n=b0.e,d=A.i(m).j("M<1,2>"),c=s.j("w.E"),b=b0.f,a=0;a<5;++a){for(a0=new A.br(k,s),a0=new A.aO(a0,a0.gm(0),q),a1=!1;a0.l();){a2=a0.d
if(a2==null)a2=c.a(a2)
a3=r.h(0,a2.a)
if(a3==null)continue
a4=new A.M(m,d).dJ(0,new A.hI(a2))
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
b.U(0,a7)
a1=!0
break}}}}if(!a1)break}},
br(a){var s,r,q,p,o,n,m
t.L.a(a)
for(s=new A.M(a,A.i(a).j("M<1,2>")).gt(0),r=this.a,q=this.e;s.l();){p=s.d
o=p.a
n=q.h(0,o)
if(n==null)continue
m=r.a6(o)
if(m instanceof A.aH)m.f=n
if(m instanceof A.al)m.e=n
for(o=J.ac(p.b);o.l();)o.gp().x=n}},
cS(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5=this,b6=b5.f
if(b6.a===0)return 0
s=t.N
r=A.L(s)
for(q=b5.c.c,q=new A.O(q,q.r,q.e,A.i(q).j("O<2>"));q.l();)r.k(0,q.d.b)
q=b5.c.d
p=A.i(q).j("ao<2>")
o=A.dp(new A.ao(q,p),p.j("h.E"))
s=A.L(s)
for(q=b5.c.r,q=new A.O(q,q.r,q.e,A.i(q).j("O<2>"));q.l();){p=q.d
for(p=p.gt(p);p.l();)s.k(0,A.D(p.gp()))}n=b5.aL(r,s).c
m=b5.aL(o,b5.c.x).c
for(s=new A.M(b6,A.i(b6).j("M<1,2>")).gt(0),r=b5.a,q=r.e,p=t.n,l=t.f,k=t.bw,j=t.pa,i=j.j("w.E"),h=t.s,g=0;s.l();){f=s.d
e=r.a6(f.a)
if(e!=null)d=!(e instanceof A.aH||e instanceof A.al||e instanceof A.aB)
else d=!0
if(d)continue
d=b5.c.b
c=A.t(d)
b=c.j("C<1>")
a=A.p(new A.C(d,c.j("v(1)").a(new A.hv(e)),b),b.j("h.E"))
B.a.ao(a,new A.hw())
if(a.length===0)continue
a0=B.a.gu(a).e===B.i?m:n
d=A.d([B.a.gu(a).b],h)
for(c=a.length,a1=0;a1<a.length;a.length===c||(0,A.k)(a),++a1)d.push(a[a1].c)
a2=A.p(new A.u(d,k.a(new A.hx(a0)),j),i)
if(B.a.Z(a2,new A.hy()))continue
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
else{d=J.nz(a6)
a8=A.p(d,d.$ti.j("w.E"))}a9=A.d([],p)
for(d=J.a9(a8),b0=0,a5=0;a5<d.gm(a8)-1;++a5){b0+=d.h(a8,a5).b*a7
B.a.k(a9,b0)}b1=A.qt(e,a9,new A.hz(b5))
if(b1.length<2)continue
b2=B.a.cr(q,e)
B.a.dZ(q,b2)
for(a5=0;a5<b1.length;++a5){b3=b1[a5]
b4=d.h(a8,Math.min(a5,d.gm(a8)-1)).a
if(b3 instanceof A.aH)b3.f=b4.a
if(b3 instanceof A.al)b3.e=b4.a
B.a.dN(q,b2+a5,b3)}++g}b6.V(0)
b5.e.V(0)
b5.c=A.l9(r).bs()
return g},
aP(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=t.U
c.a(a)
c.a(b)
c=d.a
s=c.b
s=A.m0(A.fx(s.c),s.b)
r=A.m(t.N,t.b)
q=A.d([],t.lp)
p=new A.eh(s,r,q)
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
r.i(0,m,new A.bo(m,B.Z,h,(i?l.c-l.e:k)+j,null,1,0))
continue}k=l.Q
g=new A.bo(m,B.Y,k==null?l.c-l.e:k,null,null,1,0)
r.i(0,m,g)
d.bP(p,g,l,!0)}for(c=d.c.c,c=new A.M(c,A.i(c).j("M<1,2>")).gt(0);c.l();){f=c.d
e=r.h(0,f.b.a)
if(e==null)continue
s=e.d
o=b.h(0,f.a)
e.d=s+(o==null?0:o)}for(c=d.c.e,c=new A.M(c,A.i(c).j("M<1,2>")).gt(0);c.l();){f=c.d
e=r.h(0,f.b)
if(e==null)continue
s=e.d
o=b.h(0,f.a)
e.d=s+(o==null?0:o)}for(c=d.c.x,c=A.as(c,c.r,A.i(c).c),s=c.$ti.c;c.l();){r=c.d
if(r==null)r=s.a(r)
r=d.c.aj(r)
r.toString
B.a.k(q,d.ce(r))}return p},
gaY(){var s=t.lF,r=s.j("C<h.E>")
s=A.p(new A.C(new A.ct(this.a.e,s),s.j("v(h.E)").a(new A.hR(this)),r),r.j("h.E"))
return s},
cc(a,b,c,d){var s
if(a.d!==B.X||b.a<=0)return!1
s=this.a.c.ar(a.ch)
if(s==null||s.f)return!1
return-c>10.33*Math.pow(1-0.0000225577*B.b.a1(d,-500,8000),5.25588)-0.24-3+0.000001},
cl(e3,e4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=null,e1=A.d([],t.s),e2=d9.gaY()
if(e2.length===0)return new A.b6(e3.a,e3.b,!1,B.eW,B.eX,B.bm,B.bl,B.f1,0,e3.e,0)
s=t.N
r=t.i
q=A.m(s,r)
p=A.m(s,r)
for(o=e3.c,o=A.as(o,o.r,A.i(o).c),n=o.$ti.c;o.l();){m=o.d
if(m==null)m=n.a(m)
if(d9.am(m)==null)continue
l=d9.bg(m)
q.i(0,m,l.a)
p.i(0,m,l.b)}r=A.m(s,r)
for(o=e2.length,k=0;k<e2.length;e2.length===o||(0,A.k)(e2),++k){j=e2[k]
n=j.e?0:j.f
r.i(0,j.a,n)}i=d9.aP(r,q).H()
o=A.t(e2)
n=o.j("C<1>")
h=A.p(new A.C(e2,o.j("v(1)").a(new A.hW()),n),n.j("h.E"))
g=new A.hX(d9,q,p)
if(h.length!==0){f=g.$1(i)
if(f>0){for(o=h.length,k=0;k<h.length;h.length===o||(0,A.k)(h),++k)r.i(0,h[k].a,f)
i=d9.aP(r,q).H()}}else f=0
o=i.a
if(!o)B.a.k(e1,"not_converged")
e=A.d([],t.eZ)
for(n=new A.an(q,q.r,q.e,q.$ti.j("an<1>")),m=i.c,d=d9.d,c=d.d,d=d.c;n.l();){b=n.d
a=d9.am(b)
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
B.a.k(e,new A.aT(b,a4,a3,a5,a6,d9.c.a.h(0,a).b))
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
if(typeof b3!=="number")return A.bu(b3)
b4=j.f+b3}b3=j.c
if(b3.length===0)b3=c.$1("name.supply")
a3=d9.c.a.h(0,a3)
b5=a3.Q
a3=b5==null?a3.c-a3.e:b5
b5=j.r
b6=j.w
B.a.k(a7,new A.cq(a2,b3,a9,a5,b4,a3,a6,j.f,b5,b6,j.x))
if(b6>0&&a9>b6+1e-9)B.a.k(e1,"supply_flow_exceeded:"+a2)
if(b5>0&&b4>b5+0.000001)B.a.k(e1,"supply_head_exceeded:"+a2)}b7=A.d([],t.A)
b8=A.d([],t.c)
for(r=d9.c.x,r=A.as(r,r.r,A.i(r).c),n=r.$ti.c,c=d9.a,a2=c.c,a3=d9.e;r.l();){a5=r.d
if(a5==null)a5=n.a(a5)
a6=d9.c.aj(a5)
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
if(b3===B.e){c2=a3.h(0,b6)
c3=a2.N(c2==null?a6.x:c2)
c4=d9.aw(a6)
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
B.a.k(b7,new A.bg(a5,b6,a6.r,a6.cx,a6.cy,c8,d1,a6.w,c4,d3,d4,b3,c5,d5,c0-c6,c1-c7,c9,e0,c5>d9.aA(a6)+0.000001))
if(c5>d9.aA(a6)+0.000001)B.a.k(e1,"velocity_exceeded:"+b6)
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
B.a.k(b8,new A.bS(b6,a5,c6,c7,c8,c0-d1,c1-b9,d2.b,c9))
if(b3===B.X){c3=a2.ar(a6.ch)
if(c3!=null)a5=c6>c3.z+1e-9||c6<=0
else a5=!1
if(a5)B.a.k(e1,"pump_out_of_range:"+b6)
a5=b5.Q
b3=a5==null
b9=b3?b5.c-b5.e:a5
if(b3)a5=b5.c-b5.e
if(d9.cc(a6,b2,c0-b9,a5))B.a.k(e1,"pump_suction_lift:"+b6)}}}d6=e4>0?e3.e/e4:1
r=c.b
d7=r.at*d6
for(n=a7.length,m=r.Q,r=r.as,d8=0,k=0;k<n;++k){c4=a7[k]
if(c4.r&&c4.e>0)d8+=9788.99803*c4.c*c4.e/Math.max(r,0.05)/1000*d7*m}for(n=b8.length,k=0;k<b8.length;b8.length===n||(0,A.k)(b8),++k){c4=b8[k]
d=c4.e
if(d>0){c3=a2.ar(d9.c.aj(c4.b).ch)
c=c3==null?e0:c3.x
if(c==null)c=r
d8+=9788.99803*c4.c*d/Math.max(c,0.05)/1000*d7*m}}s=A.cH(e1,s)
s=A.p(s,A.i(s).c)
return new A.b6(e3.a,e3.b,o,a7,e,b7,b8,s,a8,e3.e,d8)},
cp(){var s,r,q=this,p=q.a.f
if(p.length!==0)return p
p=q.b.$1("name.allZones")
s=q.c.c
s=A.dp(new A.a4(s,A.i(s).j("a4<1>")),t.N)
r=q.c.e
s.B(0,new A.a4(r,A.i(r).j("a4<1>")))
return A.d([A.mh(1,"auto",p,0,s)],t.cD)},
d4(d1,d2,d3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8=this,c9=null,d0={}
t.L.a(d1)
t.k6.a(d2)
s=c8.gaY()
r=t.N
q=A.m(r,t.v)
for(p=s.length,o=0;o<s.length;s.length===p||(0,A.k)(s),++o){n=s[o]
m=c8.c.d.h(0,n.a)
m.toString
q.i(0,m,n)}d0.a=d0.b=null
l=c8.aL(new A.a4(q,q.$ti.j("a4<1>")),c8.c.x)
d0.b=l.a
d0.a=l.b
p=A.m(r,r)
for(m=A.i(d1),k=m.j("M<1,2>"),j=new A.M(d1,k).gt(0);j.l();){i=j.d
for(h=J.ac(i.b),g=i.a;h.l();)p.i(0,h.gp().a,g)}f=A.d([],t.lH)
e=A.d([],t.gN)
for(j=d2.length,h=t.i,o=0;o<d2.length;d2.length===j||(0,A.k)(d2),++o){d=A.m(r,h)
for(g=d2[o].c,c=A.i(g),b=new A.R(g,g.r,c.j("R<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
if(c8.am(g)==null)continue
d.i(0,g,c8.bg(g).a)}B.a.k(e,d)
g=A.m(r,h)
for(c=s.length,a=0;a<s.length;s.length===c||(0,A.k)(s),++a){n=s[a]
b=n.e?0:n.f
g.i(0,n.a,b)}B.a.k(f,c8.aP(g,d).H())}a0=A.m(r,t.d)
a1=A.m(r,h)
j=t.S
a2=A.m(r,j)
for(k=new A.M(d1,k).gt(0);k.l();){i=k.d
for(h=f.length,g=i.b,c=J.a1(g),a3=0,o=0;o<f.length;f.length===h||(0,A.k)(f),++o){a4=f[o]
for(b=c.gt(g),a5=a4.d;b.l();){a6=a5.h(0,b.gp().a)
a6=a6==null?c9:a6.a
a3=Math.max(a3,Math.abs(a6==null?0:a6))}}h=i.a
a0.i(0,h,c8.aZ(c.gu(g),a3))
a1.i(0,h,c8.az(g))
a2.i(0,h,c8.c1(c.gu(g)))}a7=A.d([],t.jv)
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
B.a.k(a7,new A.ds(b9,b1,b2,n.c+"|"+d2[a9].b))}}c0=A.d([],t.nE)
for(j=c8.d,h=j.c,j=j.d,a9=0;a9<d2.length;++a9){if(!(a9<f.length))return A.b(f,a9)
a4=f[a9]
c1=new A.hC(d0,c8,q,p,a0,new A.hE(a4),a4,c0,a8,a9)
for(g=d2[a9].c,c=A.i(g),b=new A.R(g,g.r,c.j("R<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
c2=c8.am(g)
if(c2==null)continue
c3=j.h(0,g)
if(c3!=null){c1.$4(c2,c3.r,c9,0)
continue}c4=h.h(0,g)
if(c4==null)continue
c1.$4(c2,c4.r,c9,0)}for(g=c8.c.w,c=A.i(g),b=new A.R(g,g.r,c.j("R<1>")),b.c=g.e,c=c.c;b.l();){g=b.d
if(g==null)g=c.a(g)
a5=c8.c.a.h(0,g).f
a6=a5.length
if(a6===0)continue
for(c5=-1/0,c6=1/0,c7=0,o=0;o<a6;++o){i=a5[o]
c5=Math.max(c5,i.f)
c6=Math.min(c6,i.r)
c7=Math.max(c7,i.x)}if(isFinite(c5))c1.$4(g,c5,isFinite(c6)?c6:c9,c7)}}q=m.j("a4<1>")
q=A.p(new A.a4(d1,q),q.j("h.E"))
return A.n3(new A.ez(q,a0,a1,a2,a7,c0,A.fs(r.y,r.z),k,c8.gc4()))},
cG(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5=this,d6=null,d7=d5.cp(),d8=t.i,d9=B.a.W(d7,0,new A.i4(),d8),e0=d5.bq(d5.c.x),e1=new A.i3(d5,d7,d9)
if(e0.a===0||d5.gaY().length===0){d8=d5.d.e
B.a.V(d8)
B.a.B(d8,e1.$0())
return}s=d5.gaY()
r=A.t(s)
q=new A.u(s,r.j("c(1)").a(new A.i5(d5)),r.j("u<1,c>")).au(0)
for(r=A.i(e0),p=new A.M(e0,r.j("M<1,2>")).gt(0),o=t.G,n=d5.a,m=n.c,l=d5.e;p.l();){k=p.d
l.i(0,k.a,B.a.gu(m.ab(o.a(J.bP(k.b)).Q)).a)}for(r=r.j("ah<1,2>"),p=t.N,j=0;j<4;++j){i=A.m(p,d8)
for(h=d7.length,g=0;g<d7.length;d7.length===h||(0,A.k)(d7),++g){f=A.m(p,d8)
for(e=d7[g].c,d=A.i(e),c=new A.R(e,e.r,d.j("R<1>")),c.c=e.e,d=d.c;c.l();){e=c.d
if(e==null)e=d.a(e)
if(d5.am(e)==null)continue
f.i(0,e,d5.bg(e).a)}e=A.m(p,d8)
for(d=s.length,b=0;b<s.length;s.length===d||(0,A.k)(s),++b){a=s[b]
c=a.e?0:a.f
e.i(0,a.a,c)}a0=d5.aP(e,f).H()
for(e=new A.ah(e0,e0.r,e0.e,r),d=a0.d;e.l();){k=e.d
for(c=J.ac(k.b),a1=k.a;c.l();){a2=c.gp()
a3=i.h(0,a1)
if(a3==null)a3=0
a2=d.h(0,a2.a)
a2=a2==null?d6:a2.a
i.i(0,a1,Math.max(a3,Math.abs(a2==null?0:a2)))}}}for(h=new A.ah(e0,e0.r,e0.e,r),a4=!1;h.l();){k=h.d
e=J.bP(k.b)
d=k.a
c=i.h(0,d)
e=B.a.gu(d5.aZ(e,c==null?0:c)).a
if(l.h(0,d)!==e){l.i(0,d,e)
a4=!0}}if(!a4)break}n=n.b
if(n.fr===B.a6){h=d5.c.x
e=A.i(h)
a5=new A.C(h,e.j("v(1)").a(new A.i6(d5)),e.j("C<1>")).gm(0)
h=d5.c.w.a
if(a5>=h&&h!==0)B.a.k(d5.d.f,"lp_loops_approx")
a6=d5.d4(e0,d7,d9)
a7=a6.a
if(a7)d5.bc(a6)
else B.a.k(d5.d.f,"lp_infeasible:"+A.A(d5.b.$1("menu.mainline")))}else a7=!1
a8=e1.$0()
if(B.a.Z(s,new A.i7()))for(h=d5.f,e=A.i(q),d=e.j("R<1>"),e=e.c,a9=0;a9<400;++a9){for(c=a8.length,b0=d6,b1=b0,g=0;g<c;++g){b2=a8[g]
for(a1=b2.e,a2=a1.length,b=0;b<a2;++b){b3=a1[b]
a3=b3.e-b3.d
if(a3>0.01)a3=b0==null||a3>b0.e-b0.d
else a3=!1
if(a3){b0=b3
b1=b2}}}if(b1==null||b0==null)break
c=d5.am(b0.a)
c.toString
b4=A.L(o)
for(a1=new A.R(q,q.r,d),a1.c=q.e;a1.l();){a2=a1.d
if(a2==null)a2=e.a(a2)
b5=d5.aS(a2,c,d5.c.x)
a2=b5.length
if(a2!==0){a3=b4.a
a2=a3===0||a2<a3}else a2=!1
if(a2)b4=A.cH(b5,A.t(b5).c)}c=A.m(p,d8)
for(a1=b1.f,a2=a1.length,g=0;g<a1.length;a1.length===a2||(0,A.k)(a1),++g){b5=a1[g]
c.i(0,b5.a,b5.at)}for(a1=new A.ah(e0,e0.r,e0.e,r),b6=d6,b7=b6,b8=0;a1.l();){k=a1.d
a2=k.b
a3=J.a1(a2)
if(!a3.Z(a2,b4.gaG(b4)))continue
b9=o.a(a3.gu(a2))
c0=l.h(0,b9.f)
b9=m.N(c0==null?b9.x:c0)
b9.toString
c1=d5.aR(b9,m.ab(o.a(a3.gu(a2)).Q))
if(c1==null)continue
c2=d5.aO(a2,c1,c,b4)/Math.max((d5.ag(c1)-d5.ag(b9))*d5.az(a2),0.000001)
if(c2>b8){b7=k.a
b8=c2
b6=c1}}if(b7==null){B.a.k(d5.d.f,"mainline_cannot_meet_pressure")
break}l.i(0,b7,b6.a)
h.U(0,b7)
a8=e1.$0()}if(!a7&&n.ay){c3=A.fs(n.y,n.z)
for(h=n.at,e=n.Q,n=n.as,d=d9>0,c=A.i(q),a1=c.j("R<1>"),c=c.c,a9=0;a9<300;++a9){for(a2=new A.ah(e0,e0.r,e0.e,r),b6=d6,b7=b6,c4=0;a2.l();){k=a2.d
a3=k.b
b9=J.a1(a3)
c5=o.a(b9.gu(a3))
c0=l.h(0,c5.f)
c5=m.N(c0==null?c5.x:c0)
c5.toString
c1=d5.aR(c5,m.ab(o.a(b9.gu(a3)).Q))
if(c1==null)continue
for(c6=a8.length,c7=0,g=0;g<a8.length;a8.length===c6||(0,A.k)(a8),++g){b2=a8[g]
c8=b2.e
if(c8.length===0)continue
c8=d5.am(B.a.L(c8,new A.i8()).a)
c8.toString
b4=A.L(o)
for(c9=new A.R(q,q.r,a1),c9.c=q.e;c9.l();){d0=c9.d
if(d0==null)d0=c.a(d0)
b5=d5.aS(d0,c8,d5.c.x)
d0=b5.length
if(d0!==0){d1=b4.a
d0=d1===0||d0<d1}else d0=!1
if(d0)b4=A.cH(b5,A.t(b5).c)}if(!b9.Z(a3,b4.gaG(b4)))continue
c8=A.m(p,d8)
for(c9=b2.f,d0=c9.length,b=0;b<c9.length;c9.length===d0||(0,A.k)(c9),++b){b5=c9[b]
c8.i(0,b5.a,b5.at)}d2=d5.aO(a3,c1,c8,b4)
d3=d?b2.y/d9:1
c7+=9788.99803*b2.x*d2/Math.max(n,0.05)/1000*(h*d3)*e}d4=c7-(d5.ag(c1)-d5.ag(c5))*d5.az(a3)*c3
if(d4>c4){b7=k.a
c4=d4
b6=c1}}if(b7==null)break
l.i(0,b7,b6.a)
a8=e1.$0()}}for(d8=A.as(q,q.r,A.i(q).c),r=d8.$ti.c;d8.l();){p=d8.d
if(p==null)p=r.a(p)
d5.c7(p,d5.c.x,e0)}d5.br(e0)
d8=d5.d.e
B.a.V(d8)
B.a.B(d8,e1.$0())},
cb(a,b){return new A.c2(this.di(a,b),t.iG)},
di(a,b){var s=this
return function(){var r=a,q=b
var p=0,o=1,n=[],m,l,k,j,i,h,g,f,e
return function $async$cb(c,d,a0){if(d===1){n.push(a0)
p=o}for(;;)switch(p){case 0:e=s.d
e.y.B(0,s.c.z)
B.a.B(e.f,s.c.y)
e.b=q||r?s.a.b.fr.b:"analysis"
e=s.c.c,e=new A.an(e,e.r,e.e,A.i(e).j("an<1>")),m=0
case 2:if(!e.l()){p=3
break}l=e.d;++m
p=4
return c.b=new A.aU([new A.hL(s,q,l),B.aV,l,m]),1
case 4:p=2
break
case 3:e=B.a.gt(s.a.e),l=new A.bK(e,t.bo),k=t.m9
case 5:if(!l.l()){p=6
break}j=k.a(e.gp())
i=s.c
h=j.a
if(!i.e.E(h)){p=5
break}++m
p=7
return c.b=new A.aU([new A.hM(s,j),B.aV,h,m]),1
case 7:p=5
break
case 6:g=new A.hJ(s)
p=8
return c.b=new A.aU([new A.hN(s,r,g),B.el,null,0]),1
case 8:p=s.f.a!==0?9:10
break
case 9:f={}
f.a=0
p=11
return c.b=new A.aU([new A.hO(f,s),B.U,null,0]),1
case 11:p=f.a>0?12:13
break
case 12:e=s.c.c,e=new A.an(e,e.r,e.e,A.i(e).j("an<1>")),m=0
case 14:if(!e.l()){p=15
break}l=e.d;++m
p=16
return c.b=new A.aU([new A.hP(s,l),B.U,l,m]),1
case 16:p=14
break
case 15:p=17
return c.b=new A.aU([g,B.U,null,0]),1
case 17:case 13:case 10:p=18
return c.b=new A.aU([new A.hQ(s),B.em,null,0]),1
case 18:p=19
return c.b=new A.aU([s.gdt(),B.en,null,0]),1
case 19:p=20
return c.b=new A.aU([s.gdq(),B.aW,null,0]),1
case 20:return 0
case 1:return c.c=n.at(-1),3}}}},
d9(a){var s,r,q,p,o,n,m,l=this,k=l.aB(a)
if(k.ge6())return k
s=l.c.r.h(0,a)
r=l.bq(s==null?A.L(t.N):s)
if(r.a===0)return k
q=A.d([],t.s)
for(s=new A.M(r,A.i(r).j("M<1,2>")).gt(0),p=l.a.c,o=l.e;s.l();){n=s.d
m=p.N(J.bP(n.b).x)
if(m!=null)o.i(0,n.a,m.a)}l.ca(a,r,q,l.ah(a,!1))
l.br(r)
k=l.aB(a)
s=A.dp(q,t.N)
s.B(0,k.ch)
s=A.p(s,A.i(s).c)
return k.cn(s)},
b0(a,b,c,d){return this.dA(t.dn.a(a),b,c,t.ga.a(d))},
dA(a,b,c,d){var s=0,r=A.mL(t.nJ),q,p=this,o,n,m,l,k,j,i,h,g
var $async$b0=A.mQ(function(e,f){if(e===1)return A.mC(f,r)
for(;;)switch(s){case 0:h=p.c.c.a
g=h+4
o=p.cb(b,c),n=o.$ti,o=new A.cy(o.a(),n.j("cy<1>")),n=n.c,m=0,l=!1
case 3:if(!o.l()){s=4
break}k=o.b
j=(k==null?n.a(k):k).a
i=j[1]
if(i===B.U&&!l){g+=p.c.c.a+2
l=!0}a.$1(new A.ca(i,m,g,j[2],j[3],p.c.c.a))
s=5
return A.mB(d.$0(),$async$b0)
case 5:j[0].$0();++m
s=3
break
case 4:a.$1(new A.ca(B.aW,g,g,null,0,h))
q=p.d
s=1
break
case 1:return A.mD(q,r)}})
return A.mE($async$b0,r)},
dm(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9=this,e0=d9.d.w
B.a.V(e0)
b7=d9.a
b8=t.hP
b9=A.p(new A.ct(b7.e,b8),b8.j("h.E"))
s=b9
if(J.au(s)===0||b7.b.id<=0)return e0
b8=t.N
c0=A.m(b8,t.i)
for(c1=s,c2=c1.length,c3=0;c3<c1.length;c1.length===c2||(0,A.k)(c1),++c3){c4=c1[c3]
c0.i(0,c4.a,c4.y)}r=c0
for(c0=s,c1=c0.length,c2=b7.c,c4=b7.b,c5=c4.id,c6=c5*3.141592653589793,c3=0;c3<c0.length;c0.length===c1||(0,A.k)(c0),++c3){c7=c0[c3]
c8=c2.ad(c7.e)
if(c8==null)continue
if(c7.y<=0){c9=c8.f/1000
c7.y=c6*c9*c9/4}}q=d9.c
try{c0=A.l9(b7).bs()
d9.c=c0
for(c0=c0.c,c0=new A.an(c0,c0.r,c0.e,A.i(c0).j("an<1>")),c4=c4.k1,c1=t.s,c6=t.e;c0.l();){p=c0.d
o=c6.a(b7.a6(p))
if(o==null)continue
d0=d9.c.f.h(0,p)
n=d0==null?A.L(b8):d0
m=A.d([],c1)
l=0
k=A.L(b8)
for(c7=n,c9=A.i(c7),d1=new A.R(c7,c7.r,c9.j("R<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
j=c7==null?c9.a(c7):c7
for(c7=d9.c.a.h(0,j).f,d2=c7.length,c3=0;c3<c7.length;c7.length===d2||(0,A.k)(c7),++c3){i=c7[c3]
if(i.b===-2){J.bO(m,j)
J.bO(k,i.a)}}}l=k.a
if(J.au(m)===0)continue
h=null
g=null
c7=d9.c.c.h(0,p)
c7.toString
f=c7
h=f.a
g=f.b
e=new A.hV(d9,m)
d=0
c=20
b=d9.S(p,c,!0).H()
a=0
for(;;){c7=e.$1(b)
if(typeof c7!=="number")return c7.bG()
if(c7<c4){c7=a
if(typeof c7!=="number")return c7.bG()
c7=c7<12}else c7=!1
if(!c7)break
c7=c
if(typeof c7!=="number")return c7.af()
c=c7*2
b=d9.S(p,c,!0).H()
c7=a
if(typeof c7!=="number")return c7.al()
a=c7+1}a0=0
for(;;){c7=a0
if(typeof c7!=="number")return c7.bG()
if(!(c7<30))break
c7=d
c9=c
if(typeof c7!=="number")return c7.al()
if(typeof c9!=="number")return A.bu(c9)
a1=(c7+c9)/2
b=d9.S(p,a1,!0).H()
c7=e.$1(b)
if(typeof c7!=="number")return c7.ea()
if(c7>=c4)c=a1
else d=a1
c7=c
c9=d
if(typeof c7!=="number")return c7.R()
if(typeof c9!=="number")return A.bu(c9)
if(c7-c9<0.001)break
c7=a0
if(typeof c7!=="number")return c7.al()
a0=c7+1}a2=c
b=d9.S(p,a2,!0).H()
a3=0
for(c7=n,c9=A.i(c7),d1=new A.R(c7,c7.r,c9.j("R<1>")),d1.c=c7.e,c9=c9.c;d1.l();){c7=d1.d
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
if(typeof d3!=="number")return d3.al()
a3=d3+d6*d5}}a8=0
c7=d9.c.r.h(0,p)
if(c7==null)c7=A.L(b8)
c9=A.i(c7)
d1=new A.R(c7,c7.r,c9.j("R<1>"))
d1.c=c7.e
c9=c9.c
while(d1.l()){c7=d1.d
a9=c7==null?c9.a(c7):c7
c7=d9.c.aj(a9)
c7.toString
b0=c7
if(b0.y==null)continue
b1=b.d.h(0,a9)
if(b1!=null){c7=a8
d2=b1.a
d3=d9.aw(b0)
a8=Math.max(A.lr(c7),Math.abs(d2)/(3.141592653589793*d3*d3/4))}}b2=c2.a3(o.e)
c7=b2
d8=c7==null?null:c7.r.b4(a3)
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
if(typeof d1!=="number")return d1.al()
if(typeof d2!=="number")return A.bu(d2)
d3=b4
d4=d3.Q
d3=d4==null?d3.c-d3.e:d4
d4=b5
d5=d4.Q
d4=d5==null?d4.c-d4.e:d5
B.a.k(e0,new A.ce(p,c7,c9,a2,d1+d2+(d3-d4),l,e.$1(b),a8,c5,b.a))}}finally{for(b7=s,b8=b7.length,c3=0;c3<b7.length;b7.length===b8||(0,A.k)(b7),++c3){b6=b7[c3]
c0=J.d3(r,b6.a)
c0.toString
b6.y=c0}d9.c=q}return e0},
du(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=this.d,b2=b1.x
B.a.V(b2)
s=this.a
r=s.b
if(!r.k2)return b2
q=A.m(t.N,t.ft)
p=new A.i2(q)
for(o=b1.c,n=A.i(o).j("O<2>"),m=new A.O(o,o.r,o.e,n);m.l();){l=m.d
for(k=l.at,j=k.length,l=l.b,i=0;i<k.length;k.length===j||(0,A.k)(k),++i)p.$2(k[i],l)}for(m=b1.e,l=m.length,i=0;i<m.length;m.length===l||(0,A.k)(m),++i){h=m[i]
for(k=h.f,j=k.length,g=h.b,f=0;f<k.length;k.length===j||(0,A.k)(k),++f)p.$2(k[f],g)}for(l=new A.M(q,q.$ti.j("M<1,2>")).gt(0),e=r.k3,r=t.f,k=s.c,b1=b1.f;l.l();){d=l.d
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
for(g=new A.O(o,o.r,o.e,n);g.l();)for(a8=g.d.at,a9=a8.length,i=0;i<a9;++i){b0=a8[i]
if(b0.b===j)a7=Math.max(a7,Math.max(b0.ax,b0.ay))}for(g=m.length,i=0;i<g;++i)for(a8=m[i].f,a9=a8.length,f=0;f<a9;++f){b0=a8[f]
if(b0.b===j)a7=Math.max(a7,Math.max(b0.ax,b0.ay))}g=a.b
a8=a.y
B.a.k(b2,new A.bF(j,c.b,g,a2,a3,a6,a7,a8,e,a5))
if(a8>0&&a7+a6>a8+0.000001)B.a.k(b1,"surge_rating_exceeded:"+j)}return b2},
dr(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7=this,b8=null,b9="bom.pipes",c0="bom.outlets",c1="un",c2="bom.pivots",c3=t.N,c4=A.m(c3,t.q),c5=new A.hY(c4)
for(s=b7.c.b,r=s.length,q=b7.a,p=q.c,o=b7.e,n=0;n<s.length;s.length===r||(0,A.k)(s),++n){m=s[n]
if(m.d!==B.e)continue
l=p.ad(m.y)
if(l!=null){c5.$8$code$supplier("bom.tapes",l.b,"m",m.w,l.cx,l.a,l.d,l.c)
continue}k=o.h(0,m.f)
j=p.N(k==null?m.x:k)
if(j!=null)c5.$8$code$supplier(b9,j.b,"m",m.w,j.Q,j.a,j.d,j.c)}for(s=q.e,r=s.length,o=b7.b,i=b7.d,h=i.d,n=0;n<s.length;s.length===r||(0,A.k)(s),++n){g=s[n]
if(b7.c.z.v(0,g.a))continue
A:{f=g instanceof A.b0
e=f?g:b8
if(f){d=p.a_(e.f)
if(d!=null){f=d.b
c=d.aD(e.r)
c=c==null?b8:c.b
if(c==null)c=""
c5.$8$code$supplier(c0,f+" \u2014 "+c,c1,1,d.r,d.a,d.d,d.c)}break A}f=g instanceof A.al
d=f?g:b8
if(f){j=p.a_(d.r)
if(j!=null){f=j.b
c=j.aD(d.w)
c=c==null?b8:c.b
if(c==null)c=""
c5.$8$code$supplier(c0,f+" \u2014 "+c,c1,d.gb5(),j.r,j.a,j.d,j.c)}break A}f=g instanceof A.ba
b=f?g:b8
if(f){d=p.a3(b.e)
if(d!=null)c5.$8$code$supplier("bom.valves",d.b,c1,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.b_
a=f?g:b8
if(f){d=p.a3(a.e)
if(d!=null)c5.$8$code$supplier("bom.devices",d.b,c1,1,d.y,d.a,d.d,d.c)
break A}f=g instanceof A.bq
a0=f?g:b8
if(f){d=p.ar(a0.e)
if(d!=null)c5.$8$code$supplier("bom.pumps",d.b,c1,1,d.Q,d.a,d.d,d.c)
break A}f=g instanceof A.b3
a0=f?g:b8
if(f){a1=h.h(0,a0.a)
f=a1==null
a2=f?b8:a1.as
if(a2==null)a2=a0.e4().length
a3=a0.c
c=(a3.length!==0?a3:o.$1("tool.pivot"))+" \u2014 "
a4=A.A(a0.z===B.E?o.$1("pivot.kindPivot"):o.$1("pivot.kindLinear"))
a5=a0.x
c5.$6(c2,c+a4+" "+B.b.a2(a5)+" m, "+a2+" "+A.A(o.$1("pivot.towers")),c1,1,a0.id,b8)
c5.$6(c2,c+A.A(o.$1("pivot.towersItem"))+" ("+B.b.a2(a0.as)+" m)",c1,a2,a0.r,b8)
a6=p.N(a0.at)
if(a6!=null)c5.$8$code$supplier(b9,a6.b,"m",a5,a6.Q,a6.a,a6.d,a6.c)
a7=f?b8:a1.gcJ()
if(a7==null){f=a0.d
a7=f>0?B.b.a2(a5/f):0}a8=p.a_(a0.e)
f=a7>0
if(f){a4=a8==null
a5=a4?b8:a8.b
a5=A.A(a5==null?o.$1("pivot.sprinklersItem"):a5)
a9=a4?b8:a8.r
if(a9==null)a9=0
b0=a4?b8:a8.a
b1=a4?b8:a8.d
if(b1==null)b1=""
a4=a4?b8:a8.c
if(a4==null)a4=""
c5.$8$code$supplier(c2,c+a5,c1,a7,a9,b0,b1,a4)}b2=p.a3(a0.f)
if(b2!=null&&f)c5.$8$code$supplier(c2,c+b2.b,c1,a7,b2.y,b2.a,b2.d,b2.c)
if(a0.cx>0)c5.$6(c2,c+A.A(o.$1("pivot.endGunItem")),c1,1,0,b8)
break A}break A}}s=i.r
B.a.V(s)
B.a.B(s,new A.ao(c4,c4.$ti.j("ao<2>")))
r=q.b
if(r.k4){b3=A.qr(q,b7.c,b7.gdg(),o)
B.a.B(s,b3.a)
b4=A.L(c3)
for(c3=b3.b,q=c3.length,p=i.f,n=0;n<c3.length;c3.length===q||(0,A.k)(c3),++n){a=c3[n]
b5=A.mZ(a.a,a.b,a.c,o)
if(b4.k(0,b5))B.a.k(p,"fitting_missing:"+b5)}}B.a.ao(s,new A.hZ())
c3=A.t(s)
b6=new A.C(s,c3.j("v(1)").a(new A.i_(b7)),c3.j("C<1>")).gm(0)
if(b6>0)B.a.k(i.f,"bom_unpriced:"+b6)
c3=t.i
q=B.a.W(s,0,new A.i0(),c3)
i.z=q
i.Q=q*A.fs(r.y,r.z)
i.as=B.a.W(i.e,0,new A.i1(),c3)
return s}}
A.hA.prototype={
$2(a,b){return A.S(a)+t.cQ.a(b).gdW()},
$S:79}
A.hH.prototype={
$1(a){return t.o.a(a).a},
$S:88}
A.hT.prototype={
$0(){return A.d([],t.I)},
$S:76}
A.hS.prototype={
$2(a,b){return A.S(a)+t.G.a(b).w},
$S:93}
A.hU.prototype={
$1(a){return A.fw(t.p.a(a).f/1000,this.b)<=this.a.aA(this.c)+1e-9},
$S:5}
A.hu.prototype={
$2(a,b){var s,r
A.D(a)
t.x.a(b)
s=this.a
r=J.a1(b)
s.e.i(0,a,r.gu(b).a.a)
s=s.f
if(r.gm(b)>1)s.i(0,a,b)
else s.U(0,a)},
$S:122}
A.hB.prototype={
$0(){return A.d([],t.s)},
$S:142}
A.hG.prototype={
$1(a){var s=this.a.d.h(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:8}
A.hF.prototype={
$0(){return A.m(t.N,t.i)},
$S:16}
A.hI.prototype={
$1(a){return t.j5.a(a).b===this.a},
$S:32}
A.hv.prototype={
$1(a){t.G.a(a)
return a.f===this.a.a&&a.d===B.e},
$S:1}
A.hw.prototype={
$2(a,b){var s=t.G
return B.c.T(s.a(a).r,s.a(b).r)},
$S:34}
A.hx.prototype={
$1(a){return this.a.h(0,A.D(a))},
$S:35}
A.hy.prototype={
$1(a){return A.mz(a)==null},
$S:36}
A.hz.prototype={
$0(){return"e"+this.a.a.r++},
$S:37}
A.hR.prototype={
$1(a){var s=this.a,r=t.v.a(a).a
if(s.c.d.E(r)){s=s.c
r=s.w.v(0,s.d.h(0,r))
s=r}else s=!1
return s},
$S:9}
A.hW.prototype={
$1(a){return t.v.a(a).e},
$S:9}
A.hX.prototype={
$1(a){var s,r,q,p,o,n,m,l
for(s=this.b,s=new A.an(s,s.r,s.e,A.i(s).j("an<1>")),r=this.c,q=a.c,p=this.a,o=-1/0;s.l();){n=s.d
m=p.am(n)
l=q.h(0,m==null?"":m)
if(l==null)continue
n=r.h(0,n)
n.toString
o=Math.max(o,n-l.b)}return isFinite(o)?o:0},
$S:17}
A.hE.prototype={
$1(a){var s=this.a.d.h(0,a.a)
s=s==null?null:s.a
return Math.abs(s==null?0:s)},
$S:8}
A.hC.prototype={
$4(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this,a2=a1.a,a3=a2.a.h(0,a4)
if(a3==null)return
s=a1.c.h(0,a3)
s.toString
r=A.m(t.N,t.U)
for(q=a1.b,a2=q.c3(a2.b,a4),p=a2.length,o=a1.r.d,n=a1.d,m=a1.f,l=a1.e,k=0,j=0;j<a2.length;a2.length===p||(0,A.k)(a2),++j){i=a2[j]
h=i.a
g=n.h(0,h)
if(g!=null){f=r.ac(g,new A.hD())
for(h=l.h(0,g),e=h.length,d=0;d<h.length;h.length===e||(0,A.k)(h),++d){c=h[d]
b=c.a
a=f.h(0,b)
if(a==null)a=0
f.i(0,b,a+q.bZ(i,c,m.$1(i)))}}else if(i.d===B.e)k+=q.bT(i,m.$1(i))
else{h=o.h(0,h)
h=h==null?null:h.c
k+=h==null?0:h}}a0=q.c.a.h(0,a4).gaC()+a7-q.c.a.h(0,a3).gaC()
a2=a1.x.h(0,s.a+"|"+a1.y)
a2.toString
s=a6!=null?a6+a0:null
B.a.k(a1.w,new A.dr(a2,r,k,a5+a0,s))},
$S:40}
A.hD.prototype={
$0(){return A.m(t.N,t.i)},
$S:16}
A.i4.prototype={
$2(a,b){return A.S(a)+t.k.a(b).e},
$S:18}
A.i3.prototype={
$0(){var s,r,q,p,o,n=A.d([],t.lT)
for(s=this.b,r=s.length,q=this.a,p=this.c,o=0;o<s.length;s.length===r||(0,A.k)(s),++o)n.push(q.cl(s[o],p))
return n},
$S:42}
A.i5.prototype={
$1(a){var s
t.v.a(a)
s=this.a.c.d.h(0,a.a)
s.toString
return s},
$S:43}
A.i6.prototype={
$1(a){var s
A.D(a)
s=this.a.c.aj(a)
return(s==null?null:s.d)===B.e},
$S:44}
A.i7.prototype={
$1(a){return!t.v.a(a).e},
$S:9}
A.i8.prototype={
$2(a,b){var s=t.nN
s.a(a)
s.a(b)
return a.e-a.d>=b.e-b.d?a:b},
$S:45}
A.hL.prototype={
$0(){var s=this.a,r=this.c,q=this.b?s.cH(r):s.aB(r)
s.d.c.i(0,r,q)
return q},
$S:0}
A.hM.prototype={
$0(){var s=this.a,r=this.b,q=s.ck(r)
s.d.d.i(0,r.a,q)
return q},
$S:0}
A.hJ.prototype={
$0(){var s,r,q,p=this.a,o=p.cp(),n=B.a.W(o,0,new A.hK(),t.i),m=p.d.e
B.a.V(m)
s=A.d([],t.lT)
for(r=o.length,q=0;q<o.length;o.length===r||(0,A.k)(o),++q)s.push(p.cl(o[q],n))
B.a.B(m,s)},
$S:0}
A.hK.prototype={
$2(a,b){return A.S(a)+t.k.a(b).e},
$S:18}
A.hN.prototype={
$0(){if(this.b)this.a.cG()
else this.c.$0()},
$S:0}
A.hO.prototype={
$0(){var s,r,q=this.b,p=q.cS()
this.a.a=p
if(p>0){s=q.d
r=s.y
if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.bl()}r.B(0,q.c.z)
s.c.V(0)}},
$S:0}
A.hP.prototype={
$0(){var s=this.a,r=this.b,q=s.d9(r)
s.d.c.i(0,r,q)
return q},
$S:0}
A.hQ.prototype={
$0(){this.a.dm()},
$S:0}
A.hV.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h=1/0
for(q=this.b,p=q.length,o=this.a,n=a.c,m=0;m<q.length;q.length===p||(0,A.k)(q),++m){s=q[m]
r=n.h(0,s)
if(r==null)continue
l=h
k=r.a
j=o.c.a.h(0,s)
i=j.Q
j=i==null?j.c-j.e:i
h=Math.min(A.lr(l),k-j)}return isFinite(h)?h:0},
$S:17}
A.i2.prototype={
$2(a,b){var s=this.a,r=a.b,q=s.h(0,r)
if(q==null||a.as>q.a.as)s.i(0,r,new A.n(a,b))},
$S:46}
A.hY.prototype={
$8$code$supplier(a,b,c,d,e,f,g,h){var s=a+"|"+b,r=this.a,q=r.h(0,s)
if(q!=null)q.d+=d
else r.i(0,s,new A.ad(a,b,c,d,e,f,g,h))},
$6(a,b,c,d,e,f){return this.$8$code$supplier(a,b,c,d,e,f,"","")},
$S:47}
A.hZ.prototype={
$2(a,b){var s,r=t.q
r.a(a)
r.a(b)
r=a.a
s=b.a
return r===s?B.d.T(a.b,b.b):B.d.T(r,s)},
$S:48}
A.i_.prototype={
$1(a){var s,r
t.q.a(a)
s=a.f
r=!1
if(s!=null)if(a.d>0)if(!(a.e>0)){s=this.a.a.c.a_(s)
s=(s==null?null:s.e)!==B.at}else s=r
else s=r
else s=r
return s},
$S:49}
A.i0.prototype={
$2(a,b){A.S(a)
t.q.a(b)
return a+b.d*b.e},
$S:50}
A.i1.prototype={
$2(a,b){return A.S(a)+t.ju.a(b).z},
$S:30}
A.de.prototype={
gcs(){return this.a.b+"|"+B.b.ae(this.b,1)+"|"+B.b.ae(this.c,1)}}
A.ie.prototype={}
A.ko.prototype={
$1(a){return a===B.b.bA(a)?""+B.b.a2(a):B.b.ae(a,1)},
$S:20}
A.kR.prototype={
$4$qty$size2(a,b,c,d){var s=new A.de(a,b,d),r=this.a,q=r.h(0,s.gcs()),p=s.gcs(),o=q==null?null:q.b
r.i(0,p,new A.n(s,(o==null?0:o)+c))},
$2(a,b){return this.$4$qty$size2(a,b,1,0)},
$3$qty(a,b,c){return this.$4$qty$size2(a,b,c,0)},
$3$size2(a,b,c){return this.$4$qty$size2(a,b,1,c)},
$S:53}
A.kT.prototype={
$1(a){var s,r
t.G.a(a)
s=this.a.ad(a.y)
if(s!=null)return s.e
r=this.b.$1(a)
r=r==null?null:r.e
return r==null?0:r},
$S:8}
A.kQ.prototype={
$2(a,b){var s=a.cx,r=a.cy
return a.b===b?r.R(0,s).gct():s.R(0,r).gct()},
$S:54}
A.kI.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.e){s=this.a.$1(a)
if(typeof s!=="number")return s.cF()
s=s>0}else s=!1
return s},
$S:1}
A.kJ.prototype={
$1(a){return!this.a.v(0,t.G.a(a).f)},
$S:1}
A.kK.prototype={
$1(a){return this.a.v(0,t.G.a(a).f)},
$S:1}
A.kL.prototype={
$1(a){return t.G.a(a).d!==B.e},
$S:1}
A.kS.prototype={
$2(a,b){return this.a.h(0,B.b.ae(a.a,3)+"|"+B.b.ae(a.b,3)+"|"+b.b)},
$S:55}
A.kO.prototype={
$2(a,b){return a!=null&&B.a.Z(a.w,new A.kP(b,this.a))},
$S:56}
A.kP.prototype={
$1(a){var s
t.G.a(a)
if(a.d===B.e){s=a.f
s=s!==this.a&&!this.b.v(0,s)}else s=!1
return s},
$S:1}
A.kM.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.kN.prototype={
$1(a){return t.G.a(a).f===this.a.a.a},
$S:1}
A.kH.prototype={
$1(a){var s
A:{if(B.w===a||B.L===a){s="bom.takeoffs"
break A}if(B.m===a){s="bom.risers"
break A}s="bom.fittings"
break A}return s},
$S:57}
A.cm.prototype={
G(){return"LpSense."+this.b}}
A.cl.prototype={}
A.it.prototype={}
A.cI.prototype={}
A.bB.prototype={
G(){return"LpStatus."+this.b}}
A.kU.prototype={
$2(a,b){var s,r
A.aV(a)
A.S(b)
if(a>=0&&a<this.a){s=this.b
if(!(a>=0&&a<s.length))return A.b(s,a)
r=s[a]
s.$flags&2&&A.ab(s)
s[a]=r+b*this.c}},
$S:58}
A.kW.prototype={
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
$S:59}
A.kV.prototype={
$2(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=f.a,d=e.length
if(!(a>=0&&a<d))return A.b(e,a)
s=e[a]
r=s.length
if(!(b>=0&&b<r))return A.b(s,b)
q=s[b]
for(p=f.b,o=s.$flags|0,n=0;n<p;++n){if(!(n<r))return A.b(s,n)
m=s[n]
o&2&&A.ab(s)
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
i&2&&A.ab(m)
m[n]=h-j*g}}B.a.i(f.d,a,b)},
$S:10}
A.kX.prototype={
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
a1=a3}}if(a1<0)return B.f4
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
e=!1}}return B.bp},
$S:61}
A.ds.prototype={}
A.dr.prototype={}
A.ez.prototype={}
A.dq.prototype={}
A.ky.prototype={
$2(a,b){var s
A.D(a)
t.U.a(b)
s=this.a.h(0,a)
if(s==null)return
b.X(0,new A.kx(s,this.b))},
$S:62}
A.kx.prototype={
$2(a,b){var s,r,q
A.D(a)
A.S(b)
s=this.a.h(0,a)
if(s!=null){r=this.b
q=r.h(0,s)
r.i(0,s,(q==null?0:q)-b)}},
$S:63}
A.kz.prototype={
$2(a,b){var s=t.ca
s.a(a)
return B.b.T(s.a(b).a.f,a.a.f)},
$S:64}
A.kc.prototype={
$2(a,b){return A.S(a)+t.ca.a(b).b},
$S:65}
A.bU.prototype={
G(){return"GLinkKind."+this.b}}
A.bb.prototype={
gdW(){return this.c.a7(this.e)*this.d}}
A.aZ.prototype={
gaC(){var s=this.Q
return s==null?this.c-this.e:s}}
A.I.prototype={
gm(a){return this.w}}
A.iJ.prototype={
aj(a){var s,r,q,p
for(s=this.b,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null}}
A.iw.prototype={
gb6(){var s=this.c
return s===$?this.c=this.a.b.x:s},
gcz(){var s,r=this,q=r.d
if(q===$){s=r.a.ds()
r.d!==$&&A.qx()
r.d=s
q=s}return q},
bX(a){var s=this.gb6()*4
return(B.b.J(a.a/s)*73856093^B.b.J(a.b/s)*19349663)>>>0},
aF(a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=a0.a,e=g.gb6(),d=e*4,c=B.b.J(f/d),b=a0.b,a=B.b.J(b/d)
for(d=g.f,s=null,r=1/0,q=-1;q<=1;++q)for(p=(c+q)*73856093,o=-1;o<=1;++o){n=d.h(0,(p^(a+o)*19349663)>>>0)
if(n==null)continue
for(m=J.ac(n);m.l();){l=m.gp()
if(l.d!==a1)continue
k=l.b
j=k.a-f
k=k.b-b
i=Math.sqrt(j*j+k*k)
if(i<=e&&i<r){r=i
s=l}}}f=s==null
if(!f||!a2)return f?$.ni():s
f=g.r++
h=A.l3(g.gcz().b1(a0),"n"+f,a0,a1)
g.e.a.i(0,h.a,h)
J.bO(d.ac(g.bX(a0),new A.iy()),h)
return h},
ap(a,b){return this.aF(a,b,!0)},
bs(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6=this,f7=null,f8="outlet_spec_missing:",f9=f6.e
f9.Q=f6.gcz()
s=f6.a
r=s.c
s=s.e
q=A.t(s)
p=q.j("C<1>")
o=A.p(new A.C(s,q.j("v(1)").a(new A.iz()),p),p.j("h.E"))
q=t.C
n=A.d([],q)
p=t.N
m=A.m(p,t.V)
for(l=o.length,k=0;k<o.length;o.length===l||(0,A.k)(o),++k)m.i(0,o[k].a,A.d([],q))
j=new A.iF()
i=new A.iH()
h=new A.iG(f6,o,i,j,m)
for(l=s.length,g=t.dr,k=0;k<s.length;s.length===l||(0,A.k)(s),++k){f=s[k]
e=f instanceof A.b0
d=e?f:f7
if(e){h.$2(d.d,A.d([d.e],g))
continue}e=f instanceof A.cj
c=e?f:f7
if(e){h.$2(c.d,A.d([c.e],g))
continue}e=f instanceof A.ba
b=e?f:f7
if(e){h.$2(b.d,B.D)
continue}e=f instanceof A.bq
a=e?f:f7
if(e){h.$2(a.d,A.d([a.w],g))
continue}e=f instanceof A.b_
a0=e?f:f7
if(e){h.$2(a0.d,A.d([a0.f],g))
continue}e=f instanceof A.aC
a1=e?f:f7
if(e){h.$2(a1.d,A.d([B.i],g))
continue}e=f instanceof A.b3
a=e?f:f7
if(e){h.$2(a.w,A.d([B.i],g))
continue}continue}for(l=o.length,k=0;e=o.length,k<e;o.length===l||(0,A.k)(o),++k){f=o[k]
a2=j.$1(f)
e=J.a9(a2)
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
a2=A.ey(a8,!0,l)
if(b0.length!==0){b1=A.d([],g)
for(b2=b0.length,b3=0;b3<b0.length;b0.length===b2||(0,A.k)(b0),++b3){a1=b0[b3]
for(b4=a1.a,b5=a1.b,b6=0,b7=1/0,b8=0,b9=1;b9<a2.length;++b9){c0=b9-1
c1=A.ls(a1,a2[c0],a2[b9])
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
b6+=Math.sqrt(c4*c4+c3*c3)}B.a.k(b1,b8)}c7=A.nd(a2,b1)
a2=A.d([J.bP(B.a.gu(c7))],q)
for(b0=c7.length,b3=0;b3<c7.length;c7.length===b0||(0,A.k)(c7),++b3)B.a.B(a2,J.lF(c7[b3],1))}B.a.B(n,a2)
A:{b0=f instanceof A.aH
a=b0?f:f7
if(b0){c8=r.N(a.f)
c9=a7===B.h?B.j:B.k
b0=c8==null
b2=b0?f7:c8.a
b0=a.r||b0
f6.cR(a9,a2,a7,b0,a.w,b2,c9)
break A}b0=f instanceof A.al
a1=b0?f:f7
if(b0){d0=r.a_(a1.r)
b0=d0==null
d1=b0?f7:d0.aD(a1.w)
if(b0||d1==null){B.a.k(a5,f8+a9)
a6.k(0,a9)
continue}c8=r.N(a1.e)
d2=A.aX(a2)
d3=a1.gb5()
d4=a1.z
d4=d4>0?d4:a1.y
b0=a1.x
d5=f6.cj(d1,b0)
d6=d5.a
d7=d5.b
b2=A.d([],g)
for(b4=a1.y,b9=0;b9<d3;++b9)b2.push(d4+b9*b4)
d8=f6.c0(b2,d2)
d9=A.m(a3,a4)
for(b2=d8.length,b4=d1.c,b5=d1.w,c0=a1.as,c3=d0.x,c4=a1.at,c3=c0+c3+c4,c0=d1.b,b3=0;b3<d8.length;d8.length===b2||(0,A.k)(d8),++b3){c6=d8[b3]
d9.i(0,c6.a,new A.bb(a9,c6.c,b4,c6.b,b0,d6,d7,b5,c3,c0))}b0=c8==null
b2=b0?f7:c8.a
f6.cQ(a9,a2,a7,d9,a1.f||b0,c4,0,b2,B.p)
break A}b0=f instanceof A.aB
e0=b0?f:f7
if(b0){c8=r.ad(e0.e)
if(c8==null){B.a.k(a5,"tape_spec_missing:"+a9)
a6.k(0,a9)
continue}d2=A.aX(a2)
b0=c8.r
d3=B.b.J(d2/b0)
b2=A.d([],g)
for(b9=1;b9<=d3;++b9)b2.push(b9*b0)
d8=f6.c0(b2,d2)
b0=c8.z
b2=e0.f
d6=Math.max(b0,b2*(1-c8.at/100))
d7=Math.min(c8.Q,b2*(1+c8.ax/100))
d9=A.m(a3,a4)
for(b0=d8.length,b4=c8.w,b5=c8.y,c0=e0.x,c3=c8.b,b3=0;b3<d8.length;d8.length===b0||(0,A.k)(d8),++b3){c4=d8[b3]
d9.i(0,c4.a,new A.bb(a9,c4.c,b4,c4.b,b2,d6,d7,b5,c0,c3))}b0=c8.a
b2=c8.x
f6.bM(a9,a2,a7,d9,!1,c0,e0.y,b2,f7,b0,B.p)
break A}break A}}for(q=[0,1],m=f9.c,l=f9.d,g=f9.e,k=0;k<2;++k){e1=q[k]
for(e=s.length,a3=e1===0,b3=0;b3<s.length;s.length===e||(0,A.k)(s),++b3){f=s[b3]
a4=f instanceof A.bq
if(a3===(a4||f instanceof A.b_))continue
B:{a9=f instanceof A.b0
d=a9?f:f7
if(a9){d0=r.a_(d.f)
a4=d0==null
d1=a4?f7:d0.aD(d.r)
if(a4||d1==null){B.a.k(a5,f8+f.a)
continue}d3=f6.aF(d.d,d.e,!1)
if(d3.a.length===0){a6.k(0,f.a)
continue}a4=d.w
e2=f6.cj(d1,a4)
a9=f.a
d3.r.k(0,a9)
B.a.k(d3.f,new A.bb(a9,-1,d1.c,1,a4,e2.a,e2.b,d1.w,d.z+d0.x,d1.b))
break B}a9=f instanceof A.cj
c=a9?f:f7
if(a9){d3=f6.ap(c.d,c.e)
d3.r.k(0,f.a)
a4=c.f
if(a4!=null)d3.Q=a4
break B}a9=f instanceof A.b3
a=a9?f:f7
if(a9){d3=f6.aF(a.w,B.i,!1)
a4=d3.a
if(a4.length===0){a6.k(0,f.a)
continue}a9=f.a
d3.r.k(0,a9)
g.i(0,a9,a4)
break B}a9=f instanceof A.aC
a1=a9?f:f7
if(a9){d3=f6.ap(a1.d,B.i)
a4=f.a
d3.r.k(0,a4)
d3.y=!0
d3.z=a4
l.i(0,a4,d3.a)
if(d3.w.length===0)a6.k(0,a4)
break B}a9=f instanceof A.ba
b=a9?f:f7
if(a9){a4=b.d
e3=f6.ap(a4,B.i)
e4=f6.ap(a4,B.h)
a9=f.a
e3.r.k(0,a9)
e4.r.k(0,a9)
b0=e3.a
b2=e4.a
b4=b.e
f6.aT(new A.I("cv_"+a9,b0,b2,B.W,B.i,a9,0,0,f7,f7,!1,B.j,0,b.x,0,b4,f7,1,a4,a4,0))
m.i(0,a9,new A.n(b0,b2))
if(e4.w.length<=1)B.a.k(a5,"valve_no_zone_pipes:"+a9)
break B}a9={}
a9.a=null
if(a4){a9.a=f
b0=f}else b0=f7
if(a4){c8=r.ar(b0.e)
if(c8==null){B.a.k(a5,"pump_spec_missing:"+f.a)
continue}f6.bW(f.a,b0.d,b0.w,new A.iA(a9,f,c8))
break B}a4={}
a4.a=null
a9=f instanceof A.b_
if(a9){a4.a=f
b0=f}else b0=f7
if(a9){c8=r.a3(b0.e)
if(c8==null){B.a.k(a5,"valve_spec_missing:"+f.a)
continue}a9=c8.e
f6.bW(f.a,b0.d,b0.f,new A.iB(a4,f,a9===B.R,c8))
break B}break B}}}for(q=f9.a,e=new A.O(q,q.r,q.e,A.i(q).j("O<2>"));e.l();){a3=e.d
for(a4=a3.w,a9=a4.length,c5=0,k=0;k<a9;++k)c5=Math.max(c5,a4[k].at)
a3.e=c5}for(e=new A.M(m,A.i(m).j("M<1,2>")).gt(0),a3=f9.f,a4=f9.r,a9=t.s;e.l();){e5=e.d
e6=e5.a
e7=e5.b.b
e8=A.L(p)
e9=A.L(p)
f0=A.d([e7],a9)
e8.k(0,e7)
while(b0=f0.length,b0!==0){if(0>=b0)return A.b(f0,-1)
f1=f0.pop()
d3=q.h(0,f1)
b0=d3.x
if(b0!=null&&b0!==e6){f2=A.d([e6,b0],a9)
B.a.a0(f2)
f3="zone_overlap:"+f2[0]+":"+f2[1]
if(!B.a.v(a5,f3))B.a.k(a5,f3)}d3.x=e6
for(b0=d3.w,b2=b0.length,k=0;k<b0.length;b0.length===b2||(0,A.k)(b0),++k){f4=b0[k]
if(f4.d===B.W)continue
if(f4.e!==B.h)continue
e9.k(0,f4.a)
f4.dx=e6
d=f4.b
if(f1===d)d=f4.c
if(e8.k(0,d))B.a.k(f0,d)}}a3.i(0,e6,e8)
a4.i(0,e6,e9)}p=A.p(new A.ao(l,A.i(l).j("ao<2>")),p)
l=f9.w
l.B(0,p)
for(e=f9.x;a3=p.length,a3!==0;){if(0>=a3)return A.b(p,-1)
f1=p.pop()
for(a3=q.h(0,f1).w,a4=a3.length,k=0;k<a3.length;a3.length===a4||(0,A.k)(a3),++k){f4=a3[k]
if(f4.e!==B.i||f4.d===B.W)continue
e.k(0,f4.a)
d=f4.b
if(f1===d)d=f4.c
if(l.k(0,d))B.a.k(p,d)}}f6.d3()
for(q=s.length,k=0;k<s.length;s.length===q||(0,A.k)(s),++k){f=s[k]
if(!A.nX(f))continue
p=f.a
if(a6.v(0,p))continue
C:{if(f instanceof A.ba){f5=m.h(0,p)
if(!l.v(0,(f5==null?B.fP:f5).a))a6.k(0,p)
break C}e=f instanceof A.aH
if(e)a3=f.e===B.i
else a3=!1
if(a3){if(!f6.by(p).Z(0,new A.iC(f6)))a6.k(0,p)
break C}if(e||f instanceof A.al||f instanceof A.aB){if(!f6.by(p).Z(0,new A.iD()))a6.k(0,p)
break C}e=f instanceof A.b0
d=e?f:f7
if(e){e=d.d
a3=d.e
d3=f6.aF(e,a3,!1)
e=d3.a
if(e.length===0)a6.k(0,p)
else if(a3===B.h?d3.x==null:!l.v(0,e))a6.k(0,p)
break C}if(f instanceof A.bq||f instanceof A.b_){if(!f6.by(p).Z(0,new A.iE(f6)))a6.k(0,p)
break C}if(f instanceof A.b3){d3=g.h(0,p)
if(d3==null||!l.v(0,d3))a6.k(0,p)
break C}break C}}return f9},
by(a){var s=this.e.b,r=A.t(s)
return new A.C(s,r.j("v(1)").a(new A.iI(a)),r.j("C<1>"))},
cj(a,b){var s=a.c.dL(b,a.y,a.x)
return new A.n(Math.max(s.a,a.e),Math.min(s.b,a.f))},
c0(a,b){var s,r,q,p,o,n,m,l,k,j
t.bd.a(a)
s=a.length
if(s===0)return A.d([],t.nV)
r=this.b
q=B.b.aq(s/(r===$?this.b=Math.max(2,this.a.b.go):r))
p=A.d([],t.nV)
for(o=0;s=a.length,o<s;o=n){n=o+q
m=Math.min(n,s)
l=m-o
for(k=o,j=0;k<m;++k){if(!(k>=0&&k<s))return A.b(a,k)
j+=a[k]}B.a.k(p,new A.a(Math.min(j/l,b),l,o))}return p},
aT(a){var s=this.e
B.a.k(s.b,a)
s=s.a
B.a.k(s.h(0,a.b).w,a)
B.a.k(s.h(0,a.c).w,a)},
cR(a,b,c,d,e,f,g){var s,r,q,p,o,n,m,l,k,j,i
t.V.a(b)
for(s=a+"_",r=1;r<b.length;++r){q=r-1
p=this.ap(b[q],c)
if(!(r<b.length))return A.b(b,r)
o=this.ap(b[r],c)
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
this.aT(new A.I(s+q,n,m,B.e,c,a,q,i,f,null,d,g,0,e,0,null,null,1,j,b[r],0))}},
bM(a,b,a0,a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.V.a(b)
t.nh.a(a1)
s=A.ai([0,A.aX(b)],t.i)
for(r=0,q=1;q<b.length;++q){p=b[q-1]
o=b[q]
n=p.a-o.a
o=p.b-o.b
r+=Math.sqrt(n*n+o*o)
s.k(0,r)}s.B(0,new A.a4(a1,A.i(a1).j("a4<1>")))
m=A.p(s,s.$ti.c)
B.a.a0(m)
for(p=m.length,o=a+"_",l=null,k=0,j=0,i=0,h=0;h<m.length;m.length===p||(0,A.k)(m),++h,k=g,l=e){g=m[h]
f=A.kD(b,g)
n=l!=null
e=n&&g-k<this.gb6()?l:this.ap(f,a0)
e.r.k(0,a)
d=a1.h(0,g)
if(d!=null){B.a.k(e.f,d)
i+=d.d}if(n&&l.a!==e.a){c=j+1
this.aT(new A.I(o+j,l.a,e.a,B.e,a0,a,c-1,g-k,a6,a7,a2,a8,a5*i,a3,0,null,null,1,A.kD(b,k),f,i))
j=c
i=0}}if(a4>0&&l!=null)B.a.k(l.f,new A.bb(a,-2,new A.bT(a4,0,0,0),1,1,0,1/0,0,0,"flush"))},
cQ(a,b,c,d,e,f,g,h,i){return this.bM(a,b,c,d,e,f,0,g,h,null,i)},
d3(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=t.N,a=A.m(b,t.i)
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
if(h.d===B.X)if(p.v(0,h.a)){k=s.ar(h.ch)
k=k==null?null:k.f
k=k===!0}if(k)r.push(h)}if(r.length===0||a.a===0)return
s=A.m(b,b)
for(q=a.$ti,n=new A.an(a,a.r,a.e,q.j("an<1>"));n.l();){k=n.d
s.i(0,k,k)}b=A.p(new A.a4(a,q.j("a4<1>")),b)
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
bW(a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this
t.fC.a(a7)
s=a3.aF(a5,a6,!1)
r=s.a
if(r.length===0){a3.e.z.k(0,a4)
return}s.r.k(0,a4)
q=s.w
p=A.ey(q,!0,t.G)
o=p.length
n=null
if(o>=2){m=a3.d0(a6)
for(l=1/0,k=0;k<p.length;p.length===o||(0,A.k)(p),++k){j=p[k]
i=j.b
h=m.h(0,r===i?j.c:i)
if(h==null)h=1/0
if(h<l){l=h
n=j}}}else if(o===1)n=s.y?null:B.a.gu(p)
g=A.l3(s.c,"n"+a3.r++,a5,a6)
o=a3.e
i=o.a
f=g.a
i.i(0,f,g)
J.bO(a3.f.ac(a3.bX(a5),new A.ix()),g)
g.r.k(0,a4)
for(e=p.length,d=g.w,o=o.b,k=0;k<p.length;p.length===e||(0,A.k)(p),++k){j=p[k]
if(j===n)continue
c=B.a.cr(o,j)
b=j.b
a=b===r?f:b
a0=j.c
a1=a0===r?f:a0
a2=new A.I(j.a,a,a1,j.d,j.e,j.f,j.r,j.w,j.x,j.y,j.z,j.Q,j.as,j.at,j.ax,j.ay,j.ch,j.CW,j.cx,j.cy,j.db)
B.a.i(o,c,a2)
B.a.U(q,j)
b=i.h(0,r===b?a0:b).w
B.a.U(b,j)
B.a.k(b,a2)
B.a.k(d,a2)}a3.aT(a7.$2(r,f))},
d0(a){var s,r,q,p,o,n,m,l,k,j,i=A.m(t.N,t.i),h=A.d([],t.s)
if(a===B.i){for(s=this.e,r=s.d,r=new A.O(r,r.r,r.e,A.i(r).j("O<2>"));r.l();){q=r.d
i.i(0,q,0)
B.a.k(h,q)}for(s=s.a,s=new A.O(s,s.r,s.e,A.i(s).j("O<2>"));s.l();){r=s.d
if(r.y&&!i.E(r.a)){r=r.a
i.i(0,r,0)
B.a.k(h,r)}}}else for(s=this.e.c,s=new A.O(s,s.r,s.e,A.i(s).j("O<2>"));s.l();){r=s.d.b
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
A.iy.prototype={
$0(){return A.d([],t.go)},
$S:21}
A.iz.prototype={
$1(a){t.h.a(a)
return a instanceof A.aH||a instanceof A.al||a instanceof A.aB},
$S:67}
A.iF.prototype={
$1(a){return t.f.a(a).gP()},
$S:68}
A.iH.prototype={
$1(a){var s=A.nW(a)
return s==null?B.h:s},
$S:69}
A.iG.prototype={
$3$exclude(a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this
t.lv.a(a3)
for(s=a1.b,r=s.length,q=a2.a,p=a2.b,o=a1.a,n=a1.e,m=a1.d,l=a1.c,k=0;k<s.length;s.length===r||(0,A.k)(s),++k){j=s[k]
i=j.a
if(i===a4)continue
if(!B.a.v(a3,l.$1(j)))continue
h=m.$1(j)
for(g=J.a9(h),f=1;f<g.gm(h);++f){e=f-1
d=A.ls(a2,g.h(h,e),g.h(h,f))
c=d.a
b=d.b
a=c.a-q
a0=c.b-p
a0=Math.sqrt(a*a+a0*a0)
a=o.gb6()
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
$S:70}
A.iA.prototype={
$2(a,b){var s=this.b.a,r=this.a.a,q=r.d
return A.lT(q,q,!1,0,0,s,a,"pump_"+s,B.X,0,0,null,this.c.a,r.w,0,0,r.f,null,b,B.j,null)},
$S:22}
A.iB.prototype={
$2(a,b){var s,r=this,q=r.b.a,p=r.c,o=p?B.ev:B.eu,n=r.a.a,m=r.d
if(p){p=n.r
p=p>0?p:m.z}else p=0
s=n.d
return A.lT(s,s,!1,0,0,q,a,"dev_"+q,o,0,0,null,null,n.f,0,p,1,null,b,B.j,m.a)},
$S:22}
A.iC.prototype={
$1(a){return this.a.e.x.v(0,t.G.a(a).a)},
$S:1}
A.iD.prototype={
$1(a){return t.G.a(a).dx!=null},
$S:1}
A.iE.prototype={
$1(a){t.G.a(a)
return this.a.e.x.v(0,a.a)||a.dx!=null},
$S:1}
A.iI.prototype={
$1(a){return t.G.a(a).f===this.a},
$S:1}
A.ix.prototype={
$0(){return A.d([],t.go)},
$S:21}
A.cn.prototype={
G(){return"PivotKind."+this.b}}
A.iW.prototype={
gcm(){var s=this,r=s.c+s.ax
return s.a===B.E?3.141592653589793*r*r*(B.b.a1(s.db,1,360)/360):r*Math.max(s.d,0)},
gbH(){var s=this.ch
return s<=0?0:this.gcm()*this.ay/1000/(s*3600)},
gcC(){var s=this.e
return s<=0?0:Math.max(1,B.b.J(this.c/s))}}
A.co.prototype={
n(){var s=this
return A.V(["i",s.a,"d",s.b,"q",s.c,"h",s.d,"dz",s.e],t.N,t.z)}}
A.bC.prototype={
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
A.cN.prototype={
gcJ(){return B.a.W(this.b,0,new A.iT(),t.S)},
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
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.iU()),q),q.j("w.E"))
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
if(s.length!==0){r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.iV()),q),q.j("w.E"))
o.i(0,"spans",s)}return o}}
A.iT.prototype={
$2(a,b){return A.aV(a)+t.fR.a(b).d},
$S:72}
A.iU.prototype={
$1(a){return t.oz.a(a).n()},
$S:73}
A.iV.prototype={
$1(a){return t.fR.a(a).n()},
$S:74}
A.kh.prototype={
$1(a){return 0},
$S:23}
A.ks.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=B.b.a2(a2*10),a0=b.a,a1=a0.h(0,a)
if(a1!=null)return a1
s=b.b
r=-1/0
if(s.a===B.E){q=B.b.a1(s.db,1,360)*3.141592653589793/180
p=Math.max(8,B.b.a2(b.c*q/6.283185307179586))
for(s=b.e,o=b.f,n=o.a,o=o.b,m=b.r,l=q/2,k=q>=6.283185306179586,j=b.d,i=0;i<=p;++i){h=k?0:l
g=j+q*i/p-h
h=s.$1(new A.B(n+a2*Math.cos(g),o+a2*Math.sin(g)))
if(typeof h!=="number")return h.R()
r=Math.max(r,h-m)}}else{o=b.d
n=Math.cos(o)
o=Math.sin(o)
m=-o
s=s.d
p=Math.max(4,B.b.a2(s/25))
for(l=b.f,k=l.a,j=k+n*a2,l=l.b,o=l+o*a2,h=b.e,i=0;i<=p;++i){f=s*i/p
e=m*f
f=n*f
d=h.$1(new A.B(j+e,o+f))
f=h.$1(new A.B(k+e,l+f))
if(typeof d!=="number")return d.R()
if(typeof f!=="number")return A.bu(f)
r=Math.max(r,d-f)}}c=isFinite(r)?Math.max(r,0):0
a0.i(0,a,c)
return c},
$S:23}
A.bg.prototype={
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
A.aw.prototype={
n(){var s=this,r=s.c
return A.V(["ent",s.a,"i",s.b,"p",A.d([r.a,r.b],t.n),"z",s.d,"h",s.e,"q",s.f,"qn",s.r,"n",s.w,"lo",s.x,"hi",s.y,"label",s.z],t.N,t.z)}}
A.bS.prototype={
n(){var s=this
return A.V(["ent",s.a,"link",s.b,"q",s.c,"hf",s.d,"hp",s.e,"pu",s.f,"pd",s.r,"st",s.w,"z",s.x],t.N,t.z)}}
A.cU.prototype={
ge6(){var s=this
return s.w>=s.y-0.000001&&s.x<=s.z+0.000001},
gbz(){var s=this.ax
return s.length===0?null:B.a.L(s,new A.jC())},
gdV(){var s=this.ax
return s.length===0?null:B.a.L(s,new A.jB())},
cn(a){var s=this
t.fm.a(a)
return A.lg(s.z,s.y,s.dx,s.c,s.ay,s.e,s.cy,s.fr,s.x,s.w,s.Q,s.ax,s.dy,s.db,s.at,s.r,s.d,s.as,s.CW,s.a,s.f,s.cx,a,s.b)},
n(){var s,r,q=this,p=q.as.n(),o=q.at,n=A.t(o),m=n.j("u<1,j<c,@>>")
o=A.p(new A.u(o,n.j("j<c,@>(1)").a(new A.jD()),m),m.j("w.E"))
n=q.ax
m=A.t(n)
s=m.j("u<1,j<c,@>>")
n=A.p(new A.u(n,m.j("j<c,@>(1)").a(new A.jE()),s),s.j("w.E"))
m=q.ay
s=A.t(m)
r=s.j("u<1,j<c,@>>")
m=A.p(new A.u(m,s.j("j<c,@>(1)").a(new A.jF()),r),r.j("w.E"))
return A.V(["valve",q.a,"name",q.b,"conv",q.c,"q",q.d,"hd",q.e,"hv",q.f,"hreq",q.r,"pmin",q.w,"pmax",q.x,"lo",q.y,"hi",q.z,"pn",q.Q,"uni",p,"pipes",o,"outlets",n,"devices",m,"warn",q.ch,"zv",q.CW,"valveName",q.cx,"n",q.cy,"cost",q.db,"energy",q.dx,"ocu",q.dy,"epp",q.fr],t.N,t.z)}}
A.jC.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e<=b.e?a:b},
$S:15}
A.jB.prototype={
$2(a,b){var s=t.o
s.a(a)
s.a(b)
return a.e>=b.e?a:b},
$S:15}
A.jD.prototype={
$1(a){return t.h4.a(a).n()},
$S:24}
A.jE.prototype={
$1(a){return t.o.a(a).n()},
$S:78}
A.jF.prototype={
$1(a){return t.n6.a(a).n()},
$S:25}
A.cq.prototype={
n(){var s=this
return A.V(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"z",s.f,"calc",s.r,"dh",s.w,"mh",s.x,"dq",s.y,"mq",s.z],t.N,t.z)}}
A.aT.prototype={
n(){var s=this,r=s.f
return A.V(["id",s.a,"name",s.b,"q",s.c,"h",s.d,"hreq",s.e,"p",A.d([r.a,r.b],t.n)],t.N,t.z)}}
A.b6.prototype={
n(){var s,r,q,p=this,o=p.d,n=A.t(o),m=n.j("u<1,j<c,@>>")
o=A.p(new A.u(o,n.j("j<c,@>(1)").a(new A.jg()),m),m.j("w.E"))
n=p.e
m=A.t(n)
s=m.j("u<1,j<c,@>>")
n=A.p(new A.u(n,m.j("j<c,@>(1)").a(new A.jh()),s),s.j("w.E"))
m=p.f
s=A.t(m)
r=s.j("u<1,j<c,@>>")
m=A.p(new A.u(m,s.j("j<c,@>(1)").a(new A.ji()),r),r.j("w.E"))
s=p.r
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.jj()),q),q.j("w.E"))
return A.V(["id",p.a,"name",p.b,"conv",p.c,"supplies",o,"valves",n,"pipes",m,"devices",s,"warn",p.w,"q",p.x,"dur",p.y,"energy",p.z],t.N,t.z)}}
A.jg.prototype={
$1(a){return t.ep.a(a).n()},
$S:80}
A.jh.prototype={
$1(a){return t.nN.a(a).n()},
$S:81}
A.ji.prototype={
$1(a){return t.h4.a(a).n()},
$S:24}
A.jj.prototype={
$1(a){return t.n6.a(a).n()},
$S:25}
A.ad.prototype={
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
A.ce.prototype={
n(){var s=this
return A.V(["valve",s.a,"name",s.b,"q",s.c,"hd",s.d,"hreq",s.e,"n",s.f,"hend",s.r,"vmax",s.w,"vf",s.x,"conv",s.y],t.N,t.z)}}
A.bF.prototype={
n(){var s=this
return A.V(["ent",s.a,"ctx",s.b,"name",s.c,"v",s.d,"a",s.e,"dh",s.f,"hs",s.r,"pn",s.w,"tc",s.x,"tcrit",s.y],t.N,t.z)}}
A.eb.prototype={
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"timestamp",p.a.bD())
o.i(0,"method",p.b)
s=p.c
r=A.i(s).j("ao<2>")
q=t.P
r=A.l8(new A.ao(s,r),r.j("j<c,@>(h.E)").a(new A.ho()),r.j("h.E"),q)
s=A.p(r,A.i(r).j("h.E"))
o.i(0,"zones",s)
s=p.d
if(s.a!==0){r=A.i(s).j("ao<2>")
q=A.l8(new A.ao(s,r),r.j("j<c,@>(h.E)").a(new A.hp()),r.j("h.E"),q)
s=A.p(q,A.i(q).j("h.E"))
o.i(0,"pivots",s)}s=p.e
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.hq()),q),q.j("w.E"))
o.i(0,"systemFlows",s)
o.i(0,"messages",p.f)
s=p.r
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.hr()),q),q.j("w.E"))
o.i(0,"bom",s)
s=p.w
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.hs()),q),q.j("w.E"))
o.i(0,"flushing",s)
s=p.x
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.ht()),q),q.j("w.E"))
o.i(0,"surge",s)
s=p.y
s=A.p(s,A.i(s).c)
o.i(0,"unconnected",s)
o.i(0,"capital",p.z)
o.i(0,"annualCapital",p.Q)
o.i(0,"annualEnergy",p.as)
return o}}
A.ho.prototype={
$1(a){return t.kV.a(a).n()},
$S:82}
A.hp.prototype={
$1(a){return t.oY.a(a).n()},
$S:83}
A.hq.prototype={
$1(a){return t.ju.a(a).n()},
$S:84}
A.hr.prototype={
$1(a){return t.q.a(a).n()},
$S:85}
A.hs.prototype={
$1(a){return t.lG.a(a).n()},
$S:86}
A.ht.prototype={
$1(a){return t.eu.a(a).n()},
$S:87}
A.bT.prototype={
a7(a){if(a<=0)return 0
return this.a*Math.pow(a,this.b)},
cu(a){if(a<=0||this.c===0)return 0
return this.c*Math.pow(a,this.d)},
an(a){var s=Math.max(a,0.000001),r=this.b
if(r===0)return 1e-9
return this.a*r*Math.pow(s,r-1)},
dL(a,b,c){var s=this.b
if(s<=0.01)return B.hh
s=1/s
return new A.n(a*Math.pow(1-c,s),a*Math.pow(1+b,s))},
n(){var s=this
return A.V(["k",s.a,"x",s.b,"ra",s.c,"rb",s.d],t.N,t.z)}}
A.kq.prototype={
$2(a,b){return A.S(a)+A.S(b)},
$S:3}
A.kr.prototype={
$2(a,b){return A.S(a)+Math.abs(A.S(b)-this.a)},
$S:3}
A.cf.prototype={
G(){return"FrictionMethod."+this.b}}
A.aF.prototype={
b4(a){var s
if(a===0)return 0
s=this.a*Math.pow(Math.abs(a),this.b)+this.c
return a<0?-s:s},
an(a){var s=this.b
return Math.max(s*this.a*Math.pow(Math.max(Math.abs(a),1e-9),s-1),1e-9)},
n(){return A.V(["k",this.a,"n",this.b,"c",this.c],t.N,t.z)}}
A.dh.prototype={
G(){return"HNodeKind."+this.b}}
A.bo.prototype={}
A.bV.prototype={
G(){return"HLinkKind."+this.b}}
A.cG.prototype={
G(){return"LinkStatus."+this.b}}
A.dg.prototype={
gm(a){return this.f}}
A.iK.prototype={}
A.eJ.prototype={}
A.ew.prototype={}
A.cL.prototype={}
A.eh.prototype={
H(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7,f8=this,f9=A.d([],t.s),g0=f8.b,g1=A.i(g0).j("ao<2>"),g2=A.p(new A.ao(g0,g1),g1.j("h.E"))
g1=t.N
s=A.m(g1,t.S)
for(r=g2.length,q=0,p=0;p<g2.length;g2.length===r||(0,A.k)(g2),++p){o=g2[p]
if(o.b===B.Y){n=q+1
s.i(0,o.a,q)
q=n}}r=A.t(g2)
if(!new A.C(g2,r.j("v(1)").a(new A.ih()),r.j("C<1>")).gt(0).l())B.a.k(f9,"no_fixed_head_node")
r=t.i
m=A.m(g1,r)
for(l=g2.length,p=0;p<g2.length;g2.length===l||(0,A.k)(g2),++p){o=g2[p]
if(o.b===B.Z){k=o.e
if(k==null)k=o.c}else k=o.c+10
m.i(0,o.a,k)}j=A.d([],t.n)
for(l=f8.c,k=l.length,p=0;p<l.length;l.length===k||(0,A.k)(l),++p){i=l[p]
switch(i.d.a){case 0:case 3:case 2:h=i.e
B.a.k(j,3.141592653589793*h*h/4)
break
case 1:h=i.z
if(h!=null){h=isFinite(h.gbC())?h.gbC()/2:0.01
h=Math.max(h,0.0001)}else h=0.01
B.a.k(j,h)
break
case 4:B.a.k(j,0)
break}h=i.d
g=h===B.M
if(g)i.ay=B.x
h=h===B.ew
if(h)i.ay=B.l
if(!h&&!g)i.ay=B.n}k=A.m(g1,r)
for(h=g2.length,p=0;p<g2.length;g2.length===h||(0,A.k)(g2),++p)k.i(0,g2[p].a,0)
f=A.m(g1,t.y)
h=l.length
e=A.bd(h,1,!1,r)
g=l.length
d=A.bd(g,0,!1,r)
r=f8.a.a
b=r===B.bf
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
else{a6=f8.c5(i,a3)
o=r?1.852:2
a7=Math.max(Math.abs(a3),1e-7)
a8=i.x
if(a8>0){a9=i.e
b0=3.141592653589793*a9*a9/4
b1=a8/(19.6133*b0*b0)}else b1=0
b2=o*a6*Math.pow(a7,o-1)+2*b1*a7
if(b&&a7>0.000001)b2+=(f8.c5(i,a7*1.01)-a6)/(a7*0.01)*Math.pow(a7,o)
b3=a6*Math.pow(a7,o)+b1*a7*a7
a4=Math.max(b2,1e-12)
a5=a3<0?-b3:b3}break
case 3:b4=i.Q
if(b4==null)b4=B.I
if(i.ay===B.l)a5=1e8*a3
else{a4=Math.max(b4.an(a3),1e-9)
a5=b4.b4(a3)}break
case 2:b4=i.Q
a8=i.ay
if(a8===B.l)a5=1e8*a3
else if(a8===B.n){a8=b4!=null
a4=a8?Math.max(b4.an(a3),1e-9):0.01
a5=a8?b4.b4(a3):0.01*a3}else{a4=1/0
a5=0}break
case 1:b5=i.z
if(b5==null||i.ay===B.l)a5=1e8*a3
else if(a3<=0)a5=1e8*a3
else{b6=b5.gbC()
if(isFinite(b6)&&a3>b6){b7=Math.max(-b5.an(b6),0.000001)
a5=-b5.bv(b6)+(a3-b6)*b7
a4=b7}else{a4=Math.max(-b5.an(a3),0.000001)
a5=-b5.bv(a3)}}break
default:a4=null
a5=null}B.a.i(e,a2,a4)
B.a.i(d,a2,a5)}b8=A.os(q)
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
d3=1/Math.max(c5.an(b5)*o.r,1e-9)
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
f4=A.m(g1,t.oX)
for(g0=g2.length,p=0;p<g2.length;g2.length===g0||(0,A.k)(g2),++p){o=g2[p]
r=o.a
k=m.h(0,r)
k.toString
h=o.f
if(h!=null&&o.r>0)h.a7(Math.max(k-o.c-o.w,0))
f4.i(0,r,new A.eJ(k,k-o.c))}f5=A.m(g1,t.g_)
for(a2=0;a2<l.length;++a2){i=l[a2]
if(!(a2<j.length))return A.b(j,a2)
f6=j[a2]
g0=m.h(0,i.b)
g0.toString
g1=m.h(0,i.c)
g1.toString
f7=i.d===B.bg&&i.z!=null&&f6>0?i.z.bv(f6):0
f5.i(0,i.a,new A.ew(f6,g0-g1,i.ay,f7))}return new A.cL(c,f4,f5)},
c5(a,b){var s,r,q=this.a
switch(q.a.a){case 0:return 10.67*a.f/(Math.pow(a.r,1.852)*Math.pow(a.e,4.871))
case 1:s=a.e
r=3.141592653589793*s*s/4
return A.mW(a.w/s,A.fw(s,Math.max(Math.abs(b),1e-7))*s/q.b)*a.f/(s*2*9.80665*r*r)}}}
A.ih.prototype={
$1(a){return t.b.a(a).b===B.Z},
$S:89}
A.cP.prototype={
bv(a){var s=this,r=s.d,q=a/r
return r*r*(s.a*q*q+s.b*q+s.c)},
an(a){var s=this.d
return s*(2*this.a*(a/s)+this.b)},
gbC(){var s,r,q,p,o=this,n=o.a
if(n===0){n=o.b
return n<0?-o.c/n*o.d:1/0}s=o.b
r=s*s-4*n*o.c
if(r<0)return 1/0
s=-s
n=2*n
q=t.ee
p=A.p(new A.C(A.d([(s-Math.sqrt(r))/n,(s+Math.sqrt(r))/n],t.n),t.eq.a(new A.j6()),q),q.j("h.E"))
B.a.a0(p)
return p.length===0?1/0:B.a.gu(p)*o.d},
n(){var s=this
return A.V(["a",s.a,"b",s.b,"c",s.c,"w",s.d],t.N,t.z)}}
A.j6.prototype={
$1(a){return A.S(a)>0},
$S:6}
A.j5.prototype={
$1(a){t.aL.a(a)
return a.a>=0&&a.b>=0},
$S:91}
A.ja.prototype={
H(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5={},b6=b4.a
if(b6===0)return B.bk
s=b4.b
r=A.t(s)
q=r.j("u<1,j<f,e>>")
p=A.p(new A.u(s,r.j("j<f,e>(1)").a(new A.jb()),q),q.j("w.E"))
s=t.i
o=A.ey(b4.c,!0,s)
n=A.bd(b6,!1,!1,t.y)
r=t.X
m=A.d([],r)
l=A.d([],t.l0)
q=t.S
k=J.en(b6,q)
for(j=0;j<b6;++j){if(!(j<p.length))return A.b(p,j)
i=p[j]
i=i.gm(i)
if(!(j<p.length))return A.b(p,j)
k[j]=i-(p[j].E(j)?1:0)}h=A.m(q,t.nO)
for(j=0;j<b6;++j){if(!(j<k.length))return A.b(k,j)
h.ac(k[j],new A.jc()).k(0,j)}b5.a=0
g=new A.jd(b5,b4,h,n)
f=new A.je(b5,h,k)
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
for(a2=c.gaH(),a2=a2.gt(a2);a2.l();){a3=a2.gp()
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
a8.U(0,d)
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
B.a.k(l,a2)}a6=A.bd(b6,0,!1,s)
for(b1=m.length-1;b1>=0;--b1){if(!(b1<m.length))return A.b(m,b1)
d=m[b1]
if(!(b1<l.length))return A.b(l,b1)
c=l[b1]
if(!(d>=0&&d<o.length))return A.b(o,d)
b2=o[d]
for(s=new A.ah(c,c.r,c.e,A.i(c).j("ah<1,2>"));s.l();){b3=s.d
r=b3.a
if(r!==d){q=b3.b
if(!(r>=0&&r<b6))return A.b(a6,r)
b2-=q*a6[r]}}s=c.h(0,d)
s.toString
B.a.i(a6,d,b2/s)}return a6}}
A.jb.prototype={
$1(a){return A.ob(t.jq.a(a),t.S,t.i)},
$S:92}
A.jc.prototype={
$0(){return A.L(t.S)},
$S:26}
A.jd.prototype={
$0(){var s,r,q,p,o,n,m,l=this
for(s=l.a,r=l.b.a,q=r+1,p=l.c;;){o=p.h(0,s.a)
if(o!=null&&o.ga8(o)){n=o.gu(o)
o.U(0,n)
return n}if(++s.a>q){for(s=l.d,q=s.length,m=0;m<r;++m){if(!(m<q))return A.b(s,m)
if(!s[m])return m}return-1}}},
$S:94}
A.je.prototype={
$2(a,b){var s,r=this.b,q=this.c
if(!(a>=0&&a<q.length))return A.b(q,a)
s=r.h(0,q[a])
if(s!=null)s.U(0,a)
B.a.i(q,a,b)
r.ac(b,new A.jf()).k(0,a)
r=this.a
if(b<r.a)r.a=b},
$S:10}
A.jf.prototype={
$0(){return A.L(t.S)},
$S:26}
A.dH.prototype={
n(){var s=this
return A.V(["count",s.a,"mean",s.b,"min",s.c,"max",s.d,"cu",s.e,"du",s.f,"eu",s.r,"us",s.w,"qvar",s.x,"cv",s.y],t.N,t.z)}}
A.jw.prototype={
$1(a){return isFinite(A.S(a))},
$S:6}
A.jx.prototype={
$2(a,b){return A.S(a)+A.S(b)},
$S:3}
A.jy.prototype={
$2(a,b){return A.S(a)+Math.abs(A.S(b)-this.a)},
$S:3}
A.jz.prototype={
$2(a,b){return A.S(a)+A.S(b)},
$S:3}
A.jA.prototype={
$2(a,b){var s
A.S(a)
s=A.S(b)-this.a
return a+s*s},
$S:3}
A.b1.prototype={
G(){return"PipeMaterial."+this.b}}
A.eu.prototype={
n(){return A.V(["strings",this.a,"tutorial",B.aq,"catalog",B.aq],t.N,t.z)}}
A.ig.prototype={
n(){var s=this
return A.V(["zone",s.a,"north",s.b,"e0",s.c,"n0",s.d],t.N,t.z)}}
A.b2.prototype={
G(){return"PipeUsage."+this.b}}
A.J.prototype={
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
q=r.j("cd<1,c>")
s=A.p(new A.cd(s,r.j("c(1)").a(new A.iS()),q),q.j("h.E"))
o.i(0,"usage",s)
o.i(0,"enabled",p.at)
s=p.c
if(s.length!==0)o.i(0,"sup",s)
s=p.d
if(s.length!==0)o.i(0,"code",s)
return o}}
A.iS.prototype={
$1(a){return t.W.a(a).b},
$S:95}
A.iR.prototype={
$1(a){return A.af(B.eG,A.D(a),t.W)},
$S:96}
A.bf.prototype={
G(){return"OutletKind."+this.b}}
A.F.prototype={
n(){var s=this
return A.V(["id",s.a,"name",s.b,"curve",s.c.n(),"arc",s.d,"minH",s.e,"maxH",s.f,"defH",s.r,"cv",s.w,"tolB",s.x,"tolA",s.y],t.N,t.z)}}
A.a3.prototype={
aD(a){var s=this.f
if(s.length===0)return null
return B.a.ai(s,new A.iN(a),new A.iO(this))},
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
o.i(0,"kind",p.e.b)
s=p.f
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.iP()),q),q.j("w.E"))
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
A.iN.prototype={
$1(a){return t.mP.a(a).a===this.a},
$S:97}
A.iO.prototype={
$0(){return B.a.gu(this.a.f)},
$S:98}
A.iP.prototype={
$1(a){return t.mP.a(a).n()},
$S:99}
A.iM.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j=null,i=t.P
i.a(a)
s=A.D(a.h(0,"id"))
r=A.D(a.h(0,"name"))
i=A.lS(i.a(a.h(0,"curve")))
q=A.y(a.h(0,"arc"))
if(q==null)q=j
if(q==null)q=360
p=A.y(a.h(0,"minH"))
if(p==null)p=j
if(p==null)p=5
o=A.y(a.h(0,"maxH"))
if(o==null)o=j
if(o==null)o=60
n=A.y(a.h(0,"defH"))
if(n==null)n=j
if(n==null)n=20
m=A.y(a.h(0,"cv"))
if(m==null)m=j
if(m==null)m=0.03
l=A.y(a.h(0,"tolB"))
if(l==null)l=j
if(l==null)l=0.05
k=A.y(a.h(0,"tolA"))
if(k==null)k=j
return new A.F(s,r,i,q,p,o,n,m,l,k==null?0.05:k)},
$S:100}
A.aS.prototype={
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
A.aJ.prototype={
G(){return"ValveKind."+this.b}}
A.E.prototype={
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
A.aQ.prototype={
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"id",p.a)
o.i(0,"name",p.b)
s=p.r
r=A.t(s)
q=r.j("u<1,q<e>>")
s=A.p(new A.u(s,r.j("q<e>(1)").a(new A.j8()),q),q.j("w.E"))
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
A.j8.prototype={
$1(a){t.aL.a(a)
return A.d([a.a,a.b],t.n)},
$S:152}
A.j7.prototype={
$1(a){var s=J.a9(a)
return new A.n(A.at(s.h(a,0)),A.at(s.h(a,1)))},
$S:102}
A.a7.prototype={
G(){return"FittingKind."+this.b}}
A.Z.prototype={
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
A.fC.prototype={
dH(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g
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
s=new A.ae(s,A.t(s).j("ae<1,J?>"))
s=s.ai(s,new A.fU(a),new A.fV())}return s},
a_(a){var s
if(a==null)s=null
else{s=this.b
s=new A.ae(s,A.t(s).j("ae<1,a3?>"))
s=s.ai(s,new A.fS(a),new A.fT())}return s},
ad(a){var s
if(a==null)s=null
else{s=this.c
s=new A.ae(s,A.t(s).j("ae<1,aS?>"))
s=s.ai(s,new A.h6(a),new A.h7())}return s},
a3(a){var s
if(a==null)s=null
else{s=this.d
s=new A.ae(s,A.t(s).j("ae<1,E?>"))
s=s.ai(s,new A.he(a),new A.hf())}return s},
ar(a){var s
if(a==null)s=null
else{s=this.e
s=new A.ae(s,A.t(s).j("ae<1,aQ?>"))
s=s.ai(s,new A.fY(a),new A.fZ())}return s},
ab(a){var s=this.a,r=A.t(s),q=r.j("C<1>")
s=A.p(new A.C(s,r.j("v(1)").a(new A.fW(a)),q),q.j("h.E"))
B.a.ao(s,new A.fX())
return s},
n(){var s,r,q,p,o,n=this,m=n.a,l=A.t(m),k=l.j("u<1,j<c,@>>")
m=A.p(new A.u(m,l.j("j<c,@>(1)").a(new A.h8()),k),k.j("w.E"))
l=n.b
k=A.t(l)
s=k.j("u<1,j<c,@>>")
l=A.p(new A.u(l,k.j("j<c,@>(1)").a(new A.h9()),s),s.j("w.E"))
k=n.c
s=A.t(k)
r=s.j("u<1,j<c,@>>")
k=A.p(new A.u(k,s.j("j<c,@>(1)").a(new A.ha()),r),r.j("w.E"))
s=n.d
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.hb()),q),q.j("w.E"))
r=n.e
q=A.t(r)
p=q.j("u<1,j<c,@>>")
r=A.p(new A.u(r,q.j("j<c,@>(1)").a(new A.hc()),p),p.j("w.E"))
q=n.f
p=A.t(q)
o=p.j("u<1,j<c,@>>")
q=A.p(new A.u(q,p.j("j<c,@>(1)").a(new A.hd()),o),o.j("w.E"))
return A.V(["pipes",m,"outlets",l,"tapes",k,"valves",s,"pumps",r,"fittings",q],t.N,t.z)},
cI(){var s,r,q,p,o,n,m,l,k,j=new A.h5(),i=new A.h3(),h=this.a,g=A.t(h),f=g.j("C<1>"),e=A.p(new A.C(h,g.j("v(1)").a(new A.h_()),f),f.j("h.E"))
g=A.t(e)
f=g.j("e(1)")
s=i.$1(new A.u(e,f.a(new A.h0(j)),g.j("u<1,e>")))
r=A.m(t.N,t.i)
for(q=h.length,p=g.j("v(1)"),o=g.j("C<1>"),g=g.j("be<1,e>"),n=0;n<h.length;h.length===q||(0,A.k)(h),++n){m=h[n]
l=m.Q
if(l>0){r.i(0,m.a,l)
continue}l=i.$1(new A.be(new A.C(e,p.a(new A.h1(m)),o),f.a(new A.h2(j)),g))
k=l==null?s:l
if(k==null)k=0.0001
l=j.$1(m)
if(typeof l!=="number")return A.bu(l)
r.i(0,m.a,k*l)}return r}}
A.fU.prototype={
$1(a){return t.cV.a(a).a===this.a},
$S:103}
A.fV.prototype={
$0(){return null},
$S:2}
A.fS.prototype={
$1(a){return t.h2.a(a).a===this.a},
$S:104}
A.fT.prototype={
$0(){return null},
$S:2}
A.h6.prototype={
$1(a){return t.lJ.a(a).a===this.a},
$S:105}
A.h7.prototype={
$0(){return null},
$S:2}
A.he.prototype={
$1(a){return t.kf.a(a).a===this.a},
$S:106}
A.hf.prototype={
$0(){return null},
$S:2}
A.fY.prototype={
$1(a){return t.gL.a(a).a===this.a},
$S:107}
A.fZ.prototype={
$0(){return null},
$S:2}
A.fW.prototype={
$1(a){t.p.a(a)
return a.at&&a.as.v(0,this.a)},
$S:5}
A.fX.prototype={
$2(a,b){var s=t.p
return B.b.T(s.a(a).f,s.a(b).f)},
$S:108}
A.h8.prototype={
$1(a){return t.p.a(a).n()},
$S:109}
A.h9.prototype={
$1(a){return t.fa.a(a).n()},
$S:110}
A.ha.prototype={
$1(a){return t.gs.a(a).n()},
$S:111}
A.hb.prototype={
$1(a){return t.e4.a(a).n()},
$S:112}
A.hc.prototype={
$1(a){return t.dz.a(a).n()},
$S:113}
A.hd.prototype={
$1(a){return t.kN.a(a).n()},
$S:114}
A.fM.prototype={
$1(a){return A.oh(t.P.a(a))},
$S:115}
A.fN.prototype={
$1(a){return A.of(t.P.a(a))},
$S:116}
A.fO.prototype={
$1(a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=null,a1=t.P
a1.a(a2)
s=A.D(a2.h(0,"id"))
r=A.D(a2.h(0,"name"))
q=A.x(a2.h(0,"sup"))
if(q==null)q=""
p=A.x(a2.h(0,"code"))
if(p==null)p=""
o=A.y(a2.h(0,"nominalMm"))
if(o==null)o=a0
if(o==null)o=16
n=A.at(a2.h(0,"idMm"))
m=A.at(a2.h(0,"spacing"))
a1=A.lS(a1.a(a2.h(0,"emitter")))
l=A.y(a2.h(0,"barbK"))
if(l==null)l=a0
if(l==null)l=0.4
k=A.y(a2.h(0,"cv"))
if(k==null)k=a0
if(k==null)k=0.03
j=A.y(a2.h(0,"minH"))
if(j==null)j=a0
if(j==null)j=4
i=A.y(a2.h(0,"maxH"))
if(i==null)i=a0
if(i==null)i=15
h=A.y(a2.h(0,"inletH"))
if(h==null)h=a0
if(h==null)h=10
g=A.y(a2.h(0,"tolB"))
if(g==null)g=a0
if(g==null)g=30
f=A.y(a2.h(0,"tolA"))
if(f==null)f=a0
if(f==null)f=20
e=A.y(a2.h(0,"ratingM"))
if(e==null)e=a0
if(e==null)e=25
d=A.y(a2.h(0,"roughMm"))
if(d==null)d=a0
if(d==null)d=0.002
c=A.y(a2.h(0,"c"))
if(c==null)c=a0
if(c==null)c=140
b=A.y(a2.h(0,"cost"))
if(b==null)b=a0
if(b==null)b=0
a=A.Y(a2.h(0,"enabled"))
return A.cT(l,p,b,k,h,a1,m,a!==!1,c,s,n,i,j,r,o,e,d,q,f,g)},
$S:117}
A.fP.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e=t.P
e.a(a)
s=A.D(a.h(0,"id"))
r=A.D(a.h(0,"name"))
q=A.x(a.h(0,"sup"))
if(q==null)q=""
p=A.x(a.h(0,"code"))
if(p==null)p=""
o=A.af(B.eQ,A.D(a.h(0,"kind")),t.bn)
n=A.at(a.h(0,"sizeMm"))
e=e.a(a.h(0,"loss"))
m=A.at(e.h(0,"k"))
l=A.y(e.h(0,"n"))
if(l==null)l=f
if(l==null)l=2
e=A.y(e.h(0,"c"))
if(e==null)e=f
if(e==null)e=0
k=A.y(a.h(0,"minQ"))
if(k==null)k=f
if(k==null)k=0
j=A.y(a.h(0,"maxQ"))
if(j==null)j=f
if(j==null)j=1
i=A.y(a.h(0,"cost"))
if(i==null)i=f
if(i==null)i=0
h=A.y(a.h(0,"setting"))
if(h==null)h=f
if(h==null)h=0
g=A.Y(a.h(0,"enabled"))
return new A.E(s,r,q,p,o,n,new A.aF(m,l,e),k,j,i,h,g!==!1)},
$S:118}
A.fQ.prototype={
$1(a){return A.oo(t.P.a(a))},
$S:119}
A.fR.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j
t.P.a(a)
s=A.D(a.h(0,"id"))
r=A.D(a.h(0,"name"))
q=A.af(B.f0,A.D(a.h(0,"kind")),t.na)
p=A.at(a.h(0,"sizeMm"))
o=A.y(a.h(0,"size2Mm"))
if(o==null)o=null
if(o==null)o=0
n=A.y(a.h(0,"cost"))
if(n==null)n=null
if(n==null)n=0
m=A.Y(a.h(0,"enabled"))
l=A.x(a.h(0,"sup"))
if(l==null)l=""
k=A.x(a.h(0,"code"))
if(k==null)k=""
j=A.x(a.h(0,"mat"))
if(j==null)j=""
return new A.Z(s,r,l,k,q,p,o,n,m!==!1,j)},
$S:120}
A.h5.prototype={
$1(a){var s,r=a.f,q=a.z
q=q>0?q:Math.max(0,(a.e-r)/2)
s=r+2*Math.max(q,0.1)
return 0.7853981633974483*(s*s-r*r)},
$S:4}
A.h3.prototype={
$1(a){var s,r,q=t.kk.a(a).bF(0,new A.h4()),p=A.p(q,q.$ti.j("h.E"))
B.a.a0(p)
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
$S:121}
A.h4.prototype={
$1(a){A.S(a)
return isFinite(a)&&a>0},
$S:6}
A.h_.prototype={
$1(a){return t.p.a(a).Q>0},
$S:5}
A.h0.prototype={
$1(a){var s,r
t.p.a(a)
s=a.Q
r=this.a.$1(a)
if(typeof r!=="number")return A.bu(r)
return s/r},
$S:4}
A.h1.prototype={
$1(a){return t.p.a(a).r===this.a.r},
$S:5}
A.h2.prototype={
$1(a){var s,r
t.p.a(a)
s=a.Q
r=this.a.$1(a)
if(typeof r!=="number")return A.bu(r)
return s/r},
$S:4}
A.fE.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.n8(r,b)
s=b
break A}return s},
$S:28}
A.fF.prototype={
$4$radiusM(a,b,c,d){var s=d>0,r=s?0.35:0,q=Math.pow(b,c),p=s?d/Math.pow(b,r):0
s=s?r:0
return new A.bT(a*27777777777777776e-23/q,c,p,s)},
$3(a,b,c){return this.$4$radiusM(a,b,c,0)},
$S:123}
A.fD.prototype={
$2(a,b){return new A.aF(A.qm(b/1000,a),2,0)},
$S:124}
A.fK.prototype={
$3(a,b,c){var s,r=this.a
A:{if("pt"===r){s=a
break A}if("es"===r){s=c
break A}if("en"===r){s=b
break A}A.n8(r,b)
s=b
break A}return s},
$S:28}
A.fG.prototype={
$1(a){return t.p.a(a).e},
$S:4}
A.fJ.prototype={
$1(a){return a===B.b.bA(a)?""+B.b.a2(a):B.b.ae(a,1)},
$S:20}
A.fL.prototype={
$2(a,b){return B.b.bA(a*(0.25+b/40))},
$S:3}
A.fH.prototype={
$1(a){t.p.a(a)
return a.as.v(0,B.p)||a.e<=50},
$S:5}
A.fI.prototype={
$1(a){return t.p.a(a).e},
$S:4}
A.r.prototype={}
A.aG.prototype={
G(){return"HydraulicScope."+this.b}}
A.N.prototype={
G(){return"EntityType."+this.b}}
A.G.prototype={
D(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"type",r.gC().b)
q.i(0,"id",r.a)
q.i(0,"layer",r.b)
s=r.c
if(s.length!==0)q.i(0,"name",s)
return q}}
A.ic.prototype={
$0(){var s=t.O.a(this.a.h(0,"pts"))
if(s==null)s=[]
s=J.aE(s,new A.id(),t.g)
s=A.p(s,s.$ti.j("w.E"))
return s},
$S:125}
A.id.prototype={
$1(a){return A.bE(t.j.a(a))},
$S:126}
A.ib.prototype={
$0(){return A.bE(t.j.a(this.a.h(0,"p")))},
$S:127}
A.ia.prototype={
$2(a,b){var s=A.y(this.a.h(0,a))
if(s==null)s=null
return s==null?b:s},
$1(a){return this.$2(a,0)},
$S:128}
A.bh.prototype={}
A.a5.prototype={
gm(a){return A.aX(this.gP())},
dB(a){var s,r,q,p,o,n,m=this
for(s=a.a,r=a.b,q=1/0,p=1;p<J.au(m.gP());++p){o=A.ls(a,J.d3(m.gP(),p-1),J.d3(m.gP(),p)).a
n=s-o.a
o=r-o.b
q=Math.min(q,Math.sqrt(n*n+o*o))}return J.au(m.gP())===1?J.lB(J.bP(m.gP()),a).gm(0):q}}
A.ke.prototype={
$1(a){t.g.a(a)
return A.d([a.a,a.b],t.n)},
$S:129}
A.ck.prototype={
gC(){return B.aZ},
gm(a){return this.d.R(0,this.e).gm(0)},
n(){var s=A.X(this.D(),t.N,t.z),r=this.d,q=t.n
s.i(0,"a",A.d([r.a,r.b],q))
r=this.e
s.i(0,"b",A.d([r.a,r.b],q))
return s}}
A.cO.prototype={
gm(a){var s,r=this.d,q=A.aX(r)
if(this.e&&J.au(r)>2){s=J.a1(r)
r=J.lB(s.gM(r),t.g.a(s.gu(r))).gm(0)}else r=0
return q+r},
gC(){return B.b_},
n(){var s=A.X(this.D(),t.N,t.z)
s.i(0,"pts",A.c4(this.d))
s.i(0,"closed",this.e)
return s},
gP(){return this.d}}
A.e6.prototype={
gC(){return B.b5},
n(){var s=A.X(this.D(),t.N,t.z),r=this.d
s.i(0,"p",A.d([r.a,r.b],t.n))
s.i(0,"r",this.e)
return s}}
A.d5.prototype={
gC(){return B.b7},
gm(a){return this.e*Math.abs(this.r)},
dY(){var s,r,q,p,o,n,m=this,l=m.r,k=Math.max(2,B.b.aq(32*Math.abs(l)/6.283185307179586)),j=A.d([],t.C)
for(s=m.d,r=m.e,q=m.f,p=s.a,s=s.b,o=0;o<=k;++o){n=q+l*o/k
j.push(new A.B(p+r*Math.cos(n),s+r*Math.sin(n)))}return j},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"r",s.e)
r.i(0,"s",s.f)
r.i(0,"w",s.r)
return r}}
A.cR.prototype={
gC(){return B.b8},
gm(a){return A.aX(A.pV(this.d,this.e,8))},
n(){var s=A.X(this.D(),t.N,t.z)
s.i(0,"pts",A.c4(this.d))
s.i(0,"closed",this.e)
return s},
gP(){return this.d}}
A.eg.prototype={
gC(){return B.b9},
n(){var s=this,r=A.X(s.D(),t.N,t.z)
r.i(0,"pts",A.c4(s.d))
r.i(0,"ang",s.e)
r.i(0,"sp",s.f)
r.i(0,"solid",s.r)
return r},
gP(){return this.d}}
A.aI.prototype={
G(){return"SymbolKind."+this.b}}
A.eS.prototype={
gC(){return B.ba},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"kind",s.e.b)
r.i(0,"size",s.f)
r.i(0,"rot",s.r)
return r}}
A.eV.prototype={
gC(){return B.bb},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"text",s.e)
r.i(0,"h",s.f)
r.i(0,"rot",s.r)
return r}}
A.ed.prototype={
gC(){return B.bc},
gm(a){return this.d.R(0,this.e).gm(0)},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d,p=t.n
r.i(0,"a",A.d([q.a,q.b],p))
q=s.e
r.i(0,"b",A.d([q.a,q.b],p))
r.i(0,"off",s.f)
return r}}
A.e1.prototype={
gC(){return B.bd},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d,p=t.n
r.i(0,"v",A.d([q.a,q.b],p))
q=s.e
r.i(0,"a",A.d([q.a,q.b],p))
q=s.f
r.i(0,"b",A.d([q.a,q.b],p))
r.i(0,"r",s.r)
return r}}
A.eP.prototype={
gC(){return B.b0},
n(){var s=A.X(this.D(),t.N,t.z),r=this.d,q=t.n
s.i(0,"c",A.d([r.a,r.b],q))
r=this.e
s.i(0,"p",A.d([r.a,r.b],q))
return s}}
A.cF.prototype={
gC(){return B.b1},
n(){var s=this,r=A.X(s.D(),t.N,t.z)
r.i(0,"pts",A.c4(s.d))
r.i(0,"text",s.e)
r.i(0,"h",s.f)
return r},
gP(){return this.d}}
A.ei.prototype={
gC(){return B.b2},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"w",s.e)
r.i(0,"h",s.f)
r.i(0,"rot",s.r)
r.i(0,"op",s.w)
r.i(0,"mime",s.x)
q=s.y
if(q!=null){t.fn.j("bQ.S").a(q)
r.i(0,"data",B.cU.gbu().bt(q))}q=s.z
if(q.length!==0)r.i(0,"src",q)
return r}}
A.c9.prototype={
gC(){return B.b3},
n(){var s=this,r=A.X(s.D(),t.N,t.z)
r.i(0,"pts",A.c4(s.d))
r.i(0,"z",s.e)
if(s.f)r.i(0,"gen",!0)
return r},
gP(){return this.d}}
A.dD.prototype={
gC(){return B.b4},
n(){var s=A.X(this.D(),t.N,t.z),r=this.d
s.i(0,"p",A.d([r.a,r.b],t.n))
s.i(0,"z",this.e)
return s}}
A.aH.prototype={
gC(){return B.a9},
n(){var s,r=this,q=A.X(r.D(),t.N,t.z)
q.i(0,"pts",A.c4(r.d))
q.i(0,"scope",r.e.b)
s=r.f
if(s!=null)q.i(0,"spec",s)
q.i(0,"auto",r.r)
q.i(0,"depth",r.w)
return q},
gP(){return this.d}}
A.al.prototype={
gC(){return B.aa},
gb5(){var s=this,r=A.aX(s.d),q=s.z,p=q>0
if(r<(p?q:s.y)-1e-9)return 0
return B.b.J((r-(p?q:s.y))/s.y+1e-9)+1},
n(){var s,r=this,q=A.X(r.D(),t.N,t.z)
q.i(0,"pts",A.c4(r.d))
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
n(){var s=this,r=A.X(s.D(),t.N,t.z)
r.i(0,"pts",A.c4(s.d))
r.i(0,"spec",s.e)
r.i(0,"inlet",s.f)
r.i(0,"reg",s.r)
r.i(0,"submin",s.w)
r.i(0,"depth",s.x)
r.i(0,"flush",s.y)
return r},
gP(){return this.d}}
A.b0.prototype={
gC(){return B.ac},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
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
A.ba.prototype={
gC(){return B.ad},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
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
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"calc",s.e)
r.i(0,"dh",s.f)
r.i(0,"mh",s.r)
r.i(0,"dq",s.w)
r.i(0,"mq",s.x)
r.i(0,"wl",s.y)
return r}}
A.bq.prototype={
gC(){return B.af},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"speed",s.f)
r.i(0,"rot",s.r)
r.i(0,"scope",s.w.b)
return r}}
A.b_.prototype={
gC(){return B.ag},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
q=s.e
if(q!=null)r.i(0,"spec",q)
r.i(0,"scope",s.f.b)
r.i(0,"set",s.r)
r.i(0,"rot",s.w)
return r}}
A.cj.prototype={
gC(){return B.ah},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.d
r.i(0,"p",A.d([q.a,q.b],t.n))
r.i(0,"scope",s.e.b)
q=s.f
if(q!=null)r.i(0,"z",q)
return r}}
A.b3.prototype={
e4(){var s,r,q,p,o,n,m,l=this,k=l.as
if(k<=0)return B.eS
s=Math.max(1,B.b.J(l.x/k))
r=A.d([],t.C)
for(q=l.w,p=l.y*3.141592653589793/180,o=q.a,q=q.b,n=1;n<=s;++n){m=n*k
r.push(new A.B(o+Math.cos(p)*m,q+Math.sin(p)*m))}return r},
gC(){return B.ai},
n(){var s=this,r=A.X(s.D(),t.N,t.z),q=s.w
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
A.cD.prototype={
gC(){return B.b6},
n(){var s,r=this,q=A.X(r.D(),t.N,t.z)
q.i(0,"pts",A.c4(r.d))
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
A.eZ.prototype={}
A.f1.prototype={}
A.f2.prototype={}
A.f6.prototype={}
A.f9.prototype={}
A.fa.prototype={}
A.fc.prototype={}
A.fd.prototype={}
A.fe.prototype={}
A.ff.prototype={}
A.fg.prototype={}
A.fi.prototype={}
A.fj.prototype={}
A.fk.prototype={}
A.fn.prototype={}
A.fo.prototype={}
A.fp.prototype={}
A.fq.prototype={}
A.B.prototype={
al(a,b){return new A.B(this.a+b.a,this.b+b.b)},
R(a,b){return new A.B(this.a-b.a,this.b-b.b)},
af(a,b){return new A.B(this.a*b,this.b*b)},
gm(a){var s=this.a,r=this.b
return Math.sqrt(s*s+r*r)},
gct(){var s=this.gm(0)
return s===0?B.av:new A.B(this.a/s,this.b/s)},
co(a){return this.a*a.a+this.b*a.b},
n(){return A.V(["x",this.a,"y",this.b],t.N,t.z)},
Y(a,b){if(b==null)return!1
return b instanceof A.B&&b.a===this.a&&b.b===this.b},
gK(a){return A.cM(this.a,this.b,B.f,B.f)},
q(a){return"Pt("+B.b.ae(this.a,3)+", "+B.b.ae(this.b,3)+")"}}
A.e5.prototype={}
A.kZ.prototype={
$1(a){A.S(a)
return a>1e-9&&a<A.aX(this.a)-1e-9},
$S:6}
A.l_.prototype={
$1(a){return A.aX(t.V.a(a))>1e-9},
$S:130}
A.ki.prototype={
$1(a){var s,r,q,p=this
if(p.a){s=p.c
return J.d3(p.b,B.c.b8(B.c.b8(a,s)+s,s))}if(a<0){s=p.b
r=J.a9(s)
return r.h(s,0).af(0,2).R(0,r.h(s,1))}s=p.c
if(a>=s){r=p.b
q=J.a9(r)
return q.h(r,s-1).af(0,2).R(0,q.h(r,s-2))}return J.d3(p.b,a)},
$S:131}
A.kj.prototype={
$3(a,b,c){return a+Math.pow(b.R(0,c).gm(0),0.5)},
$S:132}
A.aA.prototype={
n(){var s=this
return A.V(["name",s.a,"color",s.b,"visible",s.c,"locked",s.d],t.N,t.z)}}
A.cp.prototype={
G(){return"SizingMethod."+this.b}}
A.hj.prototype={
n(){var s=this
return A.V(["units",s.a.n(),"method",s.b.b,"temp",s.c,"vZone",s.d,"vMain",s.e,"vLat",s.f,"minorPct",s.r,"minor",s.w,"tol",s.x,"interest",s.y,"term",s.z,"kwh",s.Q,"eff",s.as,"hours",s.at,"zoneHours",s.ax,"trade",s.ay,"latSizes",s.ch,"subSizes",s.CW,"cScale",s.cx,"cOffset",s.cy,"densify",s.db,"currency",s.dx,"currencyCode",s.dy,"sizing",s.fr.b,"mainSizes",s.fx,"epp",s.fy,"maxNodes",s.go,"flushV",s.id,"flushH",s.k1,"surge",s.k2,"closure",s.k3,"fittings",s.k4,"stick",s.ok,"zoneVar",s.p1,"terrain",s.p2.b],t.N,t.z)}}
A.hk.prototype={
$2(a,b){var s=A.y(this.a.h(0,a))
if(s==null)s=null
return s==null?b:s},
$S:133}
A.b5.prototype={
n(){var s=this,r=s.c
r=A.p(r,A.i(r).c)
return A.V(["id",s.a,"name",s.b,"valves",r,"start",s.d,"dur",s.e],t.N,t.z)}}
A.iY.prototype={
n(){var s,r=this,q=A.m(t.N,t.z)
q.i(0,"uid",r.a)
q.i(0,"created",r.b.bD())
s=r.c
if(s!=null)q.i(0,"modified",s.bD())
q.i(0,"name",r.d)
q.i(0,"client",r.e)
q.i(0,"site",r.f)
q.i(0,"designer",r.r)
q.i(0,"notes",r.w)
s=r.x
if(s!=null)q.i(0,"georef",s.n())
return q}}
A.iX.prototype={
a6(a){var s,r,q,p
for(s=this.e,r=s.length,q=0;q<r;++q){p=s[q]
if(p.a===a)return p}return null},
ds(){var s,r,q,p=this.b,o=A.d([],t.pn),n=new A.eU(p.db,p.p2,o,A.m(t.S,t.J))
for(p=this.e,s=p.length,r=0;r<p.length;p.length===s||(0,A.k)(p),++r){q=p[r]
if(q instanceof A.c9&&!q.f)n.dl(q.d,q.e)
if(q instanceof A.dD){B.a.k(o,new A.bH(q.d,q.e))
n.f=!0}}return n},
n(){var s,r,q,p=this,o=A.m(t.N,t.z)
o.i(0,"format","opencadirrigation")
o.i(0,"version",1)
o.i(0,"meta",p.a.n())
o.i(0,"params",p.b.n())
o.i(0,"catalog",p.c.n())
s=J.aE(p.d,new A.j2(),t.P)
s=A.p(s,s.$ti.j("w.E"))
o.i(0,"layers",s)
s=p.e
r=A.t(s)
q=r.j("j<c,@>(1)").a(new A.j3())
r=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,q,r),r.j("w.E"))
o.i(0,"entities",s)
s=p.f
r=A.t(s)
q=r.j("u<1,j<c,@>>")
s=A.p(new A.u(s,r.j("j<c,@>(1)").a(new A.j4()),q),q.j("w.E"))
o.i(0,"systemFlows",s)
o.i(0,"nextId",p.r)
s=p.w
if(s!=="DRAWING")o.i(0,"currentLayer",s)
return o}}
A.j2.prototype={
$1(a){return t.df.a(a).n()},
$S:134}
A.j3.prototype={
$1(a){return t.h.a(a).n()},
$S:14}
A.j4.prototype={
$1(a){return t.k.a(a).n()},
$S:135}
A.iZ.prototype={
$1(a){var s,r,q,p
t.P.a(a)
s=A.D(a.h(0,"name"))
r=A.aV(a.h(0,"color"))
q=A.Y(a.h(0,"visible"))
p=A.Y(a.h(0,"locked"))
return new A.aA(s,r,q!==!1,p===!0)},
$S:136}
A.j_.prototype={
$1(a){t.er.a(a)
return a.length===0?A.ma():a},
$S:137}
A.j0.prototype={
$1(a){return A.nZ(t.P.a(a))},
$S:138}
A.j1.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.D(a.h(0,"id"))
r=A.D(a.h(0,"name"))
q=t.O.a(a.h(0,"valves"))
if(q==null)q=[]
q=J.nw(q,t.N)
q=q.au(q)
p=A.y(a.h(0,"start"))
if(p==null)p=null
if(p==null)p=0
o=A.y(a.h(0,"dur"))
if(o==null)o=null
return A.mh(o==null?1:o,s,r,p,q)},
$S:139}
A.kY.prototype={
$1(a){A.S(a)
return a>0.000001&&a<this.a-0.000001},
$S:6}
A.cr.prototype={
G(){return"TerrainMethod."+this.b}}
A.bH.prototype={}
A.eU.prototype={
ge2(){var s,r,q,p,o,n,m,l=this,k=l.r
if(k==null||l.f){s=l.c
r=s.length
q=r>12e3?B.b.aq(r/12e3):1
p=A.d([],t.kb)
for(o=0;o<r;o+=q){if(!(o>=0&&o<s.length))return A.b(s,o)
n=s[o]
m=n.a
p.push(new A.a(m.a,m.b,n.b))}k=l.r=A.oA(p)
if(l.f)l.c8()}return k},
dl(a,b){var s,r,q,p,o=this
t.V.a(a)
s=J.a9(a)
if(s.gF(a))return
if(s.gm(a)===1){B.a.k(o.c,new A.bH(t.g.a(s.gu(a)),b))
o.f=!0
return}r=A.aX(a)
q=Math.max(1,B.b.aq(r/o.a))
for(s=o.c,p=0;p<=q;++p){B.a.k(s,new A.bH(A.kD(a,r*p/q),b))
o.f=!0}o.f=!0},
c8(){var s,r,q,p,o=this,n=o.d
n.V(0)
s=o.c
if(s.length===0){o.f=!1
return}r=A.t(s)
q=A.nF(new A.u(s,r.j("B(1)").a(new A.jl()),r.j("u<1,B>")))
o.e=Math.max(0.001,Math.max(q.c-q.a,q.d-q.b)/Math.max(1,Math.sqrt(s.length)))
for(p=0;p<s.length;++p){r=s[p].a
J.bO(n.ac((B.b.J(r.a/o.e)*73856093^B.b.J(r.b/o.e)*19349663)>>>0,new A.jm()),p)}o.f=!1},
cq(a,b,c){var s,r=this
if(r.c.length===0)return b
if(r.b===B.aP){s=r.ge2().b1(a)
if(s!=null)return s}return r.dM(a,b,c)},
b1(a){return this.cq(a,0,8)},
dM(a8,a9,b0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this,a7=a6.c
if(a7.length===0)return a9
if(a6.f)a6.c8()
s=A.d([],t.ip)
r=a8.a
q=B.b.J(r/a6.e)
p=a8.b
o=B.b.J(p/a6.e)
for(n=a6.d,m=0;m<=64;){for(l=-m,k=m>0,j=l;j<=m;++j)for(i=(q+j)*73856093,h=Math.abs(j)!==m,g=l;g<=m;++g){if(k&&h&&Math.abs(g)!==m)continue
f=n.h(0,(i^(o+g)*19349663)>>>0)
if(f==null)continue
for(e=J.ac(f);e.l();){d=e.gp()
if(d>>>0!==d||d>=a7.length)return A.b(a7,d)
c=a7[d].a
b=c.a-r
c=c.b-p
B.a.k(s,new A.n(Math.sqrt(b*b+c*c),d))}}if(s.length>=b0&&m>=1)break;++m}if(s.length===0)for(a=0;a<a7.length;++a){n=a7[a].a
k=n.a-r
n=n.b-p
B.a.k(s,new A.n(Math.sqrt(k*k+n*n),a))}B.a.ao(s,new A.jn())
a0=A.c_(s,0,A.cz(b0,"count",t.S),t.mT).cB(0)
if(B.a.gu(a0).a<1e-9){r=B.a.gu(a0).b
if(!(r>=0&&r<a7.length))return A.b(a7,r)
return a7[r].b}for(r=a0.length,p=a7.length,a1=0,a2=0,a3=0;a3<r;++a3){n=a0[a3]
a4=n.a
a=n.b
a5=1/(a4*a4)
if(!(a>=0&&a<p))return A.b(a7,a)
a1+=a5*a7[a].b
a2+=a5}return a2===0?a9:a1/a2}}
A.jl.prototype={
$1(a){return t.jH.a(a).a},
$S:141}
A.jm.prototype={
$0(){return A.d([],t.X)},
$S:29}
A.jn.prototype={
$2(a,b){var s=t.mT
return B.b.T(s.a(a).a,s.a(b).a)},
$S:143}
A.c0.prototype={}
A.jo.prototype={
d2(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=b.e
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
for(d=B.b.J((h-b.r)/b.f);d<=B.b.J((g-b.r)/b.f);++d)for(c=B.b.J((f-b.w)/b.f),n=d*73856093;c<=B.b.J((e-b.w)/b.f);++c)J.bO(a.ac((n^c*19349663)>>>0,new A.jp()),p)}},
dT(a){var s,r,q,p=this,o=p.d
if(o.length===0)return-1
s=p.e.h(0,(B.b.J((a.a-p.r)/p.f)*73856093^B.b.J((a.b-p.w)/p.f)*19349663)>>>0)
if(s==null)return-1
for(r=J.ac(s);r.l();){q=r.gp()
if(q>>>0!==q||q>=o.length)return A.b(o,q)
if(p.bQ(o[q],a)!=null)return q}return-1},
bQ(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g=this.a,f=a.a,e=g.length
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
b1(a){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.dT(a)
if(h<0)return null
s=i.d
if(!(h<s.length))return A.b(s,h)
r=s[h]
q=i.bQ(r,a)
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
A.jr.prototype={
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
$S:144}
A.jq.prototype={
$1(a){var s,r,q,p,o,n=this,m=n.a
if(!(a>=0&&a<m.length))return A.b(m,a)
s=n.c
r=n.d
q=r-1
p=B.c.a1(B.b.J((m[a]-n.b)/s*r),0,q)
m=n.e
if(!(a<m.length))return A.b(m,a)
o=B.c.a1(B.b.J((m[a]-n.f)/s*r),0,q)
m=o*r
return(o&1)===0?m+p:m+(q-p)},
$S:145}
A.js.prototype={
$2(a,b){var s
A.aV(a)
A.aV(b)
s=this.a
return J.lD(s.$1(a),s.$1(b))},
$S:146}
A.jt.prototype={
$2(a,b){var s=a<b?a*4194304+b:b*4194304+a,r=this.a,q=r.h(0,s)
if(q==null){r.i(0,s,1)
B.a.k(this.b,new A.n(a,b))}else r.i(0,s,q+1)},
$S:10}
A.jp.prototype={
$0(){return A.d([],t.X)},
$S:29}
A.bp.prototype={
G(){return"LengthUnit."+this.b}}
A.bm.prototype={
G(){return"FlowUnit."+this.b}}
A.bD.prototype={
G(){return"PressureUnit."+this.b}}
A.cb.prototype={
G(){return"DiameterUnit."+this.b}}
A.eX.prototype={
n(){var s=this
return A.V(["length",s.a.b,"flow",s.b.b,"pressure",s.c.b,"diameter",s.d.b],t.N,t.z)},
gm(a){return this.a}}
A.kB.prototype={
$1(a){var s=A.mA(a).data
if(s==null||!(typeof s==="string"))return
A.kE(t.P.a(B.aU.dv(A.D(s),null)),new A.kA(this.a))},
$S:147}
A.kA.prototype={
$1(a){return this.a.postMessage(B.aU.dD(t.P.a(a),null))},
$S:148};(function aliases(){var s=J.bX.prototype
s.cM=s.q
s=A.h.prototype
s.cL=s.bF})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._static_0,p=hunkHelpers._instance_1i,o=hunkHelpers._instance_1u,n=hunkHelpers._instance_0u,m=hunkHelpers.installInstanceTearOff,l=hunkHelpers.installStaticTearOff
s(J,"pp","o7",149)
r(A,"pS","oH",7)
r(A,"pT","oI",7)
r(A,"pU","oJ",7)
q(A,"mU","pM",0)
p(A.bt.prototype,"gaG","v",31)
r(A,"pX","pf",19)
q(A,"q0","pD",151)
var k
o(k=A.ec.prototype,"gdg","aX",66)
o(k,"gc4","ag",4)
n(k,"gdt","du",75)
n(k,"gdq","dr",77)
m(A.eU.prototype,"gdC",0,1,null,["$3$fallback$neighbours","$1"],["cq","b1"],140,0,0)
l(A,"ql",2,null,["$1$2","$2"],["n5",function(a,b){return A.n5(a,b,t.H)}],27,0)
l(A,"qk",2,null,["$1$2","$2"],["n4",function(a,b){return A.n4(a,b,t.H)}],27,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.K,null)
q(A.K,[A.l5,J.el,A.dA,J.c7,A.h,A.d8,A.Q,A.j9,A.aO,A.dt,A.dJ,A.dC,A.dc,A.bK,A.W,A.b7,A.d9,A.cv,A.bY,A.az,A.ju,A.iL,A.dd,A.dS,A.a2,A.iq,A.an,A.O,A.ah,A.eq,A.k0,A.bi,A.f5,A.k5,A.k3,A.f_,A.cy,A.b9,A.cu,A.ag,A.f0,A.fl,A.dX,A.fb,A.R,A.H,A.bQ,A.ea,A.jL,A.jK,A.jZ,A.bw,A.cc,A.f3,A.eK,A.dE,A.jM,A.df,A.aj,A.ap,A.fm,A.cS,A.ii,A.hl,A.hm,A.ca,A.ec,A.de,A.ie,A.cl,A.it,A.cI,A.ds,A.dr,A.ez,A.dq,A.bb,A.aZ,A.I,A.iJ,A.iw,A.iW,A.co,A.bC,A.cN,A.bg,A.aw,A.bS,A.cU,A.cq,A.aT,A.b6,A.ad,A.ce,A.bF,A.eb,A.bT,A.aF,A.bo,A.dg,A.iK,A.eJ,A.ew,A.cL,A.eh,A.cP,A.ja,A.dH,A.eu,A.ig,A.J,A.F,A.a3,A.aS,A.E,A.aQ,A.Z,A.fC,A.r,A.G,A.bh,A.a5,A.B,A.e5,A.aA,A.hj,A.b5,A.iY,A.iX,A.bH,A.eU,A.c0,A.jo,A.eX])
q(J.el,[J.eo,J.dj,J.dl,J.dk,J.dm,J.ch,J.ci])
q(J.dl,[J.bX,J.o,A.cJ,A.dw])
q(J.bX,[J.eL,J.cs,J.bW])
r(J.em,A.dA)
r(J.il,J.o)
q(J.ch,[J.di,J.ep])
q(A.h,[A.c1,A.z,A.be,A.C,A.dB,A.ct,A.dM,A.c2])
q(A.c1,[A.c8,A.dY])
r(A.dL,A.c8)
r(A.dK,A.dY)
r(A.ae,A.dK)
q(A.Q,[A.ev,A.bI,A.er,A.eY,A.eQ,A.f4,A.dn,A.e3,A.bk,A.dI,A.eW,A.dF,A.e9])
q(A.z,[A.w,A.db,A.a4,A.ao,A.M])
q(A.w,[A.dG,A.u,A.br,A.f8])
r(A.cd,A.be)
r(A.i9,A.dB)
q(A.b7,[A.cW,A.cX,A.cx])
r(A.n,A.cW)
r(A.a,A.cX)
q(A.cx,[A.cY,A.aU])
r(A.aM,A.d9)
q(A.bY,[A.da,A.dR])
r(A.bR,A.da)
q(A.az,[A.ek,A.e7,A.e8,A.eT,A.kt,A.kv,A.jH,A.jG,A.k8,A.jV,A.iu,A.hh,A.hi,A.hn,A.kF,A.kG,A.hH,A.hU,A.hG,A.hI,A.hv,A.hx,A.hy,A.hR,A.hW,A.hX,A.hE,A.hC,A.i5,A.i6,A.i7,A.hV,A.hY,A.i_,A.ko,A.kR,A.kT,A.kI,A.kJ,A.kK,A.kL,A.kP,A.kM,A.kN,A.kH,A.kW,A.iz,A.iF,A.iH,A.iG,A.iC,A.iD,A.iE,A.iI,A.iU,A.iV,A.kh,A.ks,A.jD,A.jE,A.jF,A.jg,A.jh,A.ji,A.jj,A.ho,A.hp,A.hq,A.hr,A.hs,A.ht,A.ih,A.j6,A.j5,A.jb,A.jw,A.iS,A.iR,A.iN,A.iP,A.iM,A.j8,A.j7,A.fU,A.fS,A.h6,A.he,A.fY,A.fW,A.h8,A.h9,A.ha,A.hb,A.hc,A.hd,A.fM,A.fN,A.fO,A.fP,A.fQ,A.fR,A.h5,A.h3,A.h4,A.h_,A.h0,A.h1,A.h2,A.fE,A.fF,A.fK,A.fG,A.fJ,A.fH,A.fI,A.id,A.ia,A.ke,A.kZ,A.l_,A.ki,A.kj,A.j2,A.j3,A.j4,A.iZ,A.j_,A.j0,A.j1,A.kY,A.jl,A.jr,A.jq,A.kB,A.kA])
r(A.cg,A.ek)
r(A.dy,A.bI)
q(A.eT,[A.eR,A.cE])
q(A.a2,[A.bA,A.f7])
q(A.e8,[A.im,A.ku,A.k9,A.kg,A.jW,A.is,A.iv,A.k_,A.ij,A.hA,A.hS,A.hu,A.hw,A.i4,A.i8,A.hK,A.i2,A.hZ,A.i0,A.i1,A.kQ,A.kS,A.kO,A.kU,A.kV,A.kX,A.ky,A.kx,A.kz,A.kc,A.iA,A.iB,A.iT,A.jC,A.jB,A.kq,A.kr,A.je,A.jx,A.jy,A.jz,A.jA,A.fX,A.fD,A.fL,A.hk,A.jn,A.js,A.jt])
q(A.dw,[A.eA,A.cK])
q(A.cK,[A.dN,A.dP])
r(A.dO,A.dN)
r(A.du,A.dO)
r(A.dQ,A.dP)
r(A.dv,A.dQ)
q(A.du,[A.eB,A.eC])
q(A.dv,[A.eD,A.eE,A.eF,A.eG,A.eH,A.dx,A.eI])
r(A.cZ,A.f4)
q(A.e7,[A.jI,A.jJ,A.k4,A.jN,A.jR,A.jQ,A.jP,A.jO,A.jU,A.jT,A.jS,A.k2,A.kf,A.hT,A.hB,A.hF,A.hz,A.hD,A.i3,A.hL,A.hM,A.hJ,A.hN,A.hO,A.hP,A.hQ,A.iy,A.ix,A.jc,A.jd,A.jf,A.iO,A.fV,A.fT,A.h7,A.hf,A.fZ,A.ic,A.ib,A.jm,A.jp])
r(A.fh,A.dX)
r(A.bt,A.dR)
q(A.bQ,[A.d7,A.es])
q(A.ea,[A.fB,A.fA,A.ip,A.io])
r(A.et,A.dn)
r(A.jY,A.jZ)
q(A.bk,[A.dz,A.ej])
q(A.f3,[A.bl,A.cm,A.bB,A.bU,A.cn,A.cf,A.dh,A.bV,A.cG,A.b1,A.b2,A.bf,A.aJ,A.a7,A.aG,A.N,A.aI,A.cp,A.cr,A.bp,A.bm,A.bD,A.cb])
q(A.G,[A.ck,A.ff,A.e6,A.d5,A.fi,A.f6,A.fn,A.fp,A.ed,A.e1,A.eP,A.fa,A.ei,A.f1,A.fj,A.fe,A.fk,A.fo,A.fd,A.f2,A.fq,A.fg,A.fc,A.f9,A.b3,A.eZ])
r(A.cO,A.ff)
r(A.cR,A.fi)
r(A.eg,A.f6)
r(A.eS,A.fn)
r(A.eV,A.fp)
r(A.cF,A.fa)
r(A.c9,A.f1)
r(A.dD,A.fj)
r(A.aH,A.fe)
r(A.al,A.fk)
r(A.aB,A.fo)
r(A.b0,A.fd)
r(A.ba,A.f2)
r(A.aC,A.fq)
r(A.bq,A.fg)
r(A.b_,A.fc)
r(A.cj,A.f9)
r(A.cD,A.eZ)
s(A.dY,A.H)
s(A.dN,A.H)
s(A.dO,A.W)
s(A.dP,A.H)
s(A.dQ,A.W)
s(A.eZ,A.a5)
s(A.f1,A.a5)
s(A.f2,A.bh)
s(A.f6,A.a5)
s(A.f9,A.bh)
s(A.fa,A.a5)
s(A.fc,A.bh)
s(A.fd,A.bh)
s(A.fe,A.a5)
s(A.ff,A.a5)
s(A.fg,A.bh)
s(A.fi,A.a5)
s(A.fj,A.bh)
s(A.fk,A.a5)
s(A.fn,A.bh)
s(A.fo,A.a5)
s(A.fp,A.bh)
s(A.fq,A.bh)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{f:"int",e:"double",ay:"num",c:"String",v:"bool",ap:"Null",q:"List",K:"Object",j:"Map",a0:"JSObject"},mangledNames:{},types:["~()","v(I)","ap()","e(e,e)","e(J)","v(J)","v(e)","~(~())","e(I)","v(aC)","~(f,f)","ap(@)","~(K?,K?)","f(c?)","j<c,@>(G)","aw(aw,aw)","j<c,e>()","e(cL)","e(e,b5)","@(@)","c(e)","q<aZ>()","I(c,c)","e(e)","j<c,@>(bg)","j<c,@>(bS)","b4<f>()","0^(0^,0^)<ay>","c(c,c,c)","q<f>()","e(e,b6)","v(K?)","v(aj<c,I?>)","~(@,@)","f(I,I)","f?(c)","v(f?)","c()","ap(~())","@(c)","~(c,e,e?,e)","~(c,c)","q<b6>()","c(aC)","v(c)","aT(aT,aT)","~(bg,c)","~(c,c,c,e,e,c?{code:c,supplier:c})","f(ad,ad)","v(ad)","e(e,ad)","@(@,c)","c(c)","~(a7,e{qty:e,size2:e})","B(I,c)","aZ?(B,aG)","v(aZ?,c)","c(a7)","~(f,e)","by(by)","~(ca)","bB(by,b4<f>)","~(c,j<c,e>)","~(c,e)","f(+(J,e),+(J,e))","e(e,+(J,e))","J?(I)","v(G)","q<B>(G)","aG(G)","~(B,h<aG>{exclude:c?})","~(@)","f(f,bC)","j<c,@>(co)","j<c,@>(bC)","q<bF>()","q<I>()","q<ad>()","j<c,@>(aw)","e(e,bb)","j<c,@>(cq)","j<c,@>(aT)","j<c,@>(cU)","j<c,@>(cN)","j<c,@>(b6)","j<c,@>(ad)","j<c,@>(ce)","j<c,@>(bF)","c(aw)","v(bo)","ap(@,bZ)","v(+(e,e))","j<f,e>(j<f,e>)","e(e,I)","f()","c(b2)","b2(@)","v(F)","F()","j<c,@>(F)","F(@)","~(f,@)","+(e,e)(@)","v(J?)","v(a3?)","v(aS?)","v(E?)","v(aQ?)","f(J,J)","j<c,@>(J)","j<c,@>(a3)","j<c,@>(aS)","j<c,@>(E)","j<c,@>(aQ)","j<c,@>(Z)","J(@)","a3(@)","aS(@)","E(@)","aQ(@)","Z(@)","e?(h<e>)","~(c,q<+(J,e)>)","bT(e,e,e{radiusM:e})","aF(e,e)","q<B>()","B(@)","B()","e(c[e])","q<e>(B)","v(q<B>)","B(f)","e(e,B,B)","e(c,e)","j<c,@>(aA)","j<c,@>(b5)","aA(@)","q<aA>(q<aA>)","G(@)","b5(@)","e(B{fallback:e,neighbours:f})","B(bH)","q<c>()","f(+(e,f),+(e,f))","~(c0)","f(f)","f(f,f)","ap(a0)","~(j<c,@>)","f(@,@)","ap(K,bZ)","bn<~>()","q<e>(+(e,e))"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.n&&a.b(c.a)&&b.b(c.b),"3;":(a,b,c)=>d=>d instanceof A.a&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;":a=>b=>b instanceof A.cY&&A.n9(a,b.a),"4;run,stage,zoneId,zoneIndex":a=>b=>b instanceof A.aU&&A.n9(a,b.a)}}
A.p6(v.typeUniverse,JSON.parse('{"eL":"bX","cs":"bX","bW":"bX","qE":"cJ","eo":{"v":[],"P":[]},"dj":{"P":[]},"dl":{"a0":[]},"bX":{"a0":[]},"o":{"q":["1"],"z":["1"],"a0":[],"h":["1"]},"em":{"dA":[]},"il":{"o":["1"],"q":["1"],"z":["1"],"a0":[],"h":["1"]},"c7":{"U":["1"]},"ch":{"e":[],"ay":[],"aL":["ay"]},"di":{"e":[],"f":[],"ay":[],"aL":["ay"],"P":[]},"ep":{"e":[],"ay":[],"aL":["ay"],"P":[]},"ci":{"c":[],"aL":["c"],"iQ":[],"P":[]},"c1":{"h":["2"]},"d8":{"U":["2"]},"c8":{"c1":["1","2"],"h":["2"],"h.E":"2"},"dL":{"c8":["1","2"],"c1":["1","2"],"z":["2"],"h":["2"],"h.E":"2"},"dK":{"H":["2"],"q":["2"],"c1":["1","2"],"z":["2"],"h":["2"]},"ae":{"dK":["1","2"],"H":["2"],"q":["2"],"c1":["1","2"],"z":["2"],"h":["2"],"H.E":"2","h.E":"2"},"ev":{"Q":[]},"z":{"h":["1"]},"w":{"z":["1"],"h":["1"]},"dG":{"w":["1"],"z":["1"],"h":["1"],"h.E":"1","w.E":"1"},"aO":{"U":["1"]},"be":{"h":["2"],"h.E":"2"},"cd":{"be":["1","2"],"z":["2"],"h":["2"],"h.E":"2"},"dt":{"U":["2"]},"u":{"w":["2"],"z":["2"],"h":["2"],"h.E":"2","w.E":"2"},"C":{"h":["1"],"h.E":"1"},"dJ":{"U":["1"]},"dB":{"h":["1"],"h.E":"1"},"i9":{"dB":["1"],"z":["1"],"h":["1"],"h.E":"1"},"dC":{"U":["1"]},"db":{"z":["1"],"h":["1"],"h.E":"1"},"dc":{"U":["1"]},"ct":{"h":["1"],"h.E":"1"},"bK":{"U":["1"]},"br":{"w":["1"],"z":["1"],"h":["1"],"h.E":"1","w.E":"1"},"n":{"cW":[],"b7":[]},"a":{"cX":[],"b7":[]},"cY":{"cx":[],"b7":[]},"aU":{"cx":[],"b7":[]},"d9":{"j":["1","2"]},"aM":{"d9":["1","2"],"j":["1","2"]},"dM":{"h":["1"],"h.E":"1"},"cv":{"U":["1"]},"da":{"bY":["1"],"b4":["1"],"z":["1"],"h":["1"]},"bR":{"da":["1"],"bY":["1"],"b4":["1"],"z":["1"],"h":["1"]},"ek":{"az":[],"bz":[]},"cg":{"az":[],"bz":[]},"dy":{"bI":[],"Q":[]},"er":{"Q":[]},"eY":{"Q":[]},"dS":{"bZ":[]},"az":{"bz":[]},"e7":{"az":[],"bz":[]},"e8":{"az":[],"bz":[]},"eT":{"az":[],"bz":[]},"eR":{"az":[],"bz":[]},"cE":{"az":[],"bz":[]},"eQ":{"Q":[]},"bA":{"a2":["1","2"],"lZ":["1","2"],"j":["1","2"],"a2.K":"1","a2.V":"2"},"a4":{"z":["1"],"h":["1"],"h.E":"1"},"an":{"U":["1"]},"ao":{"z":["1"],"h":["1"],"h.E":"1"},"O":{"U":["1"]},"M":{"z":["aj<1,2>"],"h":["aj<1,2>"],"h.E":"aj<1,2>"},"ah":{"U":["aj<1,2>"]},"cW":{"b7":[]},"cX":{"b7":[]},"cx":{"b7":[]},"eq":{"op":[],"iQ":[]},"cJ":{"a0":[],"P":[]},"dw":{"a0":[]},"eA":{"a0":[],"P":[]},"cK":{"aN":["1"],"a0":[]},"du":{"H":["e"],"q":["e"],"aN":["e"],"z":["e"],"a0":[],"h":["e"],"W":["e"]},"dv":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"]},"eB":{"H":["e"],"q":["e"],"aN":["e"],"z":["e"],"a0":[],"h":["e"],"W":["e"],"P":[],"H.E":"e","W.E":"e"},"eC":{"by":[],"H":["e"],"q":["e"],"aN":["e"],"z":["e"],"a0":[],"h":["e"],"W":["e"],"P":[],"H.E":"e","W.E":"e"},"eD":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"eE":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"eF":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"eG":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"eH":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"dx":{"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"eI":{"lf":[],"H":["f"],"q":["f"],"aN":["f"],"z":["f"],"a0":[],"h":["f"],"W":["f"],"P":[],"H.E":"f","W.E":"f"},"f4":{"Q":[]},"cZ":{"bI":[],"Q":[]},"cy":{"U":["1"]},"c2":{"h":["1"],"h.E":"1"},"b9":{"Q":[]},"ag":{"bn":["1"]},"dX":{"mk":[]},"fh":{"dX":[],"mk":[]},"bt":{"bY":["1"],"m_":["1"],"b4":["1"],"z":["1"],"h":["1"]},"R":{"U":["1"]},"a2":{"j":["1","2"]},"bY":{"b4":["1"],"z":["1"],"h":["1"]},"dR":{"bY":["1"],"b4":["1"],"z":["1"],"h":["1"]},"f7":{"a2":["c","@"],"j":["c","@"],"a2.K":"c","a2.V":"@"},"f8":{"w":["c"],"z":["c"],"h":["c"],"h.E":"c","w.E":"c"},"d7":{"bQ":["q<f>","c"],"bQ.S":"q<f>"},"dn":{"Q":[]},"et":{"Q":[]},"es":{"bQ":["K?","c"],"bQ.S":"K?"},"bw":{"aL":["bw"]},"e":{"ay":[],"aL":["ay"]},"cc":{"aL":["cc"]},"f":{"ay":[],"aL":["ay"]},"q":{"z":["1"],"h":["1"]},"ay":{"aL":["ay"]},"b4":{"z":["1"],"h":["1"]},"c":{"aL":["c"],"iQ":[]},"f3":{"a_":[]},"e3":{"Q":[]},"bI":{"Q":[]},"bk":{"Q":[]},"dz":{"Q":[]},"ej":{"Q":[]},"dI":{"Q":[]},"eW":{"Q":[]},"dF":{"Q":[]},"e9":{"Q":[]},"eK":{"Q":[]},"dE":{"Q":[]},"fm":{"bZ":[]},"cS":{"ov":[]},"bl":{"a_":[]},"cm":{"a_":[]},"bB":{"a_":[]},"bU":{"a_":[]},"cn":{"a_":[]},"cf":{"a_":[]},"dh":{"a_":[]},"bV":{"a_":[]},"cG":{"a_":[]},"b1":{"a_":[]},"b2":{"a_":[]},"bf":{"a_":[]},"aJ":{"a_":[]},"a7":{"a_":[]},"aG":{"a_":[]},"N":{"a_":[]},"aI":{"a_":[]},"al":{"a5":[],"G":[]},"aB":{"a5":[],"G":[]},"b0":{"G":[]},"aC":{"G":[]},"b3":{"G":[]},"cD":{"a5":[],"G":[]},"ck":{"G":[]},"cO":{"a5":[],"G":[]},"e6":{"G":[]},"d5":{"G":[]},"cR":{"a5":[],"G":[]},"eg":{"a5":[],"G":[]},"eS":{"G":[]},"eV":{"G":[]},"ed":{"G":[]},"e1":{"G":[]},"eP":{"G":[]},"cF":{"a5":[],"G":[]},"ei":{"G":[]},"c9":{"a5":[],"G":[]},"dD":{"G":[]},"aH":{"a5":[],"G":[]},"ba":{"G":[]},"bq":{"G":[]},"b_":{"G":[]},"cj":{"G":[]},"cp":{"a_":[]},"cr":{"a_":[]},"bp":{"a_":[]},"bm":{"a_":[]},"bD":{"a_":[]},"cb":{"a_":[]},"o4":{"q":["f"],"z":["f"],"h":["f"]},"lf":{"q":["f"],"z":["f"],"h":["f"]},"oD":{"q":["f"],"z":["f"],"h":["f"]},"o2":{"q":["f"],"z":["f"],"h":["f"]},"oB":{"q":["f"],"z":["f"],"h":["f"]},"o3":{"q":["f"],"z":["f"],"h":["f"]},"oC":{"q":["f"],"z":["f"],"h":["f"]},"o1":{"q":["e"],"z":["e"],"h":["e"]},"by":{"q":["e"],"z":["e"],"h":["e"]}}'))
A.p5(v.typeUniverse,JSON.parse('{"dY":2,"cK":1,"dR":1,"ea":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",h:"SHP: {r} registros, {n} entidades ({crs})",n:"{k}: {p} marcadores, {n} entidades ({crs})"}
var t=(function rtii(){var s=A.T
return{mu:s("cD"),t:s("b9"),fn:s("d7"),q:s("ad"),bP:s("aL<@>"),lq:s("bR<c>"),cs:s("bw"),nJ:s("eb"),n6:s("bS"),ks:s("cb"),jS:s("cc"),Y:s("z<@>"),cQ:s("bb"),h:s("G"),od:s("N"),fz:s("Q"),na:s("a7"),kN:s("Z"),kI:s("by"),mf:s("bm"),lG:s("ce"),m1:s("cf"),Z:s("bz"),G:s("I"),fC:s("I(c,c)"),cr:s("aZ"),b:s("bo"),E:s("aG"),id:s("cg<e>"),lv:s("h<aG>"),bq:s("h<c>"),kk:s("h<e>"),e7:s("h<@>"),o6:s("o<ad>"),c:s("o<bS>"),hz:s("o<bb>"),u:s("o<G>"),e0:s("o<de>"),eK:s("o<Z>"),p4:s("o<ce>"),I:s("o<I>"),go:s("o<aZ>"),lp:s("o<dg>"),dr:s("o<aG>"),j8:s("o<aA>"),gv:s("o<q<B>>"),iA:s("o<q<e>>"),cH:s("o<cl>"),nE:s("o<dr>"),jv:s("o<ds>"),ot:s("o<cm>"),gN:s("o<j<c,e>>"),l0:s("o<j<f,e>>"),lH:s("o<cL>"),nB:s("o<F>"),iv:s("o<b0>"),w:s("o<aw>"),dO:s("o<a3>"),A:s("o<bg>"),D:s("o<J>"),eN:s("o<bC>"),i5:s("o<co>"),C:s("o<B>"),fH:s("o<aQ>"),an:s("o<+(J,e)>"),dD:s("o<+(c,bT)>"),fU:s("o<+(e,e)>"),ip:s("o<+(e,f)>"),hD:s("o<+(f,f)>"),kb:s("o<+(e,e,e)>"),nV:s("o<+(e,f,f)>"),h0:s("o<al>"),s:s("o<c>"),iF:s("o<cq>"),cu:s("o<bF>"),cD:s("o<b5>"),lT:s("o<b6>"),kU:s("o<aS>"),pn:s("o<bH>"),ae:s("o<c0>"),eZ:s("o<aT>"),bD:s("o<E>"),n:s("o<e>"),dG:s("o<@>"),X:s("o<f>"),T:s("dj"),m:s("a0"),dY:s("bW"),dX:s("aN<@>"),df:s("aA"),hu:s("bp"),g_:s("ew"),e5:s("q<I>"),g2:s("q<aZ>"),er:s("q<aA>"),ms:s("q<aw>"),d:s("q<J>"),V:s("q<B>"),x:s("q<+(J,e)>"),bF:s("q<c>"),k6:s("q<b5>"),bd:s("q<e>"),j:s("q<@>"),J:s("q<f>"),j5:s("aj<c,I?>"),U:s("j<c,e>"),P:s("j<c,@>"),dV:s("j<c,f>"),nh:s("j<e,bb>"),av:s("j<@,@>"),jq:s("j<f,e>"),L:s("j<c,q<I>>"),c8:s("j<c,I?>"),pa:s("u<c,f?>"),oX:s("eJ"),mP:s("F"),a:s("ap"),K:s("K"),hF:s("bf"),o:s("aw"),fa:s("a3"),f7:s("b1"),h4:s("bg"),p:s("J"),W:s("b2"),m9:s("b3"),n7:s("cn"),oY:s("cN"),fR:s("bC"),oz:s("co"),f:s("a5"),c4:s("bD"),g:s("B"),dz:s("aQ"),lZ:s("qG"),aK:s("+()"),kh:s("+(de,e)"),ft:s("+(bg,c)"),ca:s("+(J,e)"),kM:s("+(c,c)"),aL:s("+(e,e)"),mT:s("+(e,f)"),g9:s("br<I>"),hZ:s("b4<I>"),Q:s("b4<c>"),nO:s("b4<f>"),fA:s("cp"),l:s("bZ"),N:s("c"),ep:s("cq"),eu:s("bF"),ai:s("aI"),k:s("b5"),ju:s("b6"),gs:s("aS"),oW:s("cr"),jH:s("bH"),aJ:s("P"),do:s("bI"),cx:s("cs"),nN:s("aT"),bn:s("aJ"),e4:s("E"),v:s("aC"),ji:s("C<q<B>>"),ee:s("C<e>"),hP:s("ct<aB>"),lF:s("ct<aC>"),jc:s("bK<cD>"),bo:s("bK<b3>"),kV:s("cU"),_:s("ag<@>"),cU:s("ag<~>"),iG:s("c2<+run,stage,zoneId,zoneIndex(~(),bl,c?,f)>"),y:s("v"),eV:s("v(q<B>)"),iW:s("v(K)"),eq:s("v(e)"),i:s("e"),z:s("@"),mY:s("@()"),mq:s("@(K)"),ng:s("@(K,bZ)"),S:s("f"),e:s("ba?"),gK:s("bn<ap>?"),ga:s("bn<~>()?"),B:s("I?"),mU:s("a0?"),fm:s("q<c>?"),O:s("q<@>?"),md:s("j<c,c>?"),dZ:s("j<c,@>?"),iD:s("K?"),h2:s("a3?"),cV:s("J?"),gL:s("aQ?"),bl:s("c?"),lJ:s("aS?"),kf:s("E?"),F:s("cu<@,@>?"),R:s("fb?"),o9:s("v?"),jX:s("e?"),aV:s("f?"),bw:s("f?(c)"),jh:s("ay?"),dn:s("~(ca)?"),H:s("ay"),r:s("~"),M:s("~()"),lc:s("~(c,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.ex=J.el.prototype
B.a=J.o.prototype
B.c=J.di.prototype
B.b=J.ch.prototype
B.d=J.ci.prototype
B.ey=J.bW.prototype
B.ez=J.dl.prototype
B.bu=J.eL.prototype
B.aQ=J.cs.prototype
B.cT=new A.e5(1/0,1/0,-1/0,-1/0)
B.q=new A.cg(A.qk(),t.id)
B.H=new A.cg(A.ql(),t.id)
B.cW=new A.fB()
B.cU=new A.d7()
B.cV=new A.fA()
B.cX=new A.cc()
B.cY=new A.dc(A.T("dc<0&>"))
B.aS=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.cZ=function() {
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
B.d3=function(getTagFallback) {
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
B.d_=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.d2=function(hooks) {
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
B.d1=function(hooks) {
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
B.d0=function(hooks) {
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
B.aT=function(hooks) { return hooks; }

B.aU=new A.es()
B.d4=new A.eK()
B.f=new A.j9()
B.u=new A.fh()
B.d5=new A.fm()
B.aV=new A.bl(0,"zones")
B.el=new A.bl(1,"mainline")
B.U=new A.bl(2,"splits")
B.em=new A.bl(3,"flushing")
B.en=new A.bl(4,"surge")
B.aW=new A.bl(5,"bom")
B.I=new A.aF(0,2,0)
B.aX=new A.aF(0.001,2,0)
B.aZ=new A.N(0,"line")
B.b_=new A.N(1,"polyline")
B.b0=new A.N(10,"radialDimension")
B.b1=new A.N(11,"leader")
B.b2=new A.N(12,"image")
B.b3=new A.N(13,"contour")
B.b4=new A.N(14,"spotHeight")
B.a9=new A.N(15,"pipe")
B.aa=new A.N(16,"sprayline")
B.ab=new A.N(17,"tape")
B.ac=new A.N(18,"outlet")
B.ad=new A.N(19,"controlValve")
B.b5=new A.N(2,"circle")
B.ae=new A.N(20,"waterSupply")
B.af=new A.N(21,"pump")
B.ag=new A.N(22,"misc")
B.ah=new A.N(23,"junction")
B.b6=new A.N(24,"area")
B.ai=new A.N(25,"pivot")
B.b7=new A.N(3,"arc")
B.b8=new A.N(4,"spline")
B.b9=new A.N(5,"hatch")
B.ba=new A.N(6,"symbol")
B.bb=new A.N(7,"text")
B.bc=new A.N(8,"dimension")
B.bd=new A.N(9,"angularDimension")
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
B.et=new A.df("Not an OpenCADIrrigation project",null,null)
B.an=new A.cf(0,"hazenWilliams")
B.bf=new A.cf(1,"darcyWeisbach")
B.e=new A.bU(0,"pipe")
B.W=new A.bU(1,"controlValve")
B.X=new A.bU(2,"pump")
B.eu=new A.bU(3,"device")
B.ev=new A.bU(4,"prv")
B.ao=new A.bV(0,"pipe")
B.bg=new A.bV(1,"pump")
B.M=new A.bV(2,"prv")
B.bh=new A.bV(3,"device")
B.ew=new A.bV(4,"closed")
B.Y=new A.dh(0,"junction")
B.Z=new A.dh(1,"reservoir")
B.h=new A.aG(0,"zone")
B.i=new A.aG(1,"mainline")
B.eA=new A.io(null)
B.eB=new A.ip(null)
B.n=new A.cG(0,"open")
B.l=new A.cG(1,"closed")
B.x=new A.cG(2,"active")
B.dh=new A.r("BRL","R$")
B.e2=new A.r("USD","US$")
B.ef=new A.r("EUR","\u20ac")
B.dJ=new A.r("MXN","MX$")
B.e6=new A.r("INR","\u20b9")
B.ei=new A.r("CNY","CN\xa5")
B.dg=new A.r("JPY","\xa5")
B.dz=new A.r("IDR","Rp")
B.ek=new A.r("NGN","\u20a6")
B.e0=new A.r("TZS","TSh")
B.dD=new A.r("KES","KSh")
B.du=new A.r("VND","\u20ab")
B.ed=new A.r("TRY","\u20ba")
B.dF=new A.r("RUB","\u20bd")
B.ee=new A.r("EGP","E\xa3")
B.dW=new A.r("SAR","SAR")
B.dS=new A.r("PKR","Rs")
B.ea=new A.r("BDT","\u09f3")
B.dj=new A.r("GBP","\xa3")
B.db=new A.r("ARS","AR$")
B.dn=new A.r("COP","CO$")
B.dm=new A.r("CLP","CL$")
B.dP=new A.r("PEN","S/")
B.e3=new A.r("UYU","$U")
B.dd=new A.r("PYG","\u20b2")
B.df=new A.r("BOB","Bs")
B.dv=new A.r("GTQ","Q")
B.eb=new A.r("CRC","\u20a1")
B.dr=new A.r("DOP","RD$")
B.dk=new A.r("CAD","CA$")
B.dc=new A.r("AUD","A$")
B.dO=new A.r("NZD","NZ$")
B.e8=new A.r("ZAR","R")
B.dl=new A.r("CHF","CHF")
B.dX=new A.r("SEK","kr")
B.dM=new A.r("NOK","kr")
B.dq=new A.r("DKK","kr")
B.dw=new A.r("PLN","z\u0142")
B.dU=new A.r("CZK","K\u010d")
B.dy=new A.r("HUF","Ft")
B.dV=new A.r("RON","lei")
B.d8=new A.r("UAH","\u20b4")
B.ec=new A.r("KZT","\u20b8")
B.di=new A.r("BYN","Br")
B.eh=new A.r("ILS","\u20aa")
B.d9=new A.r("AED","AED")
B.dT=new A.r("QAR","QAR")
B.dE=new A.r("KWD","KWD")
B.dQ=new A.r("OMR","OMR")
B.de=new A.r("BHD","BHD")
B.dC=new A.r("JOD","JOD")
B.dA=new A.r("IQD","IQD")
B.dG=new A.r("LBP","LBP")
B.dI=new A.r("MAD","MAD")
B.ds=new A.r("DZD","DZD")
B.dZ=new A.r("TND","TND")
B.dB=new A.r("IRR","IRR")
B.e9=new A.r("AFN","\u060b")
B.d7=new A.r("KRW","\u20a9")
B.e_=new A.r("TWD","NT$")
B.dx=new A.r("HKD","HK$")
B.dY=new A.r("SGD","S$")
B.dK=new A.r("MYR","RM")
B.e7=new A.r("THB","\u0e3f")
B.eg=new A.r("PHP","\u20b1")
B.dN=new A.r("NPR","NRs")
B.dH=new A.r("LKR","LKR")
B.d6=new A.r("UZS","so\u02bbm")
B.dR=new A.r("AZN","\u20bc")
B.e1=new A.r("UGX","USh")
B.dt=new A.r("ETB","Br")
B.ej=new A.r("GHS","GH\u20b5")
B.e5=new A.r("XOF","CFA")
B.e4=new A.r("XAF","FCFA")
B.da=new A.r("AOA","Kz")
B.dL=new A.r("MZN","MT")
B.dp=new A.r("CVE","Esc")
B.bj=s([B.dh,B.e2,B.ef,B.dJ,B.e6,B.ei,B.dg,B.dz,B.ek,B.e0,B.dD,B.du,B.ed,B.dF,B.ee,B.dW,B.dS,B.ea,B.dj,B.db,B.dn,B.dm,B.dP,B.e3,B.dd,B.df,B.dv,B.eb,B.dr,B.dk,B.dc,B.dO,B.e8,B.dl,B.dX,B.dM,B.dq,B.dw,B.dU,B.dy,B.dV,B.d8,B.ec,B.di,B.eh,B.d9,B.dT,B.dE,B.dQ,B.de,B.dC,B.dA,B.dG,B.dI,B.ds,B.dZ,B.dB,B.e9,B.d7,B.e_,B.dx,B.dY,B.dK,B.e7,B.eg,B.dN,B.dH,B.d6,B.dR,B.e1,B.dt,B.ej,B.e5,B.e4,B.da,B.dL,B.dp],A.T("o<r>"))
B.p=new A.b2(0,"lateral")
B.j=new A.b2(1,"zone")
B.k=new A.b2(2,"mainline")
B.eG=s([B.p,B.j,B.k],A.T("o<b2>"))
B.a1=new A.bf(0,"sprinkler")
B.ar=new A.bf(1,"microSprinkler")
B.as=new A.bf(2,"dripper")
B.fb=new A.bf(3,"bubbler")
B.bs=new A.bf(4,"gun")
B.at=new A.bf(5,"demandPoint")
B.eH=s([B.a1,B.ar,B.as,B.fb,B.bs,B.at],A.T("o<bf>"))
B.aY=new A.cb(0,"mm")
B.eo=new A.cb(1,"inch")
B.eI=s([B.aY,B.eo],A.T("o<cb>"))
B.o=new A.b1(3e9,0,"pvc")
B.y=new A.b1(9e8,1,"pehd")
B.au=new A.b1(3e8,2,"peld")
B.bt=new A.b1(2e11,3,"steel")
B.fc=new A.b1(17e10,4,"ductileIron")
B.fe=new A.b1(7e10,5,"aluminium")
B.fd=new A.b1(3e10,6,"concrete")
B.eJ=s([B.o,B.y,B.au,B.bt,B.fc,B.fe,B.fd],A.T("o<b1>"))
B.eK=s([B.an,B.bf],A.T("o<cf>"))
B.D=s([B.h,B.i],t.dr)
B.E=new A.cn(0,"pivot")
B.ff=new A.cn(1,"linear")
B.eL=s([B.E,B.ff],A.T("o<cn>"))
B.eM=s([B.aZ,B.b_,B.b5,B.b7,B.b8,B.b9,B.ba,B.bb,B.bc,B.bd,B.b0,B.b1,B.b2,B.b3,B.b4,B.a9,B.aa,B.ab,B.ac,B.ad,B.ae,B.af,B.ag,B.ah,B.b6,B.ai],A.T("o<N>"))
B.a6=new A.cp(0,"lp")
B.DF=new A.cp(1,"greedy")
B.eN=s([B.a6,B.DF],A.T("o<cp>"))
B.aP=new A.cr(0,"tin")
B.DP=new A.cr(1,"idw")
B.eO=s([B.aP,B.DP],A.T("o<cr>"))
B.eP=s(["id","de","en","es","fr","ha","sw","pt","vi","tr","ru","ar","ur","hi","mr","bn","pa","te","zh","ja"],t.s)
B.B=new A.aJ(0,"control")
B.R=new A.aJ(1,"prv")
B.S=new A.aJ(2,"isolation")
B.T=new A.aJ(3,"check")
B.aR=new A.aJ(4,"backflow")
B.C=new A.aJ(5,"filter")
B.a7=new A.aJ(6,"meter")
B.a8=new A.aJ(7,"airRelease")
B.E1=new A.aJ(8,"other")
B.eQ=s([B.B,B.R,B.S,B.T,B.aR,B.C,B.a7,B.a8,B.E1],A.T("o<aJ>"))
B.DG=new A.aI(0,"northArrow")
B.DH=new A.aI(1,"tree")
B.DI=new A.aI(2,"building")
B.DJ=new A.aI(3,"tank")
B.DK=new A.aI(4,"well")
B.DL=new A.aI(5,"valveBox")
B.DM=new A.aI(6,"pumpHouse")
B.DN=new A.aI(7,"gate")
B.DO=new A.aI(8,"filterStation")
B.eR=s([B.DG,B.DH,B.DI,B.DJ,B.DK,B.DL,B.DM,B.DN,B.DO],A.T("o<aI>"))
B.bl=s([],t.c)
B.eT=s([],t.I)
B.eV=s([],t.nB)
B.eU=s([],t.w)
B.bm=s([],t.A)
B.bn=s([],t.D)
B.eS=s([],t.C)
B.eW=s([],t.iF)
B.eX=s([],t.eZ)
B.bk=s([],t.n)
B.E2=s([],t.dD)
B.bi=new A.bp(0,"m")
B.eC=new A.bp(1,"mm")
B.eD=new A.bp(2,"cm")
B.eE=new A.bp(3,"ft")
B.eF=new A.bp(4,"inch")
B.eY=s([B.bi,B.eC,B.eD,B.eE,B.eF],A.T("o<bp>"))
B.bv=new A.bD(0,"mH2O")
B.fg=new A.bD(1,"kPa")
B.fh=new A.bD(2,"bar")
B.fi=new A.bD(3,"psi")
B.eZ=s([B.bv,B.fg,B.fh,B.fi],A.T("o<bD>"))
B.be=new A.bm(0,"lph")
B.ep=new A.bm(1,"lpm")
B.eq=new A.bm(2,"lps")
B.er=new A.bm(3,"m3h")
B.es=new A.bm(4,"gpm")
B.f_=s([B.be,B.ep,B.eq,B.er,B.es],A.T("o<bm>"))
B.f0=s([B.V,B.aj,B.ak,B.J,B.al,B.v,B.K,B.am,B.w,B.L,B.m],A.T("o<a7>"))
B.f1=s(["no_water_supply"],t.s)
B.f2=s(["IMAGES","DRAWING","HATCHES","SYMBOLS","TEXT","DIMENSIONS","CONTOURS","SPOT_HEIGHTS","DEM","ZONE_PIPES","MAINLINE_PIPES","SPRAYLINES","TAPES","OUTLETS","WETTED_RADII","CONTROL_VALVES","WATER_SUPPLY","PUMPS","MISC_HYDRAULIC","JUNCTIONS","PIVOTS","AREAS","LABELS"],t.s)
B.a_=new A.cm(0,"le")
B.ap=new A.cm(1,"eq")
B.bo=new A.cm(2,"ge")
B.N=new A.bB(0,"optimal")
B.f3=new A.bB(1,"infeasible")
B.f4=new A.bB(2,"unbounded")
B.bp=new A.bB(3,"iterationLimit")
B.f8={BRL:0,USD:1,EUR:2,GBP:3,JPY:4,CNY:5,INR:6,IDR:7,NGN:8,KES:9,TZS:10,UGX:11,VND:12,TRY:13,RUB:14,EGP:15,SAR:16,AED:17,MAD:18,DZD:19,TND:20,IQD:21,JOD:22,QAR:23,KWD:24,OMR:25,BHD:26,LBP:27,PKR:28,BDT:29,MXN:30,ARS:31,COP:32,CLP:33,PEN:34,UYU:35,PYG:36,BOB:37,GTQ:38,CRC:39,DOP:40,CAD:41,AUD:42,NZD:43,ZAR:44,CHF:45,SEK:46,NOK:47,DKK:48,PLN:49,CZK:50,HUF:51,RON:52,UAH:53,KZT:54,BYN:55,ILS:56,KRW:57,TWD:58,HKD:59,SGD:60,MYR:61,THB:62,PHP:63,XOF:64,XAF:65,AOA:66,MZN:67,ETB:68,GHS:69,NPR:70,LKR:71,IRR:72,AFN:73,UZS:74,AZN:75,CVE:76}
B.bq=new A.aM(B.f8,[1,0.194498,0.169492,0.14543,30.6062,1.3088,18.6598,3451.74,262.864,25.2459,516.716,745.134,5050.14,9.48874,16.495,10.1227,0.729374,0.7143,1.85499,26.0744,0.569235,254.226,0.1379,0.707979,0.060022,0.074785,0.073132,17407.7,54.0161,23.9342,3.34495,294.148,617.19,187.238,0.657038,7.83241,1160.73,2.19297,1.48678,87.1606,11.4422,0.272264,0.27313,0.34017,3.16636,0.1602,1.91301,1.83189,1.26869,0.739874,4.12219,61.7788,0.8934,8.7116,86.927,0.58924,0.589802,269.659,6.1751,1.52685,0.248332,0.793666,6.48381,12.216,111.137,111.137,183.852,12.4413,31.3447,2.22843,29.8503,64.2754,267526,12.6304,2299.29,0.331254,18.6819],A.T("aM<c,e>"))
B.f9={"app.title":0,ok:1,cancel:2,apply:3,close:4,auto:5,clear:6,"menu.file":7,"menu.edit":8,"menu.view":9,"menu.draw":10,"menu.zone":11,"menu.mainline":12,"menu.design":13,"menu.reports":14,"menu.tools":15,"menu.help":16,"file.new":17,"file.open":18,"file.save":19,"file.exportDxf":20,"file.exportDrawing":21,"file.exportReport":22,"file.georef":23,"file.newTab":24,"file.closeTab":25,"tab.new":26,"tab.close":27,"edit.clipCopy":28,"edit.clipCut":29,"edit.paste":30,"msg.copied":31,"msg.cut":32,"msg.pipeCut":33,"msg.pasted":34,"msg.nothingSelected":35,"msg.clipboardEmpty":36,"msg.unknownCommand":37,"status.command":38,"help.shortcuts":39,"sc.title":40,"sc.intro":41,"sc.file":42,"sc.edit":43,"sc.view":44,"sc.commands":45,"sc.hydraulic":46,"sc.switchTab":47,"sc.cancel":48,"sc.finish":49,"sc.undoPoint":50,"sc.repeat":51,"sc.zoom":52,"sc.pan":53,"sc.panHold":54,"sc.reports":55,"sc.gridDisplay":56,"sc.angleLock":57,"sc.autoRun":58,"sc.toggles":59,"sc.designCmds":60,"exp.dxf":61,"exp.dwg":62,"exp.pdf":63,"exp.svg":64,"exp.kml":65,"exp.kmz":66,"exp.geojson":67,"exp.csv":68,"exp.txt":69,"exp.xlsx":70,"exp.reportPdf":71,"msg.exported":72,"msg.needResults":73,"msg.nothingToExport":74,"msg.georefSet":75,"geo.title":76,"geo.explain":77,"geo.modeLatLon":78,"geo.modeUtm":79,"geo.lat":80,"geo.lon":81,"geo.zone":82,"geo.north":83,"geo.easting":84,"geo.northing":85,"geo.current":86,"geo.none":87,"geo.remove":88,"geo.invalid":89,"plot.title":90,"plot.page":91,"plot.orientation":92,"plot.landscape":93,"plot.portrait":94,"plot.scale":95,"plot.scaleAuto":96,"plot.wetted":97,"plot.labels":98,"plot.legend":99,"plot.reports":100,"plot.export":101,"plot.fits":102,"pdf.date":103,"pdf.scale":104,"pdf.sheet":105,"pdf.origin":106,"pdf.summary":107,"pdf.crs":108,"pdf.local":109,"pdf.legend":110,"pdf.subtitle":111,"pdf.reportTitle":112,"pdf.generated":113,"pdf.page":114,"pdf.cont":115,"pdf.noResults":116,"pdf.params":117,"layer.DRAWING":118,"layer.TEXT":119,"layer.DIMENSIONS":120,"layer.CONTOURS":121,"layer.SPOT_HEIGHTS":122,"layer.DEM":123,"layer.ZONE_PIPES":124,"layer.MAINLINE_PIPES":125,"layer.SPRAYLINES":126,"layer.TAPES":127,"layer.OUTLETS":128,"layer.WETTED_RADII":129,"layer.CONTROL_VALVES":130,"layer.WATER_SUPPLY":131,"layer.PUMPS":132,"layer.MISC_HYDRAULIC":133,"layer.JUNCTIONS":134,"layer.AREAS":135,"layer.LABELS":136,"file.details":137,"edit.undo":138,"edit.redo":139,"edit.delete":140,"edit.selectAll":141,"edit.copy":142,"view.zoomAll":143,"view.zoomIn":144,"view.zoomOut":145,"view.grid":146,"view.labels":147,"view.wetted":148,"view.overlay.none":149,"view.overlay.velocity":150,"view.overlay.pressure":151,"view.overlay.sizes":152,"view.layers":153,"view.language":154,"lang.pt":155,"lang.en":156,"lang.es":157,"design.params":158,"design.management":159,"design.check":160,"design.zone":161,"design.analyze":162,"design.mainline":163,"design.all":164,"design.clear":165,"design.progress.title":166,"design.progress.start":167,"design.progress.zones":168,"design.progress.mainline":169,"design.progress.splits":170,"design.progress.flushing":171,"design.progress.surge":172,"design.progress.bom":173,"design.progress.bg":174,"design.progress.hint":175,"design.catalog":176,"design.block":177,"design.autohead":178,"reports.zone":179,"reports.pipes":180,"reports.outlets":181,"reports.mainline":182,"reports.devices":183,"reports.bom":184,"reports.water":185,"reports.hgl":186,"reports.messages":187,"tools.lateral":188,"tools.pump":189,"tools.hammer":190,"tools.units":191,"help.about":192,"help.tutorial":193,"tool.select":194,"tool.pan":195,"tool.line":196,"tool.polyline":197,"tool.rect":198,"tool.circle":199,"tool.text":200,"tool.dimension":201,"tool.contour":202,"tool.spot":203,"tool.area":204,"tool.zonePipe":205,"tool.mainPipe":206,"tool.sprayline":207,"tool.tape":208,"tool.outlet":209,"tool.valve":210,"tool.supply":211,"tool.pump":212,"tool.misc":213,"tool.junction":214,"tool.block":215,"tool.autohead":216,"tool.measure":217,"hint.select":218,"hint.pan":219,"hint.line":220,"hint.polyline":221,"hint.rect":222,"hint.circle":223,"hint.text":224,"hint.dimension":225,"hint.contour":226,"hint.spot":227,"hint.area":228,"hint.pipe":229,"hint.point":230,"hint.block":231,"hint.measure":232,"status.ready":233,"status.snap":234,"status.grid":235,"status.ortho":236,"status.keepLinks":237,"status.keepLinksTip":238,"status.entities":239,"props.title":240,"props.none":241,"props.multi":242,"props.layer":243,"props.name":244,"props.pipe":245,"props.auto":246,"props.depth":247,"props.outlet":248,"props.nozzle":249,"props.head":250,"props.spacing":251,"props.offset":252,"props.arc":253,"props.riser":254,"props.tape":255,"props.inlet":256,"props.regulated":257,"props.submainMin":258,"props.valve":259,"props.zone":260,"props.fixedHead":261,"props.calc":262,"props.designHead":263,"props.maxHead":264,"props.designFlow":265,"props.maxFlow":266,"props.waterLevel":267,"props.pump":268,"props.speed":269,"props.misc":270,"props.setting":271,"props.elevation":272,"props.elevationDem":273,"props.text":274,"props.textHeight":275,"props.radius":276,"props.closed":277,"props.netDepth":278,"props.efficiency":279,"props.crop":280,"props.length":281,"props.area":282,"props.outlets":283,"props.scope":284,"props.results":285,"props.orientation":286,"props.rotation":287,"props.dimOffset":288,"props.zoomTo":289,"props.halfSpacing":290,"props.downstream":291,"props.required":292,"props.valveLoss":293,"props.emitterMinMax":294,"props.allowed":295,"props.uniformity":296,"props.defaults":297,"scope.zone":298,"scope.mainline":299,"result.flow":300,"result.velocity":301,"result.loss":302,"result.pressure":303,"result.pStart":304,"result.pEnd":305,"result.min":306,"result.max":307,"msg.saved":308,"msg.loaded":309,"msg.designDone":310,"msg.unconnected":311,"msg.allConnected":312,"msg.designBusy":313,"msg.designStale":314,"msg.noValves":315,"msg.deleted":316,"msg.imported":317,"msg.error":318,"msg.unsavedConfirm":319,"msg.noResults":320,"msg.noAreas":321,"msg.selectForHgl":322,"msg.noMessages":323,"msg.unconnectedItem":324,"imp.dwg":325,"imp.skipped":326,"imp.kml":327,"imp.dxf":328,"dwg.notDwg":329,"dwg.corrupt":330,"kmz.noKml":331,"rep.zone":332,"rep.valve":333,"rep.emitters":334,"rep.flow":335,"rep.pDown":336,"rep.valveLoss":337,"rep.pRequired":338,"rep.pMin":339,"rep.pMax":340,"rep.allowMin":341,"rep.allowMax":342,"rep.varAllow":343,"rep.varActual":344,"rep.pipeCost":345,"rep.warnings":346,"rep.context":347,"rep.entity":348,"rep.segment":349,"rep.pipe":350,"rep.innerDiam":351,"rep.length":352,"rep.q":353,"rep.velocity":354,"rep.hf":355,"rep.pStart":356,"rep.pEnd":357,"rep.zStart":358,"rep.zEnd":359,"rep.pn":360,"rep.emitter":361,"rep.n":362,"rep.qTotal":363,"rep.qMean":364,"rep.flowName":365,"rep.item":366,"rep.pAvailable":367,"rep.status":368,"rep.energyYear":369,"rep.supply":370,"rep.pump":371,"rep.device":372,"rep.calculated":373,"rep.surplus":374,"rep.fixed":375,"rep.deficit":376,"rep.ok":377,"rep.pumpHead":378,"rep.pIn":379,"rep.pOut":380,"rep.loss":381,"rep.st.running":382,"rep.st.stopped":383,"rep.st.open":384,"rep.st.closed":385,"rep.st.active":386,"rep.suction":387,"rep.submersible":388,"rep.outOfRange":389,"rep.category":390,"rep.description":391,"rep.unit":392,"rep.quantity":393,"rep.unitCost":394,"rep.total":395,"rep.totalRow":396,"rep.annualCapital":397,"rep.annualEnergy":398,"rep.annualTotal":399,"rep.area":400,"rep.grossDepth":401,"rep.volume":402,"rep.rate":403,"rep.hoursDay":404,"hgl.legend":405,"csv.zones":406,"csv.flows":407,"csv.bom":408,"bom.pipes":409,"bom.tapes":410,"bom.outlets":411,"bom.valves":412,"bom.devices":413,"bom.pumps":414,"name.zone":415,"name.supply":416,"name.allZones":417,"name.submain":418,"name.stub":419,"name.lateral":420,"name.area":421,"name.newProject":422,"name.text":423,"name.flow":424,"name.report":425,"ex.name":426,"ex.client":427,"ex.site":428,"ex.boundary":429,"ex.title":430,"ex.zoneA":431,"ex.zoneB":432,"ex.blockA":433,"ex.blockB":434,"ex.citrus":435,"ex.grape":436,"ex.riser":437,"ex.branchA":438,"ex.branchB":439,"ex.well":440,"ex.flow1":441,"ex.flow2":442,"dlg.project":443,"dlg.client":444,"dlg.site":445,"dlg.designer":446,"dlg.notes":447,"dlg.hydraulics":448,"dlg.frictionFormula":449,"dlg.hw":450,"dlg.dw":451,"dlg.waterTemp":452,"dlg.vLateral":453,"dlg.vZone":454,"dlg.vMain":455,"dlg.minorPct":456,"dlg.connectTol":457,"dlg.applyMinor":458,"dlg.cScale":459,"dlg.cOffset":460,"dlg.sizing":461,"dlg.maxSubmainSizes":462,"dlg.densify":463,"dlg.economics":464,"dlg.tradeCapital":465,"dlg.interest":466,"dlg.term":467,"dlg.energyCost":468,"dlg.pumpEff":469,"dlg.hoursMain":470,"dlg.hoursZone":471,"dlg.currency":472,"dlg.currencySymbol":473,"dlg.currencyNote":474,"dlg.convertPricesTitle":475,"dlg.convertPricesBody":476,"dlg.rate":477,"dlg.rateSource":478,"dlg.rateUnknown":479,"dlg.onlyCurrency":480,"dlg.convert":481,"msg.pricesConverted":482,"hist.currency":483,"cat.packPriced":484,"cat.packUnpriced":485,"cat.packSources":486,"cat.packConverted":487,"cat.packNoCurrency":488,"warn.bom_unpriced":489,"adv.bom_unpriced.why":490,"adv.bom_unpriced.how":491,"dlg.metric":492,"dlg.us":493,"dlg.length":494,"dlg.flow":495,"dlg.pressure":496,"dlg.diameter":497,"dlg.allTogether":498,"dlg.oneAtATime":499,"dlg.addFlow":500,"dlg.name":501,"dlg.startHour":502,"dlg.durationHours":503,"dlg.noFlows":504,"dlg.sprayBlock":505,"dlg.dripBlock":506,"dlg.laterals":507,"dlg.emitterSpacing":508,"dlg.lateralPipe":509,"dlg.lateralSpacing":510,"dlg.lateralDirection":511,"dlg.submainValve":512,"dlg.submainPosition":513,"dlg.submainStart":514,"dlg.submainCentre":515,"dlg.submainEnd":516,"dlg.submainPipe":517,"dlg.valvePosition":518,"dlg.posStart":519,"dlg.posCentre":520,"dlg.posEnd":521,"dlg.stub":522,"dlg.spacingPct":523,"dlg.direction":524,"dlg.square":525,"dlg.triangular":526,"dlg.gridSummary":527,"dlg.tapeLateral":528,"dlg.emitterLateral":529,"dlg.slope":530,"dlg.tolBelow":531,"dlg.tolAbove":532,"dlg.results":533,"dlg.emittersCount":534,"dlg.inletFlow":535,"dlg.totalLoss":536,"dlg.endPressure":537,"dlg.pMinMax":538,"dlg.pVariation":539,"dlg.maxVelocity":540,"dlg.uniformity4":541,"dlg.qvar":542,"dlg.maxLength":543,"dlg.staticHead":544,"dlg.speed":545,"dlg.mainPipe":546,"dlg.hoursYear":547,"dlg.operatingPoint":548,"dlg.pumpCannot":549,"dlg.head":550,"dlg.velocityMain":551,"dlg.hydraulicPower":552,"dlg.shaftPower":553,"dlg.annualEnergy":554,"dlg.shutoffRunout":555,"dlg.velocity":556,"dlg.closureTime":557,"dlg.staticPressure":558,"dlg.resultJoukowsky":559,"dlg.celerity":560,"dlg.maxSurge":561,"dlg.criticalTime":562,"dlg.estSurge":563,"dlg.totalPressure":564,"dlg.pipeClass":565,"cat.pipes":566,"cat.outlets":567,"cat.tapes":568,"cat.valves":569,"cat.pumps":570,"cat.use":571,"cat.name":572,"cat.dn":573,"cat.idmm":574,"cat.c":575,"cat.pn":576,"cat.costM":577,"cat.outlet":578,"cat.nozzle":579,"cat.k":580,"cat.x":581,"cat.pMin":582,"cat.pMax":583,"cat.pDefault":584,"cat.cv":585,"cat.tol":586,"cat.cost":587,"cat.spacing":588,"cat.qNom":589,"cat.kd":590,"cat.type":591,"cat.kLoss":592,"cat.n":593,"cat.qMax":594,"cat.points":595,"cat.eff":596,"cat.submersible":597,"cat.hint":598,"mat.pvc":599,"mat.pehd":600,"mat.peld":601,"mat.steel":602,"mat.ductileIron":603,"mat.aluminium":604,"mat.concrete":605,"warn.not_converged":606,"warn.cannot_meet_pressure_window":607,"warn.mainline_cannot_meet_pressure":608,"warn.no_water_supply":609,"warn.outlet_over_pressure":610,"warn.outlet_under_pressure":611,"warn.pressure_rating_exceeded":612,"warn.pump_out_of_range":613,"warn.pump_suction_lift":614,"warn.supply_flow_exceeded":615,"warn.supply_head_exceeded":616,"warn.valve_flow_out_of_range":617,"warn.valve_missing":618,"warn.valve_pressure_deficit":619,"warn.valve_unreachable":620,"warn.velocity_exceeded":621,"warn.zone_empty":622,"warn.zone_overlap":623,"warn.valve_no_zone_pipes":624,"warn.outlet_spec_missing":625,"warn.tape_spec_missing":626,"warn.pump_spec_missing":627,"warn.valve_spec_missing":628,"warn.no_fixed_head_node":629,"warn.page_missing":630,"about.text":631,"about.version":632,"about.site":633,"tool.arc":634,"tool.spline":635,"tool.hatch":636,"tool.symbol":637,"tool.dimAngular":638,"tool.dimRadial":639,"tool.leader":640,"tool.rotate":641,"tool.mirror":642,"tool.scale":643,"tool.offset":644,"tool.trim":645,"tool.extend":646,"tool.cutPipe":647,"tool.profile":648,"hint.arc":649,"hint.spline":650,"hint.hatch":651,"hint.symbol":652,"hint.dimAngular":653,"hint.dimRadial":654,"hint.leader":655,"hint.rotate":656,"hint.mirror":657,"hint.scale":658,"hint.offset":659,"hint.trim":660,"hint.extend":661,"hint.cutPipe":662,"hint.profile":663,"edit.transform":664,"edit.array":665,"edit.feed":666,"arr.title":667,"arr.rect":668,"arr.polar":669,"arr.rows":670,"arr.cols":671,"arr.dx":672,"arr.dy":673,"arr.angle":674,"arr.count":675,"arr.center":676,"arr.total":677,"arr.rotateItems":678,"arr.selection":679,"msg.layerLocked":680,"msg.noIntersection":681,"msg.selectLateral":682,"msg.feedComputed":683,"msg.arrayDone":684,"view.overlay.minMax":685,"view.baseMap":686,"view.baseMap.none":687,"view.baseMap.streets":688,"view.baseMap.satellite":689,"view.baseMap.topo":690,"view.baseMap.carto":691,"view.baseMap.esriStreets":692,"view.baseMap.esriTopo":693,"view.baseMap.googleRoads":694,"view.baseMap.googleSatellite":695,"view.baseMap.googleHybrid":696,"view.baseMap.googleTerrain":697,"view.baseMap.custom":698,"view.baseMap.googleKey":699,"view.baseMap.customUrl":700,"basemap.googleKey.title":701,"basemap.googleKey.explain":702,"basemap.googleKey.steps":703,"basemap.googleKey.console":704,"basemap.googleKey.docs":705,"basemap.googleKey.field":706,"basemap.googleKey.privacy":707,"basemap.googleKey.remove":708,"basemap.googleKeyMissing":709,"basemap.googleError":710,"basemap.custom.title":711,"basemap.custom.explain":712,"basemap.custom.field":713,"basemap.custom.placeholders":714,"basemap.customInvalid":715,"view.baseMapNeedsGeo":716,"view.grips":717,"zone.feedEnvelope":718,"layer.current":719,"layer.lock":720,"layer.add":721,"layer.rename":722,"layer.delete":723,"layer.color":724,"layer.name":725,"layer.exists":726,"layer.hint":727,"props.batch":728,"props.mixed":729,"props.symbolKind":730,"props.symbolSize":731,"props.hatchAngle":732,"props.hatchSpacing":733,"props.hatchSolid":734,"props.opacity":735,"props.imageWidth":736,"props.imageHeight":737,"props.source":738,"props.emittersPerPlant":739,"props.waterBalance":740,"props.eto":741,"props.kc":742,"props.kcPreset":743,"props.awc":744,"props.rootDepth":745,"props.mad":746,"props.wettedFraction":747,"props.plantSpacing":748,"props.rowSpacing":749,"props.etc":750,"props.interval":751,"props.offsetDistance":752,"props.copyOnTransform":753,"props.mirrorKeep":754,"props.splitOnInsert":755,"props.splineClosed":756,"props.angle":757,"props.leaderText":758,"props.dimRadius":759,"props.locked":760,"props.flushingFlow":761,"props.envelope":762,"props.envelopeBest":763,"props.envelopeRange":764,"props.envelopeNone":765,"sym.northArrow":766,"sym.tree":767,"sym.building":768,"sym.tank":769,"sym.well":770,"sym.valveBox":771,"sym.pumpHouse":772,"sym.gate":773,"sym.filterStation":774,"crop.citrus":775,"crop.grape":776,"crop.coffee":777,"crop.banana":778,"crop.mango":779,"crop.apple":780,"crop.tomato":781,"crop.maize":782,"crop.sugarcane":783,"crop.vegetables":784,"crop.turf":785,"crop.pasture":786,"crop.custom":787,"reports.flushing":788,"reports.surge":789,"reports.crop":790,"reports.schedule":791,"reports.profile":792,"rep.code":793,"rep.tapes":794,"rep.vFlush":795,"rep.celerity":796,"rep.surge":797,"rep.pStatic":798,"rep.pTotal":799,"rep.tCritical":800,"rep.raw":801,"rep.interval":802,"rep.netEvent":803,"rep.grossEvent":804,"rep.hoursEvent":805,"rep.overlapCu":806,"sch.date":807,"sch.flow":808,"sch.zones":809,"sch.start":810,"sch.end":811,"sch.duration":812,"prof.distance":813,"prof.elevation":814,"prof.hint":815,"prof.slope":816,"fit.coupler":817,"fit.elbow90":818,"fit.elbow45":819,"fit.tee":820,"fit.cross":821,"fit.reducer":822,"fit.endCap":823,"fit.adapter":824,"fit.takeOff":825,"fit.tapeEnd":826,"fit.riser":827,"bom.fittings":828,"bom.takeoffs":829,"bom.risers":830,"cat.fittings":831,"cat.kind":832,"cat.size2":833,"cat.supplier":834,"cat.code":835,"cat.add":836,"cat.duplicate":837,"cat.remove":838,"cat.import":839,"cat.export":840,"cat.exportCsv":841,"cat.reset":842,"cat.setDefault":843,"cat.importHint":844,"cat.removeConfirm":845,"cat.inUse":846,"msg.catalogImported":847,"msg.catalogDefaultSaved":848,"msg.catalogReset":849,"warn.lp_infeasible":850,"warn.fitting_missing":851,"warn.surge_rating_exceeded":852,"warn.schedule_no_area":853,"warn.schedule_over_24h":854,"file.importDrawing":855,"imp.points":856,"imp.shp":857,"imp.image":858,"imp.imageGeo":859,"imp.err.dem_bad_response":860,"imp.err.dem_bad_tile":861,"imp.err.dem_count_mismatch":862,"imp.err.points_empty":863,"imp.err.points_no_columns":864,"imp.err.shp_bad_header":865,"imp.err.shp_zip_no_shp":866,"imp.err.image_zip_no_image":867,"imp.err.image_unreadable":868,"file.georefImage":869,"gimg.title":870,"gimg.explain":871,"gimg.keepAspect":872,"dlg.sizingMethod":873,"dlg.lp":874,"dlg.greedy":875,"dlg.maxLateralSizes":876,"dlg.maxMainlineSizes":877,"dlg.epp":878,"dlg.maxNodes":879,"dlg.zoneVar":880,"dlg.flushing":881,"dlg.flushV":882,"dlg.flushH":883,"dlg.checkSurge":884,"dlg.closure":885,"dlg.bom":886,"dlg.fittings":887,"dlg.stick":888,"design.pumpSelect":889,"design.dem3d":890,"pump.title":891,"pump.duty":892,"pump.supply":893,"pump.candidates":894,"pump.hAtDuty":895,"pump.margin":896,"pump.opPoint":897,"pump.power":898,"pump.parallel":899,"pump.energy":900,"pump.insert":901,"pump.replace":902,"pump.noSupply":903,"pump.unsuitable":904,"pump.suction":905,"msg.pumpApplied":906,"dem.title":907,"dem.exaggeration":908,"dem.hint":909,"dem.noData":910,"dem.range":911,"file.recent":912,"file.noRecent":913,"file.versions":914,"file.autosave":915,"rec.title":916,"rec.text":917,"rec.restore":918,"rec.discard":919,"rec.later":920,"rec.item":921,"msg.recovered":922,"ver.title":923,"ver.none":924,"ver.restore":925,"ver.item":926,"msg.versionRestored":927,"mgmt.flows":928,"mgmt.schedule":929,"mgmt.apply":930,"mgmt.export":931,"mgmt.days":932,"mgmt.dayStart":933,"mgmt.keepStart":934,"mgmt.maxDaily":935,"mgmt.needResults":936,"mgmt.perFlow":937,"sc.editCmds":938,"sc.gripRemove":939,"sc.gripInsert":940,"sc.touch":941,"tool.pivot":942,"hint.pivot":943,"tool.alignImage":944,"hint.alignImage":945,"align.step1":946,"align.step2":947,"align.step3":948,"align.step4":949,"align.keepScale":950,"msg.alignDone":951,"msg.alignSelectFirst":952,"msg.profileCleared":953,"elev.title":954,"elev.contourTitle":955,"elev.spotTitle":956,"elev.value":957,"elev.interval":958,"elev.autoIncrement":959,"elev.ask":960,"elev.explainContour":961,"elev.explainSpot":962,"menu.terrain":963,"terrain.onlineDem":964,"terrain.generateContours":965,"terrain.method":966,"terrain.tin":967,"terrain.idw":968,"terrain.clearProfile":969,"terrain.stats":970,"terrain.none":971,"dlg.terrainMethod":972,"dem.online.title":973,"dem.online.explain":974,"dem.online.source":975,"dem.online.spacing":976,"dem.online.extent":977,"dem.online.replace":978,"dem.online.existing":979,"dem.online.replaceExisting":980,"dem.online.keepWarn":981,"dem.online.mismatchTitle":982,"dem.online.mismatch":983,"dem.online.mismatchRemove":984,"dem.online.mismatchKeep":985,"dem.online.wait":986,"dem.online.estimate":987,"dem.online.limitHint":988,"dem.online.cancelled":989,"dem.online.noData":990,"dem.online.layerHint":991,"dem.online.useView":992,"dem.online.run":993,"dem.online.progress":994,"dem.online.done":995,"dem.online.needGeo":996,"dem.online.error":997,"dem.online.empty":998,"cgen.title":999,"cgen.explain":1000,"cgen.interval":1001,"cgen.replace":1002,"cgen.preview":1003,"cgen.done":1004,"cgen.run":1005,"prof.clear":1006,"prof.ground":1007,"prof.pipe":1008,"prof.hgl":1009,"prof.lowest":1010,"prof.highest":1011,"prof.howTo":1012,"prof.noTerrain":1013,"prof.station":1014,"prof.pressure":1015,"prof.pathLabel":1016,"reports.pivots":1017,"rep.pivot":1018,"rep.type":1019,"rep.towers":1020,"rep.pAvail":1021,"rep.rise":1022,"rep.depthCycle":1023,"rep.hoursCycle":1024,"rep.appRatePeak":1025,"pivot.kindPivot":1026,"pivot.kindLinear":1027,"pivot.towers":1028,"bom.pivots":1029,"warn.pivot_pressure_deficit":1030,"warn.pivot_app_rate":1031,"warn.pivot_no_flow":1032,"warn.pivot_no_end_pressure":1033,"props.pivotKind":1034,"props.pivotRadius":1035,"props.pivotSpan":1036,"props.pivotTravel":1037,"props.pivotPipe":1038,"props.pivotPipeId":1039,"props.pivotC":1040,"props.pivotHeight":1041,"props.pivotEndP":1042,"props.pivotGunQ":1043,"props.pivotGunP":1044,"props.pivotThrow":1045,"props.pivotDepth":1046,"props.pivotHours":1047,"props.pivotWidth":1048,"props.pivotLoss":1049,"props.pivotMaxRate":1050,"props.pivotSector":1051,"props.pivotCost":1052,"props.pivotAngle":1053,"props.pivotResults":1054,"props.pivotArea":1055,"props.pivotInlet":1056,"props.contourInterval":1057,"props.derived":1058,"check.title":1059,"check.explain":1060,"check.summary":1061,"check.ok":1062,"check.run":1063,"check.sev.error":1064,"check.sev.warning":1065,"check.sev.info":1066,"check.no_hydraulics":1067,"check.no_supply":1068,"check.no_valves":1069,"check.unconnected":1070,"check.zone_no_emitters":1071,"check.duplicate_zone_name":1072,"check.mainline_dead_end":1073,"check.zone_dead_end":1074,"check.zero_length":1075,"check.tiny_segment":1076,"check.duplicate_item":1077,"check.pipes_cross":1078,"check.spec_missing":1079,"check.supply_no_head":1080,"check.pivot_unconnected":1081,"check.no_terrain":1082,"check.looped_mainline":1083,"check.area_no_emitters":1084,"adv.why":1085,"adv.how":1086,"adv.locate":1087,"adv.fixAll":1088,"adv.fixAllHint":1089,"adv.optimize":1090,"adv.level.error":1091,"adv.level.warning":1092,"adv.level.info":1093,"adv.none":1094,"adv.noneYet":1095,"adv.runHint":1096,"adv.designing":1097,"adv.working":1098,"adv.fixed":1099,"adv.fixFailed":1100,"adv.summaryTitle":1101,"adv.summaryNone":1102,"adv.summaryApplied":1103,"adv.remaining":1104,"adv.allClear":1105,"adv.undoHint":1106,"adv.undoAll":1107,"adv.problemsAfterDesign":1108,"adv.use.lateral":1109,"adv.use.zone":1110,"adv.use.mainline":1111,"opt.title":1112,"opt.explain":1113,"opt.pumps":1114,"opt.valves":1115,"opt.resizeAll":1116,"opt.run":1117,"opt.working":1118,"opt.before":1119,"opt.after":1120,"opt.capital":1121,"opt.energy":1122,"opt.annual":1123,"opt.problems":1124,"opt.kept":1125,"opt.reverted":1126,"opt.undo":1127,"opt.note":1128,"hist.fix":1129,"hist.autofix":1130,"hist.optimize":1131,"check.set_velocity":1132,"check.set_hours":1133,"check.set_economy":1134,"check.set_tolerance":1135,"check.set_variation":1136,"check.set_temperature":1137,"check.no_pipes_for_usage":1138,"check.supply_limits":1139,"check.valve_not_in_flow":1140,"check.flow_empty":1141,"check.flow_duration":1142,"check.emitter_head_range":1143,"check.pump_speed":1144,"fix.connect":1145,"fix.deleteItem":1146,"fix.cleanSegments":1147,"fix.removeDuplicates":1148,"fix.renameZone":1149,"fix.calculateSupply":1150,"fix.choosePump":1151,"fix.submersiblePump":1152,"fix.autoSizePipes":1153,"fix.raisePipeClass":1154,"fix.resizeValve":1155,"fix.assignModel":1156,"fix.splitFlows":1157,"fix.addFittings":1158,"fix.joinCrossing":1159,"fix.addSupply":1160,"fix.resetSettings":1161,"fix.addMissingFlow":1162,"fix.removeEmptyFlows":1163,"fix.fixFlowDurations":1164,"fix.nominalEmitterHead":1165,"fix.resetPumpSpeed":1166,"fix.fixSupplyLimits":1167,"fix.enablePipes":1168,"fixed.connect":1169,"fixed.deleteItem":1170,"fixed.cleanSegments":1171,"fixed.removeDuplicates":1172,"fixed.renameZone":1173,"fixed.calculateSupply":1174,"fixed.choosePump":1175,"fixed.insertPump":1176,"fixed.autoSizePipes":1177,"fixed.raisePipeClass":1178,"fixed.resizeValve":1179,"fixed.assignModel":1180,"fixed.splitFlows":1181,"fixed.addFittings":1182,"fixed.joinCrossing":1183,"fixed.addSupply":1184,"fixed.resetSettings":1185,"fixed.enablePipes":1186,"fixed.fixSupplyLimits":1187,"fixed.addMissingFlow":1188,"fixed.removeEmptyFlows":1189,"fixed.fixFlowDurations":1190,"fixed.nominalEmitterHead":1191,"fixed.resetPumpSpeed":1192,"fixed.lpSizing":1193,"fixfail.notFound":1194,"fixfail.nothingNear":1195,"fixfail.needsResults":1196,"fixfail.noSupply":1197,"fixfail.noDuty":1198,"fixfail.noPump":1199,"fixfail.alreadyBest":1200,"fixfail.noPipeAtSupply":1201,"fixfail.noChange":1202,"fixfail.noOption":1203,"adv.no_supply.why":1204,"adv.no_supply.how":1205,"adv.no_valves.why":1206,"adv.no_valves.how":1207,"adv.no_hydraulics.why":1208,"adv.no_hydraulics.how":1209,"adv.unconnected.why":1210,"adv.unconnected.how":1211,"adv.zero_length.why":1212,"adv.zero_length.how":1213,"adv.tiny_segment.why":1214,"adv.tiny_segment.how":1215,"adv.duplicate_item.why":1216,"adv.duplicate_item.how":1217,"adv.duplicate_zone_name.why":1218,"adv.duplicate_zone_name.how":1219,"adv.pipes_cross.why":1220,"adv.pipes_cross.how":1221,"adv.mainline_dead_end.why":1222,"adv.mainline_dead_end.how":1223,"adv.zone_dead_end.why":1224,"adv.zone_dead_end.how":1225,"adv.zone_no_emitters.why":1226,"adv.zone_no_emitters.how":1227,"adv.area_no_emitters.why":1228,"adv.area_no_emitters.how":1229,"adv.spec_missing.why":1230,"adv.spec_missing.how":1231,"adv.supply_no_head.why":1232,"adv.supply_no_head.how":1233,"adv.looped_mainline.why":1234,"adv.looped_mainline.how":1235,"adv.no_terrain.why":1236,"adv.no_terrain.how":1237,"adv.not_converged.why":1238,"adv.not_converged.how":1239,"adv.cannot_meet_pressure_window.why":1240,"adv.cannot_meet_pressure_window.how":1241,"adv.outlet_over_pressure.why":1242,"adv.outlet_over_pressure.how":1243,"adv.velocity_exceeded.why":1244,"adv.velocity_exceeded.how":1245,"adv.pressure_rating_exceeded.why":1246,"adv.pressure_rating_exceeded.how":1247,"adv.surge_rating_exceeded.why":1248,"adv.surge_rating_exceeded.how":1249,"adv.valve_flow_out_of_range.why":1250,"adv.valve_flow_out_of_range.how":1251,"adv.valve_pressure_deficit.why":1252,"adv.valve_pressure_deficit.how":1253,"adv.pivot_pressure_deficit.why":1254,"adv.pivot_pressure_deficit.how":1255,"adv.supply_flow_exceeded.why":1256,"adv.supply_flow_exceeded.how":1257,"adv.supply_head_exceeded.why":1258,"adv.supply_head_exceeded.how":1259,"adv.pump_out_of_range.why":1260,"adv.pump_out_of_range.how":1261,"adv.pump_suction_lift.why":1262,"adv.pump_suction_lift.how":1263,"adv.zone_overlap.why":1264,"adv.zone_overlap.how":1265,"adv.lp_infeasible.why":1266,"adv.lp_infeasible.how":1267,"adv.fitting_missing.why":1268,"adv.fitting_missing.how":1269,"adv.pivot_no_flow.why":1270,"adv.pivot_no_flow.how":1271,"adv.pivot_no_end_pressure.why":1272,"adv.pivot_no_end_pressure.how":1273,"adv.pivot_app_rate.why":1274,"adv.pivot_app_rate.how":1275,"adv.valve_missing.why":1276,"adv.valve_missing.how":1277,"adv.set_velocity.why":1278,"adv.set_velocity.how":1279,"adv.set_hours.why":1280,"adv.set_hours.how":1281,"adv.set_economy.why":1282,"adv.set_economy.how":1283,"adv.set_tolerance.why":1284,"adv.set_tolerance.how":1285,"adv.set_variation.why":1286,"adv.set_variation.how":1287,"adv.set_temperature.why":1288,"adv.set_temperature.how":1289,"adv.no_pipes_for_usage.why":1290,"adv.no_pipes_for_usage.how":1291,"adv.supply_limits.why":1292,"adv.supply_limits.how":1293,"adv.valve_not_in_flow.why":1294,"adv.valve_not_in_flow.how":1295,"adv.flow_empty.why":1296,"adv.flow_empty.how":1297,"adv.flow_duration.why":1298,"adv.flow_duration.how":1299,"adv.emitter_head_range.why":1300,"adv.emitter_head_range.how":1301,"adv.pump_speed.why":1302,"adv.pump_speed.how":1303,"design.checkFull":1304,"cat.packs":1305,"cat.packsExplain":1306,"cat.packAdd":1307,"cat.packAdded":1308,"cat.packItems":1309,"cat.exportXlsx":1310,"cat.importAny":1311,"mob.menu":1312,"mob.done":1313,"mob.cancel":1314,"mob.props":1315,"mob.tools":1316,"mob.hint":1317,"mob.group.nav":1318,"mob.group.draw":1319,"mob.group.edit":1320,"mob.group.terrain":1321,"mob.group.zone":1322,"mob.group.main":1323,"mob.selection":1324,"mob.project":1325,"mob.file":1326,"mob.view":1327,"mob.help":1328,"sc.mobile":1329,"dlg.followGuide":1330,"hist.title":1331,"hist.hint":1332,"hist.start":1333,"hist.edit":1334,"hist.add":1335,"hist.addMany":1336,"hist.delete":1337,"hist.move":1338,"hist.rotate":1339,"hist.scale":1340,"hist.mirror":1341,"hist.transform":1342,"hist.copy":1343,"hist.array":1344,"hist.block":1345,"hist.grid":1346,"hist.props":1347,"hist.import":1348,"hist.design":1349,"hist.contours":1350,"hist.dem":1351,"hist.demClear":1352,"hist.paste":1353,"hist.elevation":1354,"hist.align":1355,"hist.layer":1356,"plot.bomOnSheet":1357,"pdf.bom":1358,"pdf.qty":1359,"pdf.bomMore":1360,"imp.demTiff":1361,"reports.pivotSpans":1362,"rep.span":1363,"rep.rFrom":1364,"rep.rTo":1365,"rep.sprinklers":1366,"rep.qSprinkler":1367,"rep.pMid":1368,"rep.nozzleSuggested":1369,"props.pivotSprSpacing":1370,"props.pivotSprinkler":1371,"props.pivotRegulator":1372,"props.pivotTowerCost":1373,"pivot.towersItem":1374,"pivot.sprinklersItem":1375,"pivot.endGunItem":1376,"props.contourSmooth":1377,"dem.online.maxPoints":1378,"pump.motor":1379,"warn.lp_loops_approx":1380,"cat.packsBundled":1381,"cat.packsLoaded":1382,"cat.packImport":1383,"cat.packUrl":1384,"cat.packLoad":1385,"cat.packLoading":1386,"cat.packLoaded":1387,"cat.packLoadError":1388,"cat.packExport":1389,"cat.packExportTitle":1390,"cat.packExportExplain":1391,"cat.packBrand":1392,"cat.packName":1393,"cat.packDescription":1394,"cat.packSource":1395,"cat.packExported":1396,"cat.packFormat":1397,"cat.packFrom":1398,"imp.err.catalog_json_unknown":1399,"imp.err.catalog_index_not_pack":1400,"imp.err.catalog_index_unknown":1401,"imp.err.catalog_pack_version":1402,"dem.online.coord":1403,"dem.online.coordHint":1404,"dem.online.coordExplain":1405,"dem.online.useCoord":1406,"dem.online.areaSize":1407,"dem.online.coordInvalid":1408,"dem.online.contours":1409,"dem.online.contourInterval":1410,"dem.online.doneContours":1411,"msg.georefAt":1412,"file.examples":1413,"help.welcome":1414,"welcome.title":1415,"welcome.body":1416,"welcome.examples":1417,"welcome.examplesHint":1418,"welcome.tutorial":1419,"welcome.skip":1420,"exg.orchard.title":1421,"exg.orchard.sub":1422,"exg.orchard.tags":1423,"exg.garden.title":1424,"exg.garden.sub":1425,"exg.garden.tags":1426,"exg.sportsField.title":1427,"exg.sportsField.sub":1428,"exg.sportsField.tags":1429,"exg.rowCrop.title":1430,"exg.rowCrop.sub":1431,"exg.rowCrop.tags":1432,"exg.pivot.title":1433,"exg.pivot.sub":1434,"exg.pivot.tags":1435,"ex.shift":1436,"ex.g.name":1437,"ex.g.client":1438,"ex.g.site":1439,"ex.g.title":1440,"ex.g.lot":1441,"ex.g.house":1442,"ex.g.front":1443,"ex.g.back":1444,"ex.g.bed":1445,"ex.g.zone1":1446,"ex.g.zone2":1447,"ex.g.zone3":1448,"ex.g.supply":1449,"ex.g.grass":1450,"ex.g.shrubs":1451,"ex.g.main":1452,"ex.g.street":1453,"ex.f.name":1454,"ex.f.client":1455,"ex.f.site":1456,"ex.f.title":1457,"ex.f.pitch":1458,"ex.f.row":1459,"ex.f.tank":1460,"ex.f.pumpHouse":1461,"ex.f.grass":1462,"ex.f.main":1463,"ex.c.name":1464,"ex.c.client":1465,"ex.c.site":1466,"ex.c.title":1467,"ex.c.block":1468,"ex.c.tomato":1469,"ex.c.reservoir":1470,"ex.c.trunk":1471,"ex.c.west":1472,"ex.c.east":1473,"ex.c.road":1474,"ex.c.field":1475,"ex.p.name":1476,"ex.p.client":1477,"ex.p.site":1478,"ex.p.title":1479,"ex.p.pivot":1480,"ex.p.well":1481,"ex.p.maize":1482,"ex.p.adductor":1483,"ex.p.field":1484,"ex.p.boundary":1485,"exg.greenhouse.title":1486,"exg.greenhouse.sub":1487,"exg.greenhouse.tags":1488,"exg.nursery.title":1489,"exg.nursery.sub":1490,"exg.nursery.tags":1491,"exg.coffee.title":1492,"exg.coffee.sub":1493,"exg.coffee.tags":1494,"exg.bananas.title":1495,"exg.bananas.sub":1496,"exg.bananas.tags":1497,"exg.sugarcane.title":1498,"exg.sugarcane.sub":1499,"exg.sugarcane.tags":1500,"exg.gravity.title":1501,"exg.gravity.sub":1502,"exg.gravity.tags":1503,"exg.pasture.title":1504,"exg.pasture.sub":1505,"exg.pasture.tags":1506,"exg.golf.title":1507,"exg.golf.sub":1508,"exg.golf.tags":1509,"exg.sectorPivot.title":1510,"exg.sectorPivot.sub":1511,"exg.sectorPivot.tags":1512,"exg.linear.title":1513,"exg.linear.sub":1514,"exg.linear.tags":1515,"ex.gh.name":1516,"ex.gh.client":1517,"ex.gh.site":1518,"ex.gh.title":1519,"ex.gh.lot":1520,"ex.gh.tunnel":1521,"ex.gh.crop":1522,"ex.gh.tank":1523,"ex.gh.main":1524,"ex.nu.name":1525,"ex.nu.client":1526,"ex.nu.site":1527,"ex.nu.title":1528,"ex.nu.lot":1529,"ex.nu.bed":1530,"ex.nu.crop":1531,"ex.nu.tank":1532,"ex.nu.main":1533,"ex.cf.name":1534,"ex.cf.client":1535,"ex.cf.site":1536,"ex.cf.title":1537,"ex.cf.block":1538,"ex.cf.coffee":1539,"ex.cf.well":1540,"ex.cf.main":1541,"ex.cf.boundary":1542,"ex.ba.name":1543,"ex.ba.client":1544,"ex.ba.site":1545,"ex.ba.title":1546,"ex.ba.block":1547,"ex.ba.banana":1548,"ex.ba.well":1549,"ex.ba.field":1550,"ex.ba.road":1551,"ex.ba.main":1552,"ex.sc.name":1553,"ex.sc.client":1554,"ex.sc.site":1555,"ex.sc.title":1556,"ex.sc.block":1557,"ex.sc.cane":1558,"ex.sc.field":1559,"ex.sc.road":1560,"ex.sc.reservoir":1561,"ex.sc.trunk":1562,"ex.sc.west":1563,"ex.sc.east":1564,"ex.gr.name":1565,"ex.gr.client":1566,"ex.gr.site":1567,"ex.gr.title":1568,"ex.gr.block":1569,"ex.gr.crop":1570,"ex.gr.reservoir":1571,"ex.gr.prv":1572,"ex.gr.field":1573,"ex.gr.main":1574,"ex.gr.west":1575,"ex.gr.east":1576,"ex.pa.name":1577,"ex.pa.client":1578,"ex.pa.site":1579,"ex.pa.title":1580,"ex.pa.paddock":1581,"ex.pa.grass":1582,"ex.pa.fence":1583,"ex.pa.road":1584,"ex.pa.reservoir":1585,"ex.pa.main":1586,"ex.go.name":1587,"ex.go.client":1588,"ex.go.site":1589,"ex.go.title":1590,"ex.go.tee":1591,"ex.go.fairway":1592,"ex.go.fairwayZone":1593,"ex.go.green":1594,"ex.go.bunker":1595,"ex.go.pond":1596,"ex.go.turf":1597,"ex.go.pumpHouse":1598,"ex.go.main":1599,"ex.sp.name":1600,"ex.sp.client":1601,"ex.sp.site":1602,"ex.sp.title":1603,"ex.sp.pivot":1604,"ex.sp.soy":1605,"ex.sp.pond":1606,"ex.sp.farm":1607,"ex.sp.field":1608,"ex.sp.boundary":1609,"ex.sp.road":1610,"ex.sp.adductor":1611,"ex.li.name":1612,"ex.li.client":1613,"ex.li.site":1614,"ex.li.title":1615,"ex.li.machine":1616,"ex.li.wheat":1617,"ex.li.canal":1618,"ex.li.intake":1619,"ex.li.field":1620,"ex.li.boundary":1621,"ex.li.main":1622}
B.ng=new A.a("OpenCADIrrigation","OpenCADIrrigation","OpenCADIrrigation")
B.pX=new A.a("OK","OK","Aceptar")
B.bO=new A.a("Cancelar","Cancel","Cancelar")
B.kO=new A.a("Aplicar","Apply","Aplicar")
B.mV=new A.a("Fechar","Close","Cerrar")
B.Cy=new A.a("Autom\xe1tico","Automatic","Autom\xe1tico")
B.c9=new A.a("Limpar","Clear","Limpiar")
B.ax=new A.a("Arquivo","File","Archivo")
B.bV=new A.a("Editar","Edit","Editar")
B.cv=new A.a("Ver","View","Ver")
B.bT=new A.a("Desenhar","Draw","Dibujar")
B.F=new A.a("Zona","Zone","Zona")
B.t=new A.a("Linha principal","Mainline","L\xednea principal")
B.cC=new A.a("Projeto","Design","Dise\xf1o")
B.nz=new A.a("Relat\xf3rios","Reports","Informes")
B.bZ=new A.a("Ferramentas","Tools","Herramientas")
B.bI=new A.a("Ajuda","Help","Ayuda")
B.bD=new A.a("Novo projeto","New project","Nuevo proyecto")
B.i2=new A.a("Abrir projeto\u2026","Open project\u2026","Abrir proyecto\u2026")
B.pQ=new A.a("Salvar projeto","Save project","Guardar proyecto")
B.iR=new A.a("Exportar DXF","Export DXF","Exportar DXF")
B.jr=new A.a("Exportar desenho","Export drawing","Exportar dibujo")
B.j8=new A.a("Exportar relat\xf3rio","Export report","Exportar informe")
B.vQ=new A.a("Georrefer\xeancia\u2026","Georeference\u2026","Georreferencia\u2026")
B.j5=new A.a("Nova aba de projeto","New project tab","Nueva pesta\xf1a de proyecto")
B.hP=new A.a("Fechar aba","Close tab","Cerrar pesta\xf1a")
B.B0=new A.a("Nova aba (Ctrl+Alt+N)","New tab (Ctrl+Alt+N)","Nueva pesta\xf1a (Ctrl+Alt+N)")
B.wo=new A.a("Fechar aba (Ctrl+Alt+W)","Close tab (Ctrl+Alt+W)","Cerrar pesta\xf1a (Ctrl+Alt+W)")
B.lE=new A.a("Copiar","Copy","Copiar")
B.rj=new A.a("Recortar","Cut","Cortar")
B.bP=new A.a("Colar","Paste","Pegar")
B.Bh=new A.a("{n} itens copiados","{n} items copied","{n} elementos copiados")
B.Cd=new A.a("{n} itens recortados","{n} items cut","{n} elementos cortados")
B.vG=new A.a("Tubo cortado em 2 trechos","Pipe cut into 2 pieces","Tuber\xeda cortada en 2 tramos")
B.qx=new A.a("{n} itens colados","{n} items pasted","{n} elementos pegados")
B.bU=new A.a("Nada selecionado","Nothing selected","Nada seleccionado")
B.jv=new A.a("\xc1rea de transfer\xeancia vazia","Clipboard is empty","Portapapeles vac\xedo")
B.zo=new A.a("Comando desconhecido: {cmd} (veja Ajuda \u2192 Atalhos de teclado)","Unknown command: {cmd} (see Help \u2192 Keyboard shortcuts)","Comando desconocido: {cmd} (vea Ayuda \u2192 Atajos de teclado)")
B.lB=new A.a("Comando","Command","Comando")
B.iP=new A.a("Atalhos de teclado\u2026","Keyboard shortcuts\u2026","Atajos de teclado\u2026")
B.ip=new A.a("Atalhos de teclado","Keyboard shortcuts","Atajos de teclado")
B.ol=new A.a("Com o desenho em foco, digite o alias do comando e pressione Enter ou Espa\xe7o, como no AutoCAD (ex.: L \u23ce linha, PL \u23ce polilinha, ZE \u23ce enquadrar, E \u23ce apagar). Esc limpa o comando digitado. As combina\xe7\xf5es com Ctrl e as teclas F funcionam em qualquer parte da tela.","With the drawing focused, type the command alias and press Enter or Space, as in AutoCAD (e.g. L \u23ce line, PL \u23ce polyline, ZE \u23ce zoom extents, E \u23ce erase). Esc clears the typed command. Ctrl combinations and F keys work anywhere.","Con el dibujo enfocado, escriba el alias del comando y pulse Enter o Espacio, como en AutoCAD (p. ej. L \u23ce l\xednea, PL \u23ce polil\xednea, ZE \u23ce encuadrar, E \u23ce borrar). Esc limpia el comando. Las combinaciones con Ctrl y las teclas F funcionan en toda la pantalla.")
B.pY=new A.a("Arquivo e abas","File and tabs","Archivo y pesta\xf1as")
B.lR=new A.a("Edi\xe7\xe3o","Editing","Edici\xf3n")
B.wm=new A.a("Vista e desenho","View and drawing","Vista y dibujo")
B.jm=new A.a("Comandos (alias \u23ce)","Commands (alias \u23ce)","Comandos (alias \u23ce)")
B.kI=new A.a("Ferramentas hidr\xe1ulicas (alias \u23ce)","Hydraulic tools (alias \u23ce)","Herramientas hidr\xe1ulicas (alias \u23ce)")
B.wX=new A.a("Alternar aba de projeto","Switch project tab","Cambiar pesta\xf1a de proyecto")
B.pf=new A.a("Cancelar / voltar a selecionar","Cancel / back to select","Cancelar / volver a seleccionar")
B.mL=new A.a("Concluir polilinha / executar comando","Finish polyline / run command","Terminar polil\xednea / ejecutar comando")
B.uz=new A.a("Remover \xfaltimo ponto / apagar letra do comando","Remove last point / delete command letter","Quitar \xfaltimo punto / borrar letra del comando")
B.uw=new A.a("Repetir \xfaltima ferramenta (Enter ao selecionar)","Repeat last tool (Enter while selecting)","Repetir \xfaltima herramienta (Enter al seleccionar)")
B.ku=new A.a("Aproximar / afastar","Zoom in / out","Acercar / alejar")
B.u8=new A.a("Deslocar vista","Pan view","Desplazar vista")
B.oF=new A.a("Mover vista (segurar; ou bot\xe3o do meio do mouse)","Pan (hold; or middle mouse button)","Mover vista (mantener; o bot\xf3n central del rat\xf3n)")
B.xP=new A.a("Mostrar/ocultar relat\xf3rios","Show/hide reports","Mostrar/ocultar informes")
B.uk=new A.a("Mostrar/ocultar grade","Show/hide grid","Mostrar/ocultar cuadr\xedcula")
B.tR=new A.a("Travar a linha em 0\xb0/45\xb0/90\xb0 enquanto desenha (segurar)","Lock the line to 0\xb0/45\xb0/90\xb0 while drawing (hold)","Bloquear la l\xednea en 0\xb0/45\xb0/90\xb0 mientras dibuja (mantener)")
B.kf=new A.a("Alias digitado executa sozinho ap\xf3s uma pausa (ou Enter/Espa\xe7o)","A typed alias runs by itself after a pause (or Enter/Space)","El alias escrito se ejecuta solo tras una pausa (o Intro/Espacio)")
B.x2=new A.a("Snap / orto / grade vis\xedvel / snap \xe0 grade","Snap / ortho / grid display / grid snap","Snap / orto / cuadr\xedcula visible / snap a cuadr\xedcula")
B.mb=new A.a("Projetar tudo / verificar conex\xf5es / relat\xf3rios","Design all / check connectivity / reports","Dise\xf1ar todo / verificar conexiones / informes")
B.iw=new A.a("DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)","DXF (AutoCAD, QGIS)")
B.m4=new A.a("DWG (AutoCAD 2000, bin\xe1rio)","DWG (AutoCAD 2000, binary)","DWG (AutoCAD 2000, binario)")
B.th=new A.a("PDF (prancha para impress\xe3o)\u2026","PDF (plot sheet)\u2026","PDF (l\xe1mina para impresi\xf3n)\u2026")
B.rz=new A.a("SVG (figura vetorial: web, Inkscape)","SVG (vector figure: web, Inkscape)","SVG (figura vectorial: web, Inkscape)")
B.rK=new A.a("KML (Google Earth)","KML (Google Earth)","KML (Google Earth)")
B.qK=new A.a("KMZ (Google Earth, compactado)","KMZ (Google Earth, zipped)","KMZ (Google Earth, comprimido)")
B.x0=new A.a("GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)","GeoJSON (QGIS, web GIS)")
B.r0=new A.a("CSV (planilha)","CSV (spreadsheet)","CSV (hoja de c\xe1lculo)")
B.ig=new A.a("TXT (texto)","TXT (plain text)","TXT (texto)")
B.Bd=new A.a("XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)","XLSX (Excel, LibreOffice)")
B.uu=new A.a("PDF (documento)","PDF (document)","PDF (documento)")
B.yG=new A.a("Exportado: {f}","Exported: {f}","Exportado: {f}")
B.nS=new A.a("Execute o projeto (F5) antes de exportar o relat\xf3rio","Run the design (F5) before exporting the report","Ejecute el dise\xf1o (F5) antes de exportar el informe")
B.q1=new A.a("O desenho est\xe1 vazio","The drawing is empty","El dibujo est\xe1 vac\xedo")
B.qe=new A.a("Georrefer\xeancia definida: {crs}","Georeference set: {crs}","Georreferencia definida: {crs}")
B.xs=new A.a("Georrefer\xeancia do projeto","Project georeference","Georreferencia del proyecto")
B.tM=new A.a("Para exportar em KML, KMZ ou GeoJSON o desenho precisa de uma posi\xe7\xe3o no mundo. Informe a coordenada da origem do desenho (x = 0, y = 0). Projetos importados de KML/KMZ j\xe1 v\xeam georreferenciados.","To export KML, KMZ or GeoJSON the drawing needs a position on Earth. Enter the coordinate of the drawing origin (x = 0, y = 0). Projects imported from KML/KMZ are already georeferenced.","Para exportar en KML, KMZ o GeoJSON el dibujo necesita una posici\xf3n en el mundo. Indique la coordenada del origen del dibujo (x = 0, y = 0). Los proyectos importados de KML/KMZ ya vienen georreferenciados.")
B.vv=new A.a("Latitude / longitude (WGS84)","Latitude / longitude (WGS84)","Latitud / longitud (WGS84)")
B.zi=new A.a("UTM (WGS84)","UTM (WGS84)","UTM (WGS84)")
B.pc=new A.a("Latitude (\xb0)","Latitude (\xb0)","Latitud (\xb0)")
B.y0=new A.a("Longitude (\xb0)","Longitude (\xb0)","Longitud (\xb0)")
B.yF=new A.a("Fuso UTM (1\u201360)","UTM zone (1\u201360)","Huso UTM (1\u201360)")
B.mR=new A.a("Hemisf\xe9rio norte","Northern hemisphere","Hemisferio norte")
B.tW=new A.a("Este (m)","Easting (m)","Este (m)")
B.mo=new A.a("Norte (m)","Northing (m)","Norte (m)")
B.kK=new A.a("Atual: {crs} \xb7 origem E {e} m, N {n} m","Current: {crs} \xb7 origin E {e} m, N {n} m","Actual: {crs} \xb7 origen E {e} m, N {n} m")
B.kl=new A.a("Projeto ainda sem georrefer\xeancia","Project not georeferenced yet","Proyecto a\xfan sin georreferencia")
B.aG=new A.a("Remover","Remove","Quitar")
B.rr=new A.a("Coordenadas inv\xe1lidas","Invalid coordinates","Coordenadas no v\xe1lidas")
B.n_=new A.a("Exportar PDF (prancha)","Export PDF (plot sheet)","Exportar PDF (l\xe1mina)")
B.rG=new A.a("Formato do papel","Paper size","Tama\xf1o de papel")
B.xj=new A.a("Orienta\xe7\xe3o","Orientation","Orientaci\xf3n")
B.qs=new A.a("Paisagem","Landscape","Horizontal")
B.rq=new A.a("Retrato","Portrait","Vertical")
B.w_=new A.a("Escala 1 :","Scale 1 :","Escala 1 :")
B.ib=new A.a("Ajustar \xe0 folha","Fit to sheet","Ajustar a la hoja")
B.aO=new A.a("Raios molhados","Wetted radii","Radios mojados")
B.zx=new A.a("R\xf3tulos e resultados","Labels and results","Etiquetas y resultados")
B.xK=new A.a("Legenda de camadas","Layer legend","Leyenda de capas")
B.qv=new A.a("Anexar p\xe1ginas de relat\xf3rio","Append report pages","Adjuntar p\xe1ginas de informe")
B.mF=new A.a("Exportar","Export","Exportar")
B.Dx=new A.a("Escala autom\xe1tica: 1:{n}","Automatic scale: 1:{n}","Escala autom\xe1tica: 1:{n}")
B.bS=new A.a("Data","Date","Fecha")
B.mz=new A.a("Escala","Scale","Escala")
B.n1=new A.a("Folha","Sheet","Hoja")
B.q5=new A.a("Origem","Origin","Origen")
B.qg=new A.a("Zonas / emissores","Zones / outlets","Zonas / emisores")
B.tO=new A.a("Coordenadas","Coordinates","Coordenadas")
B.BN=new A.a("Locais (m)","Local (m)","Locales (m)")
B.oZ=new A.a("Legenda","Legend","Leyenda")
B.xQ=new A.a("Projeto de irriga\xe7\xe3o pressurizada","Pressurised irrigation design","Dise\xf1o de riego presurizado")
B.tz=new A.a("Relat\xf3rio de dimensionamento hidr\xe1ulico","Hydraulic design report","Informe de dise\xf1o hidr\xe1ulico")
B.wu=new A.a("Gerado por OpenCADIrrigation em {d}","Generated by OpenCADIrrigation on {d}","Generado por OpenCADIrrigation el {d}")
B.Dc=new A.a("P\xe1gina {i} de {n}","Page {i} of {n}","P\xe1gina {i} de {n}")
B.t8=new A.a("(continua\xe7\xe3o)","(continued)","(continuaci\xf3n)")
B.hw=new A.a("Sem resultados de dimensionamento: execute o projeto para incluir as tabelas hidr\xe1ulicas.","No design results: run the design to include the hydraulic tables.","Sin resultados de dise\xf1o: ejecute el dise\xf1o para incluir las tablas hidr\xe1ulicas.")
B.xL=new A.a("Par\xe2metros de projeto","Design parameters","Par\xe1metros de dise\xf1o")
B.m9=new A.a("Desenho","Drawing","Dibujo")
B.a3=new A.a("Texto","Text","Texto")
B.lH=new A.a("Cotas","Dimensions","Cotas")
B.wY=new A.a("Curvas de n\xedvel","Contours","Curvas de nivel")
B.uo=new A.a("Pontos cotados","Spot heights","Puntos acotados")
B.zU=new A.a("MDT baixado","Downloaded DEM","MDT descargado")
B.mi=new A.a("Tubos de zona","Zone pipes","Tuber\xedas de zona")
B.le=new A.a("Linha principal","Mainline pipes","L\xednea principal")
B.mv=new A.a("Laterais com emissores","Spraylines","Laterales con emisores")
B.Bw=new A.a("Fitas gotejadoras","Drip tapes","Cintas de goteo")
B.A=new A.a("Emissores","Outlets","Emisores")
B.AC=new A.a("V\xe1lvulas de controle","Control valves","V\xe1lvulas de control")
B.xU=new A.a("Fontes de \xe1gua","Water supplies","Fuentes de agua")
B.az=new A.a("Bombas","Pumps","Bombas")
B.cu=new A.a("Acess\xf3rios hidr\xe1ulicos","Hydraulic devices","Accesorios hidr\xe1ulicos")
B.iV=new A.a("N\xf3s","Junctions","Nudos")
B.kx=new A.a("\xc1reas irrigadas","Irrigated areas","\xc1reas regadas")
B.cP=new A.a("R\xf3tulos","Labels","Etiquetas")
B.x3=new A.a("Detalhes do projeto\u2026","Project details\u2026","Detalles del proyecto\u2026")
B.ma=new A.a("Desfazer","Undo","Deshacer")
B.rl=new A.a("Refazer","Redo","Rehacer")
B.nC=new A.a("Excluir sele\xe7\xe3o","Delete selection","Eliminar selecci\xf3n")
B.B_=new A.a("Selecionar tudo","Select all","Seleccionar todo")
B.mj=new A.a("Duplicar sele\xe7\xe3o","Duplicate selection","Duplicar selecci\xf3n")
B.lg=new A.a("Enquadrar tudo","Zoom all","Encuadrar todo")
B.zR=new A.a("Aproximar","Zoom in","Acercar")
B.pS=new A.a("Afastar","Zoom out","Alejar")
B.c4=new A.a("Grade","Grid","Cuadr\xedcula")
B.ru=new A.a("Sem resultados","No results overlay","Sin resultados")
B.uL=new A.a("Colorir por velocidade","Colour by velocity","Colorear por velocidad")
B.Dw=new A.a("Colorir por press\xe3o","Colour by pressure","Colorear por presi\xf3n")
B.iO=new A.a("Mostrar di\xe2metros","Show diameters","Mostrar di\xe1metros")
B.bN=new A.a("Camadas","Layers","Capas")
B.nY=new A.a("Idioma","Language","Idioma")
B.uS=new A.a("Portugu\xeas","Portuguese","Portugu\xe9s")
B.pG=new A.a("Ingl\xeas","English","Ingl\xe9s")
B.CF=new A.a("Espanhol","Spanish","Espa\xf1ol")
B.Dh=new A.a("Par\xe2metros de projeto\u2026","Design parameters\u2026","Par\xe1metros de dise\xf1o\u2026")
B.zv=new A.a("Turnos de opera\xe7\xe3o (management)\u2026","System flows (management)\u2026","Turnos de operaci\xf3n\u2026")
B.we=new A.a("Verifica\xe7\xe3o do projeto (Design Check)\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o (Design Check)\u2026")
B.uC=new A.a("Dimensionar zonas (LP/velocidade)","Size zones (LP/velocity)","Dimensionar zonas (LP/velocidad)")
B.v0=new A.a("Analisar (tamanhos atuais)","Analyse (existing sizes)","Analizar (tama\xf1os actuales)")
B.u0=new A.a("Dimensionar linha principal","Size mainline","Dimensionar l\xednea principal")
B.jW=new A.a("Projetar tudo","Design all","Dise\xf1ar todo")
B.pV=new A.a("Limpar resultados","Clear results","Limpiar resultados")
B.kt=new A.a("Calculando o projeto\u2026","Designing the system\u2026","Calculando el dise\xf1o\u2026")
B.nh=new A.a("Montando a rede hidr\xe1ulica","Building the hydraulic network","Armando la red hidr\xe1ulica")
B.nO=new A.a("Zona {i} de {n}","Zone {i} of {n}","Zona {i} de {n}")
B.p5=new A.a("Linha principal e turnos de opera\xe7\xe3o","Mainline and system flows","L\xednea principal y turnos de operaci\xf3n")
B.nB=new A.a("Reanalisando trechos telescopados","Re-analysing telescoped pipes","Reanalizando tramos telescopados")
B.vx=new A.a("An\xe1lise de lavagem (flushing)","Flushing analysis","An\xe1lisis de lavado (flushing)")
B.j1=new A.a("Verifica\xe7\xe3o de golpe de ar\xedete","Water hammer check","Verificaci\xf3n de golpe de ariete")
B.a4=new A.a("Lista de materiais","Bill of materials","Lista de materiales")
B.Br=new A.a("Calculando em segundo plano: navegue \xe0 vontade; edi\xe7\xf5es esperam o fim.","Running in the background: navigate freely; edits wait until it finishes.","Calculando en segundo plano: navega libremente; las ediciones esperan al final.")
B.B5=new A.a("O navegador pode ficar lento enquanto o c\xe1lculo roda.","The browser may be slow while the calculation runs.","El navegador puede ir lento mientras corre el c\xe1lculo.")
B.Cq=new A.a("Cat\xe1logo de componentes\u2026","Component catalog\u2026","Cat\xe1logo de componentes\u2026")
B.vJ=new A.a("Bloco de laterais\u2026","Lateral block\u2026","Bloque de laterales\u2026")
B.rP=new A.a("Aspersores autom\xe1ticos (grade)\u2026","Auto sprinklers (grid)\u2026","Aspersores autom\xe1ticos (malla)\u2026")
B.i6=new A.a("Resumo das zonas","Zone summary","Resumen de zonas")
B.aB=new A.a("Tubos","Pipes","Tuber\xedas")
B.yL=new A.a("Linha principal / duty","Mainline / duty","L\xednea principal / demanda")
B.oD=new A.a("Bombas e acess\xf3rios","Pumps and devices","Bombas y accesorios")
B.hK=new A.a("Requisitos h\xeddricos","Water requirements","Requerimientos h\xeddricos")
B.CI=new A.a("Linha piezom\xe9trica","Hydraulic grade line","L\xednea piezom\xe9trica")
B.pn=new A.a("Mensagens","Messages","Mensajes")
B.oG=new A.a("Calculadora de lateral\u2026","Lateral calculator\u2026","Calculadora de lateral\u2026")
B.yW=new A.a("Bomba e curva do sistema\u2026","Pump & system curve\u2026","Bomba y curva del sistema\u2026")
B.AE=new A.a("Golpe de ar\xedete\u2026","Water hammer\u2026","Golpe de ariete\u2026")
B.iu=new A.a("Unidades\u2026","Units\u2026","Unidades\u2026")
B.ql=new A.a("Sobre","About","Acerca de")
B.yo=new A.a("Tutorial interativo","Interactive tutorial","Tutorial interactivo")
B.rT=new A.a("Selecionar","Select","Seleccionar")
B.vU=new A.a("Mover vista","Pan","Mover vista")
B.yw=new A.a("Linha","Line","L\xednea")
B.iv=new A.a("Polilinha","Polyline","Polil\xednea")
B.uJ=new A.a("Ret\xe2ngulo","Rectangle","Rect\xe1ngulo")
B.mk=new A.a("C\xedrculo","Circle","C\xedrculo")
B.lG=new A.a("Cota","Dimension","Cota")
B.tc=new A.a("Curva de n\xedvel","Contour","Curva de nivel")
B.uX=new A.a("Cota de ponto","Spot height","Cota de punto")
B.aL=new A.a("\xc1rea irrigada","Irrigated area","\xc1rea regada")
B.lh=new A.a("Tubo de zona","Zone pipe","Tuber\xeda de zona")
B.B1=new A.a("Tubo principal","Mainline pipe","Tuber\xeda principal")
B.jb=new A.a("Lateral (sprayline)","Sprayline (lateral)","Lateral (sprayline)")
B.c6=new A.a("Fita/tubo gotejador","Drip tape / dripline","Cinta/tuber\xeda de goteo")
B.a2=new A.a("Emissor","Outlet","Emisor")
B.m0=new A.a("V\xe1lvula de controle","Control valve","V\xe1lvula de control")
B.ok=new A.a("Fonte de \xe1gua","Water supply","Fuente de agua")
B.ay=new A.a("Bomba","Pump","Bomba")
B.ze=new A.a("Acess\xf3rio hidr\xe1ulico","Misc. hydraulic","Accesorio hidr\xe1ulico")
B.qd=new A.a("Jun\xe7\xe3o","Junction","Nudo")
B.cA=new A.a("Bloco de laterais","Lateral block","Bloque de laterales")
B.bC=new A.a("Grade de aspersores","Sprinkler grid","Malla de aspersores")
B.pm=new A.a("Medir","Measure","Medir")
B.hR=new A.a("Clique para selecionar, arraste para mover ou janela; Shift adiciona; Del exclui","Click to select, drag to move or window; Shift adds; Del deletes","Clic para seleccionar, arrastre para mover o ventana; Shift a\xf1ade; Supr elimina")
B.xo=new A.a("Arraste para mover a vista; roda do mouse para zoom","Drag to pan; mouse wheel zooms","Arrastre para mover la vista; rueda del rat\xf3n para zoom")
B.yf=new A.a("Clique no primeiro ponto, depois no segundo","Click first point, then second","Clic en el primer punto y luego en el segundo")
B.oK=new A.a("Clique nos v\xe9rtices; Enter/duplo clique termina; Esc cancela","Click vertices; Enter/double-click ends; Esc cancels","Clic en los v\xe9rtices; Intro/doble clic termina; Esc cancela")
B.A_=new A.a("Clique nos dois cantos opostos","Click two opposite corners","Clic en dos esquinas opuestas")
B.ir=new A.a("Clique no centro, depois no raio","Click centre, then radius","Clic en el centro y luego en el radio")
B.yH=new A.a("Clique na posi\xe7\xe3o do texto","Click text position","Clic en la posici\xf3n del texto")
B.yj=new A.a("Clique nos dois pontos e depois na posi\xe7\xe3o da linha de cota","Click two points, then the dimension line position","Clic en dos puntos y luego en la posici\xf3n de la l\xednea de cota")
B.uD=new A.a("Clique os v\xe9rtices da curva de n\xedvel; Enter (ou Concluir) termina e pede a eleva\xe7\xe3o; Esc cancela","Click the contour vertices; Enter (or Done) finishes and asks for the elevation; Esc cancels","Clic en los v\xe9rtices de la curva de nivel; Intro (o Terminar) termina y pide la elevaci\xf3n; Esc cancela")
B.oM=new A.a("Clique onde fica a cota; a eleva\xe7\xe3o \xe9 pedida a cada ponto","Click where the spot height goes; the elevation is asked for each point","Clic donde va la cota; la elevaci\xf3n se pide en cada punto")
B.BO=new A.a("Clique nos v\xe9rtices do pol\xedgono; Enter fecha","Click polygon vertices; Enter closes","Clic en los v\xe9rtices del pol\xedgono; Intro cierra")
B.p9=new A.a("Clique nos v\xe9rtices do tubo; Enter/duplo clique termina; conecta automaticamente","Click pipe vertices; Enter/double-click ends; connects automatically","Clic en los v\xe9rtices de la tuber\xeda; Intro/doble clic termina; conecta autom\xe1ticamente")
B.As=new A.a("Clique sobre um tubo ou jun\xe7\xe3o para conectar","Click on a pipe or junction to connect","Clic sobre una tuber\xeda o nudo para conectar")
B.i8=new A.a("Clique nos v\xe9rtices do bloco; Enter conclui e abre as op\xe7\xf5es","Click block vertices; Enter finishes and opens options","Clic en los v\xe9rtices del bloque; Intro termina y abre las opciones")
B.pe=new A.a("Clique em dois pontos","Click two points","Clic en dos puntos")
B.qD=new A.a("Pronto","Ready","Listo")
B.rW=new A.a("Snap","Snap","Snap")
B.q6=new A.a("Orto","Ortho","Orto")
B.y9=new A.a("Conex\xe3o","Linked","Conexi\xf3n")
B.io=new A.a("Ao arrastar o n\xf3 de um tubo, as pontas de tubos e os itens ligados a ele acompanham o movimento","Dragging the node of a pipe drags along the pipe ends and items joined to it","Al arrastrar el nodo de una tuber\xeda, los extremos de tuber\xeda y los elementos unidos a \xe9l acompa\xf1an el movimiento")
B.tx=new A.a("ent.","ent.","ent.")
B.aM=new A.a("Propriedades","Properties","Propiedades")
B.wt=new A.a("{n} itens selecionados","{n} items selected","{n} elementos seleccionados")
B.lp=new A.a("Camada","Layer","Capa")
B.aE=new A.a("Nome","Name","Nombre")
B.cE=new A.a("Tubo","Pipe","Tuber\xeda")
B.yJ=new A.a("Dimensionar automaticamente","Computer sized","Dimensionar autom\xe1ticamente")
B.o3=new A.a("Profundidade (m)","Depth (m)","Profundidad (m)")
B.bM=new A.a("Bocal","Nozzle","Boquilla")
B.Bl=new A.a("Press\xe3o nominal","Nominal pressure","Presi\xf3n nominal")
B.zn=new A.a("Espa\xe7amento","Spacing","Espaciamiento")
B.BL=new A.a("Deslocamento do 1\xba emissor","First outlet offset","Desplazamiento del 1.\xba emisor")
B.yV=new A.a("Arco (\xb0)","Arc (\xb0)","Arco (\xb0)")
B.wM=new A.a("Altura da haste (m)","Riser height (m)","Altura del tubo de subida (m)")
B.wT=new A.a("Fita/tubo gotejador","Tape / dripline","Cinta/tuber\xeda de goteo")
B.wA=new A.a("Press\xe3o de entrada","Inlet pressure","Presi\xf3n de entrada")
B.rm=new A.a("Regulada","Regulated","Regulada")
B.wd=new A.a("Press\xe3o m\xedn. no submain","Submain min. pressure","Presi\xf3n m\xedn. en el submain")
B.bE=new A.a("V\xe1lvula","Valve","V\xe1lvula")
B.n9=new A.a("Press\xe3o a jusante fixa (vazio = calcular)","Fixed downstream pressure (blank = calculate)","Presi\xf3n aguas abajo fija (vac\xedo = calcular)")
B.A9=new A.a("Calcular press\xe3o necess\xe1ria","Calculate required pressure","Calcular presi\xf3n necesaria")
B.Dt=new A.a("Press\xe3o de projeto","Design pressure","Presi\xf3n de dise\xf1o")
B.DA=new A.a("Press\xe3o m\xe1xima","Maximum pressure","Presi\xf3n m\xe1xima")
B.vj=new A.a("Vaz\xe3o de projeto","Design flow","Caudal de dise\xf1o")
B.n0=new A.a("Vaz\xe3o m\xe1xima","Maximum flow","Caudal m\xe1ximo")
B.CD=new A.a("N\xedvel de \xe1gua relativo ao solo (m)","Water level relative to ground (m)","Nivel de agua respecto al suelo (m)")
B.ce=new A.a("Rota\xe7\xe3o relativa","Relative speed","Velocidad relativa")
B.cM=new A.a("Acess\xf3rio","Device","Accesorio")
B.qL=new A.a("Press\xe3o regulada (PRV)","Regulated pressure (PRV)","Presi\xf3n regulada (PRV)")
B.aN=new A.a("Eleva\xe7\xe3o (m)","Elevation (m)","Elevaci\xf3n (m)")
B.vB=new A.a("Eleva\xe7\xe3o (m; 0 = do terreno)","Elevation (m; 0 = from DEM)","Elevaci\xf3n (m; 0 = del terreno)")
B.im=new A.a("Altura do texto (m)","Text height (m)","Altura del texto (m)")
B.iT=new A.a("Raio (m)","Radius (m)","Radio (m)")
B.mU=new A.a("Fechado","Closed","Cerrado")
B.iH=new A.a("L\xe2mina l\xedquida (mm/dia)","Net depth (mm/day)","L\xe1mina neta (mm/d\xeda)")
B.jU=new A.a("Efici\xeancia","Efficiency","Eficiencia")
B.lL=new A.a("Cultura","Crop","Cultivo")
B.bQ=new A.a("Comprimento","Length","Longitud")
B.aI=new A.a("\xc1rea","Area","\xc1rea")
B.od=new A.a("Escopo","Scope","\xc1mbito")
B.ci=new A.a("Resultados","Results","Resultados")
B.Bz=new A.a("Orienta\xe7\xe3o (\xb0)","Orientation (\xb0)","Orientaci\xf3n (\xb0)")
B.oE=new A.a("Rota\xe7\xe3o (\xb0)","Rotation (\xb0)","Rotaci\xf3n (\xb0)")
B.qJ=new A.a("Afastamento da cota","Dimension offset","Desplazamiento de la cota")
B.Dl=new A.a("Enquadrar","Zoom to","Encuadrar")
B.BY=new A.a("1\xba emissor a meio espa\xe7amento","First outlet at half spacing","1.\xba emisor a medio espaciamiento")
B.hM=new A.a("P a jusante","Downstream P","P aguas abajo")
B.cH=new A.a("P requerida","Required P","P requerida")
B.Dj=new A.a("Perda na v\xe1lvula","Valve loss","P\xe9rdida en la v\xe1lvula")
B.vA=new A.a("Emissor m\xedn/m\xe1x","Outlet min/max","Emisor m\xedn/m\xe1x")
B.Ds=new A.a("Admiss\xedvel","Allowable","Admisible")
B.CB=new A.a("CU / DU / EU","CU / DU / EU","CU / DU / EU")
B.xu=new A.a("valores padr\xe3o","defaults","valores predeterminados")
B.aC=new A.a("Vaz\xe3o","Flow","Caudal")
B.tZ=new A.a("Velocidade","Velocity","Velocidad")
B.Aa=new A.a("Perda de carga","Head loss","P\xe9rdida de carga")
B.aD=new A.a("Press\xe3o","Pressure","Presi\xf3n")
B.l5=new A.a("Press\xe3o in\xedcio","Start pressure","Presi\xf3n inicio")
B.CW=new A.a("Press\xe3o fim","End pressure","Presi\xf3n final")
B.wp=new A.a("M\xedn","Min","M\xedn")
B.nE=new A.a("M\xe1x","Max","M\xe1x")
B.kC=new A.a("Projeto salvo","Project saved","Proyecto guardado")
B.tY=new A.a("Projeto carregado","Project loaded","Proyecto cargado")
B.kS=new A.a("Projeto conclu\xeddo: {z} zonas, {f} turnos","Design finished: {z} zones, {f} system flows","Dise\xf1o terminado: {z} zonas, {f} turnos")
B.y6=new A.a("{n} itens n\xe3o conectados (marcados em vermelho)","{n} unconnected items (marked in red)","{n} elementos sin conectar (marcados en rojo)")
B.kX=new A.a("Todos os itens est\xe3o conectados","All items are connected","Todos los elementos est\xe1n conectados")
B.oJ=new A.a("C\xe1lculo em andamento: aguarde para editar o projeto.","Design running: wait for it to finish before editing.","C\xe1lculo en curso: espera a que termine para editar.")
B.xF=new A.a("O projeto mudou durante o c\xe1lculo; resultados descartados. Rode o c\xe1lculo de novo.","The project changed while the design ran; results discarded. Run the design again.","El proyecto cambi\xf3 durante el c\xe1lculo; resultados descartados. Ejecuta el c\xe1lculo de nuevo.")
B.z0=new A.a("Nenhuma v\xe1lvula de controle no projeto","No control valve in the design","No hay v\xe1lvulas de control en el dise\xf1o")
B.y7=new A.a("{n} itens exclu\xeddos","{n} items deleted","{n} elementos eliminados")
B.o_=new A.a("Importado","Imported","Importado")
B.q8=new A.a("Erro: {e}","Error: {e}","Error: {e}")
B.AU=new A.a("O projeto atual tem altera\xe7\xf5es n\xe3o salvas. Continuar?","The current project has unsaved changes. Continue?","El proyecto actual tiene cambios sin guardar. \xbfContinuar?")
B.nP=new A.a("Execute Projeto \u25b6 para gerar resultados","Run Design \u25b6 to generate results","Ejecute Dise\xf1o \u25b6 para generar resultados")
B.ur=new A.a("Desenhe \xe1reas irrigadas (ferramenta \xc1rea) para calcular tempos de irriga\xe7\xe3o","Draw irrigated areas (Area tool) to compute irrigation times","Dibuje \xe1reas regadas (herramienta \xc1rea) para calcular tiempos de riego")
B.zl=new A.a("Selecione um tubo, lateral ou v\xe1lvula","Select a pipe, lateral or valve","Seleccione una tuber\xeda, lateral o v\xe1lvula")
B.vM=new A.a("Sem mensagens","No messages","Sin mensajes")
B.xA=new A.a("N\xe3o conectado","Not connected","Sin conectar")
B.vg=new A.a("DWG {v}: {n} entidades, {l} camadas","DWG {v}: {n} entities, {l} layers","DWG {v}: {n} entidades, {l} capas")
B.Cb=new A.a(", {n} objetos ignorados",", {n} objects skipped",", {n} objetos omitidos")
B.AF=new A.a(u.n,"{k}: {p} placemarks, {n} entities ({crs})",u.n)
B.w6=new A.a("DXF: {n} entidades","DXF: {n} entities","DXF: {n} entidades")
B.CZ=new A.a("N\xe3o \xe9 um arquivo DWG reconhecido","Not a recognised DWG file","No es un archivo DWG reconocido")
B.vT=new A.a("Estrutura do DWG n\xe3o encontrada (arquivo danificado ou variante n\xe3o suportada)","DWG structure not found (damaged file or unsupported variant)","Estructura del DWG no encontrada (archivo da\xf1ado o variante no compatible)")
B.mZ=new A.a("KMZ sem arquivo .kml","KMZ without a .kml file","KMZ sin archivo .kml")
B.jl=new A.a("P jusante","Downstream P","P aguas abajo")
B.tN=new A.a("Perda v\xe1lv.","Valve loss","P\xe9rdida v\xe1lv.")
B.cL=new A.a("P m\xedn","Min P","P m\xedn")
B.cl=new A.a("P m\xe1x","Max P","P m\xe1x")
B.CH=new A.a("Adm. m\xedn","Allow. min","Adm. m\xedn")
B.yd=new A.a("Adm. m\xe1x","Allow. max","Adm. m\xe1x")
B.z1=new A.a("Var. adm. %","Allow. var. %","Var. adm. %")
B.D1=new A.a("Var. real %","Actual var. %","Var. real %")
B.zL=new A.a("Custo tubos","Pipe cost","Costo tuber\xedas")
B.kV=new A.a("Avisos","Warnings","Avisos")
B.lD=new A.a("Contexto","Context","Contexto")
B.mw=new A.a("Entidade","Entity","Entidad")
B.nZ=new A.a("Seg.","Seg.","Seg.")
B.lY=new A.a("DI","ID","DI")
B.c7=new A.a("L","L","L")
B.qP=new A.a("Q","Q","Q")
B.oR=new A.a("V (m/s)","V (m/s)","V (m/s)")
B.y2=new A.a("hf","hf","hf")
B.ih=new A.a("P in\xedcio","Start P","P inicio")
B.hF=new A.a("P fim","End P","P fin")
B.vo=new A.a("Z in\xedcio","Start Z","Z inicio")
B.nr=new A.a("Z fim","End Z","Z fin")
B.qk=new A.a("PN","PN","PN")
B.pF=new A.a("N","N","N")
B.BA=new A.a("Q total","Total Q","Q total")
B.Da=new A.a("Q m\xe9dio","Mean Q","Q medio")
B.aF=new A.a("Turno","System flow","Turno")
B.o2=new A.a("Item","Item","Elemento")
B.jY=new A.a("P dispon\xedvel","Available P","P disponible")
B.up=new A.a("Situa\xe7\xe3o","Status","Estado")
B.cx=new A.a("Energia/ano","Energy/year","Energ\xeda/a\xf1o")
B.aA=new A.a("Fonte","Supply","Fuente")
B.w7=new A.a("calculada","calculated","calculada")
B.BC=new A.a("sobra","surplus","sobra")
B.xe=new A.a("fixa","fixed","fija")
B.Cg=new A.a("d\xe9ficit","deficit","d\xe9ficit")
B.Af=new A.a("ok","ok","ok")
B.jG=new A.a("H bomba","Pump H","H bomba")
B.yQ=new A.a("P entrada","Inlet P","P entrada")
B.kc=new A.a("P sa\xedda","Outlet P","P salida")
B.uN=new A.a("Perda","Loss","P\xe9rdida")
B.rg=new A.a("em opera\xe7\xe3o","running","en operaci\xf3n")
B.Au=new A.a("parada","stopped","detenida")
B.vu=new A.a("aberto","open","abierto")
B.xb=new A.a("fechado","closed","cerrado")
B.B8=new A.a("regulando","regulating","regulando")
B.lS=new A.a("suc\xe7\xe3o","suction lift","succi\xf3n")
B.BE=new A.a("submersa","submersible","sumergible")
B.pW=new A.a("fora da faixa","out of range","fuera de rango")
B.qj=new A.a("Categoria","Category","Categor\xeda")
B.Ah=new A.a("Descri\xe7\xe3o","Description","Descripci\xf3n")
B.yB=new A.a("Un.","Unit","Ud.")
B.r2=new A.a("Quantidade","Quantity","Cantidad")
B.wU=new A.a("Unit\xe1rio","Unit cost","Unitario")
B.tr=new A.a("Total","Total","Total")
B.tf=new A.a("TOTAL","TOTAL","TOTAL")
B.Ba=new A.a("Custo anualizado (capital)","Annualised cost (capital)","Costo anualizado (capital)")
B.xt=new A.a("Custo anual de energia","Annual energy cost","Costo anual de energ\xeda")
B.cN=new A.a("Custo anual total","Total annual cost","Costo anual total")
B.wj=new A.a("L\xe2mina bruta (mm/d)","Gross depth (mm/d)","L\xe1mina bruta (mm/d)")
B.hG=new A.a("Volume (m\xb3/d)","Volume (m\xb3/d)","Volumen (m\xb3/d)")
B.i_=new A.a("Taxa (mm/h)","Rate (mm/h)","Tasa (mm/h)")
B.nk=new A.a("Horas/dia","Hours/day","Horas/d\xeda")
B.pE=new A.a("HGL (azul) \xb7 terreno (marrom) \xb7 faixa admiss\xedvel (verde)","HGL (blue) \xb7 ground (brown) \xb7 allowable band (green)","LP (azul) \xb7 terreno (marr\xf3n) \xb7 banda admisible (verde)")
B.v1=new A.a("ZONAS","ZONES","ZONAS")
B.Bu=new A.a("TURNOS","SYSTEM FLOWS","TURNOS")
B.Ck=new A.a("LISTA DE MATERIAIS","BILL OF MATERIALS","LISTA DE MATERIALES")
B.nT=new A.a("Fitas/tubos gotejadores","Drip tapes/lines","Cintas/tuber\xedas de goteo")
B.cB=new A.a("V\xe1lvulas","Valves","V\xe1lvulas")
B.wg=new A.a("Todas as zonas","All zones","Todas las zonas")
B.t1=new A.a("Submain","Submain","Submain")
B.ts=new A.a("Trecho","Stub","Tramo")
B.B9=new A.a("relatorio","report","informe")
B.u6=new A.a("Exemplo pomar","Orchard example","Ejemplo huerto")
B.z=new A.a("Fazenda Exemplo","Example Farm","Finca Ejemplo")
B.jF=new A.a("Blocos A e B","Blocks A and B","Bloques A y B")
B.mc=new A.a("Divisa","Boundary","Lindero")
B.xI=new A.a("Pomar \u2014 exemplo OpenCADIrrigation","Orchard \u2014 OpenCADIrrigation example","Huerto \u2014 ejemplo OpenCADIrrigation")
B.p7=new A.a("Zona A","Zone A","Zona A")
B.p8=new A.a("Zona B","Zone B","Zona B")
B.yT=new A.a("Bloco A","Block A","Bloque A")
B.xi=new A.a("Bloco B","Block B","Bloque B")
B.cj=new A.a("Citros","Citrus","C\xedtricos")
B.cs=new A.a("Uva","Grapes","Uva")
B.n5=new A.a("Recalque","Rising main","Impulsi\xf3n")
B.zd=new A.a("Ramal A","Branch A","Ramal A")
B.Co=new A.a("Ramal B","Branch B","Ramal B")
B.P=new A.a("Po\xe7o","Well","Pozo")
B.CR=new A.a("Turno 1 \u2014 Zona A","Flow 1 \u2014 Zone A","Turno 1 \u2014 Zona A")
B.tb=new A.a("Turno 2 \u2014 Zona B","Flow 2 \u2014 Zone B","Turno 2 \u2014 Zona B")
B.qC=new A.a("Projeto","Project","Proyecto")
B.lz=new A.a("Cliente","Client","Cliente")
B.p3=new A.a("Local","Site","Lugar")
B.qB=new A.a("Projetista","Designer","Proyectista")
B.pO=new A.a("Notas","Notes","Notas")
B.uM=new A.a("Hidr\xe1ulica","Hydraulics","Hidr\xe1ulica")
B.nW=new A.a("F\xf3rmula de perda de carga","Head-loss formula","F\xf3rmula de p\xe9rdida de carga")
B.hJ=new A.a("Hazen-Williams","Hazen-Williams","Hazen-Williams")
B.xg=new A.a("Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)","Darcy-Weisbach (Swamee-Jain)")
B.hs=new A.a("Temperatura da \xe1gua (\xb0C)","Water temperature (\xb0C)","Temperatura del agua (\xb0C)")
B.hr=new A.a("Vel. m\xe1x. lateral (m/s)","Max. lateral velocity (m/s)","Vel. m\xe1x. lateral (m/s)")
B.yN=new A.a("Vel. m\xe1x. zona (m/s)","Max. zone velocity (m/s)","Vel. m\xe1x. zona (m/s)")
B.kY=new A.a("Vel. m\xe1x. linha principal (m/s)","Max. mainline velocity (m/s)","Vel. m\xe1x. l\xednea principal (m/s)")
B.nm=new A.a("Perdas localizadas (% do comprimento)","Minor losses (% of length)","P\xe9rdidas localizadas (% de la longitud)")
B.Bi=new A.a("Toler\xe2ncia de conex\xe3o (m)","Connection tolerance (m)","Tolerancia de conexi\xf3n (m)")
B.os=new A.a("Aplicar perdas localizadas","Apply minor losses","Aplicar p\xe9rdidas localizadas")
B.yi=new A.a("Fator C: escala","C factor: scale","Factor C: escala")
B.oY=new A.a("Fator C: acr\xe9scimo","C factor: offset","Factor C: incremento")
B.tD=new A.a("Dimensionamento","Sizing","Dimensionamiento")
B.qh=new A.a("N\xba m\xe1x. de di\xe2metros no submain","Max. submain sizes","N.\xba m\xe1x. de di\xe1metros en el submain")
B.oy=new A.a("Densifica\xe7\xe3o do DEM (m)","DEM densification (m)","Densificaci\xf3n del MDT (m)")
B.iX=new A.a("Economia","Economics","Econom\xeda")
B.kJ=new A.a("Balancear custo de capital vs. custo de energia","Trade capital cost vs. energy cost","Equilibrar costo de capital vs. costo de energ\xeda")
B.Ci=new A.a("Juros (fra\xe7\xe3o/ano)","Interest (fraction/year)","Inter\xe9s (fracci\xf3n/a\xf1o)")
B.Bn=new A.a("Prazo (anos)","Term (years)","Plazo (a\xf1os)")
B.uy=new A.a("Custo da energia ({c}/kWh)","Energy cost ({c}/kWh)","Costo de la energ\xeda ({c}/kWh)")
B.mt=new A.a("Efici\xeancia da bomba (fra\xe7\xe3o)","Pump efficiency (fraction)","Eficiencia de la bomba (fracci\xf3n)")
B.BP=new A.a("Horas de opera\xe7\xe3o/ano (linha principal)","Operating hours/year (mainline)","Horas de operaci\xf3n/a\xf1o (l\xednea principal)")
B.m5=new A.a("Horas/ano por zona","Hours/year per zone","Horas/a\xf1o por zona")
B.cb=new A.a("Moeda","Currency","Moneda")
B.v9=new A.a("S\xedmbolo da moeda","Currency symbol","S\xedmbolo de la moneda")
B.p_=new A.a("Os pre\xe7os do cat\xe1logo padr\xe3o s\xe3o ilustrativos: uma tabela em reais convertida pelo c\xe2mbio de {d}. Substitua-os pela tabela de pre\xe7os local.","Built-in catalogue prices are illustrative: a price list in reais converted with the exchange rates of {d}. Replace them with your local price list.","Los precios del cat\xe1logo predeterminado son ilustrativos: una lista en reales convertida con el tipo de cambio del {d}. Sustit\xfayalos por la lista de precios local.")
B.Ai=new A.a("Converter os pre\xe7os?","Convert the prices?","\xbfConvertir los precios?")
B.vN=new A.a('Converter todos os pre\xe7os do projeto (cat\xe1logo, custo da energia, piv\xf4s) de {from} para {to}? "S\xf3 trocar a moeda" mant\xe9m os n\xfameros como est\xe3o.','Convert every price of the project (catalogue, energy cost, pivots) from {from} to {to}? "Change the currency only" keeps the numbers as they are.','\xbfConvertir todos los precios del proyecto (cat\xe1logo, costo de la energ\xeda, pivotes) de {from} a {to}? "Solo cambiar la moneda" mantiene los n\xfameros como est\xe1n.')
B.ic=new A.a("C\xe2mbio ({to} por 1 {from})","Exchange rate ({to} per 1 {from})","Tipo de cambio ({to} por 1 {from})")
B.xk=new A.a("C\xe2mbio de refer\xeancia de {d} (Banco Central Europeu / exchangerate-api.com). Ajuste para a cota\xe7\xe3o do dia.","Reference rate of {d} (European Central Bank / exchangerate-api.com). Adjust it to the rate of the day.","Tipo de cambio de referencia del {d} (Banco Central Europeo / exchangerate-api.com). Aj\xfastelo a la cotizaci\xf3n del d\xeda.")
B.hO=new A.a("Sem c\xe2mbio de refer\xeancia para esta moeda: informe a taxa.","No reference rate for this currency: enter the rate.","Sin tipo de cambio de referencia para esta moneda: indique la tasa.")
B.l2=new A.a("S\xf3 trocar a moeda","Change the currency only","Solo cambiar la moneda")
B.qH=new A.a("Converter pre\xe7os","Convert prices","Convertir precios")
B.cy=new A.a("Pre\xe7os convertidos de {from} para {to} (\xd7 {r}).","Prices converted from {from} to {to} (\xd7 {r}).","Precios convertidos de {from} a {to} (\xd7 {r}).")
B.hX=new A.a("Pre\xe7os em {c}","Prices in {c}","Precios en {c}")
B.oN=new A.a("Sem pre\xe7os (preencha com a tabela local)","No prices (fill in your local price list)","Sin precios (complete con la lista local)")
B.n3=new A.a("Fontes","Sources","Fuentes")
B.wc=new A.a("O pacote n\xe3o informa a moeda: pre\xe7os mantidos como est\xe3o.","The pack does not state its currency: prices kept as they are.","El paquete no indica la moneda: precios mantenidos como est\xe1n.")
B.kj=new A.a("Itens do cat\xe1logo sem pre\xe7o","Catalogue items without a price","Elementos del cat\xe1logo sin precio")
B.p2=new A.a("Alguns itens da lista de materiais est\xe3o com pre\xe7o zero, em geral produtos adicionados de um cat\xe1logo de fabricante (que v\xeam sem pre\xe7o). Os totais os deixam de fora e, para tubos sem pre\xe7o, o dimensionamento econ\xf4mico usa uma estimativa proporcional \xe0 parede do tubo.","Some items in the bill of materials have price zero, usually products added from a manufacturer catalogue (they come without prices). The totals leave them out, and for pipes without a price the economic sizing uses an estimate proportional to the pipe wall.","Algunos elementos de la lista de materiales tienen precio cero, en general productos a\xf1adidos desde un cat\xe1logo de fabricante (que vienen sin precio). Los totales los dejan fuera y, para las tuber\xedas sin precio, el dimensionamiento econ\xf3mico usa una estimaci\xf3n proporcional a la pared del tubo.")
B.yU=new A.a("Informe os pre\xe7os no Cat\xe1logo de componentes (ou exporte para Excel, preencha com a sua tabela e importe de volta) e calcule de novo.","Enter the prices in the Component catalog (or export it to Excel, fill in your price list and import it back), then design again.","Indique los precios en el Cat\xe1logo de componentes (o exp\xf3rtelo a Excel, complete con su lista e imp\xf3rtelo de vuelta) y calcule de nuevo.")
B.pg=new A.a("M\xe9trico","Metric","M\xe9trico")
B.qn=new A.a("US","US","EE. UU.")
B.wD=new A.a("Di\xe2metro","Diameter","Di\xe1metro")
B.iC=new A.a("Todas juntas","All together","Todas juntas")
B.uT=new A.a("Uma por vez","One at a time","Una a la vez")
B.xS=new A.a("+ Turno","+ Flow","+ Turno")
B.wS=new A.a("In\xedcio (h)","Start (h)","Inicio (h)")
B.cG=new A.a("Dura\xe7\xe3o (h)","Duration (h)","Duraci\xf3n (h)")
B.Ax=new A.a("Sem turnos definidos: todas as zonas ser\xe3o consideradas operando juntas.","No system flows defined: all zones are assumed to run together.","Sin turnos definidos: se considera que todas las zonas funcionan juntas.")
B.AN=new A.a("Aspers\xe3o / microaspers\xe3o","Sprinkler / micro-sprinkler","Aspersi\xf3n / microaspersi\xf3n")
B.CU=new A.a("Gotejamento (fita/tubo)","Drip (tape/line)","Goteo (cinta/tuber\xeda)")
B.oW=new A.a("Laterais","Laterals","Laterales")
B.lO=new A.a("Espa\xe7amento entre emissores","Outlet spacing","Espaciamiento entre emisores")
B.yX=new A.a("Tubo da lateral","Lateral pipe","Tuber\xeda de la lateral")
B.lM=new A.a("Espa\xe7amento entre laterais","Lateral spacing","Espaciamiento entre laterales")
B.nV=new A.a("Dire\xe7\xe3o das laterais (\xb0)","Lateral direction (\xb0)","Direcci\xf3n de las laterales (\xb0)")
B.tg=new A.a("Submain e v\xe1lvula","Submain and valve","Submain y v\xe1lvula")
B.lc=new A.a("Posi\xe7\xe3o do submain","Submain position","Posici\xf3n del submain")
B.vV=new A.a("In\xedcio das laterais","Start of laterals","Inicio de las laterales")
B.x9=new A.a("Centro (laterais pareadas)","Centre (paired laterals)","Centro (laterales pareadas)")
B.x7=new A.a("Fim das laterais","End of laterals","Final de las laterales")
B.hB=new A.a("Tubo do submain","Submain pipe","Tuber\xeda del submain")
B.wr=new A.a("Posi\xe7\xe3o da v\xe1lvula","Valve position","Posici\xf3n de la v\xe1lvula")
B.bX=new A.a("In\xedcio","Start","Inicio")
B.lw=new A.a("Centro","Centre","Centro")
B.mY=new A.a("Fim","End","Final")
B.kZ=new A.a("Trecho at\xe9 a v\xe1lvula (stub)","Stub to the valve","Tramo hasta la v\xe1lvula")
B.AX=new A.a("Espa\xe7amento (% do di\xe2metro molhado)","Spacing (% of wetted diameter)","Espaciamiento (% del di\xe1metro mojado)")
B.qo=new A.a("Dire\xe7\xe3o (\xb0)","Direction (\xb0)","Direcci\xf3n (\xb0)")
B.r1=new A.a("Quadrado","Square","Cuadrado")
B.tt=new A.a("Triangular","Triangular","Triangular")
B.wl=new A.a("Raio {r} m \u2192 espa\xe7amento {s} m; taxa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %","Radius {r} m \u2192 spacing {s} m; rate \u2248 {pr} mm/h; theoretical CU \u2248 {cu} %","Radio {r} m \u2192 espaciamiento {s} m; tasa \u2248 {pr} mm/h; CU te\xf3rico \u2248 {cu} %")
B.qG=new A.a("Lateral com emissores","Lateral with outlets","Lateral con emisores")
B.nI=new A.a("Declividade (%; + desce)","Slope (%; + downhill)","Pendiente (%; + baja)")
B.jV=new A.a("Toler\xe2ncia abaixo (%)","Tolerance below (%)","Tolerancia por debajo (%)")
B.tK=new A.a("Toler\xe2ncia acima (%)","Tolerance above (%)","Tolerancia por encima (%)")
B.lQ=new A.a("Vaz\xe3o de entrada","Inlet flow","Caudal de entrada")
B.me=new A.a("Perda de carga total","Total head loss","P\xe9rdida de carga total")
B.uO=new A.a("Press\xe3o no fim","End pressure","Presi\xf3n al final")
B.ms=new A.a("Press\xe3o m\xedn / m\xe1x","Min / max pressure","Presi\xf3n m\xedn / m\xe1x")
B.ya=new A.a("Varia\xe7\xe3o de press\xe3o","Pressure variation","Variaci\xf3n de presi\xf3n")
B.xY=new A.a("Velocidade m\xe1x.","Max. velocity","Velocidad m\xe1x.")
B.qm=new A.a("CU / DU / EU / Us","CU / DU / EU / Us","CU / DU / EU / Us")
B.AV=new A.a("qvar","qvar","qvar")
B.k3=new A.a("Comprimento m\xe1ximo (janela \xb1)","Maximum length (\xb1 window)","Longitud m\xe1xima (ventana \xb1)")
B.yn=new A.a("Altura est\xe1tica","Static head","Altura est\xe1tica")
B.nu=new A.a("Adutora","Delivery main","Conducci\xf3n")
B.k0=new A.a("Horas/ano","Hours/year","Horas/a\xf1o")
B.cd=new A.a("Ponto de opera\xe7\xe3o","Operating point","Punto de operaci\xf3n")
B.l7=new A.a("A bomba n\xe3o vence a altura est\xe1tica.","The pump cannot overcome the static head.","La bomba no supera la altura est\xe1tica.")
B.xC=new A.a("Altura manom\xe9trica","Total head","Altura manom\xe9trica")
B.oa=new A.a("Velocidade na adutora","Velocity in the main","Velocidad en la conducci\xf3n")
B.AQ=new A.a("Pot\xeancia hidr\xe1ulica","Hydraulic power","Potencia hidr\xe1ulica")
B.y3=new A.a("Pot\xeancia no eixo (\u03b7 {e} %)","Shaft power (\u03b7 {e} %)","Potencia en el eje (\u03b7 {e} %)")
B.ji=new A.a("Energia anual","Annual energy","Energ\xeda anual")
B.zS=new A.a("Shutoff / runout","Shutoff / runout","Shutoff / runout")
B.qX=new A.a("Velocidade (m/s)","Velocity (m/s)","Velocidad (m/s)")
B.zu=new A.a("Tempo de fechamento (s)","Closure time (s)","Tiempo de cierre (s)")
B.BZ=new A.a("Press\xe3o est\xe1tica","Static pressure","Presi\xf3n est\xe1tica")
B.tE=new A.a("Resultado (Joukowsky)","Result (Joukowsky)","Resultado (Joukowsky)")
B.w0=new A.a("Celeridade","Wave celerity","Celeridad")
B.uA=new A.a("Sobrepress\xe3o m\xe1xima (fechamento instant\xe2neo)","Maximum surge (instantaneous closure)","Sobrepresi\xf3n m\xe1xima (cierre instant\xe1neo)")
B.oQ=new A.a("Tempo cr\xedtico 2L/a","Critical time 2L/a","Tiempo cr\xedtico 2L/a")
B.hv=new A.a("Sobrepress\xe3o estimada (fechamento {s} s)","Estimated surge (closure {s} s)","Sobrepresi\xf3n estimada (cierre {s} s)")
B.uK=new A.a("Press\xe3o total","Total pressure","Presi\xf3n total")
B.mq=new A.a("Classe do tubo","Pipe class","Clase de la tuber\xeda")
B.c_=new A.a("Fitas","Tapes","Cintas")
B.tL=new A.a("Uso","Use","Uso")
B.m_=new A.a("DN","DN","DN")
B.uf=new A.a("DI mm","ID mm","DI mm")
B.lo=new A.a("C","C","C")
B.CV=new A.a("PN (m)","PN (m)","PN (m)")
B.hY=new A.a("{c}/m","{c}/m","{c}/m")
B.hQ=new A.a("k (L/h\xb7m^-x)","k (L/h\xb7m^-x)","k (L/h\xb7m^-x)")
B.CP=new A.a("x","x","x")
B.AK=new A.a("P padr\xe3o","Default P","P predeterminada")
B.ln=new A.a("CV","CV","CV")
B.xH=new A.a("Tol \xb1%","Tol \xb1%","Tol \xb1%")
B.vr=new A.a("{c}","{c}","{c}")
B.AO=new A.a("Esp. m","Spacing m","Esp. m")
B.CN=new A.a("q nom L/h","q nom L/h","q nom L/h")
B.oB=new A.a("Kd","Kd","Kd")
B.co=new A.a("Tipo","Type","Tipo")
B.lP=new A.a("K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)","K (h=K\xb7Q^n, Q m\xb3/s)")
B.zV=new A.a("n","n","n")
B.jp=new A.a("Q m\xe1x m\xb3/h","Max Q m\xb3/h","Q m\xe1x m\xb3/h")
B.t6=new A.a("Pontos (Q m\xb3/h @ H m)","Points (Q m\xb3/h @ H m)","Puntos (Q m\xb3/h @ H m)")
B.qb=new A.a("\u03b7","\u03b7","\u03b7")
B.t2=new A.a("Submersa","Submersible","Sumergible")
B.t_=new A.a("Edite e pressione Enter em cada campo. Valores hidr\xe1ulicos internos em SI; vaz\xf5es em L/h ou m\xb3/h conforme indicado.","Edit and press Enter in each field. Internal hydraulic values are SI; flows in L/h or m\xb3/h as indicated.","Edite y pulse Intro en cada campo. Valores hidr\xe1ulicos internos en SI; caudales en L/h o m\xb3/h seg\xfan se indica.")
B.qr=new A.a("PVC","PVC","PVC")
B.qN=new A.a("PEAD/PE100","HDPE/PE100","PEAD/PE100")
B.qi=new A.a("PEBD","LDPE","PEBD")
B.wW=new A.a("A\xe7o","Steel","Acero")
B.hC=new A.a("Ferro d\xfactil","Ductile iron","Fundici\xf3n d\xfactil")
B.kq=new A.a("Alum\xednio","Aluminium","Aluminio")
B.zE=new A.a("Concreto","Concrete","Hormig\xf3n")
B.AI=new A.a("C\xe1lculo n\xe3o convergiu","Calculation did not converge","El c\xe1lculo no convergi\xf3")
B.D8=new A.a("N\xe3o foi poss\xedvel atender a janela de press\xe3o com os tubos dispon\xedveis","Could not meet the pressure window with the available pipes","No se pudo cumplir la ventana de presi\xf3n con las tuber\xedas disponibles")
B.qc=new A.a("Linha principal n\xe3o consegue atender a press\xe3o das v\xe1lvulas","Mainline cannot meet the valve pressures","La l\xednea principal no puede cumplir la presi\xf3n de las v\xe1lvulas")
B.jL=new A.a("Nenhuma fonte de \xe1gua conectada","No water supply connected","Ninguna fuente de agua conectada")
B.vs=new A.a("Emissor acima da press\xe3o admiss\xedvel","Outlet above allowable pressure","Emisor por encima de la presi\xf3n admisible")
B.CK=new A.a("Emissor abaixo da press\xe3o admiss\xedvel","Outlet below allowable pressure","Emisor por debajo de la presi\xf3n admisible")
B.wq=new A.a("Press\xe3o acima da classe do tubo","Pressure above the pipe rating","Presi\xf3n por encima de la clase de la tuber\xeda")
B.AL=new A.a("Bomba fora da faixa de opera\xe7\xe3o","Pump outside its operating range","Bomba fuera del rango de operaci\xf3n")
B.rF=new A.a("Suc\xe7\xe3o da bomba acima do limite pr\xe1tico: instale a bomba mais perto do n\xedvel da \xe1gua ou use uma bomba submersa","Pump suction lift above the practical limit: install the pump closer to the water level or use a submersible pump","Succi\xf3n de la bomba por encima del l\xedmite pr\xe1ctico: instale la bomba m\xe1s cerca del nivel del agua o use una bomba sumergible")
B.zb=new A.a("Vaz\xe3o da fonte excedida","Supply flow exceeded","Caudal de la fuente excedido")
B.jM=new A.a("Press\xe3o m\xe1xima da fonte excedida","Supply maximum pressure exceeded","Presi\xf3n m\xe1xima de la fuente excedida")
B.mu=new A.a("Vaz\xe3o fora da faixa da v\xe1lvula","Flow outside the valve range","Caudal fuera del rango de la v\xe1lvula")
B.po=new A.a("V\xe1lvula n\xe3o encontrada","Valve not found","V\xe1lvula no encontrada")
B.zJ=new A.a("Press\xe3o insuficiente na v\xe1lvula","Insufficient pressure at the valve","Presi\xf3n insuficiente en la v\xe1lvula")
B.t0=new A.a("V\xe1lvula n\xe3o alcan\xe7ada pela linha principal","Valve not reached by the mainline","V\xe1lvula no alcanzada por la l\xednea principal")
B.w4=new A.a("Velocidade m\xe1xima excedida","Maximum velocity exceeded","Velocidad m\xe1xima excedida")
B.y5=new A.a("Zona sem tubos ou emissores","Zone without pipes or outlets","Zona sin tuber\xedas ni emisores")
B.xv=new A.a("Zonas conectadas entre si sem v\xe1lvula","Zones connected without a valve","Zonas conectadas entre s\xed sin v\xe1lvula")
B.js=new A.a("V\xe1lvula sem tubos de zona","Valve without zone pipes","V\xe1lvula sin tuber\xedas de zona")
B.A0=new A.a("Emissor sem modelo no cat\xe1logo","Outlet without a catalog model","Emisor sin modelo en el cat\xe1logo")
B.o9=new A.a("Fita sem modelo no cat\xe1logo","Tape without a catalog model","Cinta sin modelo en el cat\xe1logo")
B.zp=new A.a("Bomba sem modelo no cat\xe1logo","Pump without a catalog model","Bomba sin modelo en el cat\xe1logo")
B.qQ=new A.a("Acess\xf3rio sem modelo no cat\xe1logo","Device without a catalog model","Accesorio sin modelo en el cat\xe1logo")
B.xz=new A.a("Rede sem fonte de carga fixa","Network without a fixed-head source","Red sin fuente de carga fija")
B.ii=new A.a("P\xe1gina de dados ausente no DWG","Missing data page in DWG","P\xe1gina de datos ausente en el DWG")
B.ux=new A.a("OpenCADIrrigation \u2014 CAD para projeto de irriga\xe7\xe3o pressurizada.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lise de laterais passo a passo, dimensionamento por velocidade e por janela de press\xe3o com crit\xe9rio econ\xf4mico.\nRoda no navegador, sem instala\xe7\xe3o.","OpenCADIrrigation \u2014 CAD for pressurised irrigation design.\nHydraulic engine: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), step-by-step lateral analysis, velocity and pressure-window pipe sizing with economic trade-off.\nRuns in the browser, nothing to install.","OpenCADIrrigation \u2014 CAD para el dise\xf1o de riego presurizado.\nMotor hidr\xe1ulico: Hazen\u2011Williams / Darcy\u2011Weisbach, Global Gradient Algorithm (Todini\u2011Pilati), an\xe1lisis de laterales paso a paso, dimensionamiento por velocidad y por ventana de presi\xf3n con criterio econ\xf3mico.\nFunciona en el navegador, sin instalaci\xf3n.")
B.u2=new A.a("Vers\xe3o {v}","Version {v}","Versi\xf3n {v}")
B.Bf=new A.a("Site do projeto","Project site","Sitio del proyecto")
B.B4=new A.a("Arco (3 pontos)","Arc (3 points)","Arco (3 puntos)")
B.wf=new A.a("Spline (curva suave)","Spline (smooth curve)","Spline (curva suave)")
B.nD=new A.a("Hachura","Hatch","Sombreado")
B.ca=new A.a("S\xedmbolo","Symbol","S\xedmbolo")
B.nH=new A.a("Cota angular","Angular dimension","Cota angular")
B.CS=new A.a("Cota radial","Radial dimension","Cota radial")
B.i3=new A.a("Chamada (leader)","Leader","Llamada (leader)")
B.ck=new A.a("Rotacionar","Rotate","Rotar")
B.wv=new A.a("Espelhar","Mirror","Simetr\xeda")
B.bW=new A.a("Escalar","Scale","Escalar")
B.uj=new A.a("Deslocar (offset)","Offset","Desfasar (offset)")
B.kN=new A.a("Aparar","Trim","Recortar")
B.mB=new A.a("Estender","Extend","Alargar")
B.CY=new A.a("Cortar tubo","Cut pipe","Cortar tuber\xeda")
B.BG=new A.a("Perfil de eleva\xe7\xe3o","Elevation profile","Perfil de elevaci\xf3n")
B.x1=new A.a("Clique no in\xedcio, em um ponto do arco e no fim","Click start, a point on the arc, then end","Clic en el inicio, un punto del arco y el final")
B.on=new A.a("Clique nos pontos da curva; Enter termina","Click curve points; Enter ends","Clic en los puntos de la curva; Intro termina")
B.iL=new A.a("Clique nos v\xe9rtices da \xe1rea a hachurar; Enter fecha","Click the hatch boundary vertices; Enter closes","Clic en los v\xe9rtices del \xe1rea; Intro cierra")
B.t9=new A.a("Clique para inserir o s\xedmbolo (tipo e tamanho no painel)","Click to insert the symbol (kind and size in the panel)","Clic para insertar el s\xedmbolo (tipo y tama\xf1o en el panel)")
B.hA=new A.a("Clique no v\xe9rtice, nos dois lados e na posi\xe7\xe3o do arco","Click the vertex, both sides, then the arc position","Clic en el v\xe9rtice, los dos lados y la posici\xf3n del arco")
B.nU=new A.a("Clique no c\xedrculo (ou centro) e depois no ponto da cota","Click the circle (or centre) then the dimension point","Clic en el c\xedrculo (o centro) y luego en el punto de la cota")
B.hU=new A.a("Clique na ponta da seta e nos v\xe9rtices; Enter abre o texto","Click the arrow tip and the vertices; Enter opens the text","Clic en la punta de la flecha y los v\xe9rtices; Intro abre el texto")
B.Cp=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (Ctrl = copiar)","Selection: click base point, reference, then target (Ctrl = copy)","Selecci\xf3n: clic en el punto base, la referencia y el destino (Ctrl = copiar)")
B.ow=new A.a("Sele\xe7\xe3o: clique nos dois pontos da linha de espelho","Selection: click the two points of the mirror line","Selecci\xf3n: clic en los dos puntos del eje de simetr\xeda")
B.CE=new A.a("Sele\xe7\xe3o: clique no ponto base, na refer\xeancia e no destino (fator = raz\xe3o)","Selection: click base point, reference, then target (factor = ratio)","Selecci\xf3n: clic en el punto base, la referencia y el destino (factor = raz\xf3n)")
B.BR=new A.a("Clique no objeto e depois no lado do deslocamento (dist\xe2ncia no painel)","Click the object then the offset side (distance in the panel)","Clic en el objeto y luego en el lado del desfase (distancia en el panel)")
B.z3=new A.a("Clique na parte a remover; a sele\xe7\xe3o define as arestas de corte","Click the part to remove; the selection defines the cutting edges","Clic en la parte a quitar; la selecci\xf3n define las aristas de corte")
B.u5=new A.a("Clique perto da extremidade a estender at\xe9 a pr\xf3xima aresta","Click near the end to extend to the next edge","Clic cerca del extremo a alargar hasta la siguiente arista")
B.oS=new A.a("Clique no ponto do tubo/lateral onde cortar","Click the point of the pipe/lateral to cut","Clic en el punto de la tuber\xeda/lateral donde cortar")
B.ti=new A.a("Clique os pontos do caminho; Enter (ou Concluir) mostra o perfil na aba Perfil; Esc limpa a linha roxa","Click the path points; Enter (or Done) shows the profile in the Profile tab; Esc clears the purple line","Clic en los puntos del camino; Intro (o Terminar) muestra el perfil en la pesta\xf1a Perfil; Esc borra la l\xednea morada")
B.pt=new A.a("Modificar","Modify","Modificar")
B.B2=new A.a("Matriz (array)\u2026","Array\u2026","Matriz (array)\u2026")
B.D5=new A.a("Envelope do submain (laterais selecionadas)","Submain envelope (selected laterals)","Envolvente del submain (laterales seleccionadas)")
B.kW=new A.a("Matriz da sele\xe7\xe3o","Array of the selection","Matriz de la selecci\xf3n")
B.te=new A.a("Retangular","Rectangular","Rectangular")
B.qy=new A.a("Polar","Polar","Polar")
B.p1=new A.a("Linhas","Rows","Filas")
B.lA=new A.a("Colunas","Columns","Columnas")
B.ki=new A.a("Espa\xe7amento em X","Column spacing","Espaciamiento en X")
B.C9=new A.a("Espa\xe7amento em Y","Row spacing","Espaciamiento en Y")
B.wn=new A.a("\xc2ngulo da matriz (\xb0)","Array angle (\xb0)","\xc1ngulo de la matriz (\xb0)")
B.kd=new A.a("N\xfamero de itens","Number of items","N\xfamero de elementos")
B.xD=new A.a("Centro (X, Y)","Centre (X, Y)","Centro (X, Y)")
B.ij=new A.a("\xc2ngulo total (\xb0)","Total angle (\xb0)","\xc1ngulo total (\xb0)")
B.vC=new A.a("Rotacionar itens","Rotate items","Rotar elementos")
B.Av=new A.a("{n} itens selecionados","{n} selected items","{n} elementos seleccionados")
B.vX=new A.a("A camada est\xe1 bloqueada","The layer is locked","La capa est\xe1 bloqueada")
B.hE=new A.a("Nenhuma interse\xe7\xe3o encontrada","No intersection found","No se encontr\xf3 intersecci\xf3n")
B.CC=new A.a("Selecione uma ou mais laterais (sprayline ou fita)","Select one or more laterals (sprayline or tape)","Seleccione una o m\xe1s laterales (sprayline o cinta)")
B.C5=new A.a("Envelope calculado para {n} laterais (verde = posi\xe7\xe3o admiss\xedvel)","Envelope computed for {n} laterals (green = allowable position)","Envolvente calculada para {n} laterales (verde = posici\xf3n admisible)")
B.x6=new A.a("{n} itens criados","{n} items created","{n} elementos creados")
B.rb=new A.a("Marcar press\xe3o m\xedn/m\xe1x por zona","Mark min/max pressure per zone","Marcar presi\xf3n m\xedn/m\xe1x por zona")
B.iq=new A.a("Mapa base","Base map","Mapa base")
B.pK=new A.a("Nenhum","None","Ninguno")
B.jj=new A.a("Ruas (OpenStreetMap)","Streets (OpenStreetMap)","Calles (OpenStreetMap)")
B.wF=new A.a("Sat\xe9lite (Esri World Imagery)","Satellite (Esri World Imagery)","Sat\xe9lite (Esri World Imagery)")
B.ov=new A.a("Topogr\xe1fico (OpenTopoMap)","Topographic (OpenTopoMap)","Topogr\xe1fico (OpenTopoMap)")
B.zs=new A.a("Ruas claras (CARTO Voyager)","Light streets (CARTO Voyager)","Calles claras (CARTO Voyager)")
B.A2=new A.a("Ruas (Esri World Street Map)","Streets (Esri World Street Map)","Calles (Esri World Street Map)")
B.i1=new A.a("Topogr\xe1fico (Esri World Topo Map)","Topographic (Esri World Topo Map)","Topogr\xe1fico (Esri World Topo Map)")
B.pz=new A.a("Google Maps \u2013 mapa","Google Maps \u2013 roadmap","Google Maps \u2013 mapa")
B.kk=new A.a("Google Maps \u2013 sat\xe9lite","Google Maps \u2013 satellite","Google Maps \u2013 sat\xe9lite")
B.ie=new A.a("Google Maps \u2013 h\xedbrido (sat\xe9lite + vias)","Google Maps \u2013 hybrid (satellite + roads)","Google Maps \u2013 h\xedbrido (sat\xe9lite + v\xedas)")
B.k_=new A.a("Google Maps \u2013 relevo","Google Maps \u2013 terrain","Google Maps \u2013 relieve")
B.nj=new A.a("Personalizado (URL XYZ)","Custom (XYZ URL)","Personalizado (URL XYZ)")
B.Cf=new A.a("Chave da API do Google Maps\u2026","Google Maps API key\u2026","Clave de la API de Google Maps\u2026")
B.Dk=new A.a("URL do mapa personalizado\u2026","Custom map URL\u2026","URL del mapa personalizado\u2026")
B.tp=new A.a("Chave da API do Google Maps","Google Maps API key","Clave de la API de Google Maps")
B.it=new A.a("Os mapas do Google s\xe3o servidos pela Map Tiles API da Google Maps Platform com a sua pr\xf3pria chave: o uso \xe9 contabilizado (e cobrado al\xe9m da cota gratuita) na sua conta Google Cloud.","Google maps come from the Map Tiles API of the Google Maps Platform with your own key: usage is counted (and billed beyond the free quota) on your Google Cloud account.","Los mapas de Google los sirve la Map Tiles API de Google Maps Platform con su propia clave: el uso se contabiliza (y se cobra m\xe1s all\xe1 de la cuota gratuita) en su cuenta de Google Cloud.")
B.Dn=new A.a('1. No Google Cloud Console, crie um projeto e ative a "Map Tiles API".   2. Em Credenciais, crie uma chave de API.   3. Restrinja a chave aos sites (referenciadores HTTP) em que usa o app.','1. In the Google Cloud Console create a project and enable the "Map Tiles API".   2. Under Credentials create an API key.   3. Restrict the key to the sites (HTTP referrers) where you use the app.','1. En Google Cloud Console cree un proyecto y active la "Map Tiles API".   2. En Credenciales cree una clave de API.   3. Restrinja la clave a los sitios (referentes HTTP) donde usa la app.')
B.vF=new A.a("Abrir Google Cloud Console","Open Google Cloud Console","Abrir Google Cloud Console")
B.tV=new A.a("Como obter a chave","How to get a key","C\xf3mo obtener la clave")
B.pT=new A.a("Chave da API","API key","Clave de la API")
B.l8=new A.a("A chave fica guardada s\xf3 neste navegador e \xe9 enviada apenas ao Google.","The key is kept in this browser only and sent to Google only.","La clave se guarda solo en este navegador y se env\xeda \xfanicamente a Google.")
B.uR=new A.a("Remover chave","Remove key","Quitar clave")
B.rH=new A.a("Google Maps: informe a chave da API em Ver \u2192 Mapa base","Google Maps: enter the API key under View \u2192 Base map","Google Maps: indique la clave de la API en Ver \u2192 Mapa base")
B.A7=new A.a("Google Maps: {e}","Google Maps: {e}","Google Maps: {e}")
B.xw=new A.a("Mapa base personalizado","Custom base map","Mapa base personalizado")
B.Az=new A.a("Endere\xe7o dos tiles no padr\xe3o XYZ (Web Mercator): um servidor pr\xf3prio, um provedor com chave ou um WMTS.","Address of the tiles in the XYZ pattern (Web Mercator): your own server, a keyed provider or a WMTS.","Direcci\xf3n de los tiles en el patr\xf3n XYZ (Web Mercator): un servidor propio, un proveedor con clave o un WMTS.")
B.Bo=new A.a("Modelo de URL","URL template","Plantilla de URL")
B.oh=new A.a("Marcadores: {z} zoom, {x} coluna, {y} linha ({-y} para TMS), {s} subdom\xednio a/b/c. A chave do provedor, se houver, vai na pr\xf3pria URL.","Placeholders: {z} zoom, {x} column, {y} row ({-y} for TMS), {s} subdomain a/b/c. The provider key, if any, goes in the URL itself.","Marcadores: {z} zoom, {x} columna, {y} fila ({-y} para TMS), {s} subdominio a/b/c. La clave del proveedor, si la hay, va en la propia URL.")
B.kF=new A.a("A URL precisa come\xe7ar com http(s):// e conter {z}, {x} e {y}","The URL must start with http(s):// and contain {z}, {x} and {y}","La URL debe empezar con http(s):// y contener {z}, {x} e {y}")
B.nR=new A.a("Defina a georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia) para mostrar o mapa base","Set the georeference (File \u2192 Georeference) to show the base map","Defina la georreferencia (Archivo \u2192 Georreferencia) para mostrar el mapa base")
B.ry=new A.a("Al\xe7as de edi\xe7\xe3o","Edit grips","Pinzamientos de edici\xf3n")
B.wB=new A.a("Envelope de posi\xe7\xe3o do submain","Allowable submain position","Posici\xf3n admisible del submain")
B.mD=new A.a("Camada atual","Current layer","Capa actual")
B.la=new A.a("Bloquear","Lock","Bloquear")
B.zM=new A.a("Nova camada","New layer","Nueva capa")
B.rn=new A.a("Renomear","Rename","Renombrar")
B.iJ=new A.a("Excluir camada (itens v\xe3o para DRAWING)","Delete layer (items move to DRAWING)","Eliminar capa (los elementos van a DRAWING)")
B.lF=new A.a("Cor","Colour","Color")
B.k5=new A.a("Nome da camada","Layer name","Nombre de la capa")
B.Aw=new A.a("J\xe1 existe uma camada com esse nome","A layer with that name already exists","Ya existe una capa con ese nombre")
B.oe=new A.a("Clique no olho para mostrar/ocultar, no cadeado para bloquear, na cor para alterar; duplo clique renomeia; o c\xedrculo marca a camada atual.","Click the eye to show/hide, the padlock to lock, the colour to change it; double-click renames; the dot marks the current layer.","Clic en el ojo para mostrar/ocultar, en el candado para bloquear, en el color para cambiarlo; doble clic renombra; el c\xedrculo marca la capa actual.")
B.lX=new A.a("Edi\xe7\xe3o em lote ({n} {type})","Batch edit ({n} {type})","Edici\xf3n en lote ({n} {type})")
B.wI=new A.a("(valores diferentes)","(mixed values)","(valores distintos)")
B.um=new A.a("Tamanho (m)","Size (m)","Tama\xf1o (m)")
B.kR=new A.a("\xc2ngulo da hachura (\xb0)","Hatch angle (\xb0)","\xc1ngulo del sombreado (\xb0)")
B.k8=new A.a("Espa\xe7amento da hachura (m)","Hatch spacing (m)","Espaciamiento del sombreado (m)")
B.nJ=new A.a("Preenchimento s\xf3lido","Solid fill","Relleno s\xf3lido")
B.q3=new A.a("Opacidade","Opacity","Opacidad")
B.oc=new A.a("Largura (m)","Width (m)","Ancho (m)")
B.mS=new A.a("Altura (m)","Height (m)","Alto (m)")
B.k4=new A.a("Emissores por planta (0 = padr\xe3o do projeto)","Emitters per plant (0 = project default)","Emisores por planta (0 = valor del proyecto)")
B.o7=new A.a("Balan\xe7o h\xeddrico (ETo \xd7 Kc, solo)","Water balance (ETo \xd7 Kc, soil)","Balance h\xeddrico (ETo \xd7 Kc, suelo)")
B.m6=new A.a("ETo (mm/dia)","ETo (mm/day)","ETo (mm/d\xeda)")
B.oA=new A.a("Kc","Kc","Kc")
B.vf=new A.a("Kc por cultura (FAO-56)","Kc by crop (FAO-56)","Kc por cultivo (FAO-56)")
B.rh=new A.a("\xc1gua dispon\xedvel (mm/m)","Available water (mm/m)","Agua disponible (mm/m)")
B.xN=new A.a("Profundidade radicular (m)","Root depth (m)","Profundidad radicular (m)")
B.rQ=new A.a("Fra\xe7\xe3o de esgotamento (MAD)","Allowed depletion (MAD)","Fracci\xf3n de agotamiento (MAD)")
B.tU=new A.a("Fra\xe7\xe3o molhada","Wetted fraction","Fracci\xf3n mojada")
B.q2=new A.a("Espa\xe7amento entre plantas (m)","Plant spacing (m)","Espaciamiento entre plantas (m)")
B.m7=new A.a("Espa\xe7amento entre linhas (m)","Row spacing (m)","Espaciamiento entre hileras (m)")
B.Bp=new A.a("ETc (mm/dia)","ETc (mm/day)","ETc (mm/d\xeda)")
B.hx=new A.a("Intervalo (dias)","Interval (days)","Intervalo (d\xedas)")
B.yc=new A.a("Dist\xe2ncia do offset","Offset distance","Distancia del desfase")
B.A1=new A.a("Manter original (copiar)","Keep original (copy)","Mantener original (copiar)")
B.Bg=new A.a("Manter original","Keep source","Mantener original")
B.AR=new A.a("Dividir tubo ao inserir sobre ele","Split pipe when inserted on it","Dividir tuber\xeda al insertar sobre ella")
B.z9=new A.a("Curva fechada","Closed curve","Curva cerrada")
B.tP=new A.a("\xc2ngulo (\xb0)","Angle (\xb0)","\xc1ngulo (\xb0)")
B.w2=new A.a("Texto da chamada","Leader text","Texto de la llamada")
B.ju=new A.a("Raio do arco de cota (m)","Dimension arc radius (m)","Radio del arco de cota (m)")
B.iM=new A.a("Camada bloqueada: edi\xe7\xe3o desativada","Locked layer: editing disabled","Capa bloqueada: edici\xf3n desactivada")
B.uU=new A.a("Vaz\xe3o de lavagem no fim (0 = autom\xe1tica)","End flushing flow (0 = automatic)","Caudal de lavado al final (0 = autom\xe1tico)")
B.Cm=new A.a("Envelope do submain","Submain envelope","Envolvente del submain")
B.w3=new A.a("Melhor posi\xe7\xe3o: {f} % do in\xedcio (\u0394p {v})","Best position: {f} % from the start (\u0394p {v})","Mejor posici\xf3n: {f} % desde el inicio (\u0394p {v})")
B.mn=new A.a("Admiss\xedvel: {a} % a {b} %","Allowable: {a} % to {b} %","Admisible: {a} % a {b} %")
B.yx=new A.a("Nenhuma posi\xe7\xe3o atende \xe0 janela de press\xe3o","No position meets the pressure window","Ninguna posici\xf3n cumple la ventana de presi\xf3n")
B.qZ=new A.a("Seta norte","North arrow","Flecha norte")
B.jy=new A.a("\xc1rvore","Tree","\xc1rbol")
B.tw=new A.a("Edifica\xe7\xe3o","Building","Edificaci\xf3n")
B.c2=new A.a("Reservat\xf3rio","Tank","Dep\xf3sito")
B.yY=new A.a("Caixa de v\xe1lvula","Valve box","Arqueta de v\xe1lvula")
B.AT=new A.a("Casa de bombas","Pump house","Caseta de bombeo")
B.wH=new A.a("Port\xe3o","Gate","Port\xf3n")
B.BX=new A.a("Esta\xe7\xe3o de filtragem","Filter station","Estaci\xf3n de filtrado")
B.cK=new A.a("Caf\xe9","Coffee","Caf\xe9")
B.bL=new A.a("Banana","Banana","Banano")
B.ph=new A.a("Manga","Mango","Mango")
B.xX=new A.a("Ma\xe7\xe3","Apple","Manzana")
B.cp=new A.a("Tomate","Tomato","Tomate")
B.bz=new A.a("Milho","Maize","Ma\xedz")
B.bK=new A.a("Cana-de-a\xe7\xfacar","Sugarcane","Ca\xf1a de az\xfacar")
B.c3=new A.a("Hortali\xe7as","Vegetables","Hortalizas")
B.bF=new A.a("Grama","Turf","C\xe9sped")
B.qt=new A.a("Pastagem","Pasture","Pasto")
B.lf=new A.a("Personalizado","Custom","Personalizado")
B.zO=new A.a("Lavagem (flushing)","Flushing","Lavado (flushing)")
B.uV=new A.a("Golpe de ar\xedete","Water hammer","Golpe de ariete")
B.Aq=new A.a("Agronomia","Agronomy","Agronom\xeda")
B.Dp=new A.a("Programa\xe7\xe3o","Schedule","Programaci\xf3n")
B.cf=new A.a("Perfil","Profile","Perfil")
B.cF=new A.a("C\xf3digo","Code","C\xf3digo")
B.yg=new A.a("V alvo (m/s)","Target V (m/s)","V objetivo (m/s)")
B.lv=new A.a("Celeridade","Celerity","Celeridad")
B.C0=new A.a("Sobrepress\xe3o","Surge","Sobrepresi\xf3n")
B.ox=new A.a("P m\xe1x regime","Max steady P","P m\xe1x r\xe9gimen")
B.pU=new A.a("P total","Total P","P total")
B.zY=new A.a("2L/a (s)","2L/a (s)","2L/a (s)")
B.kz=new A.a("AFD","RAW","ARA")
B.C4=new A.a("Intervalo (d)","Interval (d)","Intervalo (d)")
B.zt=new A.a("L\xedquida/evento","Net/event","Neta/evento")
B.wC=new A.a("Bruta/evento","Gross/event","Bruta/evento")
B.pB=new A.a("Horas/evento","Hours/event","Horas/evento")
B.us=new A.a("CU sobrep. %","Overlap CU %","CU solap. %")
B.vb=new A.a("Zonas","Zones","Zonas")
B.mX=new A.a("Fim","End","Fin")
B.zF=new A.a("Dist\xe2ncia","Distance","Distancia")
B.hS=new A.a("Use a ferramenta Perfil (PR) ou selecione um tubo/lateral para ver o perfil do terreno","Use the Profile tool (PR) or select a pipe/lateral to see the ground profile","Use la herramienta Perfil (PR) o seleccione una tuber\xeda/lateral para ver el perfil del terreno")
B.xp=new A.a("Declividade m\xe9dia {s} %  \xb7  desn\xedvel {d} m  \xb7  comprimento {l}","Mean slope {s} %  \xb7  rise {d} m  \xb7  length {l}","Pendiente media {s} %  \xb7  desnivel {d} m  \xb7  longitud {l}")
B.p6=new A.a("Luva","Coupler","Manguito")
B.Am=new A.a("Cotovelo 90\xb0","Elbow 90\xb0","Codo 90\xb0")
B.ve=new A.a("Cotovelo 45\xb0","Elbow 45\xb0","Codo 45\xb0")
B.rO=new A.a("T\xea","Tee","Te")
B.lK=new A.a("Cruzeta","Cross","Cruz")
B.ny=new A.a("Redu\xe7\xe3o","Reducer","Reducci\xf3n")
B.Ay=new A.a("Tamp\xe3o","End cap","Tap\xf3n")
B.kG=new A.a("Adaptador","Adapter","Adaptador")
B.B3=new A.a("Conector inicial de lateral","Lateral take-off","Conector inicial de lateral")
B.j4=new A.a("Final de linha","Line end","Final de l\xednea")
B.jH=new A.a("Haste / tubo de subida","Riser","Tubo de subida")
B.bB=new A.a("Conex\xf5es","Fittings","Conexiones")
B.lT=new A.a("Conectores de lateral","Lateral connectors","Conectores de lateral")
B.oi=new A.a("Hastes e tubos de subida","Risers","Tubos de subida")
B.tq=new A.a("Tipo","Kind","Tipo")
B.zW=new A.a("DN 2","Size 2","DN 2")
B.n4=new A.a("Fornecedor","Supplier","Proveedor")
B.xO=new A.a("+ Adicionar","+ Add","+ A\xf1adir")
B.mf=new A.a("Duplicar","Duplicate","Duplicar")
B.CJ=new A.a("Importar (JSON/CSV)\u2026","Import (JSON/CSV)\u2026","Importar (JSON/CSV)\u2026")
B.BK=new A.a("Exportar JSON","Export JSON","Exportar JSON")
B.l_=new A.a("Exportar CSV desta aba","Export CSV of this tab","Exportar CSV de esta pesta\xf1a")
B.i0=new A.a("Restaurar padr\xe3o","Restore default","Restaurar predeterminado")
B.wL=new A.a("Usar como padr\xe3o para novos projetos","Use as default for new projects","Usar como predeterminado en proyectos nuevos")
B.zA=new A.a("JSON no formato do cat\xe1logo (exportado daqui) ou CSV com cabe\xe7alho; colunas reconhecidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tubos); id, name, kind, sizeMm, size2Mm, cost (conex\xf5es); id, name, idMm, spacing, qLph, headM, x, cost (fitas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emissores).","JSON in the catalog format (exported from here) or CSV with a header; recognised columns: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (pipes); id, name, kind, sizeMm, size2Mm, cost (fittings); id, name, idMm, spacing, qLph, headM, x, cost (tapes); id, name, kind, sizeMm, k, n, maxQm3h, cost (valves); id, name, points (Q@H;\u2026), eff, cost (pumps); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (outlets).","JSON en el formato del cat\xe1logo (exportado desde aqu\xed) o CSV con encabezado; columnas reconocidas: id, name, nominalMm, idMm, material, c, ratingM, wallMm, cost, usage, supplier, code (tuber\xedas); id, name, kind, sizeMm, size2Mm, cost (conexiones); id, name, idMm, spacing, qLph, headM, x, cost (cintas); id, name, kind, sizeMm, k, n, maxQm3h, cost (v\xe1lvulas); id, name, points (Q@H;\u2026), eff, cost (bombas); id, name, kind, nozzle, qLph, headM, x, radiusM, cost (emisores).")
B.D_=new A.a('Remover "{n}" do cat\xe1logo? Itens do projeto que o usam ficar\xe3o sem modelo.','Remove "{n}" from the catalog? Project items using it will lose their model.','\xbfQuitar "{n}" del cat\xe1logo? Los elementos del proyecto que lo usan quedar\xe1n sin modelo.')
B.vd=new A.a("em uso: {n}","in use: {n}","en uso: {n}")
B.k2=new A.a("Cat\xe1logo: {n} itens importados","Catalog: {n} items imported","Cat\xe1logo: {n} elementos importados")
B.xh=new A.a("Cat\xe1logo salvo como padr\xe3o para novos projetos","Catalog saved as default for new projects","Cat\xe1logo guardado como predeterminado para proyectos nuevos")
B.xr=new A.a("Cat\xe1logo padr\xe3o restaurado","Default catalog restored","Cat\xe1logo predeterminado restaurado")
B.rA=new A.a("LP sem solu\xe7\xe3o com os tubos habilitados (m\xe9todo guloso usado)","LP infeasible with the enabled pipes (greedy method used)","LP sin soluci\xf3n con las tuber\xedas habilitadas (se us\xf3 el m\xe9todo voraz)")
B.An=new A.a("Conex\xe3o sem item no cat\xe1logo","Fitting without a catalog item","Conexi\xf3n sin elemento en el cat\xe1logo")
B.zj=new A.a("Golpe de ar\xedete acima da classe do tubo","Water hammer above the pipe class","Golpe de ariete por encima de la clase de la tuber\xeda")
B.A4=new A.a("Turno sem \xe1rea irrigada: dura\xe7\xe3o mantida","System flow without an irrigated area: duration kept","Turno sin \xe1rea regada: duraci\xf3n mantenida")
B.yl=new A.a("Programa\xe7\xe3o excede 24 h no dia","Schedule exceeds 24 h in a day","La programaci\xf3n supera 24 h en el d\xeda")
B.tG=new A.a("Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, imagens)\u2026","Import (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, images)\u2026","Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, im\xe1genes)\u2026")
B.ye=new A.a("Pontos: {n} cotas importadas{geo}","Points: {n} spot heights imported{geo}","Puntos: {n} cotas importadas{geo}")
B.u7=new A.a(u.h,"SHP: {r} records, {n} entities ({crs})",u.h)
B.yA=new A.a("Imagem {w}\xd7{h} px inserida na vista (ajuste com as al\xe7as ou Georreferenciar imagem)","Image {w}\xd7{h} px placed in the view (adjust with grips or Georeference image)","Imagen {w}\xd7{h} px insertada en la vista (ajuste con las pinzas o Georreferenciar imagen)")
B.z_=new A.a("Imagem georreferenciada {w}\xd7{h} px ({crs})","Georeferenced image {w}\xd7{h} px ({crs})","Imagen georreferenciada {w}\xd7{h} px ({crs})")
B.jK=new A.a("resposta inv\xe1lida do servidor de eleva\xe7\xe3o","invalid answer from the elevation server","respuesta no v\xe1lida del servidor de elevaci\xf3n")
B.D0=new A.a("bloco de eleva\xe7\xe3o inv\xe1lido recebido do servidor","invalid elevation tile received from the server","tesela de elevaci\xf3n no v\xe1lida recibida del servidor")
B.zr=new A.a("o servidor devolveu um n\xfamero de eleva\xe7\xf5es diferente do pedido","the server returned a different number of elevations than requested","el servidor devolvi\xf3 un n\xfamero de elevaciones distinto del pedido")
B.jD=new A.a("Arquivo de pontos vazio","Empty points file","Archivo de puntos vac\xedo")
B.xa=new A.a("N\xe3o foi poss\xedvel identificar as colunas X, Y (e Z)","Could not identify the X, Y (and Z) columns","No se pudieron identificar las columnas X, Y (y Z)")
B.rf=new A.a("Arquivo SHP inv\xe1lido","Invalid SHP file","Archivo SHP no v\xe1lido")
B.qR=new A.a("O ZIP n\xe3o cont\xe9m um arquivo .shp","The ZIP has no .shp file","El ZIP no contiene un archivo .shp")
B.w9=new A.a("O ZIP n\xe3o cont\xe9m imagem","The ZIP has no image","El ZIP no contiene imagen")
B.qO=new A.a("Imagem n\xe3o reconhecida","Image not recognised","Imagen no reconocida")
B.rv=new A.a("Georreferenciar imagem selecionada\u2026","Georeference selected image\u2026","Georreferenciar imagen seleccionada\u2026")
B.Ao=new A.a("Georreferenciar imagem","Georeference image","Georreferenciar imagen")
B.AJ=new A.a("Informe as coordenadas locais (m) do canto inferior esquerdo, o tamanho real e a rota\xe7\xe3o da imagem.","Enter the local coordinates (m) of the bottom-left corner, the real size and the rotation of the image.","Indique las coordenadas locales (m) de la esquina inferior izquierda, el tama\xf1o real y la rotaci\xf3n de la imagen.")
B.ja=new A.a("Manter propor\xe7\xe3o","Keep aspect ratio","Mantener proporci\xf3n")
B.iN=new A.a("M\xe9todo de dimensionamento","Sizing method","M\xe9todo de dimensionamiento")
B.uH=new A.a("Programa\xe7\xe3o linear (LP: custo de tubo + energia + topografia)","Linear programming (LP: pipe cost + energy + topography)","Programaci\xf3n lineal (LP: costo de tuber\xeda + energ\xeda + topograf\xeda)")
B.zG=new A.a("Guloso (velocidade \u2192 janela de press\xe3o \u2192 economia)","Greedy (velocity \u2192 pressure window \u2192 economics)","Voraz (velocidad \u2192 ventana de presi\xf3n \u2192 econom\xeda)")
B.wP=new A.a("N\xba m\xe1x. de di\xe2metros por lateral","Max. sizes per lateral","N.\xba m\xe1x. de di\xe1metros por lateral")
B.nK=new A.a("N\xba m\xe1x. de di\xe2metros por tubo principal","Max. sizes per mainline pipe","N.\xba m\xe1x. de di\xe1metros por tuber\xeda principal")
B.wy=new A.a("Emissores por planta (EU)","Emitters per plant (EU)","Emisores por planta (EU)")
B.lk=new A.a("N\xf3s de emissores por lateral (m\xe1x.)","Emitter nodes per lateral (max.)","Nudos de emisores por lateral (m\xe1x.)")
B.xq=new A.a("Varia\xe7\xe3o m\xe1x. de press\xe3o na zona (%; 0 = s\xf3 toler\xe2ncia)","Max. zone pressure variation (%; 0 = tolerance only)","Variaci\xf3n m\xe1x. de presi\xf3n en la zona (%; 0 = solo tolerancia)")
B.jz=new A.a("Lavagem e golpe de ar\xedete","Flushing and water hammer","Lavado y golpe de ariete")
B.zK=new A.a("Velocidade de lavagem (m/s)","Flushing velocity (m/s)","Velocidad de lavado (m/s)")
B.oH=new A.a("Press\xe3o m\xedn. no fim da fita (m)","Min. pressure at the tape end (m)","Presi\xf3n m\xedn. al final de la cinta (m)")
B.BV=new A.a("Verificar golpe de ar\xedete (classe do tubo)","Check water hammer (pipe class)","Verificar golpe de ariete (clase de tuber\xeda)")
B.iI=new A.a("Tempo de fechamento de v\xe1lvula (s; 0 = instant\xe2neo)","Valve closure time (s; 0 = instantaneous)","Tiempo de cierre de v\xe1lvula (s; 0 = instant\xe1neo)")
B.kb=new A.a("Selecionar conex\xf5es automaticamente","Select fittings automatically","Seleccionar conexiones autom\xe1ticamente")
B.pP=new A.a("Comprimento da barra de tubo (m; luvas por barra, 0 = nenhuma)","Pipe stick length (m; couplers per stick, 0 = none)","Longitud de la barra de tuber\xeda (m; manguitos por barra, 0 = ninguno)")
B.wb=new A.a("Selecionar bomba\u2026","Select pump\u2026","Seleccionar bomba\u2026")
B.ko=new A.a("Vista 3D do terreno\u2026","3D terrain view\u2026","Vista 3D del terreno\u2026")
B.tv=new A.a("Sele\xe7\xe3o autom\xe1tica de bomba","Automatic pump selection","Selecci\xf3n autom\xe1tica de bomba")
B.no=new A.a("Ponto de trabalho: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}","Duty: {q} at {h}  \xb7  static lift \u2248 {s}","Punto de trabajo: {q} a {h}  \xb7  altura est\xe1tica \u2248 {s}")
B.j7=new A.a("Bombas do cat\xe1logo ordenadas por adequa\xe7\xe3o e custo (compra + 5 anos de energia)","Catalog pumps ranked by suitability and cost (purchase + 5 years of energy)","Bombas del cat\xe1logo ordenadas por idoneidad y costo (compra + 5 a\xf1os de energ\xeda)")
B.uc=new A.a("H na vaz\xe3o","H at duty","H al caudal")
B.pj=new A.a("Margem","Margin","Margen")
B.vy=new A.a("Pot\xeancia","Power","Potencia")
B.l4=new A.a("Em paralelo","In parallel","En paralelo")
B.vp=new A.a("Inserir na fonte","Insert at the supply","Insertar en la fuente")
B.BM=new A.a("Aplicar \xe0 bomba existente","Apply to the existing pump","Aplicar a la bomba existente")
B.tl=new A.a("Execute o projeto com uma fonte de \xe1gua de press\xe3o calculada para obter o ponto de trabalho.","Run the design with a calculated-pressure water supply to get the duty point.","Ejecute el dise\xf1o con una fuente de agua de presi\xf3n calculada para obtener el punto de trabajo.")
B.iG=new A.a("insuficiente","insufficient","insuficiente")
B.zg=new A.a("suc\xe7\xe3o excessiva","suction lift too high","succi\xf3n excesiva")
B.hH=new A.a("Bomba {n} aplicada; execute o projeto novamente","Pump {n} applied; run the design again","Bomba {n} aplicada; vuelva a ejecutar el dise\xf1o")
B.wV=new A.a("Vista 3D do terreno (DEM)","3D terrain view (DEM)","Vista 3D del terreno (MDT)")
B.rN=new A.a("Exagero vertical","Vertical exaggeration","Exageraci\xf3n vertical")
B.rI=new A.a("Arraste para girar; roda do mouse para aproximar. Tubos e laterais s\xe3o drapejados sobre o terreno.","Drag to rotate; mouse wheel zooms. Pipes and laterals are draped on the terrain.","Arrastre para girar; rueda del rat\xf3n para acercar. Las tuber\xedas y laterales se drapean sobre el terreno.")
B.o5=new A.a("Sem dados de eleva\xe7\xe3o: desenhe curvas de n\xedvel ou cotas, ou importe topografia.","No elevation data: draw contours or spot heights, or import a survey.","Sin datos de elevaci\xf3n: dibuje curvas de nivel o cotas, o importe topograf\xeda.")
B.wi=new A.a("Eleva\xe7\xe3o {a} a {b} m","Elevation {a} to {b} m","Elevaci\xf3n {a} a {b} m")
B.kB=new A.a("Projetos recentes","Recent projects","Proyectos recientes")
B.At=new A.a("(nenhum)","(none)","(ninguno)")
B.xd=new A.a("Hist\xf3rico de vers\xf5es\u2026","Version history\u2026","Historial de versiones\u2026")
B.rR=new A.a("Salvar automaticamente no navegador","Autosave in the browser","Guardar autom\xe1ticamente en el navegador")
B.o6=new A.a("Recuperar projeto","Recover project","Recuperar proyecto")
B.x4=new A.a("Foram encontrados projetos salvos automaticamente que n\xe3o foram salvos em arquivo. Deseja recuper\xe1-los?","Autosaved projects that were never saved to a file were found. Recover them?","Se encontraron proyectos guardados autom\xe1ticamente que no se guardaron en archivo. \xbfDesea recuperarlos?")
B.rk=new A.a("Recuperar","Recover","Recuperar")
B.m8=new A.a("Descartar","Discard","Descartar")
B.ob=new A.a("Depois","Later","Despu\xe9s")
B.r_=new A.a("{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)","{name} \u2014 {when} ({kb} kB)")
B.BI=new A.a("{n} projetos recuperados","{n} projects recovered","{n} proyectos recuperados")
B.Ae=new A.a('Vers\xf5es de "{name}"','Versions of "{name}"','Versiones de "{name}"')
B.Be=new A.a("Nenhuma vers\xe3o guardada ainda: cada Salvar cria uma vers\xe3o (at\xe9 10, no navegador).","No versions kept yet: every Save records a version (up to 10, in the browser).","A\xfan no hay versiones: cada Guardar crea una versi\xf3n (hasta 10, en el navegador).")
B.ro=new A.a("Restaurar","Restore","Restaurar")
B.xJ=new A.a("v{v} \u2014 {when}","v{v} \u2014 {when}","v{v} \u2014 {when}")
B.pR=new A.a("Vers\xe3o {v} restaurada","Version {v} restored","Versi\xf3n {v} restaurada")
B.zC=new A.a("Turnos","System flows","Turnos")
B.A5=new A.a("Programa\xe7\xe3o do controlador","Controller programme","Programaci\xf3n del controlador")
B.r8=new A.a("Aplicar dura\xe7\xf5es calculadas aos turnos","Apply computed durations to the flows","Aplicar duraciones calculadas a los turnos")
B.Ac=new A.a("Exportar programa\xe7\xe3o (CSV)","Export programme (CSV)","Exportar programaci\xf3n (CSV)")
B.xE=new A.a("Dias","Days","D\xedas")
B.Cx=new A.a("In\xedcio do dia (h)","Day start (h)","Inicio del d\xeda (h)")
B.pr=new A.a("Usar os hor\xe1rios de in\xedcio dos turnos","Use the flows' own start hours","Usar las horas de inicio de los turnos")
B.Cj=new A.a("M\xe1ximo de horas em um dia: {h}","Maximum hours in one day: {h}","M\xe1ximo de horas en un d\xeda: {h}")
B.j0=new A.a("Execute o projeto para calcular as dura\xe7\xf5es a partir das \xe1reas irrigadas.","Run the design to compute durations from the irrigated areas.","Ejecute el dise\xf1o para calcular las duraciones a partir de las \xe1reas regadas.")
B.D4=new A.a("{name}: {h} h por evento","{name}: {h} h per event","{name}: {h} h por evento")
B.yP=new A.a("Edi\xe7\xe3o (alias \u23ce)","Editing (alias \u23ce)","Edici\xf3n (alias \u23ce)")
B.hD=new A.a("Remover v\xe9rtice (Ctrl + clique na al\xe7a)","Remove vertex (Ctrl + click on a grip)","Quitar v\xe9rtice (Ctrl + clic en la pinza)")
B.AY=new A.a("Inserir v\xe9rtice (arrastar a al\xe7a do meio do segmento)","Insert vertex (drag the segment midpoint grip)","Insertar v\xe9rtice (arrastrar la pinza del medio del segmento)")
B.va=new A.a("Toque: pin\xe7a para zoom, dois dedos para mover, um dedo para desenhar","Touch: pinch to zoom, two fingers to pan, one finger to draw","T\xe1ctil: pellizco para zoom, dos dedos para mover, un dedo para dibujar")
B.Du=new A.a("Piv\xf4 central / lateral m\xf3vel","Centre pivot / linear move","Pivote central / lateral de avance")
B.iB=new A.a("Clique o ponto do piv\xf4 (entrada de \xe1gua, sobre a linha principal) e depois o fim da lateral; Esc cancela","Click the pivot point (water inlet, on the mainline) and then the end of the span; Esc cancels","Clic en el punto del pivote (entrada de agua, sobre la l\xednea principal) y luego el fin de la lateral; Esc cancela")
B.lW=new A.a("Alinhar por 2 pontos","Align by 2 points","Alinear por 2 puntos")
B.oo=new A.a("Com a imagem/objetos selecionados: clique o ponto A na origem, onde A deve ficar, o ponto B na origem e onde B deve ficar","With the image/objects selected: click point A on the source, where A must go, point B on the source and where B must go","Con la imagen/objetos seleccionados: clic en el punto A de origen, d\xf3nde debe quedar A, el punto B de origen y d\xf3nde debe quedar B")
B.yv=new A.a("Ponto A na imagem/desenho a alinhar","Point A on the image/drawing to align","Punto A en la imagen/dibujo a alinear")
B.kn=new A.a("Onde o ponto A deve ficar (destino)","Where point A must go (target)","D\xf3nde debe quedar el punto A (destino)")
B.C1=new A.a("Ponto B na imagem/desenho a alinhar","Point B on the image/drawing to align","Punto B en la imagen/dibujo a alinear")
B.Dv=new A.a("Onde o ponto B deve ficar (define escala e rota\xe7\xe3o)","Where point B must go (sets scale and rotation)","D\xf3nde debe quedar el punto B (define escala y rotaci\xf3n)")
B.iQ=new A.a("Manter a escala (s\xf3 mover e girar)","Keep the scale (move and rotate only)","Mantener la escala (solo mover y girar)")
B.oO=new A.a("Alinhado: escala \xd7{s}, rota\xe7\xe3o {r}\xb0","Aligned: scale \xd7{s}, rotation {r}\xb0","Alineado: escala \xd7{s}, rotaci\xf3n {r}\xb0")
B.B6=new A.a("Selecione antes a imagem ou os objetos a alinhar","Select the image or the objects to align first","Seleccione antes la imagen o los objetos a alinear")
B.ik=new A.a("Caminho do perfil removido do desenho","Profile path removed from the drawing","Camino del perfil quitado del dibujo")
B.c5=new A.a("Eleva\xe7\xe3o","Elevation","Elevaci\xf3n")
B.iY=new A.a("Eleva\xe7\xe3o da curva de n\xedvel","Contour elevation","Elevaci\xf3n de la curva de nivel")
B.jx=new A.a("Eleva\xe7\xe3o da cota","Spot height elevation","Elevaci\xf3n de la cota")
B.cc=new A.a("Intervalo entre curvas (m)","Contour interval (m)","Intervalo entre curvas (m)")
B.zD=new A.a("Pr\xf3xima curva: somar o intervalo","Next contour: add the interval","Pr\xf3xima curva: sumar el intervalo")
B.nc=new A.a("Perguntar a eleva\xe7\xe3o ao terminar cada curva/cota","Ask for the elevation after each contour/spot","Preguntar la elevaci\xf3n al terminar cada curva/cota")
B.pL=new A.a('Uma curva de n\xedvel liga pontos de mesma altitude. Informe a altitude desta curva. Com "somar o intervalo", a pr\xf3xima curva j\xe1 vem com a eleva\xe7\xe3o seguinte.','A contour joins points of the same altitude. Enter the altitude of this line. With "add the interval", the next contour comes with the following elevation.','Una curva de nivel une puntos de la misma altitud. Indique la altitud de esta curva. Con "sumar el intervalo", la pr\xf3xima curva ya viene con la elevaci\xf3n siguiente.')
B.pM=new A.a("Cota de ponto: altitude do terreno neste lugar (po\xe7o, casa de bombas, canto do talh\xe3o).","Spot height: ground altitude at this place (well, pump house, field corner).","Cota de punto: altitud del terreno en este lugar (pozo, casa de bombas, esquina de la parcela).")
B.cn=new A.a("Terreno","Terrain","Terreno")
B.x5=new A.a("Baixar eleva\xe7\xe3o da internet (MDT)\u2026","Download elevation from the internet (DEM)\u2026","Descargar elevaci\xf3n de internet (MDT)\u2026")
B.v_=new A.a("Gerar curvas de n\xedvel do modelo\u2026","Generate contours from the model\u2026","Generar curvas de nivel del modelo\u2026")
B.rM=new A.a("Interpola\xe7\xe3o do terreno","Terrain interpolation","Interpolaci\xf3n del terreno")
B.AG=new A.a("Triangula\xe7\xe3o (TIN / MDT)","Triangulation (TIN / DTM)","Triangulaci\xf3n (TIN / MDT)")
B.CM=new A.a("Inverso da dist\xe2ncia (IDW)","Inverse distance (IDW)","Inverso de la distancia (IDW)")
B.hu=new A.a("Limpar perfil do desenho","Clear profile from the drawing","Limpiar perfil del dibujo")
B.De=new A.a("Modelo do terreno: {n} pontos, eleva\xe7\xe3o {a} a {b} m","Terrain model: {n} points, elevation {a} to {b} m","Modelo del terreno: {n} puntos, elevaci\xf3n {a} a {b} m")
B.ix=new A.a("Sem dados de eleva\xe7\xe3o","No elevation data","Sin datos de elevaci\xf3n")
B.p0=new A.a("Interpola\xe7\xe3o do terreno (MDT)","Terrain interpolation (DTM)","Interpolaci\xf3n del terreno (MDT)")
B.rt=new A.a("Eleva\xe7\xe3o da internet (MDT online)","Elevation from the internet (online DEM)","Elevaci\xf3n de internet (MDT en l\xednea)")
B.pq=new A.a("Baixa a altitude de uma grade de pontos sobre o projeto a partir de um modelo digital de eleva\xe7\xe3o p\xfablico e cria cotas de ponto. Precisa de georrefer\xeancia (Arquivo \u2192 Georrefer\xeancia). Resolu\xe7\xe3o de 30\u201390 m: bom para o relevo geral, n\xe3o substitui um levantamento.","Downloads the altitude of a grid of points over the project from a public digital elevation model and creates spot heights. Needs a georeference (File \u2192 Georeference). 30\u201390 m resolution: good for the general relief, not a replacement for a survey.","Descarga la altitud de una malla de puntos sobre el proyecto desde un modelo digital de elevaci\xf3n p\xfablico y crea cotas de punto. Necesita georreferencia (Archivo \u2192 Georreferencia). Resoluci\xf3n de 30\u201390 m: buena para el relieve general, no sustituye un levantamiento.")
B.n2=new A.a("Fonte","Source","Fuente")
B.kg=new A.a("Espa\xe7amento da grade (m)","Grid spacing (m)","Espaciado de la malla (m)")
B.ia=new A.a("\xc1rea {w} \xd7 {h} m \u2192 {n} pontos em {r} requisi\xe7\xf5es","Area {w} \xd7 {h} m \u2192 {n} points in {r} requests","\xc1rea {w} \xd7 {h} m \u2192 {n} puntos en {r} solicitudes")
B.wz=new A.a("Substituir cotas baixadas anteriormente","Replace previously downloaded spot heights","Reemplazar cotas descargadas antes")
B.t5=new A.a("O projeto j\xe1 tem {n} cotas e {m} curvas pr\xf3prias ({a} a {b} m).","The project already has {n} spot heights and {m} contours of its own ({a} to {b} m).","El proyecto ya tiene {n} cotas y {m} curvas propias ({a} a {b} m).")
B.vk=new A.a("Substituir essas cotas e curvas pelo modelo baixado","Replace them with the downloaded model","Reemplazarlas por el modelo descargado")
B.vw=new A.a("Mantidas, elas entram no mesmo modelo que o MDT. Se estiverem noutro datum (ex.: dados de exemplo a 100 m) o terreno fica cheio de picos.","Kept, they join the same model as the DEM. On another datum (e.g. example data at 100 m) the terrain turns into spikes.","Si se mantienen, entran en el mismo modelo que el MDT. En otro datum (p. ej. datos de ejemplo a 100 m) el terreno se llena de picos.")
B.to=new A.a("Cotas existentes fora do datum do MDT","Existing heights off the DEM datum","Cotas existentes fuera del datum del MDT")
B.jc=new A.a("As cotas e curvas do projeto ({a} a {b} m) n\xe3o batem com o modelo baixado ({c} a {d} m): o terreno ficaria cheio de picos. Remover as cotas e curvas existentes? (Ctrl+Z desfaz.)","The project's own heights and contours ({a} to {b} m) do not match the downloaded model ({c} to {d} m): the terrain would be full of spikes. Remove the existing heights and contours? (Ctrl+Z undoes it.)","Las cotas y curvas del proyecto ({a} a {b} m) no coinciden con el modelo descargado ({c} a {d} m): el terreno quedar\xeda lleno de picos. \xbfQuitar las cotas y curvas existentes? (Ctrl+Z deshace.)")
B.pi=new A.a("Manter","Keep","Mantener")
B.oC=new A.a("Limite do servidor: aguardando {s} s\u2026","Server limit: waiting {s} s\u2026","L\xedmite del servidor: esperando {s} s\u2026")
B.xT=new A.a("Tempo estimado: {t}","Estimated time: {t}","Tiempo estimado: {t}")
B.wK=new A.a("O Open-Meteo aceita cerca de 600 pontos por minuto; para \xe1reas grandes a fonte Terrain Tiles \xe9 muito mais r\xe1pida (poucas requisi\xe7\xf5es, sem limite).","Open-Meteo takes about 600 points per minute; for large areas the Terrain Tiles source is much faster (a few requests, no limit).","Open-Meteo acepta unos 600 puntos por minuto; para \xe1reas grandes la fuente Terrain Tiles es mucho m\xe1s r\xe1pida (pocas solicitudes, sin l\xedmite).")
B.vI=new A.a("Download cancelado","Download cancelled","Descarga cancelada")
B.AD=new A.a("{n} pontos sem dados","{n} points without data","{n} puntos sin datos")
B.pD=new A.a('As cotas v\xe3o para a camada "MDT baixado" (pode ser ocultada em Camadas).','The points go to the "Downloaded DEM" layer (it can be hidden in Layers).','Las cotas van a la capa "MDT descargado" (puede ocultarse en Capas).')
B.qT=new A.a("Usar a \xe1rea vis\xedvel em vez dos limites do projeto","Use the visible area instead of the project extent","Usar el \xe1rea visible en lugar de los l\xedmites del proyecto")
B.l1=new A.a("Baixar","Download","Descargar")
B.uG=new A.a("Baixando {i} de {n}\u2026","Downloading {i} of {n}\u2026","Descargando {i} de {n}\u2026")
B.Cv=new A.a("{n} cotas importadas ({s})","{n} spot heights imported ({s})","{n} cotas importadas ({s})")
B.iU=new A.a("Defina antes a georrefer\xeancia do projeto (Arquivo \u2192 Georrefer\xeancia): latitude/longitude de um ponto do desenho.","Set the project georeference first (File \u2192 Georeference): latitude/longitude of a drawing point.","Defina antes la georreferencia del proyecto (Archivo \u2192 Georreferencia): latitud/longitud de un punto del dibujo.")
B.jR=new A.a("Falha ao baixar eleva\xe7\xf5es: {e}","Failed to download elevations: {e}","Error al descargar elevaciones: {e}")
B.ke=new A.a("Desenhe algo (ou use a \xe1rea vis\xedvel) para definir a regi\xe3o.","Draw something (or use the visible area) to define the region.","Dibuje algo (o use el \xe1rea visible) para definir la regi\xf3n.")
B.bH=new A.a("Gerar curvas de n\xedvel","Generate contours","Generar curvas de nivel")
B.mm=new A.a("Cria curvas de n\xedvel a partir do modelo digital do terreno (triangula\xe7\xe3o das cotas e curvas existentes). \xdatil depois de importar pontos ou baixar eleva\xe7\xe3o da internet. As curvas geradas s\xe3o s\xf3 desenho: n\xe3o alteram o modelo.","Creates contours from the digital terrain model (triangulation of the existing spot heights and contours). Useful after importing points or downloading elevation. Generated contours are drawing only: they do not change the model.","Crea curvas de nivel a partir del modelo digital del terreno (triangulaci\xf3n de las cotas y curvas existentes). \xdatil despu\xe9s de importar puntos o descargar elevaci\xf3n. Las curvas generadas son solo dibujo: no cambian el modelo.")
B.Df=new A.a("Intervalo (m)","Interval (m)","Intervalo (m)")
B.pl=new A.a("Remover curvas geradas anteriormente","Remove previously generated contours","Quitar curvas generadas antes")
B.qI=new A.a("{n} curvas entre {a} e {b} m","{n} contours between {a} and {b} m","{n} curvas entre {a} y {b} m")
B.jA=new A.a("{n} curvas de n\xedvel geradas","{n} contours generated","{n} curvas de nivel generadas")
B.nn=new A.a("Gerar","Generate","Generar")
B.tn=new A.a("Terreno","Ground","Terreno")
B.Cu=new A.a("Tubo (com profundidade)","Pipe (with depth)","Tuber\xeda (con profundidad)")
B.Ab=new A.a("Linha piezom\xe9trica (press\xe3o + cota)","Hydraulic grade line (pressure + elevation)","L\xednea piezom\xe9trica (presi\xf3n + cota)")
B.qM=new A.a("Ponto mais baixo","Lowest point","Punto m\xe1s bajo")
B.Bk=new A.a("Ponto mais alto","Highest point","Punto m\xe1s alto")
B.zT=new A.a("Como usar: Perfil (PR) \u2192 clique os pontos do caminho \u2192 Enter (ou Concluir). Ou selecione um tubo/lateral. A linha roxa no desenho \xe9 o caminho: Limpar (ou Esc com a ferramenta Perfil) a remove.","How to use: Profile (PR) \u2192 click the path points \u2192 Enter (or Done). Or select a pipe/lateral. The purple line on the drawing is the path: Clear (or Esc with the Profile tool) removes it.","C\xf3mo usar: Perfil (PR) \u2192 clic en los puntos del camino \u2192 Intro (o Terminar). O seleccione una tuber\xeda/lateral. La l\xednea morada en el dibujo es el camino: Limpiar (o Esc con la herramienta Perfil) la quita.")
B.mr=new A.a("Sem dados de eleva\xe7\xe3o: o perfil sai plano. Desenhe curvas de n\xedvel (CT) ou cotas (SP), importe topografia ou baixe eleva\xe7\xe3o da internet (Projeto \u2192 Terreno).","No elevation data: the profile is flat. Draw contours (CT) or spot heights (SP), import a survey or download elevation from the internet (Design \u2192 Terrain).","Sin datos de elevaci\xf3n: el perfil sale plano. Dibuje curvas de nivel (CT) o cotas (SP), importe topograf\xeda o descargue elevaci\xf3n de internet (Dise\xf1o \u2192 Terreno).")
B.vY=new A.a("Esta\xe7\xe3o","Station","Estaci\xf3n")
B.wR=new A.a("Piv\xf4s","Pivots","Pivotes")
B.md=new A.a("Piv\xf4","Pivot","Pivote")
B.cq=new A.a("Torres","Towers","Torres")
B.BQ=new A.a("P dispon\xedvel","P available","P disponible")
B.mp=new A.a("Desn\xedvel","Rise","Desnivel")
B.lZ=new A.a("L\xe2mina/ciclo","Depth/cycle","L\xe1mina/ciclo")
B.Ca=new A.a("Horas/ciclo","Hours/cycle","Horas/ciclo")
B.pw=new A.a("Taxa aplic. pico","Peak app. rate","Tasa aplic. pico")
B.aH=new A.a("Piv\xf4 central","Centre pivot","Pivote central")
B.rJ=new A.a("Lateral m\xf3vel (linear)","Linear move","Lateral de avance (linear)")
B.BS=new A.a("torres","towers","torres")
B.ue=new A.a("Piv\xf4s e laterais m\xf3veis","Pivots and linear moves","Pivotes y laterales de avance")
B.tk=new A.a("Press\xe3o insuficiente na entrada do piv\xf4","Not enough pressure at the pivot inlet","Presi\xf3n insuficiente en la entrada del pivote")
B.qF=new A.a("Taxa de aplica\xe7\xe3o na ponta acima do limite do solo","Application rate at the end above the soil limit","Tasa de aplicaci\xf3n en la punta por encima del l\xedmite del suelo")
B.za=new A.a("Piv\xf4 sem vaz\xe3o (l\xe2mina ou horas por ciclo zeradas)","Pivot without flow (depth or hours per cycle are zero)","Pivote sin caudal (l\xe1mina u horas por ciclo en cero)")
B.j9=new A.a("Piv\xf4 sem press\xe3o de ponta definida","Pivot without an end pressure","Pivote sin presi\xf3n de punta definida")
B.ni=new A.a("Tipo de m\xe1quina","Machine type","Tipo de m\xe1quina")
B.lV=new A.a("Comprimento da lateral (m)","Span pipe length (m)","Longitud de la lateral (m)")
B.nQ=new A.a("V\xe3o entre torres (m)","Span between towers (m)","Vano entre torres (m)")
B.mK=new A.a("Percurso da lateral m\xf3vel (m)","Linear travel length (m)","Recorrido de la lateral (m)")
B.AH=new A.a("Tubo dos v\xe3os (cat\xe1logo)","Span pipe (catalogue)","Tubo de los vanos (cat\xe1logo)")
B.ug=new A.a("Di\xe2metro interno do tubo (mm)","Pipe inner diameter (mm)","Di\xe1metro interior del tubo (mm)")
B.o8=new A.a("C de Hazen-Williams","Hazen-Williams C","C de Hazen-Williams")
B.D2=new A.a("Altura do tubo (m)","Pipe height (m)","Altura del tubo (m)")
B.kp=new A.a("Press\xe3o na ponta","End pressure","Presi\xf3n en la punta")
B.o4=new A.a("Vaz\xe3o do canh\xe3o final","End gun flow","Caudal del ca\xf1\xf3n final")
B.qa=new A.a("Press\xe3o do canh\xe3o final","End gun pressure","Presi\xf3n del ca\xf1\xf3n final")
B.uv=new A.a("Alcance al\xe9m da ponta (m)","Throw beyond the end (m)","Alcance m\xe1s all\xe1 de la punta (m)")
B.qW=new A.a("L\xe2mina bruta por ciclo (mm)","Gross depth per cycle (mm)","L\xe1mina bruta por ciclo (mm)")
B.C6=new A.a("Horas por ciclo (volta/passada)","Hours per cycle (revolution/pass)","Horas por ciclo (vuelta/pasada)")
B.vO=new A.a("Largura molhada na ponta (m)","Wetted width at the end (m)","Ancho mojado en la punta (m)")
B.om=new A.a("Perdas da m\xe1quina (m)","Machine losses (m)","P\xe9rdidas de la m\xe1quina (m)")
B.lN=new A.a("Taxa m\xe1x. do solo (mm/h; 0 = n\xe3o verificar)","Soil max. rate (mm/h; 0 = no check)","Tasa m\xe1x. del suelo (mm/h; 0 = no verificar)")
B.il=new A.a("Setor irrigado (\xb0)","Irrigated sector (\xb0)","Sector regado (\xb0)")
B.vi=new A.a("Custo da m\xe1quina","Machine cost","Costo de la m\xe1quina")
B.rL=new A.a("\xc2ngulo de desenho (\xb0)","Drawing angle (\xb0)","\xc1ngulo de dibujo (\xb0)")
B.rp=new A.a("Resultado","Result","Resultado")
B.ll=new A.a("Press\xe3o necess\xe1ria na entrada","Required inlet pressure","Presi\xf3n necesaria en la entrada")
B.y1=new A.a("Gerada do modelo (n\xe3o entra no MDT)","Generated from the model (not used by the DTM)","Generada del modelo (no entra al MDT)")
B.k9=new A.a("Verifica\xe7\xe3o do projeto (Design Check)","Design check","Verificaci\xf3n del dise\xf1o (Design Check)")
B.hV=new A.a("Varre o desenho procurando erros que impedem ou distorcem o c\xe1lculo hidr\xe1ulico: itens desconectados, tubos que se cruzam sem jun\xe7\xe3o, pontas soltas, zonas sem emissores, duplicados e dados de cat\xe1logo faltando. Clique num item para localiz\xe1-lo.","Sweeps the drawing for errors that stop or distort the hydraulic calculation: disconnected items, pipes crossing without a junction, dead ends, zones without emitters, duplicates and missing catalogue data. Click an item to locate it.","Recorre el dibujo buscando errores que impiden o distorsionan el c\xe1lculo hidr\xe1ulico: elementos desconectados, tuber\xedas que se cruzan sin nudo, extremos sueltos, zonas sin emisores, duplicados y datos de cat\xe1logo faltantes. Haga clic en un \xedtem para ubicarlo.")
B.zk=new A.a("{e} erro(s), {w} aviso(s), {i} nota(s)","{e} error(s), {w} warning(s), {i} note(s)","{e} error(es), {w} aviso(s), {i} nota(s)")
B.v3=new A.a("Nenhum erro encontrado: o projeto est\xe1 pronto para o c\xe1lculo (F5).","No errors found: the design is ready to run (F5).","No se encontraron errores: el dise\xf1o est\xe1 listo para calcular (F5).")
B.yp=new A.a("Verificar novamente","Run again","Verificar de nuevo")
B.my=new A.a("Erro","Error","Error")
B.kU=new A.a("Aviso","Warning","Aviso")
B.pN=new A.a("Nota","Note","Nota")
B.nd=new A.a("Nenhum item hidr\xe1ulico no desenho","No hydraulic items in the drawing","Ning\xfan elemento hidr\xe1ulico en el dibujo")
B.oz=new A.a("Falta a fonte de \xe1gua (WS)","Water supply missing (WS)","Falta la fuente de agua (WS)")
B.r5=new A.a("H\xe1 laterais/emissores mas nenhuma v\xe1lvula de controle (V)","There are laterals/outlets but no control valve (V)","Hay laterales/emisores pero ninguna v\xe1lvula de control (V)")
B.wQ=new A.a("Item desconectado da rede","Item not connected to the network","Elemento desconectado de la red")
B.pJ=new A.a("Zona sem emissores","Zone without emitters","Zona sin emisores")
B.xm=new A.a("V\xe1lvulas com o mesmo nome de zona","Valves with the same zone name","V\xe1lvulas con el mismo nombre de zona")
B.is=new A.a("Ponta solta na linha principal (tubo sem sa\xedda)","Dead end on the mainline (pipe with no outlet)","Extremo suelto en la l\xednea principal (tuber\xeda sin salida)")
B.o1=new A.a("Tubo de zona terminando sem lateral","Zone pipe ending without a lateral","Tuber\xeda de zona que termina sin lateral")
B.nl=new A.a("Tubo de comprimento zero","Zero-length pipe","Tuber\xeda de longitud cero")
B.jo=new A.a("Segmento menor que a toler\xe2ncia de conex\xe3o","Segment shorter than the connection tolerance","Segmento menor que la tolerancia de conexi\xf3n")
B.A6=new A.a("Itens duplicados na mesma posi\xe7\xe3o","Duplicated items at the same position","Elementos duplicados en la misma posici\xf3n")
B.j2=new A.a("Tubos se cruzam sem jun\xe7\xe3o (n\xe3o est\xe3o conectados)","Pipes cross without a junction (not connected)","Tuber\xedas se cruzan sin nudo (no est\xe1n conectadas)")
B.q4=new A.a("Modelo do cat\xe1logo n\xe3o encontrado","Catalogue model not found","Modelo del cat\xe1logo no encontrado")
B.D3=new A.a("Fonte com press\xe3o fixa igual a zero","Supply with a fixed pressure of zero","Fuente con presi\xf3n fija igual a cero")
B.w1=new A.a("Piv\xf4 fora da linha principal","Pivot not on the mainline","Pivote fuera de la l\xednea principal")
B.xZ=new A.a("Sem dados de eleva\xe7\xe3o: o terreno \xe9 considerado plano","No elevation data: the ground is taken as flat","Sin datos de elevaci\xf3n: el terreno se considera plano")
B.jd=new A.a("Linha principal em anel (rede malhada) \u2014 resolvida pelo solver","Looped mainline (meshed network) \u2014 solved by the solver","L\xednea principal en anillo (red mallada) \u2014 resuelta por el solver")
B.ws=new A.a("\xc1rea sem emissores dentro","Area with no emitters inside","\xc1rea sin emisores dentro")
B.BD=new A.a("Por qu\xea","Why","Por qu\xe9")
B.rV=new A.a("Como resolver","How to fix","C\xf3mo resolver")
B.vW=new A.a("Mostrar no desenho","Show on the drawing","Mostrar en el dibujo")
B.ps=new A.a("Corrigir automaticamente","Fix automatically","Corregir autom\xe1ticamente")
B.xM=new A.a("Aplica as corre\xe7\xf5es seguras, recalcula e repete at\xe9 n\xe3o restar nada que ele consiga corrigir sozinho. Tudo vira um \xfanico passo: desfa\xe7a com Ctrl+Z.","Applies the safe corrections, runs the design again and repeats until nothing is left that it can fix on its own. It is all one step: undo with Ctrl+Z.","Aplica las correcciones seguras, recalcula y repite hasta que no quede nada que pueda corregir solo. Todo es un \xfanico paso: deshaga con Ctrl+Z.")
B.bY=new A.a("Otimizar projeto","Optimise design","Optimizar dise\xf1o")
B.id=new A.a("erro(s)","error(s)","error(es)")
B.Aj=new A.a("aviso(s)","warning(s)","aviso(s)")
B.zq=new A.a("nota(s)","note(s)","nota(s)")
B.vq=new A.a("Nenhum problema: o projeto atende todos os requisitos.","No problems: the design meets every requirement.","Ning\xfan problema: el dise\xf1o cumple todos los requisitos.")
B.jE=new A.a("Nenhum problema no desenho. Calcule o projeto (F5) para conferir press\xf5es e vaz\xf5es.","No problems in the drawing. Run the design (F5) to check pressures and flows.","Ning\xfan problema en el dibujo. Calcule el dise\xf1o (F5) para comprobar presiones y caudales.")
B.jI=new A.a("Estes s\xe3o os problemas do desenho e das configura\xe7\xf5es. Depois de calcular (F5) aparecem tamb\xe9m os de press\xe3o, vaz\xe3o e bomba.","These are the problems of the drawing and the settings. After a design run (F5) the pressure, flow and pump ones show too.","Estos son los problemas del dibujo y de la configuraci\xf3n. Tras calcular (F5) aparecen tambi\xe9n los de presi\xf3n, caudal y bomba.")
B.ui=new A.a("Calculando\u2026","Designing\u2026","Calculando\u2026")
B.k6=new A.a("Corrigindo\u2026 rodada {n}","Fixing\u2026 round {n}","Corrigiendo\u2026 ronda {n}")
B.y8=new A.a("Corrigido: {m}","Fixed: {m}","Corregido: {m}")
B.pA=new A.a("N\xe3o foi poss\xedvel corrigir: {m}","Could not fix: {m}","No se pudo corregir: {m}")
B.ct=new A.a("Corre\xe7\xe3o autom\xe1tica","Automatic correction","Correcci\xf3n autom\xe1tica")
B.uZ=new A.a('Nada p\xf4de ser corrigido automaticamente. Siga o "Como resolver" de cada mensagem.','Nothing could be fixed automatically. Follow the "How to fix" of each message.','No se pudo corregir nada autom\xe1ticamente. Siga el "C\xf3mo resolver" de cada mensaje.')
B.Do=new A.a("{n} corre\xe7\xe3o(\xf5es) aplicada(s):","{n} correction(s) applied:","{n} correcci\xf3n(es) aplicada(s):")
B.uh=new A.a('Restam {e} erro(s) e {w} aviso(s) que dependem de uma decis\xe3o sua: veja o "Como resolver" de cada um em Mensagens.','{e} error(s) and {w} warning(s) are left that need your decision: see the "How to fix" of each one in Messages.','Quedan {e} error(es) y {w} aviso(s) que dependen de una decisi\xf3n suya: vea el "C\xf3mo resolver" de cada uno en Mensajes.')
B.ht=new A.a("Pronto: nenhum erro ou aviso restante.","Done: no errors or warnings left.","Listo: no quedan errores ni avisos.")
B.np=new A.a("Tudo foi feito num \xfanico passo do hist\xf3rico: Desfazer (Ctrl+Z) volta ao projeto anterior.","Everything was a single history step: Undo (Ctrl+Z) returns to the previous design.","Todo fue un \xfanico paso del historial: Deshacer (Ctrl+Z) vuelve al dise\xf1o anterior.")
B.zc=new A.a("Desfazer tudo","Undo all","Deshacer todo")
B.qf=new A.a("C\xe1lculo conclu\xeddo com {n} erro(s). A aba Mensagens explica cada um e como resolver.","Design finished with {n} error(s). The Messages tab explains each one and how to fix it.","C\xe1lculo terminado con {n} error(es). La pesta\xf1a Mensajes explica cada uno y c\xf3mo resolverlo.")
B.zf=new A.a("laterais","laterals","laterales")
B.vH=new A.a("tubos de zona","zone pipes","tuber\xedas de zona")
B.Dg=new A.a("linha principal","mainline","l\xednea principal")
B.AW=new A.a("Procura o menor custo anual (investimento anualizado + energia) que ainda atende todas as press\xf5es e velocidades: dimensiona os tubos por programa\xe7\xe3o linear, escolhe a bomba de menor custo de ciclo de vida e a v\xe1lvula certa para cada zona. Se n\xe3o melhorar, nada \xe9 alterado.","Looks for the lowest annual cost (annualised investment + energy) that still meets every pressure and velocity: sizes the pipes by linear programming, picks the pump with the lowest life-cycle cost and the right valve for each zone. If nothing improves, nothing changes.","Busca el menor costo anual (inversi\xf3n anualizada + energ\xeda) que a\xfan cumple todas las presiones y velocidades: dimensiona las tuber\xedas por programaci\xf3n lineal, elige la bomba de menor costo de ciclo de vida y la v\xe1lvula correcta para cada zona. Si no mejora, no se cambia nada.")
B.l6=new A.a("Escolher a bomba de menor custo total (compra + energia)","Choose the pump with the lowest total cost (purchase + energy)","Elegir la bomba de menor costo total (compra + energ\xeda)")
B.Bb=new A.a("Ajustar o tamanho de cada v\xe1lvula \xe0 vaz\xe3o da sua zona","Size each valve to the flow of its zone","Ajustar el tama\xf1o de cada v\xe1lvula al caudal de su zona")
B.ty=new A.a("Redimensionar tamb\xe9m os tubos com di\xe2metro fixado por voc\xea","Also resize the pipes whose diameter you fixed","Redimensionar tambi\xe9n las tuber\xedas con di\xe1metro fijado por usted")
B.q9=new A.a("Otimizar","Optimise","Optimizar")
B.oL=new A.a("Otimizando: calculando alternativas\u2026","Optimising: designing alternatives\u2026","Optimizando: calculando alternativas\u2026")
B.kM=new A.a("Antes","Before","Antes")
B.Dm=new A.a("Depois","After","Despu\xe9s")
B.oV=new A.a("Investimento","Investment","Inversi\xf3n")
B.nL=new A.a("Energia por ano","Energy per year","Energ\xeda por a\xf1o")
B.uq=new A.a("Erros / avisos","Errors / warnings","Errores / avisos")
B.oT=new A.a("Otimiza\xe7\xe3o aplicada: o projeto ficou mais barato ou com menos problemas.","Optimisation applied: the design is cheaper or has fewer problems.","Optimizaci\xf3n aplicada: el dise\xf1o es m\xe1s barato o tiene menos problemas.")
B.qY=new A.a("O projeto j\xe1 estava otimizado: nenhuma alternativa melhor foi encontrada e nada foi alterado.","The design was already optimal: no better alternative was found and nothing changed.","El dise\xf1o ya estaba optimizado: no se encontr\xf3 una alternativa mejor y no se cambi\xf3 nada.")
B.j6=new A.a("Desfazer otimiza\xe7\xe3o","Undo optimisation","Deshacer optimizaci\xf3n")
B.qq=new A.a("Custos com os pre\xe7os do cat\xe1logo e os par\xe2metros econ\xf4micos (juros, prazo, tarifa de energia, horas por ano).","Costs use the catalogue prices and the economic parameters (interest, term, energy tariff, hours per year).","Costos con los precios del cat\xe1logo y los par\xe1metros econ\xf3micos (inter\xe9s, plazo, tarifa de energ\xeda, horas por a\xf1o).")
B.t3=new A.a("Corre\xe7\xe3o: {n}","Correction: {n}","Correcci\xf3n: {n}")
B.pC=new A.a("Otimiza\xe7\xe3o","Optimisation","Optimizaci\xf3n")
B.Cw=new A.a("Limites de velocidade imposs\xedveis","Impossible velocity limits","L\xedmites de velocidad imposibles")
B.pd=new A.a("Horas de funcionamento por ano imposs\xedveis","Impossible operating hours per year","Horas de funcionamiento por a\xf1o imposibles")
B.vR=new A.a("Par\xe2metros econ\xf4micos imposs\xedveis","Impossible economic parameters","Par\xe1metros econ\xf3micos imposibles")
B.wZ=new A.a("Toler\xe2ncia de conex\xe3o fora da faixa","Connection tolerance out of range","Tolerancia de conexi\xf3n fuera de rango")
B.AS=new A.a("Varia\xe7\xe3o de press\xe3o na zona fora da faixa","Zone pressure variation out of range","Variaci\xf3n de presi\xf3n en la zona fuera de rango")
B.tI=new A.a("Temperatura da \xe1gua fora da faixa","Water temperature out of range","Temperatura del agua fuera de rango")
B.wG=new A.a("Nenhum tubo habilitado para este uso","No pipe enabled for this use","Ninguna tuber\xeda habilitada para este uso")
B.tC=new A.a("M\xe1ximo da fonte menor que o valor de projeto","Supply maximum below the design value","M\xe1ximo de la fuente menor que el valor de dise\xf1o")
B.pH=new A.a("Zonas fora de todos os turnos","Zones in no system flow","Zonas fuera de todos los turnos")
B.nN=new A.a("Turnos vazios","Empty system flows","Turnos vac\xedos")
B.kA=new A.a("Turno com dura\xe7\xe3o zero","System flow with zero duration","Turno con duraci\xf3n cero")
B.mW=new A.a("Press\xe3o do emissor fora da faixa do bocal","Emitter pressure outside the nozzle range","Presi\xf3n del emisor fuera del rango de la boquilla")
B.Bm=new A.a("Rota\xe7\xe3o da bomba fora da faixa","Pump speed out of range","Velocidad de la bomba fuera de rango")
B.i7=new A.a("Conectar ao mais pr\xf3ximo (at\xe9 {d} m)","Connect to the nearest (up to {d} m)","Conectar al m\xe1s cercano (hasta {d} m)")
B.pb=new A.a("Excluir o tubo","Delete the pipe","Eliminar la tuber\xeda")
B.vn=new A.a("Remover v\xe9rtices repetidos","Remove repeated vertices","Quitar v\xe9rtices repetidos")
B.m1=new A.a("Manter s\xf3 um","Keep only one","Dejar solo uno")
B.mG=new A.a("Renomear as zonas repetidas","Rename the repeated zones","Renombrar las zonas repetidas")
B.Ar=new A.a("Calcular a press\xe3o necess\xe1ria na fonte","Calculate the pressure needed at the supply","Calcular la presi\xf3n necesaria en la fuente")
B.lU=new A.a("Escolher a bomba adequada","Choose a suitable pump","Elegir la bomba adecuada")
B.Cl=new A.a("Trocar por bomba submersa","Replace with a submersible pump","Cambiar por bomba sumergible")
B.og=new A.a("Deixar o c\xe1lculo escolher os di\xe2metros","Let the design choose the diameters","Dejar que el c\xe1lculo elija los di\xe1metros")
B.rZ=new A.a("Usar tubo de classe de press\xe3o maior","Use a pipe of a higher pressure class","Usar tuber\xeda de clase de presi\xf3n mayor")
B.nf=new A.a("Trocar a v\xe1lvula pelo tamanho certo","Change the valve to the right size","Cambiar la v\xe1lvula por el tama\xf1o correcto")
B.BU=new A.a("Usar um modelo do cat\xe1logo","Use a catalogue model","Usar un modelo del cat\xe1logo")
B.jt=new A.a("Dividir em mais turnos","Split into more system flows","Dividir en m\xe1s turnos")
B.lu=new A.a("Adicionar as conex\xf5es ao cat\xe1logo","Add the fittings to the catalogue","A\xf1adir las conexiones al cat\xe1logo")
B.q_=new A.a("Conectar os tubos no cruzamento","Connect the pipes at the crossing","Conectar las tuber\xedas en el cruce")
B.kT=new A.a("Colocar a fonte na ponta livre","Place the supply at the free end","Colocar la fuente en el extremo libre")
B.rC=new A.a("Voltar aos valores padr\xe3o","Restore the default values","Volver a los valores por defecto")
B.yb=new A.a("Criar um turno para essas zonas","Create a system flow for these zones","Crear un turno para esas zonas")
B.jZ=new A.a("Limpar os turnos","Clean up the system flows","Limpiar los turnos")
B.m3=new A.a("Definir 1 h de dura\xe7\xe3o","Set a 1 h duration","Definir 1 h de duraci\xf3n")
B.lj=new A.a("Usar a press\xe3o nominal do emissor","Use the emitter nominal pressure","Usar la presi\xf3n nominal del emisor")
B.nq=new A.a("Voltar \xe0 rota\xe7\xe3o nominal","Back to the rated speed","Volver a la velocidad nominal")
B.vz=new A.a("Ajustar os limites da fonte","Adjust the supply limits","Ajustar los l\xedmites de la fuente")
B.vL=new A.a("Habilitar tubos no cat\xe1logo","Enable pipes in the catalogue","Habilitar tuber\xedas en el cat\xe1logo")
B.zz=new A.a("item conectado (movido {d} m)","item connected (moved {d} m)","elemento conectado (movido {d} m)")
B.rc=new A.a("{n} tubo(s) de comprimento zero exclu\xeddo(s)","{n} zero-length pipe(s) deleted","{n} tuber\xeda(s) de longitud cero eliminada(s)")
B.Bq=new A.a("{n} v\xe9rtice(s) repetido(s) removido(s)","{n} repeated vertex(es) removed","{n} v\xe9rtice(s) repetido(s) quitado(s)")
B.re=new A.a("{n} item(ns) duplicado(s) removido(s)","{n} duplicated item(s) removed","{n} elemento(s) duplicado(s) quitado(s)")
B.or=new A.a("{n} zona(s) renomeada(s)","{n} zone(s) renamed","{n} zona(s) renombrada(s)")
B.r4=new A.a("a press\xe3o da fonte agora \xe9 calculada ({n})","the supply pressure is now calculated ({n})","la presi\xf3n de la fuente ahora se calcula ({n})")
B.kw=new A.a("bomba trocada por {n}","pump changed to {n}","bomba cambiada por {n}")
B.z8=new A.a("bomba {n} inserida junto \xe0 fonte","pump {n} inserted next to the supply","bomba {n} insertada junto a la fuente")
B.oU=new A.a("{n} tubo(s) liberado(s) para o c\xe1lculo escolher o di\xe2metro","{n} pipe(s) freed for the design to choose the diameter","{n} tuber\xeda(s) liberada(s) para que el c\xe1lculo elija el di\xe1metro")
B.n7=new A.a("tubo trocado por {n}","pipe changed to {n}","tuber\xeda cambiada por {n}")
B.jk=new A.a("v\xe1lvula trocada por {n}","valve changed to {n}","v\xe1lvula cambiada por {n}")
B.vc=new A.a("modelo definido: {n}","model set: {n}","modelo definido: {n}")
B.vK=new A.a("zonas reagrupadas em {n} turnos","zones regrouped into {n} system flows","zonas reagrupadas en {n} turnos")
B.BB=new A.a("{n} conex\xe3o(\xf5es) gen\xe9rica(s) adicionada(s) ao cat\xe1logo","{n} generic fitting(s) added to the catalogue","{n} conexi\xf3n(es) gen\xe9rica(s) a\xf1adida(s) al cat\xe1logo")
B.qV=new A.a("tubos conectados no cruzamento","pipes connected at the crossing","tuber\xedas conectadas en el cruce")
B.wJ=new A.a("fonte de \xe1gua colocada na ponta livre da linha principal","water supply placed at the free end of the mainline","fuente de agua colocada en el extremo libre de la l\xednea principal")
B.yD=new A.a("par\xe2metros de projeto restaurados aos valores padr\xe3o","design parameters restored to the defaults","par\xe1metros de dise\xf1o restaurados a los valores por defecto")
B.zP=new A.a("{n} tubo(s) habilitado(s) no cat\xe1logo","{n} pipe(s) enabled in the catalogue","{n} tuber\xeda(s) habilitada(s) en el cat\xe1logo")
B.oj=new A.a("limites da fonte ajustados aos valores de projeto","supply limits set to the design values","l\xedmites de la fuente ajustados a los valores de dise\xf1o")
B.B7=new A.a("{n} zona(s) colocada(s) num novo turno","{n} zone(s) put in a new system flow","{n} zona(s) puesta(s) en un nuevo turno")
B.k1=new A.a("{n} refer\xeancia(s) a turnos vazios ou v\xe1lvulas apagadas removida(s)","{n} reference(s) to empty flows or deleted valves removed","{n} referencia(s) a turnos vac\xedos o v\xe1lvulas borradas quitada(s)")
B.v8=new A.a("dura\xe7\xe3o de {n} turno(s) definida em 1 h","duration of {n} system flow(s) set to 1 h","duraci\xf3n de {n} turno(s) definida en 1 h")
B.u9=new A.a("press\xe3o nominal aplicada a {n} emissor(es) ou linha(s)","nominal pressure applied to {n} emitter(s) or line(s)","presi\xf3n nominal aplicada a {n} emisor(es) o l\xednea(s)")
B.vZ=new A.a("rota\xe7\xe3o nominal restaurada em {n} bomba(s)","rated speed restored on {n} pump(s)","velocidad nominal restaurada en {n} bomba(s)")
B.oq=new A.a("dimensionamento por programa\xe7\xe3o linear com o custo da energia","linear-programming sizing with the energy cost","dimensionamiento por programaci\xf3n lineal con el costo de la energ\xeda")
B.iZ=new A.a("o item n\xe3o existe mais","the item no longer exists","el elemento ya no existe")
B.wa=new A.a("nenhum tubo ou item compat\xedvel a menos de {d} m","no compatible pipe or item within {d} m","ninguna tuber\xeda o elemento compatible a menos de {d} m")
B.uE=new A.a("calcule o projeto (F5) antes","run the design (F5) first","calcule el dise\xf1o (F5) antes")
B.yO=new A.a("n\xe3o h\xe1 fonte de \xe1gua","there is no water supply","no hay fuente de agua")
B.iS=new A.a("a fonte n\xe3o precisa de bombeamento","the supply needs no pumping","la fuente no necesita bombeo")
B.rD=new A.a("nenhuma bomba do cat\xe1logo atende sozinha a vaz\xe3o e a press\xe3o; adicione uma bomba maior ao cat\xe1logo","no catalogue pump meets the flow and the pressure alone; add a bigger pump to the catalogue","ninguna bomba del cat\xe1logo cumple sola el caudal y la presi\xf3n; a\xf1ada una bomba mayor al cat\xe1logo")
B.iW=new A.a("{n} j\xe1 \xe9 a melhor op\xe7\xe3o do cat\xe1logo","{n} already is the best option in the catalogue","{n} ya es la mejor opci\xf3n del cat\xe1logo")
B.qS=new A.a("nenhum tubo da linha principal sai da fonte","no mainline pipe leaves the supply","ninguna tuber\xeda de la l\xednea principal sale de la fuente")
B.v4=new A.a("n\xe3o havia nada a mudar","there was nothing to change","no hab\xeda nada que cambiar")
B.xl=new A.a("o cat\xe1logo n\xe3o tem uma op\xe7\xe3o adequada","the catalogue has no suitable option","el cat\xe1logo no tiene una opci\xf3n adecuada")
B.D9=new A.a("O c\xe1lculo come\xe7a numa fonte de \xe1gua (po\xe7o, reservat\xf3rio, rede p\xfablica ou canal) com n\xedvel e press\xe3o conhecidos. Sem ela a \xe1gua n\xe3o tem de onde vir e nada pode ser calculado.","The design starts at a water supply (well, reservoir, public mains or canal) with a known level and pressure. Without one the water has nowhere to come from and nothing can be calculated.","El c\xe1lculo empieza en una fuente de agua (pozo, reservorio, red p\xfablica o canal) con nivel y presi\xf3n conocidos. Sin ella el agua no tiene de d\xf3nde venir y no se puede calcular nada.")
B.Cz=new A.a('Use a ferramenta Fonte de \xe1gua (WS) e clique na ponta da linha principal por onde a \xe1gua entra. Marque "Calcular press\xe3o necess\xe1ria" se ainda n\xe3o souber a press\xe3o dispon\xedvel: o programa diz quanto \xe9 preciso.','Use the Water supply tool (WS) and click the end of the mainline where the water comes in. Tick "Calculate required pressure" if you do not know the available pressure yet: the program tells you how much is needed.','Use la herramienta Fuente de agua (WS) y haga clic en el extremo de la l\xednea principal por donde entra el agua. Marque "Calcular presi\xf3n necesaria" si a\xfan no conoce la presi\xf3n disponible: el programa indica cu\xe1nta se necesita.')
B.lJ=new A.a("Cada zona (conjunto de laterais que irrigam juntas) precisa de uma v\xe1lvula de controle que a ligue \xe0 linha principal. \xc9 na v\xe1lvula que o programa separa as zonas e calcula a press\xe3o de cada uma.","Each zone (a set of laterals that irrigate together) needs a control valve that links it to the mainline. The valve is where the program separates the zones and works out the pressure of each one.","Cada zona (conjunto de laterales que riegan juntas) necesita una v\xe1lvula de control que la una a la l\xednea principal. En la v\xe1lvula el programa separa las zonas y calcula la presi\xf3n de cada una.")
B.jX=new A.a("Coloque uma V\xe1lvula de controle (V) onde a linha principal encontra o in\xedcio da zona. O Bloco de laterais (B) desenha laterais, linha de deriva\xe7\xe3o e v\xe1lvula de uma vez.","Place a Control valve (V) where the mainline meets the start of the zone. The Lateral block tool (B) draws laterals, submain and valve in one go.","Coloque una V\xe1lvula de control (V) donde la l\xednea principal se encuentra con el inicio de la zona. El Bloque de laterales (B) dibuja laterales, secundaria y v\xe1lvula de una vez.")
B.je=new A.a("O desenho ainda n\xe3o tem tubos, emissores nem v\xe1lvulas: s\xf3 h\xe1 o que calcular depois que a rede de irriga\xe7\xe3o \xe9 desenhada.","The drawing has no pipes, emitters or valves yet: there is only something to calculate once the irrigation network is drawn.","El dibujo todav\xeda no tiene tuber\xedas, emisores ni v\xe1lvulas: solo hay algo que calcular cuando la red de riego est\xe1 dibujada.")
B.kv=new A.a("Comece por um exemplo (Arquivo \u2192 Exemplos) ou pelo Tutorial interativo (Ajuda). Num projeto novo: desenhe a \xe1rea, gere um Bloco de laterais (B), ligue as v\xe1lvulas com a linha principal e coloque a fonte de \xe1gua.","Start from an example (File \u2192 Examples) or the Interactive tutorial (Help). For a new design: draw the area, generate a Lateral block (B), link the valves with the mainline and place the water supply.","Empiece por un ejemplo (Archivo \u2192 Ejemplos) o por el Tutorial interactivo (Ayuda). En un dise\xf1o nuevo: dibuje el \xe1rea, genere un Bloque de laterales (B), una las v\xe1lvulas con la l\xednea principal y coloque la fuente de agua.")
B.CL=new A.a("S\xf3 est\xe3o ligados itens que se tocam exatamente (dentro da toler\xe2ncia de conex\xe3o). Um item fora da rede n\xe3o recebe \xe1gua e fica fora do c\xe1lculo; geralmente ele foi solto a poucos cent\xedmetros do tubo.","Only items that touch exactly (within the connection tolerance) are joined. An item off the network gets no water and is left out of the calculation; usually it was dropped a few centimetres from the pipe.","Solo est\xe1n unidos los elementos que se tocan exactamente (dentro de la tolerancia de conexi\xf3n). Un elemento fuera de la red no recibe agua y queda fuera del c\xe1lculo; normalmente se solt\xf3 a pocos cent\xedmetros de la tuber\xeda.")
B.qp=new A.a('Clique em "Mostrar no desenho" e arraste o item at\xe9 o tubo com o Snap ligado, ou use a corre\xe7\xe3o, que o leva ao tubo ou item compat\xedvel mais pr\xf3ximo.','Click "Show on the drawing" and drag the item onto the pipe with Snap on, or use the correction, which moves it to the nearest compatible pipe or item.','Haga clic en "Mostrar en el dibujo" y arrastre el elemento sobre la tuber\xeda con el Snap activado, o use la correcci\xf3n, que lo lleva a la tuber\xeda o elemento compatible m\xe1s cercano.')
B.x_=new A.a("Um tubo sem comprimento (os dois pontos no mesmo lugar) n\xe3o conduz \xe1gua e atrapalha a montagem da rede. Costuma surgir de um clique duplo acidental.","A pipe without length (both points at the same place) carries no water and confuses the network. It usually comes from an accidental double click.","Una tuber\xeda sin longitud (los dos puntos en el mismo lugar) no conduce agua y entorpece el armado de la red. Suele surgir de un doble clic accidental.")
B.l3=new A.a("Exclua o tubo; nada se perde.","Delete the pipe; nothing is lost.","Elimine la tuber\xeda; no se pierde nada.")
B.Ak=new A.a("Dois v\xe9rtices mais pr\xf3ximos que a toler\xe2ncia de conex\xe3o viram um s\xf3 n\xf3; o trecho min\xfasculo entre eles pode ligar coisas que n\xe3o deviam se tocar.","Two vertices closer than the connection tolerance become a single node; the tiny piece between them may join things that should not touch.","Dos v\xe9rtices m\xe1s cerca que la tolerancia de conexi\xf3n se vuelven un solo nudo; el tramo diminuto entre ellos puede unir cosas que no deber\xedan tocarse.")
B.wO=new A.a("Remova os v\xe9rtices repetidos (a corre\xe7\xe3o faz isso sem mudar o tra\xe7ado).","Remove the repeated vertices (the correction does it without changing the layout).","Quite los v\xe9rtices repetidos (la correcci\xf3n lo hace sin cambiar el trazado).")
B.m2=new A.a("Dois itens iguais no mesmo ponto (colados duas vezes, por exemplo) dobram a vaz\xe3o e o custo na lista de materiais.","Two identical items at the same point (pasted twice, for instance) double the flow and the cost in the bill of materials.","Dos elementos iguales en el mismo punto (pegados dos veces, por ejemplo) duplican el caudal y el costo en la lista de materiales.")
B.kr=new A.a("Mantenha s\xf3 um deles.","Keep only one of them.","Deje solo uno de ellos.")
B.v6=new A.a("Relat\xf3rios, turnos e programa\xe7\xe3o identificam as zonas pelo nome; nomes repetidos deixam os resultados amb\xedguos.","Reports, system flows and the schedule identify the zones by name; repeated names make the results ambiguous.","Los informes, los turnos y la programaci\xf3n identifican las zonas por el nombre; los nombres repetidos hacen ambiguos los resultados.")
B.BH=new A.a("D\xea um nome diferente a cada zona nas propriedades da v\xe1lvula, ou deixe a corre\xe7\xe3o numer\xe1-las.","Give each zone a different name in the valve properties, or let the correction number them.","D\xe9 un nombre distinto a cada zona en las propiedades de la v\xe1lvula, o deje que la correcci\xf3n las numere.")
B.CT=new A.a("Tubos que se cruzam sem um v\xe9rtice comum n\xe3o est\xe3o ligados, como na obra, onde um passa por cima do outro. Se deviam se conectar, falta a jun\xe7\xe3o.","Pipes that cross without a shared vertex are not joined, as on site, where one passes over the other. If they should connect, the junction is missing.","Las tuber\xedas que se cruzan sin un v\xe9rtice com\xfan no est\xe1n unidas, como en obra, donde una pasa por encima de la otra. Si deb\xedan conectarse, falta el nudo.")
B.uB=new A.a('Se \xe9 uma conex\xe3o (t\xea ou cruzeta), use "Conectar os tubos no cruzamento". Se um s\xf3 passa sobre o outro, est\xe1 certo e o aviso pode ser ignorado.','If it is a connection (a tee or a cross), use "Connect the pipes at the crossing". If one only passes over the other, that is right and the warning can be ignored.','Si es una conexi\xf3n (te o cruz), use "Conectar las tuber\xedas en el cruce". Si una solo pasa sobre la otra, es correcto y el aviso se puede ignorar.')
B.hz=new A.a("Uma ponta da linha principal n\xe3o chega a nenhuma v\xe1lvula, fonte ou emissor: o tubo termina no vazio. Ele n\xe3o leva \xe1gua a lugar nenhum, mas entra no custo.","An end of the mainline reaches no valve, supply or emitter: the pipe ends in the void. It takes water nowhere but adds to the cost.","Un extremo de la l\xednea principal no llega a ninguna v\xe1lvula, fuente ni emisor: la tuber\xeda termina en el vac\xedo. No lleva agua a ninguna parte, pero suma al costo.")
B.u1=new A.a("Ligue a ponta \xe0 v\xe1lvula ou \xe0 fonte que ela devia alcan\xe7ar, ou apague o trecho que sobra. Se o projeto ainda n\xe3o tem fonte, essa ponta costuma ser o lugar dela.","Join the end to the valve or supply it should reach, or delete the leftover piece. If the design has no supply yet, that end is usually where it goes.","Una el extremo a la v\xe1lvula o a la fuente a la que deb\xeda llegar, o borre el tramo sobrante. Si el dise\xf1o a\xfan no tiene fuente, ese extremo suele ser su lugar.")
B.yu=new A.a("Um tubo da zona termina sem lateral nem emissor na ponta. \xc0s vezes \xe9 proposital (ponto de lavagem), \xe0s vezes \xe9 um trecho esquecido.","A zone pipe ends without a lateral or emitter at its end. Sometimes on purpose (a flushing point), sometimes a forgotten piece.","Una tuber\xeda de la zona termina sin lateral ni emisor en el extremo. A veces es a prop\xf3sito (punto de lavado), a veces es un tramo olvidado.")
B.yt=new A.a("Se ele n\xe3o serve para nada, encurte ou apague o trecho para economizar tubo.","If it serves no purpose, shorten or delete it to save pipe.","Si no sirve para nada, ac\xf3rtela o b\xf3rrela para ahorrar tuber\xeda.")
B.vl=new A.a("A v\xe1lvula n\xe3o alimenta nenhum emissor: sem vaz\xe3o n\xe3o h\xe1 o que dimensionar, e a zona fica vazia nos resultados.","The valve feeds no emitter: with no flow there is nothing to size, and the zone stays empty in the results.","La v\xe1lvula no alimenta ning\xfan emisor: sin caudal no hay nada que dimensionar y la zona queda vac\xeda en los resultados.")
B.z5=new A.a('Confira se os tubos e laterais da zona tocam a v\xe1lvula (sa\xedda da v\xe1lvula = in\xedcio da linha de deriva\xe7\xe3o). Use "Mostrar no desenho" e ligue-os, ou apague a v\xe1lvula se a zona n\xe3o existe.','Check that the zone pipes and laterals touch the valve (valve outlet = start of the submain). Use "Show on the drawing" and join them, or delete the valve if the zone does not exist.','Compruebe que las tuber\xedas y laterales de la zona tocan la v\xe1lvula (salida de la v\xe1lvula = inicio de la secundaria). Use "Mostrar en el dibujo" y \xfanalos, o borre la v\xe1lvula si la zona no existe.')
B.Cc=new A.a("Uma \xe1rea irrigada foi desenhada, mas n\xe3o tem emissores dentro; ela entra no balan\xe7o h\xeddrico sem ser irrigada.","An irrigated area was drawn but has no emitters inside; it enters the water balance without being irrigated.","Se dibuj\xf3 un \xe1rea regada pero no tiene emisores dentro; entra en el balance h\xeddrico sin ser regada.")
B.kh=new A.a("Gere um Bloco de laterais (B) ou uma Grade de aspersores dentro da \xe1rea, ou apague a \xe1rea se ela \xe9 s\xf3 refer\xeancia.","Generate a Lateral block (B) or a Sprinkler grid inside the area, or delete the area if it is only a reference.","Genere un Bloque de laterales (B) o una Malla de aspersores dentro del \xe1rea, o borre el \xe1rea si es solo referencia.")
B.yS=new A.a("O item aponta para um modelo que n\xe3o est\xe1 no cat\xe1logo do projeto (apagado, ou vindo de outro arquivo). Sem as curvas do modelo n\xe3o \xe9 poss\xedvel calcular.","The item points to a model that is not in the project catalogue (deleted, or coming from another file). Without the model curves it cannot be calculated.","El elemento apunta a un modelo que no est\xe1 en el cat\xe1logo del proyecto (borrado o venido de otro archivo). Sin las curvas del modelo no se puede calcular.")
B.q0=new A.a("Escolha um modelo nas propriedades do item, ou use a corre\xe7\xe3o, que aplica um modelo do cat\xe1logo (nos tubos, o di\xe2metro passa a ser escolhido pelo c\xe1lculo).","Pick a model in the item properties, or use the correction, which applies a catalogue model (for pipes, the design then chooses the diameter).","Elija un modelo en las propiedades del elemento, o use la correcci\xf3n, que aplica un modelo del cat\xe1logo (en las tuber\xedas, el di\xe1metro pasa a elegirlo el c\xe1lculo).")
B.uQ=new A.a("A fonte est\xe1 com press\xe3o fixa igual a zero: \xe9 como uma caixa d'\xe1gua no n\xedvel do ch\xe3o, sem bomba. Quase nunca \xe9 o que se quer, e todas as v\xe1lvulas ficar\xe3o sem press\xe3o.","The supply has a fixed pressure of zero: like a tank at ground level with no pump. It is hardly ever what you want, and every valve will lack pressure.","La fuente tiene presi\xf3n fija igual a cero: como un tanque a nivel del suelo, sin bomba. Casi nunca es lo que se quiere, y todas las v\xe1lvulas quedar\xe1n sin presi\xf3n.")
B.AA=new A.a('Informe a press\xe3o real da fonte (rede p\xfablica, por exemplo 25 m.c.a.) ou marque "Calcular press\xe3o necess\xe1ria" para o programa dizer quanto \xe9 preciso.','Enter the real supply pressure (public mains, e.g. 25 m of head) or tick "Calculate required pressure" so the program tells you how much is needed.','Ingrese la presi\xf3n real de la fuente (red p\xfablica, por ejemplo 25 m.c.a.) o marque "Calcular presi\xf3n necesaria" para que el programa diga cu\xe1nta se necesita.')
B.pZ=new A.a("A linha principal forma um anel. O solver de rede calcula an\xe9is corretamente; s\xf3 o dimensionamento por programa\xe7\xe3o linear usa uma aproxima\xe7\xe3o em \xe1rvore, conferida depois pela an\xe1lise.","The mainline forms a loop. The network solver handles loops correctly; only the linear-programming sizing uses a tree approximation, checked afterwards by the analysis.","La l\xednea principal forma un anillo. El solver de red calcula anillos correctamente; solo el dimensionamiento por programaci\xf3n lineal usa una aproximaci\xf3n en \xe1rbol, verificada despu\xe9s por el an\xe1lisis.")
B.wN=new A.a("Nada a fazer se o anel \xe9 intencional (ele distribui melhor a press\xe3o). Se n\xe3o \xe9, remova o trecho que fecha o anel.","Nothing to do if the loop is intended (it spreads the pressure better). If it is not, remove the piece that closes the loop.","Nada que hacer si el anillo es intencional (reparte mejor la presi\xf3n). Si no lo es, quite el tramo que cierra el anillo.")
B.y4=new A.a("Sem curvas de n\xedvel nem cotas, o terreno \xe9 considerado plano. Em \xe1reas com desn\xedvel, subidas e descidas mudam muito a press\xe3o nos emissores.","Without contours or spot heights the ground is taken as flat. On sloping land, rises and falls change the emitter pressures a lot.","Sin curvas de nivel ni cotas, el terreno se considera plano. En terrenos con desnivel, las subidas y bajadas cambian mucho la presi\xf3n en los emisores.")
B.y_=new A.a("Baixe a eleva\xe7\xe3o da internet (Projeto \u2192 Terreno), importe um GeoTIFF ou DXF com curvas, ou digite algumas cotas. Em terreno plano de verdade, pode ignorar.","Download the elevation from the internet (Design \u2192 Terrain), import a GeoTIFF or a DXF with contours, or type a few spot heights. On truly flat ground you can ignore it.","Descargue la elevaci\xf3n de internet (Dise\xf1o \u2192 Terreno), importe un GeoTIFF o un DXF con curvas, o escriba algunas cotas. En terreno realmente plano puede ignorarlo.")
B.yE=new A.a("O c\xe1lculo hidr\xe1ulico n\xe3o chegou a uma solu\xe7\xe3o est\xe1vel, geralmente por dados extremos: tubo min\xfasculo com vaz\xe3o enorme, bomba muito fora da faixa ou valores zerados.","The hydraulic calculation did not reach a stable solution, usually because of extreme data: a tiny pipe with a huge flow, a pump far outside its range, or zero values.","El c\xe1lculo hidr\xe1ulico no lleg\xf3 a una soluci\xf3n estable, normalmente por datos extremos: tuber\xeda diminuta con caudal enorme, bomba muy fuera de rango o valores en cero.")
B.mM=new A.a("Resolva primeiro os outros erros da lista (principalmente itens desconectados e modelos faltando) e calcule de novo. Procure di\xe2metros e press\xf5es absurdos nas propriedades.","First solve the other errors in the list (mainly unconnected items and missing models) and run again. Look for absurd diameters and pressures in the properties.","Resuelva primero los otros errores de la lista (sobre todo elementos desconectados y modelos faltantes) y calcule de nuevo. Busque di\xe1metros y presiones absurdos en las propiedades.")
B.of=new A.a("Os emissores da zona precisam trabalhar numa faixa de press\xe3o (a janela). Mesmo com os maiores tubos permitidos, a perda de carga ou o desn\xedvel deixam algum emissor fora dela: a zona \xe9 longa ou inclinada demais, ou a press\xe3o pedida est\xe1 fora da faixa do bocal.","The emitters of the zone must work within a pressure range (the window). Even with the largest pipes allowed, friction loss or the slope leave some emitter outside it: the zone is too long or too steep, or the pressure asked is outside the nozzle range.","Los emisores de la zona deben trabajar en un rango de presi\xf3n (la ventana). Incluso con las mayores tuber\xedas permitidas, la p\xe9rdida de carga o el desnivel dejan alg\xfan emisor fuera: la zona es demasiado larga o empinada, o la presi\xf3n pedida est\xe1 fuera del rango de la boquilla.")
B.C8=new A.a("Tente, nesta ordem: deixar o c\xe1lculo escolher os di\xe2metros; dividir a zona em duas v\xe1lvulas; alimentar as laterais pelo meio; usar emissores autocompensantes; habilitar tubos maiores no cat\xe1logo.","Try, in this order: let the design choose the diameters; split the zone into two valves; feed the laterals from the middle; use pressure-compensating emitters; enable larger pipes in the catalogue.","Pruebe, en este orden: dejar que el c\xe1lculo elija los di\xe1metros; dividir la zona en dos v\xe1lvulas; alimentar los laterales por el centro; usar emisores autocompensantes; habilitar tuber\xedas mayores en el cat\xe1logo.")
B.jf=new A.a("Algum emissor recebe mais press\xe3o do que o bocal suporta, o que \xe9 comum em zonas morro abaixo, onde cada metro de descida soma press\xe3o. Isso aumenta a vaz\xe3o, o tamanho das gotas e o desgaste.","Some emitter gets more pressure than the nozzle stands, which is common in downhill zones, where every metre of fall adds pressure. It raises the flow, the droplet size and the wear.","Alg\xfan emisor recibe m\xe1s presi\xf3n de la que soporta la boquilla, algo com\xfan en zonas cuesta abajo, donde cada metro de bajada suma presi\xf3n. Eso aumenta el caudal, el tama\xf1o de gota y el desgaste.")
B.yq=new A.a("Divida a zona por faixas de altitude, use emissores autocompensantes ou reguladores de press\xe3o nas laterais, ou reduza a press\xe3o na v\xe1lvula.","Split the zone by elevation bands, use pressure-compensating emitters or pressure regulators on the laterals, or lower the pressure at the valve.","Divida la zona por franjas de altitud, use emisores autocompensantes o reguladores de presi\xf3n en los laterales, o reduzca la presi\xf3n en la v\xe1lvula.")
B.xV=new A.a("A \xe1gua passa r\xe1pido demais neste tubo (acima do limite dos par\xe2metros, em geral 1,5 a 2 m/s). Velocidade alta gasta press\xe3o, aumenta o golpe de ar\xedete e desgasta o tubo.","Water runs too fast in this pipe (above the limit in the parameters, usually 1.5 to 2 m/s). High velocity wastes pressure, increases water hammer and wears the pipe.","El agua pasa demasiado r\xe1pido por esta tuber\xeda (por encima del l\xedmite de los par\xe1metros, en general 1,5 a 2 m/s). La velocidad alta gasta presi\xf3n, aumenta el golpe de ariete y desgasta la tuber\xeda.")
B.uP=new A.a("Deixe o c\xe1lculo escolher o di\xe2metro (se voc\xea o fixou) ou use um tubo maior. Se j\xe1 \xe9 o maior do cat\xe1logo, divida a vaz\xe3o: mais turnos ou mais uma linha.","Let the design choose the diameter (if you fixed it) or use a bigger pipe. If it is already the largest in the catalogue, split the flow: more system flows or another line.","Deje que el c\xe1lculo elija el di\xe1metro (si usted lo fij\xf3) o use una tuber\xeda mayor. Si ya es la mayor del cat\xe1logo, divida el caudal: m\xe1s turnos u otra l\xednea.")
B.qw=new A.a("A press\xe3o de trabalho passa da classe (PN) do tubo, que pode estourar. Acontece perto de bombas fortes ou no ponto mais baixo do terreno.","The working pressure exceeds the class (PN) of the pipe, which may burst. It happens near strong pumps or at the lowest point of the ground.","La presi\xf3n de trabajo supera la clase (PN) de la tuber\xeda, que puede reventar. Pasa cerca de bombas fuertes o en el punto m\xe1s bajo del terreno.")
B.mO=new A.a("Use um tubo de classe maior no mesmo di\xe2metro (a corre\xe7\xe3o escolhe o mais barato que aguenta), ou reduza a press\xe3o: bomba menor ou v\xe1lvula redutora.","Use a higher-class pipe of the same diameter (the correction picks the cheapest that withstands it), or lower the pressure: a smaller pump or a pressure-reducing valve.","Use una tuber\xeda de clase mayor en el mismo di\xe1metro (la correcci\xf3n elige la m\xe1s barata que resiste), o reduzca la presi\xf3n: bomba menor o v\xe1lvula reductora.")
B.x8=new A.a("Ao fechar uma v\xe1lvula r\xe1pido, a \xe1gua em movimento para de repente e gera um pico de press\xe3o (golpe de ar\xedete). Somado \xe0 press\xe3o normal, ele passa da classe do tubo.","Closing a valve fast stops the moving water suddenly and causes a pressure spike (water hammer). Added to the normal pressure it exceeds the pipe class.","Al cerrar una v\xe1lvula r\xe1pido, el agua en movimiento se detiene de golpe y genera un pico de presi\xf3n (golpe de ariete). Sumado a la presi\xf3n normal, supera la clase de la tuber\xeda.")
B.zX=new A.a("Use tubo de classe maior, feche as v\xe1lvulas mais devagar (tempo de fechamento nos par\xe2metros) ou reduza a velocidade com um tubo mais largo.","Use a higher-class pipe, close the valves more slowly (closure time in the parameters) or lower the velocity with a wider pipe.","Use tuber\xeda de clase mayor, cierre las v\xe1lvulas m\xe1s despacio (tiempo de cierre en los par\xe1metros) o reduzca la velocidad con una tuber\xeda m\xe1s ancha.")
B.nM=new A.a("A vaz\xe3o da zona est\xe1 fora da faixa da v\xe1lvula escolhida: pequena demais, ela perde muita press\xe3o; grande demais, n\xe3o regula bem.","The zone flow is outside the range of the chosen valve: too small a valve loses a lot of pressure; too big a valve does not regulate well.","El caudal de la zona est\xe1 fuera del rango de la v\xe1lvula elegida: si es peque\xf1a pierde mucha presi\xf3n; si es grande no regula bien.")
B.jn=new A.a("Troque a v\xe1lvula por uma do tamanho certo (a corre\xe7\xe3o escolhe a menor que atende).","Change the valve to the right size (the correction picks the smallest that fits).","Cambie la v\xe1lvula por una del tama\xf1o correcto (la correcci\xf3n elige la menor que sirve).")
B.u_=new A.a("A press\xe3o que chega \xe0 v\xe1lvula \xe9 menor que a que a zona precisa: a fonte n\xe3o tem press\xe3o para vencer a perda na linha principal e o desn\xedvel at\xe9 a zona.","The pressure reaching the valve is lower than the zone needs: the supply does not have the pressure to overcome the mainline loss and the rise to the zone.","La presi\xf3n que llega a la v\xe1lvula es menor que la que necesita la zona: la fuente no tiene presi\xf3n para vencer la p\xe9rdida en la l\xednea principal y el desnivel hasta la zona.")
B.mC=new A.a("Coloque ou troque a bomba (a corre\xe7\xe3o escolhe uma para a vaz\xe3o e a press\xe3o), use tubos maiores na linha principal ou divida os turnos. Se a press\xe3o da fonte foi s\xf3 um palpite, deixe o programa calcul\xe1-la.","Add or change the pump (the correction picks one for the flow and the pressure), use larger mainline pipes or split the system flows. If the supply pressure was only a guess, let the program calculate it.","Coloque o cambie la bomba (la correcci\xf3n elige una para el caudal y la presi\xf3n), use tuber\xedas mayores en la l\xednea principal o divida los turnos. Si la presi\xf3n de la fuente era solo una estimaci\xf3n, deje que el programa la calcule.")
B.Dz=new A.a("O piv\xf4 precisa de uma press\xe3o na entrada para que o \xfaltimo aspersor funcione; a linha principal entrega menos que isso.","The pivot needs an inlet pressure so that the last sprinkler works; the mainline delivers less than that.","El pivote necesita una presi\xf3n de entrada para que funcione el \xfaltimo aspersor; la l\xednea principal entrega menos.")
B.l9=new A.a("Escolha uma bomba adequada, aumente o di\xe2metro da adutora ou confira a press\xe3o de ponta pedida nas propriedades do piv\xf4.","Choose a suitable pump, increase the diameter of the supply main or check the end pressure asked in the pivot properties.","Elija una bomba adecuada, aumente el di\xe1metro de la aductora o revise la presi\xf3n de punta pedida en las propiedades del pivote.")
B.CQ=new A.a("O turno pede mais vaz\xe3o do que a fonte fornece (a vaz\xe3o de projeto da fonte). Na pr\xe1tica faltaria \xe1gua e as press\xf5es cairiam.","The system flow asks for more flow than the supply gives (its design flow). In practice the water would run short and the pressures would drop.","El turno pide m\xe1s caudal del que da la fuente (su caudal de dise\xf1o). En la pr\xe1ctica faltar\xeda agua y las presiones bajar\xedan.")
B.Bj=new A.a("Divida as zonas em mais turnos (a corre\xe7\xe3o reagrupa para que nenhum passe da vaz\xe3o da fonte), ou aumente a vaz\xe3o da fonte se ela realmente comporta.","Split the zones into more system flows (the correction regroups them so that none exceeds the supply flow), or raise the supply flow if it really allows it.","Divida las zonas en m\xe1s turnos (la correcci\xf3n las reagrupa para que ninguno supere el caudal de la fuente), o aumente el caudal de la fuente si realmente lo permite.")
B.un=new A.a("Para atender todas as v\xe1lvulas, a fonte precisaria de mais press\xe3o do que o m\xe1ximo informado para ela.","To serve every valve the supply would need more pressure than the maximum entered for it.","Para atender todas las v\xe1lvulas, la fuente necesitar\xeda m\xe1s presi\xf3n que el m\xe1ximo indicado para ella.")
B.t4=new A.a("Coloque uma bomba (booster) depois da fonte, use tubos maiores ou divida os turnos para reduzir a perda de carga.","Add a booster pump after the supply, use larger pipes or split the system flows to reduce the friction loss.","Coloque una bomba (booster) despu\xe9s de la fuente, use tuber\xedas mayores o divida los turnos para reducir la p\xe9rdida de carga.")
B.BJ=new A.a("A bomba trabalha fora da faixa de vaz\xe3o da sua curva: pequena demais, n\xe3o entrega a vaz\xe3o; grande demais, trabalha perto do fechamento e desperdi\xe7a energia.","The pump works outside the flow range of its curve: too small, it cannot deliver the flow; too big, it runs near shut-off and wastes energy.","La bomba trabaja fuera del rango de caudal de su curva: si es peque\xf1a, no entrega el caudal; si es grande, trabaja cerca del cierre y desperdicia energ\xeda.")
B.Cr=new A.a("Escolha uma bomba adequada: a corre\xe7\xe3o compara as bombas do cat\xe1logo e fica com a de menor custo de compra + energia que atende todos os turnos.","Choose a suitable pump: the correction compares the catalogue pumps and keeps the one with the lowest purchase + energy cost that serves every system flow.","Elija una bomba adecuada: la correcci\xf3n compara las bombas del cat\xe1logo y se queda con la de menor costo de compra + energ\xeda que atiende todos los turnos.")
B.qE=new A.a("Uma bomba de superf\xedcie puxa a \xe1gua por v\xe1cuo, e a press\xe3o atmosf\xe9rica s\xf3 empurra a \xe1gua at\xe9 uns 10 m; na pr\xe1tica, com perdas e o NPSH, o limite \xe9 uns 7 m ao n\xedvel do mar (menos em altitude). Al\xe9m disso a bomba cavita ou perde a escorva.","A surface pump pulls the water through a vacuum, and the atmospheric pressure only pushes water up about 10 m; in practice, with losses and the NPSH, the limit is about 7 m at sea level (less at altitude). Beyond it the pump cavitates or loses its prime.","Una bomba de superficie succiona el agua por vac\xedo, y la presi\xf3n atmosf\xe9rica solo empuja el agua unos 10 m; en la pr\xe1ctica, con p\xe9rdidas y el NPSH, el l\xedmite es unos 7 m a nivel del mar (menos en altitud). M\xe1s all\xe1 la bomba cavita o pierde el cebado.")
B.t7=new A.a("Use uma bomba submersa dentro do po\xe7o, ou instale a bomba de superf\xedcie mais perto do n\xedvel da \xe1gua. A press\xe3o negativa na entrada da bomba \xe9 essa altura de suc\xe7\xe3o.","Use a submersible pump inside the well, or install the surface pump closer to the water level. The negative pressure at the pump inlet is that suction lift.","Use una bomba sumergible dentro del pozo, o instale la bomba de superficie m\xe1s cerca del nivel del agua. La presi\xf3n negativa en la entrada de la bomba es esa altura de succi\xf3n.")
B.jC=new A.a("Duas zonas est\xe3o ligadas por tubo sem v\xe1lvula entre elas: a \xe1gua de uma passa para a outra e o programa n\xe3o consegue separ\xe1-las.","Two zones are joined by pipe without a valve between them: the water of one flows into the other and the program cannot tell them apart.","Dos zonas est\xe1n unidas por tuber\xeda sin v\xe1lvula entre ellas: el agua de una pasa a la otra y el programa no puede separarlas.")
B.uF=new A.a("Corte o tubo que liga as zonas (ferramenta Cortar tubo). Se na verdade s\xe3o uma zona s\xf3, apague uma das v\xe1lvulas.","Cut the pipe that joins the zones (Cut pipe tool). If they really are a single zone, delete one of the valves.","Corte la tuber\xeda que une las zonas (herramienta Cortar tuber\xeda). Si en realidad son una sola zona, borre una de las v\xe1lvulas.")
B.jP=new A.a("Com os tubos habilitados no cat\xe1logo, nenhuma combina\xe7\xe3o atende todas as press\xf5es ao mesmo tempo; o programa usou o m\xe9todo guloso (aumenta os tubos passo a passo), que d\xe1 um bom resultado, mas talvez n\xe3o o mais barato.","With the pipes enabled in the catalogue, no combination meets every pressure at once; the program used the greedy method (upsizing step by step), which gives a good result but perhaps not the cheapest.","Con las tuber\xedas habilitadas en el cat\xe1logo, ninguna combinaci\xf3n cumple todas las presiones a la vez; el programa us\xf3 el m\xe9todo voraz (aumenta las tuber\xedas paso a paso), que da un buen resultado, pero quiz\xe1 no el m\xe1s barato.")
B.uY=new A.a("Habilite di\xe2metros maiores no cat\xe1logo, aumente o n\xfamero de di\xe2metros por linha nos par\xe2metros ou reduza a exig\xeancia de press\xe3o (zonas menores).","Enable larger diameters in the catalogue, raise the number of diameters per line in the parameters or reduce the pressure demand (smaller zones).","Habilite di\xe1metros mayores en el cat\xe1logo, aumente el n\xfamero de di\xe1metros por l\xednea en los par\xe1metros o reduzca la exigencia de presi\xf3n (zonas menores).")
B.wh=new A.a("A lista de materiais precisa de uma conex\xe3o (luva, joelho, t\xea\u2026) de um tamanho que o cat\xe1logo n\xe3o tem; ela fica sem pre\xe7o.","The bill of materials needs a fitting (coupler, elbow, tee\u2026) of a size the catalogue lacks; it stays without a price.","La lista de materiales necesita una conexi\xf3n (manguito, codo, te\u2026) de un tama\xf1o que el cat\xe1logo no tiene; queda sin precio.")
B.n8=new A.a("Adicione as conex\xf5es gen\xe9ricas ao cat\xe1logo (corre\xe7\xe3o) ou cadastre as do seu fornecedor no Cat\xe1logo de componentes.","Add the generic fittings to the catalogue (correction) or enter those of your supplier in the Component catalog.","A\xf1ada las conexiones gen\xe9ricas al cat\xe1logo (correcci\xf3n) o registre las de su proveedor en el Cat\xe1logo de componentes.")
B.lI=new A.a("O piv\xf4 est\xe1 com l\xe2mina ou horas por ciclo iguais a zero, ent\xe3o a vaz\xe3o calculada \xe9 zero.","The pivot has a zero depth or zero hours per cycle, so its computed flow is zero.","El pivote tiene l\xe1mina u horas por ciclo en cero, as\xed que el caudal calculado es cero.")
B.ut=new A.a("Informe a l\xe2mina por ciclo (mm) e as horas por volta nas propriedades do piv\xf4.","Enter the depth per cycle (mm) and the hours per turn in the pivot properties.","Ingrese la l\xe1mina por ciclo (mm) y las horas por vuelta en las propiedades del pivote.")
B.vS=new A.a("Sem a press\xe3o na ponta (\xfaltimo aspersor) n\xe3o d\xe1 para calcular a press\xe3o de entrada do piv\xf4.","Without the end pressure (last sprinkler) the inlet pressure of the pivot cannot be calculated.","Sin la presi\xf3n de punta (\xfaltimo aspersor) no se puede calcular la presi\xf3n de entrada del pivote.")
B.Bc=new A.a("Informe a press\xe3o de ponta nas propriedades do piv\xf4 (t\xedpico: 10 a 20 m.c.a. com reguladores).","Enter the end pressure in the pivot properties (typical: 10 to 20 m of head with regulators).","Ingrese la presi\xf3n de punta en las propiedades del pivote (t\xedpico: 10 a 20 m.c.a. con reguladores).")
B.z4=new A.a("Na ponta, o piv\xf4 aplica \xe1gua mais r\xe1pido do que o solo consegue infiltrar: a \xe1gua escorre e causa eros\xe3o.","At the end the pivot applies water faster than the soil can take it in: the water runs off and causes erosion.","En la punta el pivote aplica agua m\xe1s r\xe1pido de lo que el suelo puede infiltrar: el agua escurre y causa erosi\xf3n.")
B.Di=new A.a("Use aspersores de maior raio molhado na ponta, aumente a velocidade de giro (menos l\xe2mina por volta) ou confira o limite do solo.","Use sprinklers with a larger wetted radius at the end, speed up the rotation (less depth per turn) or check the soil limit.","Use aspersores de mayor radio mojado en la punta, aumente la velocidad de giro (menos l\xe1mina por vuelta) o revise el l\xedmite del suelo.")
B.km=new A.a("Um turno faz refer\xeancia a uma v\xe1lvula que n\xe3o existe mais (foi apagada).","A system flow refers to a valve that no longer exists (it was deleted).","Un turno hace referencia a una v\xe1lvula que ya no existe (fue borrada).")
B.ua=new A.a("Limpe os turnos (corre\xe7\xe3o) ou abra Projeto \u2192 Turnos de opera\xe7\xe3o e retire a v\xe1lvula do turno.","Clean up the system flows (correction) or open Design \u2192 System flows and take the valve out of the flow.","Limpie los turnos (correcci\xf3n) o abra Dise\xf1o \u2192 Turnos de operaci\xf3n y quite la v\xe1lvula del turno.")
B.lb=new A.a("Os limites de velocidade nos par\xe2metros est\xe3o fora da faixa f\xedsica (0,3 a 5 m/s). Zero ou valores enormes tornam o dimensionamento imposs\xedvel ou sem sentido.","The velocity limits in the parameters are outside the physical range (0.3 to 5 m/s). Zero or huge values make the sizing impossible or meaningless.","Los l\xedmites de velocidad de los par\xe1metros est\xe1n fuera del rango f\xedsico (0,3 a 5 m/s). Cero o valores enormes hacen el dimensionamiento imposible o sin sentido.")
B.rU=new A.a("Volte aos valores padr\xe3o (1,5 m/s nas zonas, 2 m/s nas laterais e na linha principal) ou ajuste em Projeto \u2192 Par\xe2metros de projeto.","Restore the defaults (1.5 m/s in zones, 2 m/s in laterals and the mainline) or adjust them in Design \u2192 Design parameters.","Vuelva a los valores por defecto (1,5 m/s en las zonas, 2 m/s en los laterales y en la l\xednea principal) o aj\xfastelos en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.Db=new A.a("As horas de funcionamento por ano est\xe3o fora de 1 a 8760 (o ano tem 8760 h). O custo de energia e a escolha dos tubos pelo custo total dependem delas.","The operating hours per year are outside 1 to 8760 (a year has 8760 h). The energy cost and the choice of pipes by total cost depend on them.","Las horas de funcionamiento por a\xf1o est\xe1n fuera de 1 a 8760 (el a\xf1o tiene 8760 h). El costo de energ\xeda y la elecci\xf3n de tuber\xedas por costo total dependen de ellas.")
B.AZ=new A.a("Volte aos padr\xf5es (2000 h na linha principal, 500 h por zona) ou informe as horas reais em Projeto \u2192 Par\xe2metros de projeto.","Restore the defaults (2000 h for the mainline, 500 h per zone) or enter the real hours in Design \u2192 Design parameters.","Vuelva a los valores por defecto (2000 h en la l\xednea principal, 500 h por zona) o ingrese las horas reales en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.tB=new A.a("Algum par\xe2metro econ\xf4mico \xe9 imposs\xedvel: juros negativos ou acima de 50 % ao ano, prazo fora de 1 a 100 anos, rendimento da bomba fora de 20 a 95 % ou tarifa de energia negativa.","Some economic parameter is impossible: interest negative or above 50 % a year, a term outside 1 to 100 years, a pump efficiency outside 20 to 95 % or a negative energy tariff.","Alg\xfan par\xe1metro econ\xf3mico es imposible: inter\xe9s negativo o mayor que 50 % al a\xf1o, plazo fuera de 1 a 100 a\xf1os, rendimiento de la bomba fuera de 20 a 95 % o tarifa de energ\xeda negativa.")
B.CG=new A.a("Volte aos valores padr\xe3o ou corrija em Projeto \u2192 Par\xe2metros de projeto.","Restore the defaults or correct them in Design \u2192 Design parameters.","Vuelva a los valores por defecto o corr\xedjalos en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.u4=new A.a("A toler\xe2ncia de conex\xe3o diz a que dist\xe2ncia dois pontos contam como ligados. Zero n\xe3o liga nada; valores grandes (mais de 1 m) ligam coisas que deviam estar separadas.","The connection tolerance says how close two points must be to count as joined. Zero joins nothing; large values (over 1 m) join things that should stay apart.","La tolerancia de conexi\xf3n dice a qu\xe9 distancia dos puntos cuentan como unidos. Cero no une nada; valores grandes (m\xe1s de 1 m) unen cosas que deber\xedan estar separadas.")
B.C_=new A.a("Volte ao padr\xe3o (5 cm) em Projeto \u2192 Par\xe2metros de projeto.","Restore the default (5 cm) in Design \u2192 Design parameters.","Vuelva al valor por defecto (5 cm) en Dise\xf1o \u2192 Par\xe1metros de dise\xf1o.")
B.nG=new A.a("A varia\xe7\xe3o m\xe1xima de press\xe3o na zona est\xe1 fora de 0 a 60 %. Os crit\xe9rios usuais ficam entre 10 e 20 % (cerca de \xb110 % na vaz\xe3o).","The maximum pressure variation in the zone is outside 0 to 60 %. The usual criteria are 10 to 20 % (about \xb110 % in flow).","La variaci\xf3n m\xe1xima de presi\xf3n en la zona est\xe1 fuera de 0 a 60 %. Los criterios usuales est\xe1n entre 10 y 20 % (cerca de \xb110 % en el caudal).")
B.yk=new A.a("Volte ao padr\xe3o (0 = usa a faixa de press\xe3o do emissor) ou informe 20 %.","Restore the default (0 = use the pressure range of the emitter) or enter 20 %.","Vuelva al valor por defecto (0 = usa el rango de presi\xf3n del emisor) o ingrese 20 %.")
B.tF=new A.a("A temperatura da \xe1gua est\xe1 fora de 0 a 60 \xb0C; ela muda a viscosidade usada na perda de carga (Darcy-Weisbach).","The water temperature is outside 0 to 60 \xb0C; it changes the viscosity used in the friction loss (Darcy-Weisbach).","La temperatura del agua est\xe1 fuera de 0 a 60 \xb0C; cambia la viscosidad usada en la p\xe9rdida de carga (Darcy-Weisbach).")
B.Ct=new A.a("Volte ao padr\xe3o (20 \xb0C).","Restore the default (20 \xb0C).","Vuelva al valor por defecto (20 \xb0C).")
B.n6=new A.a("O cat\xe1logo n\xe3o tem nenhum tubo habilitado para este uso (laterais, zona ou linha principal), ent\xe3o o c\xe1lculo n\xe3o tem di\xe2metro para escolher.","The catalogue has no pipe enabled for this use (laterals, zone or mainline), so the design has no diameter to choose.","El cat\xe1logo no tiene ninguna tuber\xeda habilitada para este uso (laterales, zona o l\xednea principal), as\xed que el c\xe1lculo no tiene di\xe1metro que elegir.")
B.jN=new A.a("Habilite tubos no Cat\xe1logo de componentes ou use a corre\xe7\xe3o, que reativa os tubos padr\xe3o desse uso.","Enable pipes in the Component catalog or use the correction, which re-enables the default pipes of that use.","Habilite tuber\xedas en el Cat\xe1logo de componentes o use la correcci\xf3n, que reactiva las tuber\xedas por defecto de ese uso.")
B.mh=new A.a("Na fonte, a press\xe3o ou a vaz\xe3o de projeto \xe9 maior que o m\xe1ximo informado: um dos valores est\xe1 trocado ou foi digitado errado.","At the supply, the design pressure or flow is higher than the maximum entered: one of the values is swapped or mistyped.","En la fuente, la presi\xf3n o el caudal de dise\xf1o es mayor que el m\xe1ximo indicado: uno de los valores est\xe1 cambiado o mal escrito.")
B.mx=new A.a("Confira os valores nas propriedades da fonte; a corre\xe7\xe3o iguala o m\xe1ximo ao valor de projeto.","Check the values in the supply properties; the correction sets the maximum to the design value.","Revise los valores en las propiedades de la fuente; la correcci\xf3n iguala el m\xe1ximo al valor de dise\xf1o.")
B.xf=new A.a("H\xe1 turnos definidos, mas estas zonas n\xe3o est\xe3o em nenhum: elas nunca abrem na simula\xe7\xe3o da linha principal e ficam fora da press\xe3o e da energia calculadas.","System flows are defined, but these zones are in none: they never open in the mainline simulation and are left out of the pressures and energy computed.","Hay turnos definidos, pero estas zonas no est\xe1n en ninguno: nunca abren en la simulaci\xf3n de la l\xednea principal y quedan fuera de la presi\xf3n y la energ\xeda calculadas.")
B.iF=new A.a("Inclua as zonas num turno em Projeto \u2192 Turnos de opera\xe7\xe3o, ou use a corre\xe7\xe3o, que cria um turno novo para elas.","Put the zones in a flow in Design \u2192 System flows, or use the correction, which creates a new flow for them.","Incluya las zonas en un turno en Dise\xf1o \u2192 Turnos de operaci\xf3n, o use la correcci\xf3n, que crea un turno nuevo para ellas.")
B.ym=new A.a("H\xe1 turnos sem nenhuma zona (vazios ou s\xf3 com v\xe1lvulas apagadas): eles n\xe3o fazem nada e confundem a programa\xe7\xe3o.","Some system flows have no zone (empty or with deleted valves only): they do nothing and confuse the schedule.","Hay turnos sin ninguna zona (vac\xedos o solo con v\xe1lvulas borradas): no hacen nada y confunden la programaci\xf3n.")
B.hZ=new A.a("Limpe os turnos (corre\xe7\xe3o) ou inclua zonas neles em Projeto \u2192 Turnos de opera\xe7\xe3o.","Clean up the system flows (correction) or put zones in them in Design \u2192 System flows.","Limpie los turnos (correcci\xf3n) o incluya zonas en ellos en Dise\xf1o \u2192 Turnos de operaci\xf3n.")
B.xB=new A.a("Um turno com dura\xe7\xe3o zero ou negativa n\xe3o irriga e zera a energia daquele turno.","A system flow with a zero or negative duration irrigates nothing and zeroes its energy.","Un turno con duraci\xf3n cero o negativa no riega y deja en cero la energ\xeda de ese turno.")
B.nv=new A.a("Informe a dura\xe7\xe3o de cada turno (horas) em Projeto \u2192 Turnos de opera\xe7\xe3o; a corre\xe7\xe3o define 1 h.","Enter the duration of each flow (hours) in Design \u2192 System flows; the correction sets 1 h.","Ingrese la duraci\xf3n de cada turno (horas) en Dise\xf1o \u2192 Turnos de operaci\xf3n; la correcci\xf3n define 1 h.")
B.yZ=new A.a("A press\xe3o de trabalho pedida para o emissor est\xe1 fora da faixa do bocal (m\xednima e m\xe1xima do cat\xe1logo). Assim nenhum tubo consegue deixar a zona dentro da janela de press\xe3o: a zona fica imposs\xedvel.","The working pressure asked for the emitter is outside the nozzle range (catalogue minimum and maximum). Then no pipe can keep the zone inside its pressure window: the zone becomes impossible.","La presi\xf3n de trabajo pedida para el emisor est\xe1 fuera del rango de la boquilla (m\xednima y m\xe1xima del cat\xe1logo). As\xed ninguna tuber\xeda puede dejar la zona dentro de la ventana de presi\xf3n: la zona se vuelve imposible.")
B.Bt=new A.a("Use a press\xe3o nominal do bocal (corre\xe7\xe3o) ou escolha outro bocal ou emissor feito para a press\xe3o desejada.","Use the nominal pressure of the nozzle (correction) or choose another nozzle or emitter made for the pressure you want.","Use la presi\xf3n nominal de la boquilla (correcci\xf3n) o elija otra boquilla o emisor hecho para la presi\xf3n deseada.")
B.ml=new A.a("A rota\xe7\xe3o relativa da bomba est\xe1 fora de 40 a 130 % da nominal; pelas leis de afinidade, a curva vira algo que a bomba real n\xe3o faz.","The relative pump speed is outside 40 to 130 % of the rated one; by the affinity laws the curve becomes something the real pump cannot do.","La velocidad relativa de la bomba est\xe1 fuera de 40 a 130 % de la nominal; por las leyes de afinidad, la curva se vuelve algo que la bomba real no hace.")
B.pp=new A.a("Volte \xe0 rota\xe7\xe3o nominal (1,0) ou use o inversor de frequ\xeancia s\xf3 dentro da faixa do fabricante.","Go back to the rated speed (1.0) or use a variable-speed drive only within the range of the manufacturer.","Vuelva a la velocidad nominal (1,0) o use el variador de frecuencia solo dentro del rango del fabricante.")
B.ou=new A.a("Verifica\xe7\xe3o do projeto\u2026","Design check\u2026","Verificaci\xf3n del dise\xf1o\u2026")
B.nX=new A.a("Cat\xe1logos de fabricantes\u2026","Manufacturer catalogues\u2026","Cat\xe1logos de fabricantes\u2026")
B.A3=new A.a("Produtos com os dados das tabelas publicadas pelos fabricantes (vaz\xe3o, expoente, raio, faixa de press\xe3o, perda de carga) e os documentos de origem de cada pacote. Os pre\xe7os ficam em zero: exporte para Excel, preencha com a tabela local e importe de volta. Confirme sempre na folha de dados atual.","Products with the data of the manufacturers' published tables (flow, exponent, radius, pressure range, head loss) and the source documents of each pack. Prices are left at zero: export to Excel, fill in the local price list and import it back. Always confirm with the current data sheet.","Productos con los datos de las tablas publicadas por los fabricantes (caudal, exponente, radio, rango de presi\xf3n, p\xe9rdida de carga) y los documentos de origen de cada paquete. Los precios quedan en cero: exporte a Excel, complete con la lista local e importe de vuelta. Confirme siempre con la hoja de datos vigente.")
B.Ch=new A.a("Adicionar","Add","A\xf1adir")
B.zB=new A.a("{n} itens adicionados de {b}","{n} items added from {b}","{n} \xedtems a\xf1adidos de {b}")
B.ud=new A.a("{n} itens","{n} items","{n} \xedtems")
B.xy=new A.a("Exportar Excel","Export Excel","Exportar Excel")
B.xc=new A.a("Importar (JSON, CSV, Excel)\u2026","Import (JSON, CSV, Excel)\u2026","Importar (JSON, CSV, Excel)\u2026")
B.hT=new A.a("Menu","Menu","Men\xfa")
B.lC=new A.a("Concluir","Done","Terminar")
B.Bs=new A.a("Toque para desenhar \xb7 pin\xe7a para zoom \xb7 dois dedos para mover","Tap to draw \xb7 pinch to zoom \xb7 two fingers to pan","Toque para dibujar \xb7 pellizco para zoom \xb7 dos dedos para mover")
B.pI=new A.a("Navegar","Navigate","Navegar")
B.qA=new A.a("Principal","Mainline","Principal")
B.ks=new A.a("{n} selecionado(s)","{n} selected","{n} seleccionado(s)")
B.j_=new A.a("No celular: bot\xf5es Concluir/Cancelar substituem Enter/Esc; menu \u2630 re\xfane os menus","On a phone: Done/Cancel buttons replace Enter/Esc; the \u2630 menu gathers the menus","En el m\xf3vil: los botones Terminar/Cancelar reemplazan Intro/Esc; el men\xfa \u2630 re\xfane los men\xfas")
B.vP=new A.a("Laterais seguem a linha selecionada ({n}): laterais curvas","Laterals follow the selected line ({n}): curved laterals","Laterales siguen la l\xednea seleccionada ({n}): laterales curvas")
B.xx=new A.a("Hist\xf3rico","History","Historial")
B.z7=new A.a("Clique num passo para voltar (ou avan\xe7ar) no tempo; uma nova edi\xe7\xe3o descarta os passos \xe0 frente.","Click a step to go back (or forward) in time; a new edit discards the steps ahead.","Haga clic en un paso para volver (o avanzar) en el tiempo; una nueva edici\xf3n descarta los pasos siguientes.")
B.iK=new A.a("Estado inicial","Initial state","Estado inicial")
B.ne=new A.a("Edi\xe7\xe3o","Edit","Edici\xf3n")
B.AP=new A.a("Adicionar {n}","Add {n}","A\xf1adir {n}")
B.z6=new A.a("Adicionar {n} itens","Add {n} items","A\xf1adir {n} elementos")
B.tA=new A.a("Excluir {n} item(ns)","Delete {n} item(s)","Eliminar {n} elemento(s)")
B.pv=new A.a("Mover","Move","Mover")
B.mA=new A.a("Espelhar","Mirror","Reflejar")
B.yy=new A.a("Transformar {n} item(ns)","Transform {n} item(s)","Transformar {n} elemento(s)")
B.td=new A.a("Copiar {n} item(ns)","Copy {n} item(s)","Copiar {n} elemento(s)")
B.pk=new A.a("Matriz","Array","Matriz")
B.o0=new A.a("Importar","Import","Importar")
B.ky=new A.a("Projetar (dimensionar)","Design (size pipes)","Dise\xf1ar (dimensionar)")
B.Cs=new A.a("Eleva\xe7\xe3o importada","Elevation imported","Elevaci\xf3n importada")
B.yz=new A.a("Remover cotas pr\xf3prias","Remove own heights","Quitar cotas propias")
B.kL=new A.a("Alinhar","Align","Alinear")
B.ra=new A.a("Lista de materiais na prancha","Bill of materials on the sheet","Lista de materiales en la l\xe1mina")
B.rs=new A.a("Qtd.","Qty","Cant.")
B.jh=new A.a("\u2026 mais {n} itens (ver relat\xf3rio)","\u2026 {n} more items (see report)","\u2026 {n} \xedtems m\xe1s (ver informe)")
B.rE=new A.a("GeoTIFF de eleva\xe7\xe3o: {n} cotas de {w}\xd7{h} px ({crs})","Elevation GeoTIFF: {n} spot heights from {w}\xd7{h} px ({crs})","GeoTIFF de elevaci\xf3n: {n} cotas de {w}\xd7{h} px ({crs})")
B.zh=new A.a("V\xe3os do piv\xf4","Pivot spans","Vanos del pivote")
B.mQ=new A.a("V\xe3o","Span","Vano")
B.jT=new A.a("R inicial","R start","R inicial")
B.CO=new A.a("R final","R end","R final")
B.kQ=new A.a("Aspersores","Sprinklers","Aspersores")
B.u3=new A.a("q por aspersor","q per sprinkler","q por aspersor")
B.hN=new A.a("P no v\xe3o","P at span","P en el vano")
B.j3=new A.a("Bocal sugerido","Suggested nozzle","Boquilla sugerida")
B.iE=new A.a("Espa\xe7amento dos aspersores (m)","Sprinkler spacing (m)","Espaciado de los aspersores (m)")
B.wk=new A.a("Aspersor do piv\xf4 (cat\xe1logo)","Pivot sprinkler (catalogue)","Aspersor del pivote (cat\xe1logo)")
B.CA=new A.a("Regulador de press\xe3o (cat\xe1logo)","Pressure regulator (catalogue)","Regulador de presi\xf3n (cat\xe1logo)")
B.jB=new A.a("Custo por torre","Cost per tower","Costo por torre")
B.vE=new A.a("Aspersores do piv\xf4","Pivot sprinklers","Aspersores del pivote")
B.r9=new A.a("Canh\xe3o final","End gun","Ca\xf1\xf3n final")
B.ns=new A.a("Suavizar curva (spline pelos pontos)","Smooth contour (spline through the points)","Suavizar curva (spline por los puntos)")
B.nF=new A.a("M\xe1x. de pontos","Max. points","M\xe1x. de puntos")
B.pu=new A.a("Motor","Motor","Motor")
B.v2=new A.a("Linha principal em anel: o dimensionamento LP usa caminhos em \xe1rvore (aproxima\xe7\xe3o); a an\xe1lise final confere as press\xf5es","Looped mainline: LP sizing uses tree paths (approximation); the final analysis checks the pressures","L\xednea principal en anillo: el dimensionamiento LP usa caminos en \xe1rbol (aproximaci\xf3n); el an\xe1lisis final verifica las presiones")
B.r3=new A.a("Inclu\xeddos no app","Bundled with the app","Incluidos en la app")
B.l0=new A.a("Carregados agora","Loaded now","Cargados ahora")
B.mH=new A.a("Importar pacote (.oci.cat)\u2026","Import pack (.oci.cat)\u2026","Importar paquete (.oci.cat)\u2026")
B.BF=new A.a("URL de um pacote ou de um \xedndice (index.json)","URL of a pack or of an index (index.json)","URL de un paquete o de un \xedndice (index.json)")
B.nx=new A.a("Carregar da URL","Load from URL","Cargar de la URL")
B.Ap=new A.a("Carregando\u2026","Loading\u2026","Cargando\u2026")
B.tH=new A.a("{n} pacote(s) carregado(s)","{n} pack(s) loaded","{n} paquete(s) cargado(s)")
B.mJ=new A.a("N\xe3o foi poss\xedvel carregar: {e}","Could not load: {e}","No se pudo cargar: {e}")
B.xW=new A.a("Exportar pacote .oci.cat\u2026","Export pack .oci.cat\u2026","Exportar paquete .oci.cat\u2026")
B.AB=new A.a("Exportar cat\xe1logo como pacote","Export catalogue as a pack","Exportar cat\xe1logo como paquete")
B.i9=new A.a("Gera um arquivo .oci.cat com os itens deste cat\xe1logo, para compartilhar ou publicar num reposit\xf3rio da comunidade. O formato (JSON aberto) est\xe1 documentado em catalogs/README.md.","Writes an .oci.cat file with the items of this catalogue, to share or publish in a community repository. The format (open JSON) is documented in catalogs/README.md.","Genera un archivo .oci.cat con los \xedtems de este cat\xe1logo, para compartir o publicar en un repositorio de la comunidad. El formato (JSON abierto) est\xe1 documentado en catalogs/README.md.")
B.mI=new A.a("Fabricante","Manufacturer","Fabricante")
B.ld=new A.a("Nome do pacote","Pack name","Nombre del paquete")
B.Dy=new A.a("Descri\xe7\xe3o (linhas de produto)","Description (product lines)","Descripci\xf3n (l\xedneas de producto)")
B.ta=new A.a("Fonte (URL da folha de dados)","Source (data sheet URL)","Fuente (URL de la hoja de datos)")
B.tX=new A.a("Pacote {f} exportado ({n} itens)","Pack {f} exported ({n} items)","Paquete {f} exportado ({n} \xedtems)")
B.Ad=new A.a("Pacotes s\xe3o arquivos JSON abertos (.oci.cat): fabricantes, revendas e a comunidade podem public\xe1-los num reposit\xf3rio e voc\xea os carrega por arquivo ou URL. Formato em catalogs/README.md.","Packs are open JSON files (.oci.cat): manufacturers, dealers and the community can publish them in a repository and you load them from a file or a URL. Format in catalogs/README.md.","Los paquetes son archivos JSON abiertos (.oci.cat): fabricantes, distribuidores y la comunidad pueden publicarlos en un repositorio y usted los carga desde un archivo o una URL. Formato en catalogs/README.md.")
B.w5=new A.a("de {o}","from {o}","de {o}")
B.wx=new A.a("O JSON n\xe3o \xe9 um cat\xe1logo nem um pacote .oci.cat","The JSON is neither a catalogue nor an .oci.cat pack","El JSON no es un cat\xe1logo ni un paquete .oci.cat")
B.zw=new A.a("Este arquivo \xe9 um \xedndice de pacotes, n\xe3o um pacote (carregue-o pela URL)","This file is a pack index, not a pack (load it by URL)","Este archivo es un \xedndice de paquetes, no un paquete (c\xe1rguelo por URL)")
B.Ag=new A.a("O JSON n\xe3o \xe9 um \xedndice de pacotes","The JSON is not a pack index","El JSON no es un \xedndice de paquetes")
B.A8=new A.a("Pacote gravado por uma vers\xe3o mais nova do formato","Pack written by a newer format version","Paquete escrito por una versi\xf3n m\xe1s nueva del formato")
B.By=new A.a("Coordenada do local (lat, lon)","Site coordinate (lat, lon)","Coordenada del sitio (lat, lon)")
B.pa=new A.a("-22.9068, -43.1729 \xb7 link do Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 Google Maps link \xb7 22\xb054'24\"S 43\xb010'22\"W","-22.9068, -43.1729 \xb7 enlace de Google Maps \xb7 22\xb054'24\"S 43\xb010'22\"W")
B.Dq=new A.a("Sem desenho ainda? Cole a coordenada do terreno: a origem do projeto vai para l\xe1 e a eleva\xe7\xe3o \xe9 baixada num quadrado ao redor.","No drawing yet? Paste the site coordinate: the project origin goes there and the elevation is downloaded over a square around it.","\xbfSin dibujo todav\xeda? Pegue la coordenada del terreno: el origen del proyecto va all\xed y la elevaci\xf3n se descarga en un cuadrado alrededor.")
B.zN=new A.a("Usar coordenada","Use coordinate","Usar coordenada")
B.tj=new A.a("Lado da \xe1rea (m)","Area side (m)","Lado del \xe1rea (m)")
B.kD=new A.a("Coordenada n\xe3o reconhecida","Coordinate not recognised","Coordenada no reconocida")
B.hI=new A.a("Gerar curvas de n\xedvel ap\xf3s baixar","Generate contours after downloading","Generar curvas de nivel tras descargar")
B.iz=new A.a("Intervalo (m; 0 = autom\xe1tico)","Interval (m; 0 = automatic)","Intervalo (m; 0 = autom\xe1tico)")
B.CX=new A.a("{n} cotas importadas ({s}); {c} curvas de n\xedvel a cada {i} m","{n} spot heights imported ({s}); {c} contours every {i} m","{n} cotas importadas ({s}); {c} curvas de nivel cada {i} m")
B.zZ=new A.a("Georrefer\xeancia definida em {lat}, {lon} ({crs})","Georeference set at {lat}, {lon} ({crs})","Georreferencia definida en {lat}, {lon} ({crs})")
B.mE=new A.a("Exemplos","Examples","Ejemplos")
B.lm=new A.a("Boas-vindas e galeria de exemplos\u2026","Welcome and example gallery\u2026","Bienvenida y galer\xeda de ejemplos\u2026")
B.Ce=new A.a("Bem-vindo ao OpenCADIrrigation","Welcome to OpenCADIrrigation","Bienvenido a OpenCADIrrigation")
B.D7=new A.a("CAD para projeto de irriga\xe7\xe3o pressurizada, direto no navegador. Comece por um exemplo pronto ou fa\xe7a o tutorial interativo: ele come\xe7a localizando a sua \xe1rea no mapa de sat\xe9lite e baixando o relevo da internet, e segue em cerca de 70 passos curtos em que voc\xea mesmo navega, desenha, monta a rede e projeta; cada passo reconhece quando voc\xea o completou e avan\xe7a sozinho. Leva uns 20 minutos e pode ser pulado a qualquer momento (Ajuda \u2192 Tutorial interativo reabre depois).","CAD for pressurised irrigation design, right in the browser. Start from a ready example or take the interactive tutorial: it begins by locating your site on the satellite map and downloading the terrain from the internet, then goes on in about 70 short steps in which you navigate, draw, build the network and design it yourself; each step recognises when you have completed it and moves on. It takes about 20 minutes and can be skipped at any time (Help \u2192 Interactive tutorial reopens it).","CAD para dise\xf1o de riego presurizado, directamente en el navegador. Empiece por un ejemplo listo o haga el tutorial interactivo: comienza ubicando su \xe1rea en el mapa satelital y descargando el relieve de internet, y sigue en unos 70 pasos cortos en los que usted mismo navega, dibuja, arma la red y dise\xf1a; cada paso reconoce cuando lo complet\xf3 y avanza solo. Tarda unos 20 minutos y puede omitirse en cualquier momento (Ayuda \u2192 Tutorial interactivo lo reabre).")
B.zI=new A.a("Comece por um exemplo","Start from an example","Empiece por un ejemplo")
B.mP=new A.a("Cada projeto abre pronto para calcular: pressione F5 ou \u25b6 e veja zonas, press\xf5es, di\xe2metros e lista de materiais. Arquivo \u2192 Exemplos reabre qualquer um deles.","Each project opens ready to design: press F5 or \u25b6 and see zones, pressures, pipe sizes and the bill of materials. File \u2192 Examples reopens any of them.","Cada proyecto se abre listo para calcular: pulse F5 o \u25b6 y vea zonas, presiones, di\xe1metros y lista de materiales. Archivo \u2192 Ejemplos reabre cualquiera de ellos.")
B.r6=new A.a("Iniciar tutorial","Start tutorial","Iniciar tutorial")
B.BW=new A.a("Come\xe7ar do zero","Start from scratch","Empezar de cero")
B.qz=new A.a("Pomar","Orchard","Huerto")
B.li=new A.a("Microaspers\xe3o em citros e gotejamento em uva, po\xe7o com bomba e filtro, terreno em declive.","Micro-sprinklers on citrus and drip on grapes, well with pump and filter, sloping ground.","Microaspersi\xf3n en c\xedtricos y goteo en uva, pozo con bomba y filtro, terreno en pendiente.")
B.nb=new A.a("2 zonas \xb7 1,1 ha \xb7 po\xe7o + bomba","2 zones \xb7 1.1 ha \xb7 well + pump","2 zonas \xb7 1,1 ha \xb7 pozo + bomba")
B.bJ=new A.a("Jardim residencial","Residential garden","Jard\xedn residencial")
B.mN=new A.a("Sprays pop-up no gramado da frente, rotores nos fundos e gotejamento nos canteiros, ligados \xe0 rede p\xfablica com hidr\xf4metro e anti-refluxo.","Pop-up sprays on the front lawn, rotors at the back and drip in the beds, fed by the mains with a meter and a backflow preventer.","Difusores emergentes en el c\xe9sped frontal, rotores atr\xe1s y goteo en los canteros, conectados a la red p\xfablica con contador y antirretorno.")
B.vm=new A.a("3 zonas \xb7 640 m\xb2 \xb7 rede p\xfablica","3 zones \xb7 640 m\xb2 \xb7 mains supply","3 zonas \xb7 640 m\xb2 \xb7 red p\xfablica")
B.cD=new A.a("Campo de futebol","Football pitch","Campo de f\xfatbol")
B.kE=new A.a("Campo oficial 105 \xd7 68 m com aspersores de impacto em cinco linhas, reservat\xf3rio, bomba e turnos noturnos.","Full-size 105 \xd7 68 m pitch with impact sprinklers in five rows, reservoir, pump and night-time shifts.","Campo oficial de 105 \xd7 68 m con aspersores de impacto en cinco filas, dep\xf3sito, bomba y turnos nocturnos.")
B.Cn=new A.a("5 zonas \xb7 40 aspersores \xb7 bomba","5 zones \xb7 40 sprinklers \xb7 pump","5 zonas \xb7 40 aspersores \xb7 bomba")
B.hW=new A.a("Lavoura gotejada","Drip row crop","Cultivo en hileras con goteo")
B.rw=new A.a("Quatro talh\xf5es de tomate com fita gotejadora, submains com v\xe1lvulas, filtro de tela, bomba e terreno em declive.","Four tomato blocks on drip tape, submains with valves, screen filter, pump and sloping ground.","Cuatro parcelas de tomate con cinta de goteo, submains con v\xe1lvulas, filtro de malla, bomba y terreno en pendiente.")
B.Dr=new A.a("4 zonas \xb7 2,9 ha \xb7 filtro + bomba","4 zones \xb7 2.9 ha \xb7 filter + pump","4 zonas \xb7 2,9 ha \xb7 filtro + bomba")
B.yK=new A.a("Piv\xf4 de 300 m em milho alimentado por adutora, po\xe7o e bomba; relat\xf3rio de torres, v\xe3os e bocais.","A 300 m pivot on maize fed by a mainline, well and pump; tower, span and sprinkler report.","Pivote de 300 m en ma\xedz alimentado por conducci\xf3n, pozo y bomba; informe de torres, tramos y boquillas.")
B.kH=new A.a("1 piv\xf4 \xb7 28 ha \xb7 po\xe7o + bomba","1 pivot \xb7 28 ha \xb7 well + pump","1 pivote \xb7 28 ha \xb7 pozo + bomba")
B.jS=new A.a("Turno {n} \u2014 {z}","Shift {n} \u2014 {z}","Turno {n} \u2014 {z}")
B.k7=new A.a("Resid\xeancia Exemplo","Example Residence","Residencia Ejemplo")
B.jJ=new A.a("Lote 16 \xd7 40 m","Lot 16 \xd7 40 m","Lote 16 \xd7 40 m")
B.ww=new A.a("Jardim residencial \u2014 exemplo OpenCADIrrigation","Residential garden \u2014 OpenCADIrrigation example","Jard\xedn residencial \u2014 ejemplo OpenCADIrrigation")
B.p4=new A.a("Lote","Lot","Lote")
B.lt=new A.a("Casa","House","Casa")
B.mg=new A.a("Gramado da frente","Front lawn","C\xe9sped frontal")
B.yC=new A.a("Gramado dos fundos","Back lawn","C\xe9sped trasero")
B.ls=new A.a("Canteiro","Bed","Cantero")
B.hy=new A.a("Zona 1 \u2014 sprays","Zone 1 \u2014 sprays","Zona 1 \u2014 difusores")
B.oX=new A.a("Zona 2 \u2014 rotores","Zone 2 \u2014 rotors","Zona 2 \u2014 rotores")
B.ot=new A.a("Zona 3 \u2014 gotejamento","Zone 3 \u2014 drip","Zona 3 \u2014 goteo")
B.tT=new A.a("Rede p\xfablica","Mains supply","Red p\xfablica")
B.kP=new A.a("Arbustos","Shrubs","Arbustos")
B.rx=new A.a("Rua","Street","Calle")
B.cQ=new A.a("Clube Exemplo","Example Club","Club Ejemplo")
B.jg=new A.a("Campo oficial 105 \xd7 68 m","Full-size pitch 105 \xd7 68 m","Campo oficial 105 \xd7 68 m")
B.jO=new A.a("Campo de futebol \u2014 exemplo OpenCADIrrigation","Football pitch \u2014 OpenCADIrrigation example","Campo de f\xfatbol \u2014 ejemplo OpenCADIrrigation")
B.lq=new A.a("Campo","Pitch","Campo")
B.v5=new A.a("Linha {n}","Row {n}","Fila {n}")
B.a5=new A.a("Reservat\xf3rio","Reservoir","Dep\xf3sito")
B.cg=new A.a("Casa de bombas","Pump house","Casa de bombas")
B.c0=new A.a("Grama esportiva","Sports turf","C\xe9sped deportivo")
B.wE=new A.a("Lavoura gotejada","Drip row crop","Cultivo con goteo")
B.xR=new A.a("S\xedtio Exemplo","Example Farm","Finca Ejemplo")
B.Bx=new A.a("Talh\xf5es 1 a 4","Blocks 1 to 4","Parcelas 1 a 4")
B.zy=new A.a("Lavoura de tomate gotejada \u2014 exemplo OpenCADIrrigation","Drip-irrigated tomato field \u2014 OpenCADIrrigation example","Cultivo de tomate con goteo \u2014 ejemplo OpenCADIrrigation")
B.Q=new A.a("Talh\xe3o {n}","Block {n}","Parcela {n}")
B.cr=new A.a("Tronco","Trunk","Tronco")
B.aK=new A.a("Ramal oeste","West branch","Ramal oeste")
B.aw=new A.a("Ramal leste","East branch","Ramal este")
B.O=new A.a("Estrada","Road","Camino")
B.r=new A.a("Gleba","Field","Campo")
B.tJ=new A.a("Piv\xf4 1 \u2014 raio 300 m","Pivot 1 \u2014 300 m radius","Pivote 1 \u2014 radio 300 m")
B.jq=new A.a("Piv\xf4 central \u2014 exemplo OpenCADIrrigation","Centre pivot \u2014 OpenCADIrrigation example","Pivote central \u2014 ejemplo OpenCADIrrigation")
B.yh=new A.a("Piv\xf4 1","Pivot 1","Pivote 1")
B.G=new A.a("Adutora","Mainline","Conducci\xf3n")
B.cw=new A.a("\xc1rea do piv\xf4","Pivot area","\xc1rea del pivote")
B.cI=new A.a("Estufa de hortali\xe7as","Vegetable greenhouse","Invernadero de hortalizas")
B.uI=new A.a("Quatro t\xfaneis de piment\xe3o com tubo gotejador autocompensante, uma zona por t\xfanel, reservat\xf3rio, bomba pequena e filtro de discos.","Four pepper tunnels on pressure-compensating dripline, one zone per tunnel, tank, small pump and disc filter.","Cuatro t\xfaneles de pimiento con tuber\xeda de goteo autocompensante, una zona por t\xfanel, dep\xf3sito, bomba peque\xf1a y filtro de discos.")
B.jw=new A.a("4 zonas \xb7 1.800 m\xb2 \xb7 reservat\xf3rio + bomba","4 zones \xb7 1,800 m\xb2 \xb7 tank + pump","4 zonas \xb7 1.800 m\xb2 \xb7 dep\xf3sito + bomba")
B.bG=new A.a("Viveiro de mudas","Plant nursery","Vivero de plantas")
B.xG=new A.a("Tr\xeas canteiros de 12 \xd7 48 m com microaspersores suspensos em malha 4 \xd7 4 m, uma zona por canteiro, caixa d\u2019\xe1gua elevada, bomba pequena e filtro de discos.","Three 12 \xd7 48 m beds under overhead micro-sprinklers on a 4 \xd7 4 m grid, one zone per bed, elevated tank, small pump and disc filter.","Tres canteros de 12 \xd7 48 m con microaspersores suspendidos en malla de 4 \xd7 4 m, una zona por cantero, tanque elevado, bomba peque\xf1a y filtro de discos.")
B.jQ=new A.a("3 zonas \xb7 108 microaspersores \xb7 bomba","3 zones \xb7 108 micro-sprinklers \xb7 pump","3 zonas \xb7 108 microaspersores \xb7 bomba")
B.c1=new A.a("Cafezal em curvas de n\xedvel","Coffee on contour lines","Cafetal en curvas de nivel")
B.uW=new A.a("Tr\xeas talh\xf5es de caf\xe9 em encosta com laterais curvas que seguem as curvas de n\xedvel (bloco guiado), tubo gotejador PC, po\xe7o e bomba no p\xe9 do morro.","Three coffee blocks on a hillside with curved laterals following the contours (guided block), PC dripline, well and pump at the foot of the slope.","Tres parcelas de caf\xe9 en ladera con laterales curvos que siguen las curvas de nivel (bloque guiado), tuber\xeda de goteo PC, pozo y bomba al pie de la pendiente.")
B.z2=new A.a("3 zonas \xb7 2,7 ha \xb7 po\xe7o + bomba","3 zones \xb7 2.7 ha \xb7 well + pump","3 zonas \xb7 2,7 ha \xb7 pozo + bomba")
B.cO=new A.a("Bananal","Banana plantation","Platanal")
B.w8=new A.a("Dois talh\xf5es de banana com microaspersores autocompensantes em 5 \xd7 5 m, po\xe7o com bomba submersa, filtro de discos e terreno em declive.","Two banana blocks under pressure-compensating micro-sprinklers at 5 \xd7 5 m, well with submersible pump, disc filter and sloping ground.","Dos parcelas de banano con microaspersores autocompensantes a 5 \xd7 5 m, pozo con bomba sumergible, filtro de discos y terreno en pendiente.")
B.xn=new A.a("2 zonas \xb7 1,2 ha \xb7 bomba submersa","2 zones \xb7 1.2 ha \xb7 submersible pump","2 zonas \xb7 1,2 ha \xb7 bomba sumergible")
B.ch=new A.a("Cana-de-a\xe7\xfacar subsuperficial","Subsurface drip sugarcane","Ca\xf1a de az\xfacar con goteo subterr\xe1neo")
B.oI=new A.a("Dois talh\xf5es de cana com tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, submains enterrados, reservat\xf3rio, bomba, filtro de tela e ventosa.","Two sugarcane blocks on 20 mm PC dripline buried 0.3 m deep, 180 m laterals, buried submains, reservoir, pump, screen filter and air valve.","Dos parcelas de ca\xf1a con tuber\xeda de goteo PC de 20 mm enterrada a 0,3 m, laterales de 180 m, submains enterrados, dep\xf3sito, bomba, filtro de malla y ventosa.")
B.ly=new A.a("2 zonas \xb7 3,2 ha \xb7 filtro + bomba","2 zones \xb7 3.2 ha \xb7 filter + pump","2 zonas \xb7 3,2 ha \xb7 filtro + bomba")
B.bA=new A.a("Gotejamento por gravidade","Gravity-fed drip","Goteo por gravedad")
B.iD=new A.a("Reservat\xf3rio 40 m acima de dois talh\xf5es de hortali\xe7as gotejados, sem bomba: registro, v\xe1lvula reguladora de press\xe3o e filtro de discos na adutora; curvas de n\xedvel da encosta.","A reservoir 40 m above two drip-irrigated vegetable blocks, no pump: gate valve, pressure reducing valve and disc filter on the mainline; hillside contours.","Dep\xf3sito 40 m por encima de dos parcelas de hortalizas con goteo, sin bomba: v\xe1lvula de compuerta, reguladora de presi\xf3n y filtro de discos en la conducci\xf3n; curvas de nivel de la ladera.")
B.i5=new A.a("2 zonas \xb7 1,2 ha \xb7 sem bomba","2 zones \xb7 1.2 ha \xb7 no pump","2 zonas \xb7 1,2 ha \xb7 sin bomba")
B.cJ=new A.a("Pastagem em aspers\xe3o","Sprinkler-irrigated pasture","Pastura con aspersi\xf3n")
B.hL=new A.a("Tr\xeas piquetes de 72 \xd7 72 m com linhas de aspersores de impacto em 12 \xd7 18 m, submains com v\xe1lvulas, reservat\xf3rio, bomba e v\xe1lvula de reten\xe7\xe3o.","Three 72 \xd7 72 m paddocks with impact-sprinkler spray lines at 12 \xd7 18 m, submains with valves, reservoir, pump and check valve.","Tres potreros de 72 \xd7 72 m con l\xedneas de aspersores de impacto a 12 \xd7 18 m, submains con v\xe1lvulas, dep\xf3sito, bomba y v\xe1lvula de retenci\xf3n.")
B.iy=new A.a("3 zonas \xb7 1,6 ha \xb7 72 aspersores","3 zones \xb7 1.6 ha \xb7 72 sprinklers","3 zonas \xb7 1,6 ha \xb7 72 aspersores")
B.bR=new A.a("Buraco de golfe","Golf hole","Hoyo de golf")
B.AM=new A.a("Tee com sprays, fairway com rotores em malha triangular (duas zonas) e green com rotores no per\xedmetro, lago com bomba e turnos noturnos.","Tee with sprays, fairway with rotors on a triangular grid (two zones) and green with rotors around the edge, pond with pump and night-time shifts.","Tee con difusores, fairway con rotores en malla triangular (dos zonas) y green con rotores en el per\xedmetro, laguna con bomba y turnos nocturnos.")
B.iA=new A.a("4 zonas \xb7 64 emissores \xb7 lago + bomba","4 zones \xb7 64 heads \xb7 pond + pump","4 zonas \xb7 64 emisores \xb7 laguna + bomba")
B.rY=new A.a("Piv\xf4 setorial com canh\xe3o","Sector pivot with end gun","Pivote sectorial con ca\xf1\xf3n")
B.Dd=new A.a("Piv\xf4 de 250 m em soja que gira 270\xb0, deixando livre o quadrante da sede, com canh\xe3o final de 12 m\xb3/h; lago, bomba de 30 cv e registro.","A 250 m pivot on soybean sweeping 270\xb0, leaving the farmstead quadrant free, with a 12 m\xb3/h end gun; pond, 30 hp pump and gate valve.","Pivote de 250 m en soja que gira 270\xb0, dejando libre el cuadrante del casco, con ca\xf1\xf3n final de 12 m\xb3/h; laguna, bomba de 30 CV y v\xe1lvula de compuerta.")
B.vt=new A.a("1 piv\xf4 \xb7 15,7 ha \xb7 lago + bomba","1 pivot \xb7 15.7 ha \xb7 pond + pump","1 pivote \xb7 15,7 ha \xb7 laguna + bomba")
B.cz=new A.a("Piv\xf4 linear","Linear move","Pivote lineal")
B.vD=new A.a("Lateral m\xf3vel de 392 m em trigo percorrendo 800 m ao longo de um canal, capta\xe7\xe3o com bomba de 30 cv e v\xe1lvula de reten\xe7\xe3o; relat\xf3rio de torres e bocais.","A 392 m lateral-move machine on wheat travelling 800 m along a canal, intake with a 30 hp pump and check valve; tower and sprinkler report.","Lateral de avance frontal de 392 m en trigo que recorre 800 m a lo largo de un canal, toma con bomba de 30 CV y v\xe1lvula de retenci\xf3n; informe de torres y boquillas.")
B.rd=new A.a("1 linear \xb7 32 ha \xb7 canal + bomba","1 linear \xb7 32 ha \xb7 canal + pump","1 lineal \xb7 32 ha \xb7 canal + bomba")
B.BT=new A.a("Hortifruti Exemplo","Example Growers","Hortalizas Ejemplo")
B.C2=new A.a("T\xfaneis 1 a 4","Tunnels 1 to 4","T\xfaneles 1 a 4")
B.ul=new A.a("Estufa de hortali\xe7as \u2014 exemplo OpenCADIrrigation","Vegetable greenhouse \u2014 OpenCADIrrigation example","Invernadero de hortalizas \u2014 ejemplo OpenCADIrrigation")
B.cm=new A.a("Terreno","Site","Terreno")
B.rB=new A.a("T\xfanel {n}","Tunnel {n}","T\xfanel {n}")
B.C3=new A.a("Piment\xe3o","Bell pepper","Pimiento")
B.v7=new A.a("Viveiro Exemplo","Example Nursery","Vivero Ejemplo")
B.yI=new A.a("Canteiros 1 a 3","Beds 1 to 3","Canteros 1 a 3")
B.ka=new A.a("Viveiro de mudas \u2014 exemplo OpenCADIrrigation","Plant nursery \u2014 OpenCADIrrigation example","Vivero de plantas \u2014 ejemplo OpenCADIrrigation")
B.ub=new A.a("Canteiro {n}","Bed {n}","Cantero {n}")
B.py=new A.a("Mudas","Seedlings","Plantines")
B.ri=new A.a("Caixa d\u2019\xe1gua","Tank","Tanque")
B.na=new A.a("Encosta norte \u2014 talh\xf5es 1 a 3","North slope \u2014 blocks 1 to 3","Ladera norte \u2014 parcelas 1 a 3")
B.r7=new A.a("Cafezal em curvas de n\xedvel \u2014 exemplo OpenCADIrrigation","Coffee on contour lines \u2014 OpenCADIrrigation example","Cafetal en curvas de nivel \u2014 ejemplo OpenCADIrrigation")
B.aJ=new A.a("Talh\xf5es 1 e 2","Blocks 1 and 2","Parcelas 1 y 2")
B.zm=new A.a("Bananal \u2014 exemplo OpenCADIrrigation","Banana plantation \u2014 OpenCADIrrigation example","Platanal \u2014 ejemplo OpenCADIrrigation")
B.px=new A.a("Usina Exemplo","Example Mill","Ingenio Ejemplo")
B.tS=new A.a("Cana-de-a\xe7\xfacar em gotejamento subsuperficial \u2014 exemplo OpenCADIrrigation","Subsurface drip sugarcane \u2014 OpenCADIrrigation example","Ca\xf1a de az\xfacar con goteo subterr\xe1neo \u2014 ejemplo OpenCADIrrigation")
B.D6=new A.a("S\xedtio Exemplo","Example Smallholding","Finca Ejemplo")
B.C7=new A.a("Gotejamento por gravidade \u2014 exemplo OpenCADIrrigation","Gravity-fed drip \u2014 OpenCADIrrigation example","Goteo por gravedad \u2014 ejemplo OpenCADIrrigation")
B.zH=new A.a("Reservat\xf3rio no alto","Hilltop reservoir","Dep\xf3sito en lo alto")
B.Al=new A.a("V\xe1lvula reguladora de press\xe3o","Pressure reducing valve","V\xe1lvula reguladora de presi\xf3n")
B.i4=new A.a("Piquetes 1 a 3","Paddocks 1 to 3","Potreros 1 a 3")
B.q7=new A.a("Pastagem em aspers\xe3o \u2014 exemplo OpenCADIrrigation","Sprinkler-irrigated pasture \u2014 OpenCADIrrigation example","Pastura con aspersi\xf3n \u2014 ejemplo OpenCADIrrigation")
B.tQ=new A.a("Piquete {n}","Paddock {n}","Potrero {n}")
B.qu=new A.a("Pastagem","Pasture","Pastura")
B.lx=new A.a("Cerca","Fence","Cerco")
B.ys=new A.a("Buraco 1 \u2014 par 4","Hole 1 \u2014 par 4","Hoyo 1 \u2014 par 4")
B.yM=new A.a("Buraco de golfe \u2014 exemplo OpenCADIrrigation","Golf hole \u2014 OpenCADIrrigation example","Hoyo de golf \u2014 ejemplo OpenCADIrrigation")
B.tm=new A.a("Tee","Tee","Tee")
B.mT=new A.a("Fairway","Fairway","Fairway")
B.op=new A.a("Fairway {n}","Fairway {n}","Fairway {n}")
B.nt=new A.a("Green","Green","Green")
B.zQ=new A.a("Bunker","Bunker","B\xfanker")
B.c8=new A.a("Lago","Pond","Laguna")
B.oP=new A.a("Piv\xf4 setorial","Sector pivot","Pivote sectorial")
B.vh=new A.a("Piv\xf4 2 \u2014 raio 250 m, setor de 270\xb0","Pivot 2 \u2014 250 m radius, 270\xb0 sector","Pivote 2 \u2014 radio 250 m, sector de 270\xb0")
B.nw=new A.a("Piv\xf4 setorial com canh\xe3o final \u2014 exemplo OpenCADIrrigation","Sector pivot with end gun \u2014 OpenCADIrrigation example","Pivote sectorial con ca\xf1\xf3n final \u2014 ejemplo OpenCADIrrigation")
B.qU=new A.a("Piv\xf4 2","Pivot 2","Pivote 2")
B.rX=new A.a("Soja","Soybean","Soja")
B.rS=new A.a("Sede","Farmstead","Casco")
B.nA=new A.a("Linear 1 \u2014 392 \xd7 800 m","Linear 1 \u2014 392 \xd7 800 m","Lineal 1 \u2014 392 \xd7 800 m")
B.yR=new A.a("Piv\xf4 linear \u2014 exemplo OpenCADIrrigation","Linear move \u2014 OpenCADIrrigation example","Pivote lineal \u2014 ejemplo OpenCADIrrigation")
B.Bv=new A.a("Linear 1","Linear 1","Lineal 1")
B.tu=new A.a("Trigo","Wheat","Trigo")
B.lr=new A.a("Canal","Canal","Canal")
B.yr=new A.a("Capta\xe7\xe3o","Intake","Toma")
B.f5=new A.aM(B.f9,[B.ng,B.pX,B.bO,B.kO,B.mV,B.Cy,B.c9,B.ax,B.bV,B.cv,B.bT,B.F,B.t,B.cC,B.nz,B.bZ,B.bI,B.bD,B.i2,B.pQ,B.iR,B.jr,B.j8,B.vQ,B.j5,B.hP,B.B0,B.wo,B.lE,B.rj,B.bP,B.Bh,B.Cd,B.vG,B.qx,B.bU,B.jv,B.zo,B.lB,B.iP,B.ip,B.ol,B.pY,B.lR,B.wm,B.jm,B.kI,B.wX,B.pf,B.mL,B.uz,B.uw,B.ku,B.u8,B.oF,B.xP,B.uk,B.tR,B.kf,B.x2,B.mb,B.iw,B.m4,B.th,B.rz,B.rK,B.qK,B.x0,B.r0,B.ig,B.Bd,B.uu,B.yG,B.nS,B.q1,B.qe,B.xs,B.tM,B.vv,B.zi,B.pc,B.y0,B.yF,B.mR,B.tW,B.mo,B.kK,B.kl,B.aG,B.rr,B.n_,B.rG,B.xj,B.qs,B.rq,B.w_,B.ib,B.aO,B.zx,B.xK,B.qv,B.mF,B.Dx,B.bS,B.mz,B.n1,B.q5,B.qg,B.tO,B.BN,B.oZ,B.xQ,B.tz,B.wu,B.Dc,B.t8,B.hw,B.xL,B.m9,B.a3,B.lH,B.wY,B.uo,B.zU,B.mi,B.le,B.mv,B.Bw,B.A,B.aO,B.AC,B.xU,B.az,B.cu,B.iV,B.kx,B.cP,B.x3,B.ma,B.rl,B.nC,B.B_,B.mj,B.lg,B.zR,B.pS,B.c4,B.cP,B.aO,B.ru,B.uL,B.Dw,B.iO,B.bN,B.nY,B.uS,B.pG,B.CF,B.Dh,B.zv,B.we,B.uC,B.v0,B.u0,B.jW,B.pV,B.kt,B.nh,B.nO,B.p5,B.nB,B.vx,B.j1,B.a4,B.Br,B.B5,B.Cq,B.vJ,B.rP,B.i6,B.aB,B.A,B.yL,B.oD,B.a4,B.hK,B.CI,B.pn,B.oG,B.yW,B.AE,B.iu,B.ql,B.yo,B.rT,B.vU,B.yw,B.iv,B.uJ,B.mk,B.a3,B.lG,B.tc,B.uX,B.aL,B.lh,B.B1,B.jb,B.c6,B.a2,B.m0,B.ok,B.ay,B.ze,B.qd,B.cA,B.bC,B.pm,B.hR,B.xo,B.yf,B.oK,B.A_,B.ir,B.yH,B.yj,B.uD,B.oM,B.BO,B.p9,B.As,B.i8,B.pe,B.qD,B.rW,B.c4,B.q6,B.y9,B.io,B.tx,B.aM,B.bU,B.wt,B.lp,B.aE,B.cE,B.yJ,B.o3,B.a2,B.bM,B.Bl,B.zn,B.BL,B.yV,B.wM,B.wT,B.wA,B.rm,B.wd,B.bE,B.F,B.n9,B.A9,B.Dt,B.DA,B.vj,B.n0,B.CD,B.ay,B.ce,B.cM,B.qL,B.aN,B.vB,B.a3,B.im,B.iT,B.mU,B.iH,B.jU,B.lL,B.bQ,B.aI,B.A,B.od,B.ci,B.Bz,B.oE,B.qJ,B.Dl,B.BY,B.hM,B.cH,B.Dj,B.vA,B.Ds,B.CB,B.xu,B.F,B.t,B.aC,B.tZ,B.Aa,B.aD,B.l5,B.CW,B.wp,B.nE,B.kC,B.tY,B.kS,B.y6,B.kX,B.oJ,B.xF,B.z0,B.y7,B.o_,B.q8,B.AU,B.nP,B.ur,B.zl,B.vM,B.xA,B.vg,B.Cb,B.AF,B.w6,B.CZ,B.vT,B.mZ,B.F,B.bE,B.A,B.aC,B.jl,B.tN,B.cH,B.cL,B.cl,B.CH,B.yd,B.z1,B.D1,B.zL,B.kV,B.lD,B.mw,B.nZ,B.cE,B.lY,B.c7,B.qP,B.oR,B.y2,B.ih,B.hF,B.vo,B.nr,B.qk,B.a2,B.pF,B.BA,B.Da,B.aF,B.o2,B.jY,B.up,B.cx,B.aA,B.ay,B.cM,B.w7,B.BC,B.xe,B.Cg,B.Af,B.jG,B.yQ,B.kc,B.uN,B.rg,B.Au,B.vu,B.xb,B.B8,B.lS,B.BE,B.pW,B.qj,B.Ah,B.yB,B.r2,B.wU,B.tr,B.tf,B.Ba,B.xt,B.cN,B.aI,B.wj,B.hG,B.i_,B.nk,B.pE,B.v1,B.Bu,B.Ck,B.aB,B.nT,B.A,B.cB,B.cu,B.az,B.F,B.aA,B.wg,B.t1,B.ts,B.c7,B.aI,B.bD,B.a3,B.aF,B.B9,B.u6,B.z,B.jF,B.mc,B.xI,B.p7,B.p8,B.yT,B.xi,B.cj,B.cs,B.n5,B.zd,B.Co,B.P,B.CR,B.tb,B.qC,B.lz,B.p3,B.qB,B.pO,B.uM,B.nW,B.hJ,B.xg,B.hs,B.hr,B.yN,B.kY,B.nm,B.Bi,B.os,B.yi,B.oY,B.tD,B.qh,B.oy,B.iX,B.kJ,B.Ci,B.Bn,B.uy,B.mt,B.BP,B.m5,B.cb,B.v9,B.p_,B.Ai,B.vN,B.ic,B.xk,B.hO,B.l2,B.qH,B.cy,B.cb,B.hX,B.oN,B.n3,B.cy,B.wc,B.kj,B.p2,B.yU,B.pg,B.qn,B.bQ,B.aC,B.aD,B.wD,B.iC,B.uT,B.xS,B.aE,B.wS,B.cG,B.Ax,B.AN,B.CU,B.oW,B.lO,B.yX,B.lM,B.nV,B.tg,B.lc,B.vV,B.x9,B.x7,B.hB,B.wr,B.bX,B.lw,B.mY,B.kZ,B.AX,B.qo,B.r1,B.tt,B.wl,B.c6,B.qG,B.nI,B.jV,B.tK,B.ci,B.A,B.lQ,B.me,B.uO,B.ms,B.ya,B.xY,B.qm,B.AV,B.k3,B.yn,B.ce,B.nu,B.k0,B.cd,B.l7,B.xC,B.oa,B.AQ,B.y3,B.ji,B.zS,B.qX,B.zu,B.BZ,B.tE,B.w0,B.uA,B.oQ,B.hv,B.uK,B.mq,B.aB,B.A,B.c_,B.cB,B.az,B.tL,B.aE,B.m_,B.uf,B.lo,B.CV,B.hY,B.a2,B.bM,B.hQ,B.CP,B.cL,B.cl,B.AK,B.ln,B.xH,B.vr,B.AO,B.CN,B.oB,B.co,B.lP,B.zV,B.jp,B.t6,B.qb,B.t2,B.t_,B.qr,B.qN,B.qi,B.wW,B.hC,B.kq,B.zE,B.AI,B.D8,B.qc,B.jL,B.vs,B.CK,B.wq,B.AL,B.rF,B.zb,B.jM,B.mu,B.po,B.zJ,B.t0,B.w4,B.y5,B.xv,B.js,B.A0,B.o9,B.zp,B.qQ,B.xz,B.ii,B.ux,B.u2,B.Bf,B.B4,B.wf,B.nD,B.ca,B.nH,B.CS,B.i3,B.ck,B.wv,B.bW,B.uj,B.kN,B.mB,B.CY,B.BG,B.x1,B.on,B.iL,B.t9,B.hA,B.nU,B.hU,B.Cp,B.ow,B.CE,B.BR,B.z3,B.u5,B.oS,B.ti,B.pt,B.B2,B.D5,B.kW,B.te,B.qy,B.p1,B.lA,B.ki,B.C9,B.wn,B.kd,B.xD,B.ij,B.vC,B.Av,B.vX,B.hE,B.CC,B.C5,B.x6,B.rb,B.iq,B.pK,B.jj,B.wF,B.ov,B.zs,B.A2,B.i1,B.pz,B.kk,B.ie,B.k_,B.nj,B.Cf,B.Dk,B.tp,B.it,B.Dn,B.vF,B.tV,B.pT,B.l8,B.uR,B.rH,B.A7,B.xw,B.Az,B.Bo,B.oh,B.kF,B.nR,B.ry,B.wB,B.mD,B.la,B.zM,B.rn,B.iJ,B.lF,B.k5,B.Aw,B.oe,B.lX,B.wI,B.ca,B.um,B.kR,B.k8,B.nJ,B.q3,B.oc,B.mS,B.ax,B.k4,B.o7,B.m6,B.oA,B.vf,B.rh,B.xN,B.rQ,B.tU,B.q2,B.m7,B.Bp,B.hx,B.yc,B.A1,B.Bg,B.AR,B.z9,B.tP,B.w2,B.ju,B.iM,B.uU,B.Cm,B.w3,B.mn,B.yx,B.qZ,B.jy,B.tw,B.c2,B.P,B.yY,B.AT,B.wH,B.BX,B.cj,B.cs,B.cK,B.bL,B.ph,B.xX,B.cp,B.bz,B.bK,B.c3,B.bF,B.qt,B.lf,B.zO,B.uV,B.Aq,B.Dp,B.cf,B.cF,B.c_,B.yg,B.lv,B.C0,B.ox,B.pU,B.zY,B.kz,B.C4,B.zt,B.wC,B.pB,B.us,B.bS,B.aF,B.vb,B.bX,B.mX,B.cG,B.zF,B.aN,B.hS,B.xp,B.p6,B.Am,B.ve,B.rO,B.lK,B.ny,B.Ay,B.kG,B.B3,B.j4,B.jH,B.bB,B.lT,B.oi,B.bB,B.tq,B.zW,B.n4,B.cF,B.xO,B.mf,B.aG,B.CJ,B.BK,B.l_,B.i0,B.wL,B.zA,B.D_,B.vd,B.k2,B.xh,B.xr,B.rA,B.An,B.zj,B.A4,B.yl,B.tG,B.ye,B.u7,B.yA,B.z_,B.jK,B.D0,B.zr,B.jD,B.xa,B.rf,B.qR,B.w9,B.qO,B.rv,B.Ao,B.AJ,B.ja,B.iN,B.uH,B.zG,B.wP,B.nK,B.wy,B.lk,B.xq,B.jz,B.zK,B.oH,B.BV,B.iI,B.a4,B.kb,B.pP,B.wb,B.ko,B.tv,B.no,B.aA,B.j7,B.uc,B.pj,B.cd,B.vy,B.l4,B.cx,B.vp,B.BM,B.tl,B.iG,B.zg,B.hH,B.wV,B.rN,B.rI,B.o5,B.wi,B.kB,B.At,B.xd,B.rR,B.o6,B.x4,B.rk,B.m8,B.ob,B.r_,B.BI,B.Ae,B.Be,B.ro,B.xJ,B.pR,B.zC,B.A5,B.r8,B.Ac,B.xE,B.Cx,B.pr,B.Cj,B.j0,B.D4,B.yP,B.hD,B.AY,B.va,B.Du,B.iB,B.lW,B.oo,B.yv,B.kn,B.C1,B.Dv,B.iQ,B.oO,B.B6,B.ik,B.c5,B.iY,B.jx,B.aN,B.cc,B.zD,B.nc,B.pL,B.pM,B.cn,B.x5,B.v_,B.rM,B.AG,B.CM,B.hu,B.De,B.ix,B.p0,B.rt,B.pq,B.n2,B.kg,B.ia,B.wz,B.t5,B.vk,B.vw,B.to,B.jc,B.aG,B.pi,B.oC,B.xT,B.wK,B.vI,B.AD,B.pD,B.qT,B.l1,B.uG,B.Cv,B.iU,B.jR,B.ke,B.bH,B.mm,B.Df,B.pl,B.qI,B.jA,B.nn,B.c9,B.tn,B.Cu,B.Ab,B.qM,B.Bk,B.zT,B.mr,B.vY,B.aD,B.cf,B.wR,B.md,B.co,B.cq,B.BQ,B.mp,B.lZ,B.Ca,B.pw,B.aH,B.rJ,B.BS,B.ue,B.tk,B.qF,B.za,B.j9,B.ni,B.lV,B.nQ,B.mK,B.AH,B.ug,B.o8,B.D2,B.kp,B.o4,B.qa,B.uv,B.qW,B.C6,B.vO,B.om,B.lN,B.il,B.vi,B.rL,B.rp,B.aL,B.ll,B.cc,B.y1,B.k9,B.hV,B.zk,B.v3,B.yp,B.my,B.kU,B.pN,B.nd,B.oz,B.r5,B.wQ,B.pJ,B.xm,B.is,B.o1,B.nl,B.jo,B.A6,B.j2,B.q4,B.D3,B.w1,B.xZ,B.jd,B.ws,B.BD,B.rV,B.vW,B.ps,B.xM,B.bY,B.id,B.Aj,B.zq,B.vq,B.jE,B.jI,B.ui,B.k6,B.y8,B.pA,B.ct,B.uZ,B.Do,B.uh,B.ht,B.np,B.zc,B.qf,B.zf,B.vH,B.Dg,B.bY,B.AW,B.l6,B.Bb,B.ty,B.q9,B.oL,B.kM,B.Dm,B.oV,B.nL,B.cN,B.uq,B.oT,B.qY,B.j6,B.qq,B.t3,B.ct,B.pC,B.Cw,B.pd,B.vR,B.wZ,B.AS,B.tI,B.wG,B.tC,B.pH,B.nN,B.kA,B.mW,B.Bm,B.i7,B.pb,B.vn,B.m1,B.mG,B.Ar,B.lU,B.Cl,B.og,B.rZ,B.nf,B.BU,B.jt,B.lu,B.q_,B.kT,B.rC,B.yb,B.jZ,B.m3,B.lj,B.nq,B.vz,B.vL,B.zz,B.rc,B.Bq,B.re,B.or,B.r4,B.kw,B.z8,B.oU,B.n7,B.jk,B.vc,B.vK,B.BB,B.qV,B.wJ,B.yD,B.zP,B.oj,B.B7,B.k1,B.v8,B.u9,B.vZ,B.oq,B.iZ,B.wa,B.uE,B.yO,B.iS,B.rD,B.iW,B.qS,B.v4,B.xl,B.D9,B.Cz,B.lJ,B.jX,B.je,B.kv,B.CL,B.qp,B.x_,B.l3,B.Ak,B.wO,B.m2,B.kr,B.v6,B.BH,B.CT,B.uB,B.hz,B.u1,B.yu,B.yt,B.vl,B.z5,B.Cc,B.kh,B.yS,B.q0,B.uQ,B.AA,B.pZ,B.wN,B.y4,B.y_,B.yE,B.mM,B.of,B.C8,B.jf,B.yq,B.xV,B.uP,B.qw,B.mO,B.x8,B.zX,B.nM,B.jn,B.u_,B.mC,B.Dz,B.l9,B.CQ,B.Bj,B.un,B.t4,B.BJ,B.Cr,B.qE,B.t7,B.jC,B.uF,B.jP,B.uY,B.wh,B.n8,B.lI,B.ut,B.vS,B.Bc,B.z4,B.Di,B.km,B.ua,B.lb,B.rU,B.Db,B.AZ,B.tB,B.CG,B.u4,B.C_,B.nG,B.yk,B.tF,B.Ct,B.n6,B.jN,B.mh,B.mx,B.xf,B.iF,B.ym,B.hZ,B.xB,B.nv,B.yZ,B.Bt,B.ml,B.pp,B.ou,B.nX,B.A3,B.Ch,B.zB,B.ud,B.xy,B.xc,B.hT,B.lC,B.bO,B.aM,B.bZ,B.Bs,B.pI,B.bT,B.bV,B.cn,B.F,B.qA,B.ks,B.cC,B.ax,B.cv,B.bI,B.j_,B.vP,B.xx,B.z7,B.iK,B.ne,B.AP,B.z6,B.tA,B.pv,B.ck,B.bW,B.mA,B.yy,B.td,B.pk,B.cA,B.bC,B.aM,B.o0,B.ky,B.bH,B.Cs,B.yz,B.bP,B.c5,B.kL,B.bN,B.ra,B.a4,B.rs,B.jh,B.rE,B.zh,B.mQ,B.jT,B.CO,B.kQ,B.u3,B.hN,B.j3,B.iE,B.wk,B.CA,B.jB,B.cq,B.vE,B.r9,B.ns,B.nF,B.pu,B.v2,B.r3,B.l0,B.mH,B.BF,B.nx,B.Ap,B.tH,B.mJ,B.xW,B.AB,B.i9,B.mI,B.ld,B.Dy,B.ta,B.tX,B.Ad,B.w5,B.wx,B.zw,B.Ag,B.A8,B.By,B.pa,B.Dq,B.zN,B.tj,B.kD,B.hI,B.iz,B.CX,B.zZ,B.mE,B.lm,B.Ce,B.D7,B.zI,B.mP,B.r6,B.BW,B.qz,B.li,B.nb,B.bJ,B.mN,B.vm,B.cD,B.kE,B.Cn,B.hW,B.rw,B.Dr,B.aH,B.yK,B.kH,B.jS,B.bJ,B.k7,B.jJ,B.ww,B.p4,B.lt,B.mg,B.yC,B.ls,B.hy,B.oX,B.ot,B.tT,B.bF,B.kP,B.t,B.rx,B.cD,B.cQ,B.jg,B.jO,B.lq,B.v5,B.a5,B.cg,B.c0,B.t,B.wE,B.xR,B.Bx,B.zy,B.Q,B.cp,B.a5,B.cr,B.aK,B.aw,B.O,B.r,B.aH,B.z,B.tJ,B.jq,B.yh,B.P,B.bz,B.G,B.cw,B.r,B.cI,B.uI,B.jw,B.bG,B.xG,B.jQ,B.c1,B.uW,B.z2,B.cO,B.w8,B.xn,B.ch,B.oI,B.ly,B.bA,B.iD,B.i5,B.cJ,B.hL,B.iy,B.bR,B.AM,B.iA,B.rY,B.Dd,B.vt,B.cz,B.vD,B.rd,B.cI,B.BT,B.C2,B.ul,B.cm,B.rB,B.C3,B.c2,B.t,B.bG,B.v7,B.yI,B.ka,B.cm,B.ub,B.py,B.ri,B.t,B.c1,B.z,B.na,B.r7,B.Q,B.cK,B.P,B.G,B.r,B.cO,B.z,B.aJ,B.zm,B.Q,B.bL,B.P,B.r,B.O,B.G,B.ch,B.px,B.aJ,B.tS,B.Q,B.bK,B.r,B.O,B.a5,B.cr,B.aK,B.aw,B.bA,B.D6,B.aJ,B.C7,B.Q,B.c3,B.zH,B.Al,B.r,B.G,B.aK,B.aw,B.cJ,B.z,B.i4,B.q7,B.tQ,B.qu,B.lx,B.O,B.a5,B.t,B.bR,B.cQ,B.ys,B.yM,B.tm,B.mT,B.op,B.nt,B.zQ,B.c8,B.c0,B.cg,B.t,B.oP,B.z,B.vh,B.nw,B.qU,B.rX,B.c8,B.rS,B.cw,B.r,B.O,B.G,B.cz,B.z,B.nA,B.yR,B.Bv,B.tu,B.lr,B.yr,B.aL,B.r,B.G],A.T("aM<c,+(c,c,c)>"))
B.a0={}
B.br=new A.aM(B.a0,[],A.T("aM<c,q<+(J,e)>>"))
B.aq=new A.aM(B.a0,[],A.T("aM<c,c>"))
B.f7={DRAWING:0,TEXT:1,DIMENSIONS:2,CONTOURS:3,SPOT_HEIGHTS:4,DEM:5,ZONE_PIPES:6,MAINLINE_PIPES:7,SPRAYLINES:8,TAPES:9,OUTLETS:10,WETTED_RADII:11,CONTROL_VALVES:12,WATER_SUPPLY:13,PUMPS:14,MISC_HYDRAULIC:15,JUNCTIONS:16,AREAS:17,LABELS:18,IMAGES:19,HATCHES:20,SYMBOLS:21,PIVOTS:22}
B.f6=new A.aM(B.f7,[4289773253,4293718001,4287669422,4287458915,4288776319,4286483095,4282557941,4280191205,4280731354,4284922730,4280923894,1428797174,4294944550,4286470082,4293874512,4294953512,4286091420,867095937,4291811548,4294967295,4286091420,4289773253,4283283116],A.T("aM<c,f>"))
B.av=new A.B(0,0)
B.fj=new A.cP(0,0,0,1)
B.fk=new A.n(0.0016666666666666666,12)
B.fl=new A.n(0.011111111111111112,65)
B.bw=new A.n(0,0)
B.fm=new A.n(0,110)
B.fn=new A.n(0,27)
B.fo=new A.n(0,37)
B.fp=new A.n(0,45)
B.fq=new A.n(0,50)
B.fr=new A.n(0,53)
B.fs=new A.n(0,58)
B.ft=new A.n(0,60)
B.fu=new A.n(0,63)
B.fv=new A.n(0,70)
B.fw=new A.n(0,72)
B.bx=new A.n(0,78)
B.fx=new A.n(0,80)
B.fy=new A.n(0,82)
B.fz=new A.n(0,85)
B.by=new A.n(0,90)
B.fA=new A.n(0.044444444444444446,55)
B.fB=new A.n(0.041666666666666664,78)
B.fC=new A.n(0.002777777777777778,18)
B.fD=new A.n(0.0011111111111111111,20)
B.fE=new A.n(0.0005555555555555556,25)
B.fF=new A.n(0.06388888888888888,38)
B.fG=new A.n(0.001388888888888889,41)
B.fH=new A.n(0.03333333333333333,55)
B.fI=new A.n(0.022222222222222223,31)
B.fJ=new A.n(0.03888888888888889,40)
B.fK=new A.n(0.0022222222222222222,55)
B.fL=new A.n(0.006944444444444444,60)
B.fM=new A.n(0.005555555555555556,53)
B.fN=new A.n(0.003333333333333333,36)
B.fO=new A.n(0.0011111111111111111,68)
B.fP=new A.n("","")
B.fQ=new A.n(0.0019444444444444444,28)
B.fR=new A.n(0.03194444444444444,72)
B.fS=new A.n(0.015277777777777777,45)
B.fT=new A.n(0.016666666666666666,30)
B.fU=new A.n(0.005555555555555556,80)
B.fV=new A.n(0.011666666666666667,27)
B.fW=new A.n(0.016666666666666666,42)
B.fX=new A.n(0.011111111111111112,45)
B.fY=new A.n(0.0075,26)
B.fZ=new A.n(0.0016666666666666666,80)
B.h_=new A.n(0.09166666666666666,42)
B.h0=new A.n(0.0077777777777777776,55)
B.h1=new A.n(0.027777777777777776,33)
B.h2=new A.n(0.0077777777777777776,40)
B.h3=new A.n(0.0025,46)
B.h4=new A.n(0.0038888888888888888,49)
B.h5=new A.n(0.022222222222222223,52)
B.h6=new A.n(0.009722222222222222,40)
B.h7=new A.n(0.004166666666666667,25)
B.h8=new A.n(0.027777777777777776,60)
B.h9=new A.n(0.013888888888888888,74)
B.ha=new A.n(0.11666666666666667,45)
B.hb=new A.n(0.022222222222222223,66)
B.hc=new A.n(0.0077777777777777776,98)
B.hd=new A.n(0.019444444444444445,48)
B.he=new A.n(0.005,42)
B.hf=new A.n(0.08333333333333333,65)
B.hg=new A.n(0.002777777777777778,35)
B.hh=new A.n(0,1/0)
B.hi=new A.n(0.003333333333333333,72)
B.hj=new A.n(0.05,38)
B.hk=new A.n(0.016666666666666666,64)
B.hl=new A.n(0.06388888888888888,60)
B.hm=new A.n(0.015277777777777777,80)
B.hn=new A.n(0.0009722222222222222,34)
B.ho=new A.n(0.005,38)
B.hp=new A.n(0.003333333333333333,65)
B.hq=new A.n(0.009722222222222222,58)
B.DB=new A.cY([0,0,0,0])
B.fa={pump_s3:0,pump_s5:1,pump_sub:2,pump_s15:3,pump_s25:4,pump_s30:5}
B.DC=new A.bR(B.fa,6,t.lq)
B.DE=new A.bR(B.a0,0,t.lq)
B.DD=new A.bR(B.a0,0,A.T("bR<f>"))
B.DQ=A.bj("qz")
B.DR=A.bj("qA")
B.DS=A.bj("o1")
B.DT=A.bj("by")
B.DU=A.bj("o2")
B.DV=A.bj("o3")
B.DW=A.bj("o4")
B.DX=A.bj("K")
B.DY=A.bj("oB")
B.DZ=A.bj("oC")
B.E_=A.bj("oD")
B.E0=A.bj("lf")
B.cR=new A.dH(0,0,0,0,0,0,0,0,0,0)
B.cS=new A.eX(B.bi,B.be,B.bv,B.aY)})();(function staticFields(){$.jX=null
$.aW=A.d([],A.T("o<K>"))
$.m1=null
$.lI=null
$.lH=null
$.n_=null
$.mR=null
$.nb=null
$.kl=null
$.kw=null
$.lw=null
$.k1=A.d([],A.T("o<q<K>?>"))
$.d_=null
$.e_=null
$.e0=null
$.lo=!1
$.a6=B.u
$.kd=A.m(t.N,A.T("eu"))
$.la=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"qC","ng",()=>A.kp("_$dart_dartClosure"))
s($,"qB","lz",()=>A.kp("_$dart_dartClosure_dartJSInterop"))
s($,"qW","nv",()=>A.d([new J.em()],A.T("o<dA>")))
s($,"qI","nj",()=>A.bJ(A.jv({
toString:function(){return"$receiver$"}})))
s($,"qJ","nk",()=>A.bJ(A.jv({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"qK","nl",()=>A.bJ(A.jv(null)))
s($,"qL","nm",()=>A.bJ(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"qO","np",()=>A.bJ(A.jv(void 0)))
s($,"qP","nq",()=>A.bJ(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"qN","no",()=>A.bJ(A.mi(null)))
s($,"qM","nn",()=>A.bJ(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"qR","ns",()=>A.bJ(A.mi(void 0)))
s($,"qQ","nr",()=>A.bJ(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"qS","lA",()=>A.oG())
s($,"qU","nu",()=>A.oc(A.ph(A.d([-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-1,-2,-2,-2,-2,-2,62,-2,62,-2,63,52,53,54,55,56,57,58,59,60,61,-2,-2,-2,-1,-2,-2,-2,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-2,-2,-2,-2,63,-2,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,-2,-2,-2,-2,-2],t.X))))
s($,"qT","nt",()=>A.od(0))
s($,"qD","nh",()=>A.oq("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"qV","fy",()=>A.n7(B.DX))
s($,"qF","ni",()=>A.l3(0,"",B.av,B.h))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.cJ,SharedArrayBuffer:A.cJ,ArrayBufferView:A.dw,DataView:A.eA,Float32Array:A.eB,Float64Array:A.eC,Int16Array:A.eD,Int32Array:A.eE,Int8Array:A.eF,Uint16Array:A.eG,Uint32Array:A.eH,Uint8ClampedArray:A.dx,CanvasPixelArray:A.dx,Uint8Array:A.eI})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.cK.$nativeSuperclassTag="ArrayBufferView"
A.dN.$nativeSuperclassTag="ArrayBufferView"
A.dO.$nativeSuperclassTag="ArrayBufferView"
A.du.$nativeSuperclassTag="ArrayBufferView"
A.dP.$nativeSuperclassTag="ArrayBufferView"
A.dQ.$nativeSuperclassTag="ArrayBufferView"
A.dv.$nativeSuperclassTag="ArrayBufferView"})()
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
var s=A.qi
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()