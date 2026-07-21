import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import RulView from '../views/RulView.vue'
import AircraftDetailView from '../views/AircraftDetailView.vue'
import EngineDetailView from '../views/EngineDetailView.vue'
import SupplyDecisionView from '../views/SupplyDecisionView.vue'
import EasaDocsView from '../views/EasaDocsView.vue'
import EasaDocDetailView from '../views/EasaDocDetailView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: HomeView },
    { path: '/rul', name: 'rul', component: RulView },
    { path: '/easa-docs', name: 'easa-docs', component: EasaDocsView },
    {
      path: '/easa-docs/:docid',
      name: 'easa-doc-detail',
      component: EasaDocDetailView,
      props: true,
    },
    { path: '/supply/:aircraftid?', name: 'supply-decision', component: SupplyDecisionView },
    {
      path: '/aircraft/:aircraftid',
      name: 'aircraft-detail',
      component: AircraftDetailView,
      props: true,
    },
    {
      path: '/aircraft/:aircraftid/engine/:engineid',
      name: 'engine-detail',
      component: EngineDetailView,
      props: true,
    },
  ],
})

export default router
